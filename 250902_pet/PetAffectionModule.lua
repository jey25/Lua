--!strict
-- ServerScriptService/PetAffectionService.lua
local PetAffectionService = {}

local Players            = game:GetService("Players")
local DataStoreService   = game:GetService("DataStoreService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

-- RemoteEvents 폴더 확보
local remoteFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "RemoteEvents"
	remoteFolder.Parent = ReplicatedStorage
end


local AffectionSync = ReplicatedStorage:FindFirstChild("PetAffectionSync") or Instance.new("RemoteEvent", ReplicatedStorage)
AffectionSync.Name = "PetAffectionSync"

if not AffectionSync then
	AffectionSync = Instance.new("RemoteEvent")
	AffectionSync.Name = "PetAffectionSync"
	AffectionSync.Parent = remoteFolder
end


-- 테스트용 이벤트(최대 도달/최소 유지 알림)
local AffectionTest = ReplicatedStorage:FindFirstChild("PetAffectionTest") or Instance.new("RemoteEvent", ReplicatedStorage)
AffectionTest.Name = "PetAffectionTest"

if not AffectionTest then
	AffectionTest = Instance.new("RemoteEvent")
	AffectionTest.Name = "PetAffectionTest"
	AffectionTest.Parent = remoteFolder
end

-- DataStore
local STORE_NAME = "PetAffection_v1"
local Store = DataStoreService:GetDataStore(STORE_NAME)

-- 기본 설정 (원하면 Configure로 바꿀 수 있음)
local DEFAULT_MAX            = 10
local DEFAULT_DECAY_SECONDS  = 120  -- ⏱ 테스트는 20~30으로 낮추면 편함
local DEFAULT_MIN_HOLD_SEC   = 180  -- 최소치 유지 판정 시간


-- 퀘스트별 증가량 (미정의면 1)
local DEFAULT_GAIN = 1
local AFFECTION_GAINS: {[string]: number} = {}

local function getGain(questName: string): number
	local v = AFFECTION_GAINS[questName]
	if typeof(v) == "number" then
		return v
	else
		return DEFAULT_GAIN
	end
end



-- 내부 상태
local DecayToken   : {[Player]: number} = {}
local MinHoldToken : {[Player]: number} = {}

-- ─────────────────────────────────────────────────────────────

local function now(): number
	return os.time()
end

local function clamp(n: number, a: number, b: number): number
	return math.max(a, math.min(b, n))
end

local function trySave(userId: number, payload)
	local ok, err
	for i=1,3 do
		ok, err = pcall(function()
			Store:SetAsync("u_"..userId, payload)
		end)
		if ok then return true end
		task.wait(0.5*i)
	end
	warn(("[Affection] Save failed %d: %s"):format(userId, tostring(err)))
	return false
end

local function tryLoad(userId: number)
	local ok, data = pcall(function()
		return Store:GetAsync("u_"..userId)
	end)
	if ok and typeof(data) == "table" then
		return data
	end
	return { Affection = 0, Max = DEFAULT_MAX, LastChangeUnix = now() }
end

local function broadcast(player: Player, value: number, maxv: number, decaySec: number)
	AffectionSync:FireClient(player, {
		Affection = value, Max = maxv, DecaySec = decaySec
	})
end

-- 다음 감소예약 취소/재설정
local function scheduleDecay(player: Player)
	if not (player and player.Parent) then return end

	DecayToken[player] = (DecayToken[player] or 0) + 1
	local my = DecayToken[player]

	local decSec = player:GetAttribute("PetAffectionDecaySec") or DEFAULT_DECAY_SECONDS
	local last   = player:GetAttribute("PetAffectionLastChangeUnix") or now()
	local dueIn  = math.max(0, last + decSec - now())

	task.delay(dueIn, function()
		-- 토큰/유효성 확인
		if not (player and player.Parent) then return end
		if DecayToken[player] ~= my then return end

		-- 퀘스트 미클리어로 감소 1
		local val = player:GetAttribute("PetAffection") or 0
		local maxv = player:GetAttribute("PetAffectionMax") or DEFAULT_MAX
		if val > 0 then
			val -= 1
			player:SetAttribute("PetAffection", val)
			player:SetAttribute("PetAffectionLastChangeUnix", now())
			broadcast(player, val, maxv, decSec)
		end

		-- 최소치 도달 시 최소 유지 타이머 시동
		if val == 0 then
			MinHoldToken[player] = (MinHoldToken[player] or 0) + 1
			local holdTok = MinHoldToken[player]
			local holdSec = player:GetAttribute("PetAffectionMinHoldSec") or DEFAULT_MIN_HOLD_SEC

			task.delay(holdSec, function()
				if not (player and player.Parent) then return end
				if MinHoldToken[player] ~= holdTok then return end
				-- 여전히 0이면 테스트 이벤트
				local cur = player:GetAttribute("PetAffection") or 0
				if cur == 0 then
					AffectionTest:FireClient(player, { type = "MinHeld", value = cur })
				end
			end)
		end

		-- 다음 감소 예약 (값이 0이어도 반복적으로 체크, 중간에 증가하면 토큰이 갱신되어 무효화됨)
		scheduleDecay(player)
	end)
end

-- 증가 처리(퀘스트 클리어)
local function addAffectionInternal(player: Player, addBy: number)
	if not (player and player.Parent) then return end
	addBy = math.max(0, math.floor(addBy))
	if addBy == 0 then return end

	local val  = player:GetAttribute("PetAffection") or 0
	local maxv = player:GetAttribute("PetAffectionMax") or DEFAULT_MAX
	local decS = player:GetAttribute("PetAffectionDecaySec") or DEFAULT_DECAY_SECONDS

	local newv = clamp(val + addBy, 0, maxv)
	player:SetAttribute("PetAffection", newv)
	player:SetAttribute("PetAffectionLastChangeUnix", now())
	broadcast(player, newv, maxv, decS)

	-- 감소 타이머 리셋
	DecayToken[player] = (DecayToken[player] or 0) + 1
	scheduleDecay(player)

	-- 최소 유지 모니터 해제(값이 증가했으니 토큰 무효화)
	MinHoldToken[player] = (MinHoldToken[player] or 0) + 1

	-- 최대치 도달 테스트 이벤트
	if newv >= maxv then
		AffectionTest:FireClient(player, { type = "MaxReached", value = newv })
	end
end

-- ─────────────────────────────────────────────────────────────
-- 🔸 공개 API

-- 설정 변경(옵션)
function PetAffectionService.Configure(opts: {DefaultMax: number?, DecaySec: number?, MinHoldSec: number?})
	if opts.DefaultMax then DEFAULT_MAX = math.max(1, math.floor(opts.DefaultMax)) end
	if opts.DecaySec then DEFAULT_DECAY_SECONDS = math.max(5, math.floor(opts.DecaySec)) end
	if opts.MinHoldSec then DEFAULT_MIN_HOLD_SEC = math.max(5, math.floor(opts.MinHoldSec)) end
end

-- 퀘스트별 증가량 등록/변경 (미설정은 1)
function PetAffectionService.SetQuestGain(questName: string, amount: number)
	AFFECTION_GAINS[questName] = math.max(0, math.floor(amount))
end

-- 플레이어별 최대치 변경(선택)
function PetAffectionService.SetMaxForPlayer(player: Player, maxv: number)
	maxv = math.max(1, math.floor(maxv))
	player:SetAttribute("PetAffectionMax", maxv)
	-- 클램프 및 브로드캐스트
	local cur = math.min(player:GetAttribute("PetAffection") or 0, maxv)
	player:SetAttribute("PetAffection", cur)
	broadcast(player, cur, maxv, player:GetAttribute("PetAffectionDecaySec") or DEFAULT_DECAY_SECONDS)
end

-- 퀘스트 클리어 시 호출(권장)
function PetAffectionService.OnQuestCleared(player: Player, questName: string)
	local gain = getGain(questName)
	addAffectionInternal(player, gain)
end

-- 임의 증감이 필요하면 아래 함수 사용(증가는 양수로)
function PetAffectionService.Add(player: Player, amount: number)
	addAffectionInternal(player, amount)
end

-- 현재값 조회
function PetAffectionService.Get(player: Player): (number, number)
	return player:GetAttribute("PetAffection") or 0, player:GetAttribute("PetAffectionMax") or DEFAULT_MAX
end

-- 초기화/로드
local function initPlayer(player: Player)
	local data = tryLoad(player.UserId)
	local val  = math.max(0, tonumber(data.Affection) or 0)
	local maxv = math.max(1, tonumber(data.Max) or DEFAULT_MAX)
	local last = tonumber(data.LastChangeUnix) or now()

	player:SetAttribute("PetAffection", val)
	player:SetAttribute("PetAffectionMax", maxv)
	player:SetAttribute("PetAffectionDecaySec", DEFAULT_DECAY_SECONDS)
	player:SetAttribute("PetAffectionMinHoldSec", DEFAULT_MIN_HOLD_SEC)
	player:SetAttribute("PetAffectionLastChangeUnix", last)

	broadcast(player, val, maxv, DEFAULT_DECAY_SECONDS)

	-- 재접속 시 잔여감소까지 남은 시간 반영해서 예약
	scheduleDecay(player)
end

local function savePlayer(player: Player)
	local payload = {
		Affection = player:GetAttribute("PetAffection") or 0,
		Max = player:GetAttribute("PetAffectionMax") or DEFAULT_MAX,
		LastChangeUnix = player:GetAttribute("PetAffectionLastChangeUnix") or now(),
	}
	trySave(player.UserId, payload)
end

-- 자동 훅(ExperienceService와 유사하게 require만 해도 붙음)
Players.PlayerAdded:Connect(initPlayer)
Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	DecayToken[player] = nil
	MinHoldToken[player] = nil
end)
game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		savePlayer(p)
	end
end)

-- 기본 증가량(원하면 자유 수정)
-- 미등록은 1로 처리됨 → 아래는 예시로 "Play a Game"만 2로 설정
AFFECTION_GAINS["Play a Game"] = 2

return PetAffectionService
