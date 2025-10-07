--!strict
-- ServerScriptService/TreatServer.lua
-- Treat 구매: 코인 차감 → 버프 적용 → 최신 잔액 반환
-- Jumper 배지 보유자만 'duckbone / Jump up' 구매 가능(영구)

----------------------------------------------------------------
-- Services
----------------------------------------------------------------
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

----------------------------------------------------------------
-- Requires (project modules)
----------------------------------------------------------------
local ExperienceService    = require(ServerScriptService:WaitForChild("ExperienceService"))
local PetAffectionService  = require(ServerScriptService:WaitForChild("PetAffectionService"))
local CoinService          = require(ServerScriptService:WaitForChild("CoinService"))
local BuffService          = require(ServerScriptService:WaitForChild("BuffService"))
local BadgeManager         = require(ServerScriptService:WaitForChild("BadgeManager"))

----------------------------------------------------------------
-- Remotes
----------------------------------------------------------------
-- Coins
local RemotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder")
RemotesFolder.Name = "RemoteEvents"
RemotesFolder.Parent = ReplicatedStorage

local CoinUpdate = RemotesFolder:FindFirstChild("CoinUpdate") :: RemoteEvent
if not CoinUpdate then
	CoinUpdate = Instance.new("RemoteEvent")
	CoinUpdate.Name = "CoinUpdate"
	CoinUpdate.Parent = RemotesFolder
end

-- Treat
local TreatFolder = ReplicatedStorage:FindFirstChild("TreatEvents") or Instance.new("Folder")
TreatFolder.Name = "TreatEvents"
TreatFolder.Parent = ReplicatedStorage

local TryBuyTreat = TreatFolder:FindFirstChild("TryBuyTreat") :: RemoteFunction
if not TryBuyTreat then
	TryBuyTreat = Instance.new("RemoteFunction")
	TryBuyTreat.Name = "TryBuyTreat"
	TryBuyTreat.Parent = TreatFolder
end

-- GUI에서 배지 언락 여부/버튼 활성화 질의
local GetTreatUnlocks = TreatFolder:FindFirstChild("GetTreatUnlocks") :: RemoteFunction
if not GetTreatUnlocks then
	GetTreatUnlocks = Instance.new("RemoteFunction")
	GetTreatUnlocks.Name = "GetTreatUnlocks"
	GetTreatUnlocks.Parent = TreatFolder
end

-- Buff 토스트(옵션)
local BuffEvents = ReplicatedStorage:FindFirstChild("BuffEvents")
local BuffApplied   : RemoteEvent? = BuffEvents and BuffEvents:FindFirstChild("BuffApplied")   :: RemoteEvent
local BuffExpired   : RemoteEvent? = BuffEvents and BuffEvents:FindFirstChild("BuffExpired")   :: RemoteEvent

----------------------------------------------------------------
-- Utils
----------------------------------------------------------------
local function canonItem(s: any): string
	local v = typeof(s) == "string" and s or ""
	v = string.lower(v)
	v = (v:gsub("[%s_%-]+", "")) -- 공백/언더바/하이픈 제거
	return v
end

local function badgeKeyJumper(): any
	-- BadgeManager.Keys.Jumper가 있으면 사용, 없으면 문자열 "Jumper"로 호출
	local k = (BadgeManager :: any).Keys
	return (k and k.Jumper) or "Jumper"
end

local function getHumanoid(p: Player): Humanoid?
	local char = p.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

local function toast(p: Player, text: string, kind: "BuffApplied" | "BuffExpired")
	if kind == "BuffApplied" and BuffApplied then
		BuffApplied:FireClient(p, { kind = "Duckbone", text = text })
	elseif kind == "BuffExpired" and BuffExpired then
		BuffExpired:FireClient(p, { kind = "Duckbone", text = text })
	end
end

local function getCoins(p: Player): number
	-- 프로젝트 CoinService에 맞춰 사용 (이미 다른 곳에서 사용중)
	return CoinService:GetBalance(p)
end

local function trySpend(p: Player, cost: number): boolean
	return CoinService:TrySpend(p, cost)
end

local function getLevel(p: Player): number
	return tonumber(p:GetAttribute("Level")) or 1
end

----------------------------------------------------------------
-- Item tables / gates
----------------------------------------------------------------
-- 표시명 → 내부 처리 키 매핑
local ITEM_KEYMAP: {[string]: string} = {
	munchies = "Munchies",
	doggum   = "DogGum",
	snack    = "Snack",
	duckbone = "duckbone",    -- 점프버프
	jumpup   = "duckbone",    -- "Jump up" 별칭
	jumpup2  = "duckbone",    -- 안전(혹시 다른 표기)
}

-- 유효 아이템 집합
local VALID_ITEMS: {[string]: boolean} = {
	Munchies = true, DogGum = true, Snack = true, duckbone = true
}

-- 배지 게이트: Jumper 필요
local BADGE_GATE: {[string]: boolean} = {
	duckbone = true,
}

-- 요구 레벨/코인
local TREAT_LEVEL_REQ = { Munchies = 30, duckbone = 20, DogGum = 10, Snack = 10 }
local TREAT_COIN_COST = { Munchies = 5,  duckbone = 3,  DogGum = 3,  Snack = 1 }

