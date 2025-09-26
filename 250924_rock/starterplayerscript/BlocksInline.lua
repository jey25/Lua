--!strict
-- StarterPlayerScripts/BlocksInline.client.lua
-- Block 아이콘 + 숫자 인라인 HUD

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService") -- ✅ 추가

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BlocksEvent = RS:WaitForChild("Blocks_Update") :: RemoteEvent
local startEvent  = RS:WaitForChild("TwoSeatStart") :: RemoteEvent

local myId: number = player.UserId
local opponentId: number? = nil
local latestCounts: {[number]: number} = {}

local IS_TOUCH: boolean = UserInputService.TouchEnabled
local ICON_SIZE: number
local LABEL_TEXT_SIZE: number
local TOP_Y: number
local BOTTOM_Y: number       -- ★ 추가

if IS_TOUCH then
	ICON_SIZE = 48
	LABEL_TEXT_SIZE = 44
	TOP_Y = 0.34            -- ⬆ 기존 0.26 → 0.34 (상대 행을 아래쪽으로)
	BOTTOM_Y = 0.64         -- ⬇ 기존 0.70 → 0.64 (내 행을 위쪽으로)
else
	ICON_SIZE = 56
	LABEL_TEXT_SIZE = 60
	TOP_Y = 0.28            -- ⬆ 기존 0.18 → 0.28
	BOTTOM_Y = 0.62         -- ⬇ 기존 0.70 → 0.62
end

local ROW_HEIGHT: number = math.max(ICON_SIZE, 56)
------------------------------------------------------------

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


-- 아이콘/라벨을 상수 기반으로 배치하도록 수정
local function makeRow(name: string, pos: UDim2): Frame
	local root = ensureInlineLayer()
	local row = root:FindFirstChild(name) :: Frame?

	if not row then
		row = Instance.new("Frame")
		row.Name = name
		row.AnchorPoint = Vector2.new(0.5, 0.5)
		row.Position = pos
		row.Size = UDim2.fromOffset(200, ROW_HEIGHT) -- ✅ 행 높이 상수화
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Parent = root

		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 0, 0.5, 0)            -- ✅ 세로 중앙 정렬
		icon.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE) -- ✅ 크기 상수화
		icon.BackgroundTransparency = 1
		icon.Image = getBlockImageId()
		icon.Parent = row

		local lbl = Instance.new("TextLabel")
		lbl.Name = "Count"
		lbl.AnchorPoint = Vector2.new(0, 0.5)
		lbl.Position = UDim2.fromOffset(ICON_SIZE + 8, math.floor(ROW_HEIGHT/2)) -- ✅ 자동 위치
		lbl.Size = UDim2.fromOffset(90, 34)
		lbl.BackgroundTransparency = 1
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.Font = Enum.Font.GothamBold
		lbl.TextSize = LABEL_TEXT_SIZE -- ✅ 크기 상수화
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
	else
		-- ✅ 이미 있는 행도 최신 상수로 업데이트
		row.Position = pos
		row.Size = UDim2.fromOffset(200, ROW_HEIGHT)

		local icon = row:FindFirstChild("Icon") :: ImageLabel?
		if icon then
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, 0, 0.5, 0)
			icon.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
		end

		local lbl = row:FindFirstChild("Count") :: TextLabel?
		if lbl then
			lbl.AnchorPoint = Vector2.new(0, 0.5)
			lbl.Position = UDim2.fromOffset(ICON_SIZE + 8, math.floor(ROW_HEIGHT/2))
			lbl.TextSize = LABEL_TEXT_SIZE
		end
	end

	return row
end


local function ensureMyRow(): Frame
	-- 보드가 0.82쯤이니 그 위 0.70, 좌측-중앙 느낌의 X=0.22
	return makeRow("Bottom", UDim2.fromScale(0.22, BOTTOM_Y))
end

local function ensureOppRow(): Frame
	-- ⬇ 모바일에서만 더 아래로
	return makeRow("Top", UDim2.fromScale(0.22, TOP_Y))
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
