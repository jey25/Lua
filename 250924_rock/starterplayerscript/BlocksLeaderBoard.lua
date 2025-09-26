--!strict
-- StarterPlayerScripts/BlocksLeaderboard.client.lua
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LBEvent = RS:WaitForChild("BlocksLeaderboard") :: RemoteEvent

-- StarterPlayerScripts/BlocksLeaderboard.client.lua
-- ...생략...

local function ensureGui(): Frame
	local root = playerGui:FindFirstChild("BlocksLeaderboardGui") :: ScreenGui?
	if not root then
		root = Instance.new("ScreenGui")
		root.Name = "BlocksLeaderboardGui"
		root.ResetOnSpawn = false
		root.IgnoreGuiInset = true
		root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		root.Parent = playerGui
	end

	local panel = root:FindFirstChild("Panel") :: Frame?
	if not panel then
		panel = Instance.new("Frame")
		panel.Name = "Panel"
		panel.AnchorPoint = Vector2.new(1, 0.5)
		panel.Position = UDim2.fromScale(0.999, 0.4)
		panel.Size = UDim2.fromScale(0.25, 0.60)
		panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
		panel.BackgroundTransparency = 0.2
		panel.Parent = root

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = panel

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, -20, 0, 36)
		title.Position = UDim2.fromOffset(10, 8)
		title.Font = Enum.Font.GothamBold
		title.TextScaled = true
		title.TextSize = 15
		title.TextColor3 = Color3.fromRGB(255, 230, 120)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = "GLOBAL RANKING"
		title.Parent = panel

		local sizeConstraint = Instance.new("UITextSizeConstraint")
		sizeConstraint.MinTextSize = 12
		sizeConstraint.MaxTextSize = 24
		sizeConstraint.Parent = title

		local list = Instance.new("ScrollingFrame")
		list.Name = "List"
		list.AnchorPoint = Vector2.new(0.5, 1)
		list.Position = UDim2.fromScale(0.5, 0.98)
		list.Size = UDim2.new(1, -16, 1, -56)
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 6
		list.CanvasSize = UDim2.fromOffset(0, 0)
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.Parent = panel

		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 3) -- ✅ 간격 줄이기 (기존 6)
		layout.Parent = list
	end

	-- ✅ 패널이 이미 있었다면 간격을 항상 3으로 보정
	do
		local list = panel:FindFirstChild("List")
		local layout = list and list:FindFirstChildOfClass("UIListLayout")
		if layout then (layout :: UIListLayout).Padding = UDim.new(0, 3) end
	end

	return (root:FindFirstChild("Panel") :: Frame)
end

-- ...나머지 동일...


-- makeRow: 한 줄 높이와 폰트 크기 살짝 축소
local function makeRow(idx: number, name: string, count: number): Frame
	local ROW_H = 28       -- ✅ 32 → 28 (조금만 축소)
	local FONT = 14        -- ✅ 15 → 14
	local RANK_W = 28      -- ✅ 36 → 28
	local GAP = 6

	local row = Instance.new("Frame")
	row.Name = ("Row_%d"):format(idx)
	row.Size = UDim2.new(1, -8, 0, ROW_H)
	row.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	row.BackgroundTransparency = 0.2

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = row

	local rank = Instance.new("TextLabel")
	rank.Name = "Rank"
	rank.BackgroundTransparency = 1
	rank.Size = UDim2.new(0, RANK_W, 1, 0)
	rank.Position = UDim2.fromOffset(GAP, 0)
	rank.Font = Enum.Font.GothamBold
	rank.TextSize = FONT
	rank.TextColor3 = Color3.fromRGB(255, 230, 120)
	rank.TextXAlignment = Enum.TextXAlignment.Center
	rank.Text = tostring(idx)
	rank.Parent = row

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "Name"
	nameLbl.BackgroundTransparency = 1
	-- 좌측: GAP + RANK_W + GAP = 6 + 28 + 6 = 40
	nameLbl.Position = UDim2.fromOffset(GAP + RANK_W + GAP, 0) -- ✅ 40px
	nameLbl.Size = UDim2.new(1, -140, 1, 0) -- 필요시 -120로 더 타이트하게 가능
	nameLbl.Font = Enum.Font.Gotham
	nameLbl.TextSize = FONT
	nameLbl.TextColor3 = Color3.fromRGB(230, 230, 235)
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Text = name
	nameLbl.Parent = row

	local cnt = Instance.new("TextLabel")
	cnt.Name = "Count"
	cnt.BackgroundTransparency = 1
	cnt.AnchorPoint = Vector2.new(1, 0)
	cnt.Position = UDim2.new(1, -10, 0, 0)
	cnt.Size = UDim2.new(0, 90, 1, 0)
	cnt.Font = Enum.Font.GothamBold
	cnt.TextSize = FONT
	cnt.TextColor3 = Color3.fromRGB(255, 230, 120)
	cnt.TextXAlignment = Enum.TextXAlignment.Right
	cnt.Text = tostring(count)
	cnt.Parent = row

	return row
end


local function renderTop(listData: { {userId: number, name: string, blocks: number} })
	local panel = ensureGui()
	local list = panel:FindFirstChild("List") :: ScrollingFrame
	if not list then return end

	-- clear
	for _, ch in ipairs(list:GetChildren()) do
		if ch:IsA("Frame") then ch:Destroy() end
	end

	for i, item in ipairs(listData) do
		local row = makeRow(i, item.name, item.blocks)
		row.LayoutOrder = i
		row.Parent = list
	end
end

LBEvent.OnClientEvent:Connect(function(kind: string, payload)
	if kind == "top" then
		renderTop(payload :: { {userId: number, name: string, blocks: number} })
	end
end)

