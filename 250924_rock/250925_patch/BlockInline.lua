--!strict
-- StarterPlayerScripts/BlocksInline.client.lua
-- 인라인 블록(포인트) HUD: 내/상대 현재 블록 수를 화면에 작게 띄움

local Players         = game:GetService("Players")
local RS              = game:GetService("ReplicatedStorage")
local TweenService    = game:GetService("TweenService")

local player   = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remotes
local BlocksEvent  = RS:WaitForChild("Blocks_Update") :: RemoteEvent
local startEvent   = RS:WaitForChild("TwoSeatStart")  :: RemoteEvent
local cancelledEv  = RS:WaitForChild("RPS_Cancelled") :: RemoteEvent

-- State
local myId: number = player.UserId
local opponentId: number? = nil
local latestCounts: {[number]: number} = {}

-- ========= UI =========
local function normalizeAssetId(s: string): string
	-- 숫자만 들어오면 rbxassetid:// 접두 부여
	if s:match("^%d+$") then return "rbxassetid://"..s end
	return s
end

local BLOCK_ICON_IMAGE: string? = nil
local function getBlockImageId(): string
	if BLOCK_ICON_IMAGE then return BLOCK_ICON_IMAGE end
	local images = RS:FindFirstChild("Images")
	if not images then return "" end
	local blk = images:FindFirstChild("Block")
	if not blk then return "" end
	if blk:IsA("ImageLabel") or blk:IsA("ImageButton") then
		BLOCK_ICON_IMAGE = (blk :: any).Image
	elseif blk:IsA("Decal") or blk:IsA("Texture") then
		BLOCK_ICON_IMAGE = (blk :: any).Texture
	else
		BLOCK_ICON_IMAGE = ""
	end
	if type(BLOCK_ICON_IMAGE) == "string" then
		BLOCK_ICON_IMAGE = normalizeAssetId(BLOCK_ICON_IMAGE :: string)
	end
	return BLOCK_ICON_IMAGE or ""
end

local function ensureInlineLayer(): ScreenGui
	local root = playerGui:FindFirstChild("BlocksInline") :: ScreenGui?
	if not root then
		root = Instance.new("ScreenGui")
		root.Name = "BlocksInline"
		root.ResetOnSpawn = false
		root.IgnoreGuiInset = true
		root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		root.DisplayOrder = 998 -- 보드보다 위, 결과팝업(1001)보다 아래
		root.Parent = playerGui
	end
	return root
end

-- 공용 숫자 펄스(선택)
local function pulseLabel(lbl: TextLabel)
	local sc = lbl:FindFirstChildOfClass("UIScale") :: UIScale?
	if not sc then
		sc = Instance.new("UIScale")
		sc.Scale = 1
		sc.Parent = lbl
	end
	local t1 = TweenService:Create(sc, TweenInfo.new(0.08), {Scale = 1.08})
	local t2 = TweenService:Create(sc, TweenInfo.new(0.10), {Scale = 1.00})
	t1:Play()
	t1.Completed:Once(function() t2:Play() end)
end

-- 아이콘 56px, 숫자 라벨은 오른쪽 8px
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
	icon.Size = UDim2.fromOffset(56, 56)
	icon.BackgroundTransparency = 1
	icon.Image = getBlockImageId()
	icon.Parent = row

	local lbl = Instance.new("TextLabel")
	lbl.Name = "Count"
	lbl.AnchorPoint = Vector2.new(0, 0.5)
	lbl.Position = UDim2.fromOffset(56 + 8, 28)
	lbl.Size = UDim2.fromOffset(90, 34)
	lbl.BackgroundTransparency = 1
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextYAlignment = Enum.TextYAlignment.Center
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 28
	lbl.TextColor3 = Color3.fromRGB(255, 230, 120)
	lbl.Text = "0"
	lbl.Parent = row

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

	return row
end

local function ensureMyRow(): Frame
	-- 보드가 0.82쯤이니 그 위 0.70 근방
	return makeRow("Bottom", UDim2.fromScale(0.22, 0.70))
end

local function ensureOppRow(): Frame
	return makeRow("Top", UDim2.fromScale(0.22, 0.18))
end

local function setRowCount(which: "Top"|"Bottom", n: number, doPulse: boolean?)
	local root = ensureInlineLayer()
	local row = root:FindFirstChild(which) :: Frame?
	if not row then return end
	local lbl = row:FindFirstChild("Count") :: TextLabel?
	if not lbl then return end
	if lbl.Text ~= tostring(n) then
		lbl.Text = tostring(n)
		if doPulse then pulseLabel(lbl) end
	end
end

-- 예전 상단 검은 UI 제거(있다면)
do
	local oldPanel = playerGui:FindFirstChild("BlocksHUD")
	if oldPanel then oldPanel:Destroy() end
end

-- ========= Blocks sync =========
type FullEntry = {name: string, blocks: number}

BlocksEvent.OnClientEvent:Connect(function(kind: string, a: any, b: any, _c: any)
	if kind == "full" then
		-- 문자열/숫자 키 모두 허용 → number로 정규화
		local snap = a :: {[any]: FullEntry}
		for k, entry in pairs(snap) do
			local uid: number? =
				(typeof(k) == "number" and (k :: number))
				or (typeof(k) == "string" and tonumber(k :: string))
			if uid and entry and typeof(entry.blocks) == "number" then
				latestCounts[uid] = entry.blocks
			end
		end

		ensureMyRow(); ensureOppRow()
		setRowCount("Bottom", latestCounts[myId] or 0, false)
		if opponentId then setRowCount("Top", latestCounts[opponentId] or 0, false) end

	elseif kind == "delta" then
		local uid = a :: number
		local cnt = (typeof(b) == "number") and (b :: number) or 0
		latestCounts[uid] = cnt
		if uid == myId then
			setRowCount("Bottom", cnt, true)
		elseif opponentId and uid == opponentId then
			setRowCount("Top", cnt, true)
		end

	elseif kind == "leave" then
		local uid = a :: number
		if opponentId and uid == opponentId then
			setRowCount("Top", 0, true)
		end
	end
end)

-- ========= 매치 시작/취소와 연동 =========
startEvent.OnClientEvent:Connect(function(seatA: Seat, seatB: Seat, p1Id: number?, p2Id: number?)
	-- 서버 신호 우선
	if typeof(p1Id) == "number" and typeof(p2Id) == "number" then
		opponentId = (myId == p1Id) and p2Id or p1Id
	else
		-- 폴백(좌석 추정)
		local myHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid") :: Humanoid?
		local otherHum: Humanoid? = nil
		if myHum then
			if seatA.Occupant == myHum then otherHum = seatB.Occupant
			elseif seatB.Occupant == myHum then otherHum = seatA.Occupant end
		end
		local oppPlr = (otherHum and Players:GetPlayerFromCharacter(otherHum.Parent)) :: Player?
		opponentId = oppPlr and oppPlr.UserId or nil
	end

	-- 즉시 값 반영
	ensureMyRow(); ensureOppRow()
	setRowCount("Bottom", latestCounts[myId] or 0, false)
	if opponentId then setRowCount("Top", latestCounts[opponentId] or 0, false) end
end)

-- 매치가 취소되면 상대 표시만 초기화(내 값은 유지)
cancelledEv.OnClientEvent:Connect(function(_reason: string)
	opponentId = nil
	-- 상대 행을 0으로 하거나 숨기고 싶다면 아래 중 택1:
	setRowCount("Top", 0, false)
	-- 숨기려면:
	-- local root = ensureInlineLayer()
	-- local top = root:FindFirstChild("Top")
	-- if top then top.Visible = false end
end)
