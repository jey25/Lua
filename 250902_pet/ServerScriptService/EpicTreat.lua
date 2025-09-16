--!strict
-- Treat 구매: CoinService로 코인 차감 → 성공 시 효과 적용 → 최신 잔액 반환

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 모듈들
local ExperienceService      = require(script.Parent:WaitForChild("ExperienceService"))
local PetAffectionService    = require(script.Parent:WaitForChild("PetAffectionService"))
local CoinService            = require(script.Parent:WaitForChild("CoinService"))

-- Remotes
local RemotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder", ReplicatedStorage)
RemotesFolder.Name = "RemoteEvents"
local CoinUpdate   = RemotesFolder:FindFirstChild("CoinUpdate") or Instance.new("RemoteEvent", RemotesFolder)
CoinUpdate.Name = "CoinUpdate"

local TreatFolder  = ReplicatedStorage:FindFirstChild("TreatEvents") or Instance.new("Folder", ReplicatedStorage)
TreatFolder.Name = "TreatEvents"
local TryBuyTreat  = TreatFolder:FindFirstChild("TryBuyTreat") or Instance.new("RemoteFunction", TreatFolder)
TryBuyTreat.Name = "TryBuyTreat"

-- Buff 이벤트 세팅
local BuffFolder   = ReplicatedStorage:FindFirstChild("BuffEvents") or Instance.new("Folder", ReplicatedStorage)
BuffFolder.Name    = "BuffEvents"
local BuffApplied  = BuffFolder:FindFirstChild("BuffApplied") or Instance.new("RemoteEvent", BuffFolder)
BuffApplied.Name   = "BuffApplied"

-- 클라/서버 동일 테이블(필요에 맞게 변경하세요)
local TREAT_LEVEL_REQ = { Munchies = 20, DogGum = 10,  Snack = 10 }
local TREAT_COIN_COST = { Munchies = 2, DogGum = 1,  Snack = 1 }

-- 버프 파라미터
local SPEED_BOOST       = 4       -- Snack 이동속도 +4
local SPEED_BOOST_SECS  = 1800
local MUNCHIES_SECS     = 1800
local AFFECTION_MAX     = 10

local speedBuffUntil : {[Player]: number} = {}
local munchiesUntil  : {[Player]: number} = {}



local function getLevel(p: Player): number
	return tonumber(p:GetAttribute("Level")) or 1
end

-- ───── 효과들
local function applySnack(p: Player)
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local now = os.time()
	local expires = now + SPEED_BOOST_SECS
	-- 연장 로직(가장 늦은 시각 유지)
	speedBuffUntil[p] = math.max(speedBuffUntil[p] or 0, expires)

	-- 속도 적용/연장
	if p:GetAttribute("BaseWalkSpeed") == nil then
		p:SetAttribute("BaseWalkSpeed", hum.WalkSpeed)
	end
	local base = tonumber(p:GetAttribute("BaseWalkSpeed")) or hum.WalkSpeed
	hum.WalkSpeed = base + SPEED_BOOST

	-- 클라 UI에 알림 + 버프바 업데이트(절대시각 전달)
	BuffApplied:FireClient(p, {
		kind = "Speed",
		text = "SpeedUp+",
		expiresAt = speedBuffUntil[p],
		duration = SPEED_BOOST_SECS,
	})

	-- 만료 복원 타이머(연장 고려)
	task.delay(SPEED_BOOST_SECS, function()
		if (speedBuffUntil[p] or 0) > expires then return end -- 연장됨
		local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if not h then return end
		local b = tonumber(p:GetAttribute("BaseWalkSpeed")) or 16
		h.WalkSpeed = b
		-- 만료 시각도 정리
		speedBuffUntil[p] = 0
	end)
end


local function applyDogGum(p: Player)
	local cur, maxv = PetAffectionService.Get(p)
	local target = AFFECTION_MAX > 0 and AFFECTION_MAX or maxv
	local delta = target - cur
	if delta > 0 then
		PetAffectionService.Adjust(p, delta, "DogGum")
	end
	-- 즉시 효과용 토스트/하트 팝업
	BuffApplied:FireClient(p, {
		kind = "Affection",  -- 비지속형(버프바 X)
		text = "♥",
	})
end

-- Munchies: 퀘스트 EXP 2배(추가분 지급)
local QuestCleared = ReplicatedStorage:WaitForChild("QuestCleared") :: RemoteEvent
QuestCleared.OnServerEvent:Connect(function(p: Player, payload)
	local base = (typeof(payload) == "table") and tonumber(payload.exp) or tonumber(payload)
	if not base or base <= 0 then return end
	if (munchiesUntil[p] or 0) > os.time() then
		ExperienceService.AddExp(p, base) -- 추가분(=기본과 동일) → 총 2배
	end
end)

-- Munchies: 퀘스트 EXP 2배(추가분 지급은 기존 QuestCleared 핸들러에서)
local function applyMunchies(p: Player)
	local now = os.time()
	local expires = now + MUNCHIES_SECS
	munchiesUntil[p] = math.max(munchiesUntil[p] or 0, expires)

	BuffApplied:FireClient(p, {
		kind = "Exp2x",
		text = "Exp x2",
		expiresAt = munchiesUntil[p],
		duration = MUNCHIES_SECS,
	})
end

-- ───── 구매 RF
type BuyResp = { ok: boolean, coins: number, reason: string? }
local VALID_ITEMS = { Munchies = true, DogGum = true, Snack = true }

local function getCoins(p: Player): number
	return CoinService:GetBalance(p)
end

local function trySpend(p: Player, cost: number): boolean
	return CoinService:TrySpend(p, cost)
end

TryBuyTreat.OnServerInvoke = function(p: Player, payload): BuyResp
	if not (p and p.Parent) then return { ok = false, coins = 0, reason = "InvalidPlayer" } end
	local item = (typeof(payload) == "table" and payload.item) or tostring(payload)
	if not VALID_ITEMS[item] then
		return { ok = false, coins = getCoins(p), reason = "InvalidItem" }
	end

	local reqLv = TREAT_LEVEL_REQ[item] or math.huge
	local cost  = TREAT_COIN_COST[item] or math.huge
	if getLevel(p) < reqLv then
		return { ok = false, coins = getCoins(p), reason = "LevelTooLow" }
	end

	-- ⚠️ 코인 차감은 반드시 CoinService를 사용
	if not trySpend(p, cost) then
		return { ok = false, coins = getCoins(p), reason = "NotEnoughCoins" }
	end

	-- 효과 적용
	if item == "Snack" then
		applySnack(p)
	elseif item == "DogGum" then
		applyDogGum(p)
	elseif item == "Munchies" then
		applyMunchies(p)
	end

	-- 최신 잔액 반환(브로드캐스트는 CoinService가 이미 해줍니다)
	local coinsNow = getCoins(p)
	return { ok = true, coins = coinsNow }
end

-- 접속 시 현재 잔액을 한 번 쏴 주면 클라도 바로 동기화됨(옵션)
Players.PlayerAdded:Connect(function(p)
	CoinUpdate:FireClient(p, getCoins(p))
end)

Players.PlayerRemoving:Connect(function(p)
	speedBuffUntil[p] = nil
	munchiesUntil[p] = nil
end)
