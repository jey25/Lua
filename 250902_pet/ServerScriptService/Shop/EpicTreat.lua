--!strict
-- ServerScriptService/TreatServer.lua
-- Treat 구매: 코인 차감 → 버프 적용 → 최신 잔액 반환
-- Jumper 배지 보유자만 'duckbone / Jump up' 구매 가능(영구)

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerScriptService= game:GetService("ServerScriptService")
local HttpService        = game:GetService("HttpService")

-- 모듈
local ExperienceService   = require(ServerScriptService:WaitForChild("ExperienceService"))
local PetAffectionService = require(ServerScriptService:WaitForChild("PetAffectionService"))
local CoinService         = require(ServerScriptService:WaitForChild("CoinService"))
local BuffService         = require(ServerScriptService:WaitForChild("BuffService"))
local BadgeManager        = require(ServerScriptService:WaitForChild("BadgeManager"))


-- Remotes(코인)
local RemotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder")
RemotesFolder.Name = "RemoteEvents"
RemotesFolder.Parent = ReplicatedStorage

local CoinUpdate = RemotesFolder:FindFirstChild("CoinUpdate") :: RemoteEvent
if not CoinUpdate then
	CoinUpdate = Instance.new("RemoteEvent")
	CoinUpdate.Name = "CoinUpdate"
	CoinUpdate.Parent = RemotesFolder
end

-- Treat Remotes
local TreatFolder = ReplicatedStorage:FindFirstChild("TreatEvents") or Instance.new("Folder")
TreatFolder.Name = "TreatEvents"
TreatFolder.Parent = ReplicatedStorage

local TryBuyTreat = TreatFolder:FindFirstChild("TryBuyTreat") :: RemoteFunction
if not TryBuyTreat then
	TryBuyTreat = Instance.new("RemoteFunction")
	TryBuyTreat.Name = "TryBuyTreat"
	TryBuyTreat.Parent = TreatFolder
end

-- ★ 추가: GUI에서 버튼 활성화 여부 질의용
local GetTreatUnlocks = TreatFolder:FindFirstChild("GetTreatUnlocks") :: RemoteFunction
if not GetTreatUnlocks then
	GetTreatUnlocks = Instance.new("RemoteFunction")
	GetTreatUnlocks.Name = "GetTreatUnlocks"
	GetTreatUnlocks.Parent = TreatFolder
end

-- ─────────────────────────────────────────────────────────────

-- 내부 키를 소문자/공백제거로 정규화
local function canonItem(s: any): string
	local v = typeof(s)=="string" and s or ""
	v = string.lower(v)
	v = (v:gsub("%s+", "")):gsub("_", "")
	return v
end

-- 표시명 매핑(사전 정의 키)
-- 오른쪽 값이 실제 처리용 아이템 키
local ITEM_KEYMAP: {[string]: string} = {
	munchies = "Munchies",
	doggum   = "DogGum",
	snack    = "Snack",
	duckbone = "duckbone",
	jumpup   = "duckbone",  -- "Jump up" 버튼도 duckbone 버프로 처리
}

-- 유효 아이템
local VALID_ITEMS: {[string]: boolean} = { Munchies=true, DogGum=true, Snack=true, duckbone=true }

-- ★ 배지 게이트: 이 아이템들은 Jumper 배지 필요
local BADGE_GATE: {[string]: boolean} = {
	duckbone = true, -- (= Jump up)
}

-- 레벨/코인 요구
local TREAT_LEVEL_REQ = { Munchies = 30, duckbone = 20, DogGum = 10, Snack = 10 }
local TREAT_COIN_COST = { Munchies = 5,  duckbone = 3,  DogGum = 3,  Snack = 1 }

-- 버프 파라미터
local SPEED_BOOST_SECS = 1800
local MUNCHIES_SECS    = 1800
local AFFECTION_MAX    = 5

-- duckbone(jump up)
local DUCKBONE_SECS        = 1800
local DUCKBONE_BASE_POWER  = 50
local DUCKBONE_BUFF_POWER  = 80
local A_DUCK_UNTIL      = "DuckboneUntil"
local A_DUCK_BASE       = "DuckboneBaseJump"
local A_DUCK_USINGPOWER = "DuckboneUsingPower"
local A_DUCK_TOKEN      = "DuckboneToken"

local function getHumanoid(p: Player): Humanoid?
	local char = p.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function toast(p: Player, kind: string, text: string)
	local folder = ReplicatedStorage:FindFirstChild("BuffEvents")
	local evt = folder and folder:FindFirstChild(kind)
	if evt and evt:IsA("RemoteEvent") then
		(evt :: RemoteEvent):FireClient(p, { kind = "Duckbone", text = text })
	end
end

local function reapplyDuckboneIfActive(p: Player)
	local untilAt = p:GetAttribute(A_DUCK_UNTIL)
	if typeof(untilAt) ~= "number" or untilAt <= os.time() then return end
	local hum = getHumanoid(p)
	if not hum then return end
	p:SetAttribute(A_DUCK_BASE, DUCKBONE_BASE_POWER)
	p:SetAttribute(A_DUCK_USINGPOWER, 1)
	hum.UseJumpPower = true
	hum.JumpPower = DUCKBONE_BUFF_POWER
end

local function scheduleDuckboneExpiry(p: Player, token: string, endAt: number)
	task.delay(math.max(0, endAt - os.time()), function()
		if not p or not p.Parent then return end
		if p:GetAttribute(A_DUCK_TOKEN) ~= token then return end
		if (p:GetAttribute(A_DUCK_UNTIL) :: any) > os.time() then return end

		local hum = getHumanoid(p)
		if hum then
			hum.UseJumpPower = true
			hum.JumpPower = DUCKBONE_BASE_POWER
		end
		p:SetAttribute(A_DUCK_TOKEN, nil)
		p:SetAttribute(A_DUCK_UNTIL, nil)
		p:SetAttribute(A_DUCK_BASE, nil)
		p:SetAttribute(A_DUCK_USINGPOWER, nil)

		toast(p, "BuffExpired", "Jump power buff ends")
	end)