-- 버프 파라미터
local SPEED_BOOST_SECS = 1800
local MUNCHIES_SECS    = 1800
local DOGGUM_DELTA     = 5

-- duckbone (Jump Up) - 상점 표준값
local DUCKBONE_SECS        = 1800
local DUCKBONE_BASE_POWER  = 50
local DUCKBONE_BUFF_POWER  = 80

----------------------------------------------------------------
-- Badge check (always real-time)
----------------------------------------------------------------
local function hasJumper(p: Player): boolean
	local key = badgeKeyJumper()
	local ok, res = pcall(function()
		return BadgeManager.HasRobloxBadge(p, key)
	end)
	return ok and res == true
end

----------------------------------------------------------------
-- Effects
----------------------------------------------------------------
local function applySnack(p: Player)
	-- Speed 버프는 BuffService가 WalkSpeed를 관리 (기본속도 대비 곱)
	local base: number = 16
	local hum = getHumanoid(p)
	local baseAttr = p:GetAttribute("BaseWalkSpeed")
	if typeof(baseAttr) == "number" then
		base = baseAttr
	elseif hum then
		base = hum.WalkSpeed
	end
	local add = 4
	local mult = (base + add) / math.max(1, base)
	BuffService:ApplyBuff(p, "Speed", SPEED_BOOST_SECS, { mult = mult }, "SpeedUP!")
end

local function applyDogGum(p: Player)
	-- 애정도 +5 (최대치 고려)
	local cur, maxv = PetAffectionService.Get(p)
	local target = math.min(cur + DOGGUM_DELTA, maxv)
	local delta = target - cur
	if delta > 0 then
		PetAffectionService.Adjust(p, delta, "DogGum")
		toast(p, "+5 Affection!", "BuffApplied")
	end
end

local function applyMunchies(p: Player)
	-- Exp 2배 30분
	BuffService:ApplyBuff(p, "Exp2x", MUNCHIES_SECS, { mult = 2 }, "EXPx2")
end

-- JumpUp(duckbone) 구매 시 BuffService 사용(상점과 동일: 50 -> 80 = 1.6배)
local function applyDuckbone(p: Player)
	BuffService:ApplyBuff(p, "JumpUp", DUCKBONE_SECS, { mult = DUCKBONE_BUFF_POWER / DUCKBONE_BASE_POWER }, "JUMP UP")
end

----------------------------------------------------------------
-- Remote: GetTreatUnlocks (for GUI button enabling)
----------------------------------------------------------------
GetTreatUnlocks.OnServerInvoke = function(p: Player)
	local j = hasJumper(p)
	-- 속성도 함께 갱신해서 클라가 AttributeChanged로 반응 가능
	p:SetAttribute("HasJumperBadge", j)
	return { duckbone = j, jumpup = j }
end

----------------------------------------------------------------
-- Remote: TryBuyTreat
----------------------------------------------------------------
type BuyResp = { ok: boolean, coins: number, reason: string? }

TryBuyTreat.OnServerInvoke = function(p: Player, payload): BuyResp
	if not (p and p.Parent) then
		return { ok = false, coins = 0, reason = "InvalidPlayer" }
	end

	-- 아이템 키 정규화/매핑
	local raw = (typeof(payload) == "table" and payload.item) or tostring(payload)
	local mapped = ITEM_KEYMAP[canonItem(raw)]
	if not mapped or not VALID_ITEMS[mapped] then
		return { ok = false, coins = getCoins(p), reason = "InvalidItem" }
	end

	-- 배지 게이트
	if BADGE_GATE[mapped] and not hasJumper(p) then
		-- 속성 동기화(클라 UI 갱신용)
		p:SetAttribute("HasJumperBadge", false)
		return { ok = false, coins = getCoins(p), reason = "LockedByBadge" }
	end

	-- 레벨/코인 요구
	local reqLv = TREAT_LEVEL_REQ[mapped] or math.huge
	local cost  = TREAT_COIN_COST[mapped] or math.huge

	if getLevel(p) < reqLv then
		return { ok = false, coins = getCoins(p), reason = "LevelTooLow" }
	end

	if not trySpend(p, cost) then
		return { ok = false, coins = getCoins(p), reason = "NotEnoughCoins" }
	end

	-- 효과 적용
	if mapped == "Snack" then
		applySnack(p)
	elseif mapped == "DogGum" then
		applyDogGum(p)
	elseif mapped == "Munchies" then
		applyMunchies(p)
	elseif mapped == "duckbone" then
		applyDuckbone(p)
	end

	local bal = getCoins(p)
	CoinUpdate:FireClient(p, bal) -- 글로벌 코인 HUD와의 일관 동기화
	return { ok = true, coins = bal }
end

----------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------
Players.PlayerAdded:Connect(function(p)
	-- 코인 HUD 초기 동기화
	CoinUpdate:FireClient(p, getCoins(p))

	-- 접속 시 배지 보유 속성 한 번 동기화 (GUI가 바로 쓸 수 있게)
	task.spawn(function()
		local j = hasJumper(p)
		p:SetAttribute("HasJumperBadge", j)
	end)
end)

-- duckbone에 대한 별도 재적용/정리 로직은 BuffService가 처리하므로 제거
Players.PlayerRemoving:Connect(function(_p) end)
