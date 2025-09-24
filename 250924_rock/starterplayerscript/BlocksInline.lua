--!strict
-- StarterPlayerScripts/BlocksInline.client.lua
-- Block 아이콘 + 숫자 인라인 HUD

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BlocksEvent = RS:WaitForChild("Blocks_Update") :: RemoteEvent
local startEvent  = RS:WaitForChild("TwoSeatStart") :: RemoteEvent

local myId: number = player.UserId
local opponentId: number? = nil
local latestCounts: {[number]: number} = {}

-- ===== UI =====
local function getBlockImageId(): string
	local folder = RS:WaitForChild("Images")
	local blk = folder:FindFirstChild("Block")
	if not blk then return "" end
	if blk:IsA("ImageLabel") or blk:IsA("ImageButton") then
		return (blk :: any).Image
	elseif blk:IsA("Decal") or blk:IsA("Texture") then
		return (blk :: any).Texture
	end
	return ""
end

local function ensureInlineLayer(): ScreenGui
	local root = playerGui:FindFirstChild("BlocksInline") :: ScreenGui?
	if not root then
		root = Instance.new("ScreenGui")
		root.Name = "BlocksInline"
		root.ResetOnSpawn = false
		root.IgnoreGuiInset = true
		root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		root.Parent = playerGui
	end
	return root
end

-- 아이콘 56px, 숫자는 아이콘 오른쪽에 딱 붙게(8px)
local function makeRow(name: string, pos: UDim2): Frame
	local root = ensureInlineLayer()
	local row = root:FindFirstChild(name) :: Frame?
	if row then
		row.Position = pos
		return row
	end

	row = Instance.new("Frame")
	row.Name = name
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = pos
	row.Size = UDim2.fromOffset(200, 56)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Parent = root

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromOffset(0, 28)
	icon.Size = UDim2.fromOffset(56, 56)         -- ★ 더 크게
	icon.BackgroundTransparency = 1
	icon.Image = getBlockImageId()
	icon.Parent = row

	local lbl = Instance.new("TextLabel")
	lbl.Name = "Count"
	lbl.AnchorPoint = Vector2.new(0, 0.5)
	lbl.Position = UDim2.fromOffset(56 + 8, 28)   -- ★ 아이콘 오른쪽 8px
	lbl.Size = UDim2.fromOffset(90, 34)
	lbl.BackgroundTransparency = 1
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextYAlignment = Enum.TextYAlignment.Center
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 28
	lbl.TextColor3 = Color3.fromRGB(255, 230, 120)
	lbl.Text = "0"

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(0,0,0)
	stroke.Parent = lbl

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255,245,200)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,215,90)),
		ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255,245,200)),
	})
	grad.Parent = lbl
	lbl.Parent = row

	return row
end

local function ensureMyRow(): Frame
	-- 보드가 0.82쯤이니 그 위 0.70, 좌측-중앙 느낌의 X=0.22
	return makeRow("Bottom", UDim2.fromScale(0.22, 0.70))
end

local function ensureOppRow(): Frame
	return makeRow("Top", UDim2.fromScale(0.22, 0.18))
end

local function setRowCount(which: "Top"|"Bottom", n: number)
	local root = ensureInlineLayer()
	local row = root:FindFirstChild(which) :: Frame?
	if not row then return end
	local lbl = row:FindFirstChild("Count") :: TextLabel?
	if not lbl then return end
	lbl.Text = tostring(n)
end

-- 예전 상단 검은 UI 제거(있다면)
do
	local oldPanel = playerGui:FindFirstChild("BlocksHUD")
	if oldPanel then oldPanel:Destroy() end
end

-- ===== Blocks sync =====
BlocksEvent.OnClientEvent:Connect(function(kind: string, a, b, _c)
	if kind == "full" then
		-- 문자열/숫자 키 모두 허용 → number로 정규화
		type Entry = {name: string, blocks: number}
		local snap = a :: {[any]: Entry}
		for k, entry in pairs(snap) do
			local uid: number? = (typeof(k) == "number") and (k :: number)
				or ((typeof(k) == "string") and tonumber(k :: string))
			if uid then
				latestCounts[uid] = entry.blocks
			end
		end

		ensureMyRow(); ensureOppRow()
		setRowCount("Bottom", latestCounts[myId] or 0)
		if opponentId then setRowCount("Top", latestCounts[opponentId] or 0) end

	elseif kind == "delta" then
		local uid = a :: number
		local cnt = b :: number
		latestCounts[uid] = cnt
		if uid == myId then
			setRowCount("Bottom", cnt)
		elseif opponentId and uid == opponentId then
			setRowCount("Top", cnt)
		end

	elseif kind == "leave" then
		local uid = a :: number
		if opponentId and uid == opponentId then
			setRowCount("Top", 0)
		end
	end
end)

-- ===== 상대 확정(레이스 방지) =====
startEvent.OnClientEvent:Connect(function(seatA: Seat, seatB: Seat, p1Id: number?, p2Id: number?)
	-- 1) 서버가 아이디를 보내주면 그걸로 확정 (권장)
	if typeof(p1Id) == "number" and typeof(p2Id) == "number" then
		opponentId = (myId == p1Id) and p2Id or p1Id
	else
		-- 2) 폴백: 좌석 점유로 추정 (레이스 위험 있지만 보조용)
		local myHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid") :: Humanoid?
		local otherHum: Humanoid? = nil
		if myHum then
			if seatA.Occupant == myHum then otherHum = seatB.Occupant
			elseif seatB.Occupant == myHum then otherHum = seatA.Occupant end
		end
		local oppPlr = (otherHum and Players:GetPlayerFromCharacter(otherHum.Parent)) :: Player?
		opponentId = oppPlr and oppPlr.UserId or nil
	end

	-- 즉시 현재 값 반영
	ensureMyRow(); ensureOppRow()
	setRowCount("Bottom", latestCounts[myId] or 0)
	if opponentId then setRowCount("Top", latestCounts[opponentId] or 0) end
end)