end

local function applyDuckbone(p: Player)
	local hum = getHumanoid(p)
	p:SetAttribute(A_DUCK_BASE, DUCKBONE_BASE_POWER)
	p:SetAttribute(A_DUCK_USINGPOWER, 1)
	if hum then
		hum.UseJumpPower = true
		hum.JumpPower = DUCKBONE_BUFF_POWER
	end
	local token = HttpService:GenerateGUID(false)
	local endAt = os.time() + DUCKBONE_SECS
	p:SetAttribute(A_DUCK_TOKEN, token)
	p:SetAttribute(A_DUCK_UNTIL, endAt)
	toast(p, "BuffApplied", "JUMP UP! (30 min)")
	scheduleDuckboneExpiry(p, token, endAt)
end

local function getCoins(p: Player): number
	return CoinService:GetBalance(p)
end

local function trySpend(p: Player, cost: number): boolean
	return CoinService:TrySpend(p, cost)
end

local function getLevel(p: Player): number
	return tonumber(p:GetAttribute("Level")) or 1
end

local function applySnack(p: Player)
	local base: number = 16
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local baseAttr = p:GetAttribute("BaseWalkSpeed")
	if typeof(baseAttr) == "number" then
		base = baseAttr
	elseif hum then
		base = hum.WalkSpeed
	end
	local add = 4
	local mult = (base + add) / math.max(1, base)
	BuffService:ApplyBuff(p, "Speed", SPEED_BOOST_SECS, { mult = mult }, "Speed UP!")
end

local DOGGUM_DELTA = 5
local function applyDogGum(p: Player)
	local cur, maxv = PetAffectionService.Get(p)
	local target = math.min(cur + DOGGUM_DELTA, maxv)
	local delta = target - cur
	if delta > 0 then
		PetAffectionService.Adjust(p, delta, "DogGum")
		local folder = ReplicatedStorage:FindFirstChild("BuffEvents")
		local BuffApplied = folder and folder:FindFirstChild("BuffApplied")
		if BuffApplied then
			(BuffApplied :: RemoteEvent):FireClient(p, { kind = "Affection", text = "+5 Affection!" })
		end
	end
end

local function applyMunchies(p: Player)
	BuffService:ApplyBuff(p, "Exp2x", MUNCHIES_SECS, { mult = 2 }, "Exp x2!")
end

-- ─────────── 구매 게이트 ───────────

local function hasJumper(p: Player): boolean
	if not BadgeManager then return false end
	local ok, res = pcall(function()
		-- BadgeManager.Keys를 안 쓰고 문자열로 직접
		return BadgeManager.HasRobloxBadge(p, "Jumper")
	end)
	return ok and res == true
end


-- 클라가 GUI 열 때 호출해서 버튼 활성화 결정
GetTreatUnlocks.OnServerInvoke = function(p: Player)
	local j = hasJumper(p)
	-- jumpup 별칭도 같이 내려줌(클라에서 키 매칭 편의)
	return {
		duckbone = j,
		jumpup   = j,
	}
end

-- ===== 구매 RF =====
type BuyResp = { ok: boolean, coins: number, reason: string? }

TryBuyTreat.OnServerInvoke = function(p: Player, payload): BuyResp
	if not (p and p.Parent) then
		return { ok = false, coins = 0, reason = "InvalidPlayer" }
	end

	-- ★ 아이템 이름 정규화/매핑
	local raw = (typeof(payload) == "table" and payload.item) or tostring(payload)
	local key = ITEM_KEYMAP[canonItem(raw)]
	if not key or not VALID_ITEMS[key] then
		return { ok = false, coins = getCoins(p), reason = "InvalidItem" }
	end

	-- ★ 배지 게이트: Jumper 배지 없으면 구매 불가(버튼은 기본 비활성화)
	if BADGE_GATE[key] and not hasJumper(p) then
		return { ok = false, coins = getCoins(p), reason = "LockedByBadge" }
	end

	-- 기존 요구 조건
	local reqLv = TREAT_LEVEL_REQ[key] or math.huge
	local cost  = TREAT_COIN_COST[key] or math.huge
	if getLevel(p) < reqLv then
		return { ok = false, coins = getCoins(p), reason = "LevelTooLow" }
	end

	if not trySpend(p, cost) then
		return { ok = false, coins = getCoins(p), reason = "NotEnoughCoins" }
	end

	-- 효과 적용
	if key == "Snack" then
		applySnack(p)
	elseif key == "DogGum" then
		applyDogGum(p)
	elseif key == "Munchies" then
		applyMunchies(p)
	elseif key == "duckbone" then
		applyDuckbone(p)
	end

	return { ok = true, coins = getCoins(p) }
end

-- 접속 시 잔액 동기화 + 캐릭터 리스폰 시 버프 재적용
Players.PlayerAdded:Connect(function(p)
	CoinUpdate:FireClient(p, getCoins(p))
	p.CharacterAdded:Connect(function()
		task.defer(function()
			reapplyDuckboneIfActive(p)
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(p)
	p:SetAttribute(A_DUCK_TOKEN, nil)
	p:SetAttribute(A_DUCK_UNTIL, nil)
	p:SetAttribute(A_DUCK_BASE, nil)
	p:SetAttribute(A_DUCK_USINGPOWER, nil)
end)
