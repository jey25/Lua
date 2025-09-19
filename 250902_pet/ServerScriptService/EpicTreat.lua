--!strict
-- ServerScriptService/TreatServer.lua (예시 이름)
-- Treat 구매: CoinService로 코인 차감 → 성공 시 BuffService로 버프 적용 → 최신 잔액 반환

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- 모듈들
local ExperienceService      = require(script.Parent:WaitForChild("ExperienceService"))
local PetAffectionService    = require(script.Parent:WaitForChild("PetAffectionService"))
local CoinService            = require(script.Parent:WaitForChild("CoinService"))
local BuffService            = require(ServerScriptService:WaitForChild("BuffService")) -- ★ 버프는 여기로 위임

-- Remotes (코인 표시는 유지)
local RemotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder")
RemotesFolder.Name = "RemoteEvents"
RemotesFolder.Parent = ReplicatedStorage

local CoinUpdate = RemotesFolder:FindFirstChild("CoinUpdate") :: RemoteEvent
if not CoinUpdate then
	CoinUpdate = Instance.new("RemoteEvent")
	CoinUpdate.Name = "CoinUpdate"
	CoinUpdate.Parent = RemotesFolder
end

-- Treat 구매 RF
local TreatFolder = ReplicatedStorage:FindFirstChild("TreatEvents") or Instance.new("Folder")
TreatFolder.Name = "TreatEvents"
TreatFolder.Parent = ReplicatedStorage

local TryBuyTreat = TreatFolder:FindFirstChild("TryBuyTreat") :: RemoteFunction
if not TryBuyTreat then
	TryBuyTreat = Instance.new("RemoteFunction")
	TryBuyTreat.Name = "TryBuyTreat"
	TryBuyTreat.Parent = TreatFolder
end

-- ===== 설정 =====
local TREAT_LEVEL_REQ = { Munchies = 20, DogGum = 10, Snack = 10 }
local TREAT_COIN_COST = { Munchies = 2,  DogGum = 1,  Snack = 1 }

-- 버프 파라미터
local SPEED_BOOST_SECS = 1800      -- 30분
local MUNCHIES_SECS    = 1800
local AFFECTION_MAX    = 10        -- DogGum 목표치

-- ===== 유틸 =====
local function getCoins(p: Player): number
	return CoinService:GetBalance(p)
end

local function trySpend(p: Player, cost: number): boolean
	return CoinService:TrySpend(p, cost)
end

local function getLevel(p: Player): number
	return tonumber(p:GetAttribute("Level")) or 1
end

-- Snack: 이동속도 +4 (가법 → BuffService는 승수 기반이라 승수로 환산)
local function applySnack(p: Player)
	-- 현재 기준 속도를 얻어 승수 계산
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
	local mult = (base + add) / math.max(1, base)  -- 예: base 16 → 20 ⇒ 1.25배

	-- BuffService에 위임 (UI 토스트/만료 동기화 포함)
	BuffService:ApplyBuff(p, "Speed", SPEED_BOOST_SECS, { mult = mult }, "이동 속도 UP!")
end

-- DogGum: 애정도 즉시 목표치로
local function applyDogGum(p: Player)
	local cur, maxv = PetAffectionService.Get(p)
	local target = AFFECTION_MAX > 0 and AFFECTION_MAX or maxv
	local delta = target - cur
	if delta > 0 then
		PetAffectionService.Adjust(p, delta, "DogGum")
	end
	-- (토스트는 필요시 PetAffectionService나 별도 UI에서 처리. BuffService는 관여 X)
end

-- Munchies: EXP 2배 (권장: 전역 2배 → ExperienceService.AddExp가 ExpMultiplier를 곱함)
local function applyMunchies(p: Player)
	BuffService:ApplyBuff(p, "Exp2x", MUNCHIES_SECS, { mult = 2 }, "경험치 2배!")
end


-- ===== 구매 RF =====
type BuyResp = { ok: boolean, coins: number, reason: string? }
local VALID_ITEMS = { Munchies = true, DogGum = true, Snack = true }

TryBuyTreat.OnServerInvoke = function(p: Player, payload): BuyResp
	if not (p and p.Parent) then
		return { ok = false, coins = 0, reason = "InvalidPlayer" }
	end

	local item = (typeof(payload) == "table" and payload.item) or tostring(payload)
	if not VALID_ITEMS[item] then
		return { ok = false, coins = getCoins(p), reason = "InvalidItem" }
	end

	local reqLv = TREAT_LEVEL_REQ[item] or math.huge
	local cost  = TREAT_COIN_COST[item] or math.huge
	if getLevel(p) < reqLv then
		return { ok = false, coins = getCoins(p), reason = "LevelTooLow" }
	end

	-- 코인 차감
	if not trySpend(p, cost) then
		return { ok = false, coins = getCoins(p), reason = "NotEnoughCoins" }
	end

	-- 효과 적용 (BuffService 위임)
	if item == "Snack" then
		applySnack(p)
	elseif item == "DogGum" then
		applyDogGum(p)
	elseif item == "Munchies" then
		applyMunchies(p)
	end

	-- 최신 잔액 반환 (브로드캐스트는 CoinService에서 이미 처리)
	local coinsNow = getCoins(p)
	return { ok = true, coins = coinsNow }
end

-- 접속 시 잔액 초기 동기화(옵션)
Players.PlayerAdded:Connect(function(p)
	CoinUpdate:FireClient(p, getCoins(p))
end)
