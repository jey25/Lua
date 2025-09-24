--!strict
-- StarterPlayerScripts/BlocksLeaderboard.client.lua
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LBEvent = RS:WaitForChild("BlocksLeaderboard") :: RemoteEvent

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
		panel.Position = UDim2.fromScale(0.985, 0.5) -- 우측 거의 끝, 세로 중앙
		panel.Size = UDim2.fromScale(0.23, 0.60)
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
		title.TextScaled = false
		title.TextSize = 20
		title.TextColor3 = Color3.fromRGB(255, 230, 120)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Text = "GLOBAL RANKING"
		title.Parent = panel

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
		layout.Padding = UDim.new(0, 6)
		layout.Parent = list
	end

	return (root:FindFirstChild("Panel") :: Frame)
end

local function makeRow(idx: number, name: string, count: number): Frame
	local row = Instance.new("Frame")
	row.Name = ("Row_%d"):format(idx)
	row.Size = UDim2.new(1, -8, 0, 32)
	row.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	row.BackgroundTransparency = 0.2

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = row

	local rank = Instance.new("TextLabel")
	rank.Name = "Rank"
	rank.BackgroundTransparency = 1
	rank.Size = UDim2.new(0, 36, 1, 0)
	rank.Position = UDim2.fromOffset(6, 0)
	rank.Font = Enum.Font.GothamBold
	rank.TextSize = 18
	rank.TextColor3 = Color3.fromRGB(255, 230, 120)
	rank.TextXAlignment = Enum.TextXAlignment.Center
	rank.Text = tostring(idx)
	rank.Parent = row

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Name = "Name"
	nameLbl.BackgroundTransparency = 1
	nameLbl.Size = UDim2.new(1, -140, 1, 0)
	nameLbl.Position = UDim2.fromOffset(46, 0)
	nameLbl.Font = Enum.Font.Gotham
	nameLbl.TextSize = 18
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
	cnt.TextSize = 18
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

