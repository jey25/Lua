--!strict
-- ServerScriptService/PetAffectionService.lua
local PetAffectionService = {}

local Players            = game:GetService("Players")
local DataStoreService   = game:GetService("DataStoreService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

-- 파일 상단 근처에 추가
local HeartUiOn : {[Player]: boolean} = {}

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

-- [추가] StreetFood와 동일한 클라 액션을 재사용(버블/사운드)
local StreetFoodEvent = remoteFolder:FindFirstChild("StreetFoodEvent")
if not StreetFoodEvent then
	StreetFoodEvent = Instance.new("RemoteEvent")
	StreetFoodEvent.Name = "StreetFoodEvent"
	StreetFoodEvent.Parent = remoteFolder
end


-- 테스트용 이벤트(최대 도달/최소 유지 알림)
local AffectionTest = ReplicatedStorage:FindFirstChild("PetAffectionTest") or Instance.new("RemoteEvent", ReplicatedStorage)
AffectionTest.Name = "PetAffectionTest"

if not AffectionTest then
	AffectionTest = Instance.new("RemoteEvent")
	AffectionTest.Name = "PetAffectionTest"
	AffectionTest.Parent = remoteFolder
end

-- [추가] Heart 아이콘 토글용 RemoteEvent
local PetAffectionHeart = (function()
	local rf = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not rf then
		rf = Instance.new("Folder")
		rf.Name = "RemoteEvents"
		rf.Parent = ReplicatedStorage
	end
	local ev = rf:FindFirstChild("PetAffectionHeart")
	if not ev then
		ev = Instance.new("RemoteEvent")
		ev.Name = "PetAffectionHeart"
		ev.Parent = rf
	end
	return ev
end)()


-- [추가] 0 상태 아이콘 토글용 RemoteEvent
local PetAffectionZero = (function()
	local rf = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not rf then
		rf = Instance.new("Folder"); rf.Name = "RemoteEvents"; rf.Parent = ReplicatedStorage
	end
	local ev = rf:FindFirstChild("PetAffectionZero")
	if not ev then
		ev = Instance.new("RemoteEvent"); ev.Name = "PetAffectionZero"; ev.Parent = rf
	end
	return ev
end)()


-- DataStore
local STORE_NAME = "PetAffection_v1"
local Store = DataStoreService:GetDataStore(STORE_NAME)

-- 기본 설정 (원하면 Configure로 바꿀 수 있음)
local DEFAULT_MAX            = 10
local DEFAULT_DECAY_SECONDS  = 120   -- ⏱ 테스트는 20~30으로 낮추면 편함
local DEFAULT_MIN_HOLD_SEC   = 120  -- 최소치 유지 판정 시간


-- 퀘스트별 증가량 (미정의면 1)
local DEFAULT_GAIN = 1
local AFFECTION_GAINS: {[string]: number} = {}


-- [추가] MAX 달성 후 표시까지 대기시간(초) - 원하는 값으로 조정
local DEFAULT_MAX_HOLD_SEC = 10

-- [추가] 0 지속 후 표시 대기시간(초) — 마음대로 조절
local DEFAULT_ZERO_HOLD_SEC = 30

-- [추가] 하트 표시 스케줄 토큰 (취소/무효화 용)
local HeartToken : {[Player]: number} = {}


-- [추가] Heart-Secret 액션 설정 (원하면 값만 조정)
local SECRET_LIVE_FOLDER_NAME = "Secret_LIVE"
local HEART_DETECT_RADIUS   = 60      -- Secret_LIVE를 ‘감지’하는 거리
local HEART_CANCEL_RADIUS   = 5      -- 플레이어가 이 거리 안으로 가까워지면 액션 ‘취소’
local HEART_BARK_INTERVAL   = 1.6     -- 짖는 소리 반복 간격(초)
local HEART_BUBBLE_TEXT     = "I sense something..."  -- 말풍선 텍스트

-- [추가] SFX 이름 지정(우선순위: Attribute → 기본 후보)
-- ReplicatedStorage 또는 workspace.Secret_LIVE에 HeartBarkSfxName(string)로 오버라이드 가능
local HEART_BARK_NAME_CANDIDATES = { "Howl" }


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


-- [추가] 클라에 하트 on/off 브로드캐스트
local function fireHeart(player: Player, show: boolean)
	PetAffectionHeart:FireClient(player, { show = show })
end




-- [추가] 0 아이콘 스케줄 토큰
local ZeroToken : {[Player]: number} = {}

local function fireZero(player: Player, show: boolean)
	PetAffectionZero:FireClient(player, { show = show })
end

local function tryShowZeroNow(player: Player): boolean
	if not (player and player.Parent) then return false end
	local val   = player:GetAttribute("PetAffection") or 0
	local zeroH = player:GetAttribute("PetAffectionZeroHoldSec") or DEFAULT_ZERO_HOLD_SEC
	local last0 = player:GetAttribute("PetAffectionMinReachedUnix") or 0
	if val == 0 and last0 > 0 and (now() - last0) >= zeroH then
		fireZero(player, true)
		return true
	end
	return false
end


local function scheduleZeroIcon(player: Player)
	if not (player and player.Parent) then return end
	ZeroToken[player] = (ZeroToken[player] or 0) + 1
	local my = ZeroToken[player]

	local zeroH = player:GetAttribute("PetAffectionZeroHoldSec") or DEFAULT_ZERO_HOLD_SEC
	local last0 = player:GetAttribute("PetAffectionMinReachedUnix") or now()
	local dueIn = math.max(0, last0 + zeroH - now())

	task.delay(dueIn, function()
		if not (player and player.Parent) then return end
		if ZeroToken[player] ~= my then return end
		tryShowZeroNow(player) -- 조건이면 여기서 on
	end)
end


-- [추가] 0 도달 타임스탬프 기록 + 스케줄 시작
local function markMinReached(player: Player)
	player:SetAttribute("PetAffectionMinReachedUnix", now())
	ZeroToken[player] = (ZeroToken[player] or 0) + 1
	scheduleZeroIcon(player)
end


-- [추가] 간단 파트 해석
local function getAnyBasePart(inst: Instance): BasePart?
	if not inst then return nil end
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then
		local m = inst :: Model
		if m.PrimaryPart then return m.PrimaryPart end
		local hrp = m:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then return hrp end
		return m:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- [추가] 짖는 사운드 템플릿 찾기
local function resolveHeartBarkTemplate(): Sound?
	local sfxFolder = ReplicatedStorage:FindFirstChild("SFX")
	if not sfxFolder then return nil end

	local nameAttr = ReplicatedStorage:GetAttribute("HeartBarkSfxName")
	local secretLive = workspace:FindFirstChild(SECRET_LIVE_FOLDER_NAME)
	if not nameAttr and secretLive then
		local v = secretLive:GetAttribute("HeartBarkSfxName")
		if typeof(v) == "string" and #v > 0 then nameAttr = v end
	end
	if typeof(nameAttr) == "string" and #nameAttr > 0 then
		local s = sfxFolder:FindFirstChild(nameAttr)
		if s and s:IsA("Sound") then return s end
	end
	for _, cand in ipairs(HEART_BARK_NAME_CANDIDATES) do
		local s = sfxFolder:FindFirstChild(cand)
		if s and s:IsA("Sound") then return s end
	end
	return nil
end

-- [추가] Secret_LIVE 안에서 ‘가장 가까운’ 대상 찾기
local function findNearestSecret(hrp: BasePart): (Instance?, number?)
	local live = workspace:FindFirstChild(SECRET_LIVE_FOLDER_NAME)
	if not live then return nil, nil end
	local bestInst: Instance? = nil
	local bestDist: number? = nil
	for _, inst in ipairs(live:GetDescendants()) do
		if inst:IsA("Model") or inst:IsA("BasePart") then
			local bp = getAnyBasePart(inst)
			if bp then
				local d = (bp.Position - hrp.Position).Magnitude
				if d <= HEART_DETECT_RADIUS and (bestDist == nil or d < bestDist) then
					bestInst, bestDist = inst, d
				end
			end
		end
	end
	return bestInst, bestDist
end

-- [추가] 하트-시크릿 액션 루프 토큰
local HeartScanToken : {[Player]: number} = {}


-- [추가] 하트 액션 중단
local function stopHeartScan(player: Player)
	HeartScanToken[player] = (HeartScanToken[player] or 0) + 1
	-- 남아있을지 모르는 이펙트/말풍선 정리
	if HeartUiOn[player] then
		StreetFoodEvent:FireClient(player, "Bubble", { text = "" })
		-- StreetFoodEvent:FireClient(player, "ClearEffect") -- ← 제거 또는 주석
		HeartUiOn[player] = false
	end

end

-- [추가] 하트 액션 시작(하트 on 동안만 유지)
local function startHeartScan(player: Player)
	HeartScanToken[player] = (HeartScanToken[player] or 0) + 1
	local my = HeartScanToken[player]
	local barkTpl = resolveHeartBarkTemplate()
	local lastSfxAt = 0.0
	local actionActive = false  -- 말풍선/사운드 ‘on’ 상태

	task.spawn(function()
		while player and player.Parent and HeartScanToken[player] == my do
			local char = player.Character or player.CharacterAdded:Wait()
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart
			if not hrp then task.wait(0.3) continue end

			local target, dist = findNearestSecret(hrp)

			if target and dist then
				if dist <= HEART_CANCEL_RADIUS then
					-- 취소 조건: 플레이어가 타겟에 충분히 가까움 → 액션 off
					if actionActive then
						if HeartUiOn[player] then
							StreetFoodEvent:FireClient(player, "Bubble", { text = "" })
							-- StreetFoodEvent:FireClient(player, "ClearEffect") -- ← 제거 또는 주석
							HeartUiOn[player] = false
						end

						actionActive = false
					end
				else
					-- 감지 상태: 액션 on(버블 유지 + 주기적 짖음)
					if not actionActive then
						StreetFoodEvent:FireClient(player, "Bubble", { text = HEART_BUBBLE_TEXT, stash = true })
						HeartUiOn[player] = true
						actionActive = true
						lastSfxAt = 0.0
					end
					if barkTpl and (os.clock() - lastSfxAt) >= HEART_BARK_INTERVAL then
						StreetFoodEvent:FireClient(player, "PlaySfxTemplate", barkTpl)
						lastSfxAt = os.clock()
					end
				end
			else
				-- 감지 대상 없음 → 액션 off
				if actionActive then
					if HeartUiOn[player] then
						StreetFoodEvent:FireClient(player, "Bubble", { text = "" })
						-- StreetFoodEvent:FireClient(player, "ClearEffect") -- ← 제거 또는 주석
						HeartUiOn[player] = false
					end

					actionActive = false
				end
			end

			task.wait(0.3)
		end

		-- 루프 종료 시 잔여 정리(토큰 불일치로 끊긴 경우 포함)
		if player and player.Parent then
			if HeartUiOn[player] then
				StreetFoodEvent:FireClient(player, "Bubble", { text = "" })
				-- StreetFoodEvent:FireClient(player, "ClearEffect") -- ← 제거 또는 주석
				HeartUiOn[player] = false
			end

		end
	end)
end


-- [추가] 지금 조건이면 즉시 표시 시도
local function tryShowHeartNow(player: Player): boolean
	if not (player and player.Parent) then return false end
	local val   = player:GetAttribute("PetAffection") or 0
	local maxv  = player:GetAttribute("PetAffectionMax") or DEFAULT_MAX
	local hold  = player:GetAttribute("PetAffectionMaxHoldSec") or DEFAULT_MAX_HOLD_SEC
	local lastM = player:GetAttribute("PetAffectionMaxReachedUnix") or 0
	if val >= maxv and lastM > 0 and (now() - lastM) >= hold then
		fireHeart(player, true)
		startHeartScan(player)    -- ★ 추가
		return true
	end
	return false
end


-- [추가] MAX 달성 후 hold 시간이 지났을 때 표시 스케줄
local function scheduleMaxHeart(player: Player)
	if not (player and player.Parent) then return end
	HeartToken[player] = (HeartToken[player] or 0) + 1
	local my = HeartToken[player]

	local hold  = player:GetAttribute("PetAffectionMaxHoldSec") or DEFAULT_MAX_HOLD_SEC
	local lastM = player:GetAttribute("PetAffectionMaxReachedUnix") or now()
	local dueIn = math.max(0, lastM + hold - now())

	task.delay(dueIn, function()
		if not (player and player.Parent) then return end
		-- 콜백 내 마지막 줄
		if HeartToken[player] ~= my then return end
		tryShowHeartNow(player) -- 조건 맞으면 여기서 on (+ startHeartScan 내부에서 연결됨)

	end)
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
			
			-- ▼▼ 추가: 감소로 MAX 미만이 되면 하트 숨김
			if val < maxv then
				HeartToken[player] = (HeartToken[player] or 0) + 1
				fireHeart(player, false)
				stopHeartScan(player)   -- ★ 추가
			end

			-- ▼▼ 0이 된 순간 → 0 아이콘 스케줄 시작
			if val == 0 then
				markMinReached(player)
			end
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



-- 🔁 교체: 증가/감소 후 하트 토글 처리 추가
local function adjustAffectionInternal(player: Player, delta: number)
	if not (player and player.Parent) then return end
	delta = math.floor(tonumber(delta) or 0)
	if delta == 0 then return end

	local val  = player:GetAttribute("PetAffection") or 0
	local maxv = player:GetAttribute("PetAffectionMax") or DEFAULT_MAX
	local decS = player:GetAttribute("PetAffectionDecaySec") or DEFAULT_DECAY_SECONDS

	local newv = clamp(val + delta, 0, maxv)
	player:SetAttribute("PetAffection", newv)
	player:SetAttribute("PetAffectionLastChangeUnix", now())
	broadcast(player, newv, maxv, decS)

	-- 패시브 감소 재예약
	DecayToken[player] = (DecayToken[player] or 0) + 1
	scheduleDecay(player)

	-- 최소 유지 모니터 갱신
	MinHoldToken[player] = (MinHoldToken[player] or 0) + 1

	if newv == 0 then
		local holdTok = (MinHoldToken[player] or 0) + 1
		MinHoldToken[player] = holdTok
		local holdSec = player:GetAttribute("PetAffectionMinHoldSec") or DEFAULT_MIN_HOLD_SEC
		task.delay(holdSec, function()
			if not (player and player.Parent) then return end
			if MinHoldToken[player] ~= holdTok then return end
			if (player:GetAttribute("PetAffection") or 0) == 0 then
				AffectionTest:FireClient(player, { type = "MinHeld", value = 0 })
			end
		end)
	end

	-- 기존 adjustAffectionInternal의 본문에서 newv 계산 이후 분기 부분을 아래처럼 확장
	if newv >= maxv then
		-- MAX 도달: 하트 스케줄/표시
		player:SetAttribute("PetAffectionMaxReachedUnix", now())
		HeartToken[player] = (HeartToken[player] or 0) + 1
		scheduleMaxHeart(player)

		-- 동시에 0 아이콘은 숨김
		ZeroToken[player] = (ZeroToken[player] or 0) + 1
		fireZero(player, false)

		if delta > 0 then
			AffectionTest:FireClient(player, { type = "MaxReached", value = newv })
		end
	else
		-- MAX 미만이면 하트는 숨김
		HeartToken[player] = (HeartToken[player] or 0) + 1
		fireHeart(player, false)
		stopHeartScan(player)   -- ★ 추가

		if newv == 0 then
			-- 0 도달: 타임스탬프 찍고 스케줄
			markMinReached(player)
		else
			-- 0 벗어남: 즉시 숨김
			ZeroToken[player] = (ZeroToken[player] or 0) + 1
			fireZero(player, false)
		end
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


-- 🔧 교체: OnQuestCleared는 여전히 "증가"만 수행
function PetAffectionService.OnQuestCleared(player: Player, questName: string)
	local gain = getGain(questName)
	adjustAffectionInternal(player, gain)
end

-- 🔧 교체: Add도 음수 허용(하위호환)
function PetAffectionService.Add(player: Player, amount: number)
	adjustAffectionInternal(player, amount)
end

-- 🆕 추가: 명시적 Adjust API (StreetFood에서 이걸 우선 사용)
function PetAffectionService.Adjust(player: Player, delta: number, reason: string?)
	adjustAffectionInternal(player, delta)
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
	local lastMax = tonumber(data.LastMaxReachedUnix) or 0  -- [추가]

	player:SetAttribute("PetAffection", val)
	player:SetAttribute("PetAffectionMax", maxv)
	player:SetAttribute("PetAffectionDecaySec", DEFAULT_DECAY_SECONDS)
	player:SetAttribute("PetAffectionMinHoldSec", DEFAULT_MIN_HOLD_SEC)
	player:SetAttribute("PetAffectionLastChangeUnix", last)

	-- [추가] MAX 관련 유지시간, 마지막 MAX 타임스탬프
	player:SetAttribute("PetAffectionMaxHoldSec", DEFAULT_MAX_HOLD_SEC)
	player:SetAttribute("PetAffectionMaxReachedUnix", lastMax)
	
	-- initPlayer 내부 설정들에 이어서 ▼▼ 추가
	player:SetAttribute("PetAffectionZeroHoldSec", DEFAULT_ZERO_HOLD_SEC)
	player:SetAttribute("PetAffectionMinReachedUnix",
		tonumber((tryLoad(player.UserId) or {}).LastMinReachedUnix) or 0)

	broadcast(player, val, maxv, DEFAULT_DECAY_SECONDS)

	-- 패시브 감소 예약
	scheduleDecay(player)

	-- 재접속 시 즉시/예약 표시
	if val >= maxv then
		if not tryShowHeartNow(player) then scheduleMaxHeart(player) end
	else
		--fireHeart(player, false)
		stopHeartScan(player)   -- ★ 추가
	end

	-- ▼▼ 여기부터 Zero 처리 로직 교체
	if val == 0 then
		local last0 = tonumber(player:GetAttribute("PetAffectionMinReachedUnix")) or 0
		if last0 <= 0 then
			-- ▶ 접속 시점부터 0 카운트 시작
			player:SetAttribute("PetAffectionMinReachedUnix", now())
			scheduleZeroIcon(player)  -- 30초 뒤 on
		else
			-- 지난 시간에 따라 즉시 on 또는 잔여 대기
			if not tryShowZeroNow(player) then scheduleZeroIcon(player) end
		end
	else
		fireZero(player, false)
	end
end


local function savePlayer(player: Player)
	-- savePlayer(payload)에 저장 필드 추가
	local payload = {
		Affection   = player:GetAttribute("PetAffection") or 0,
		Max         = player:GetAttribute("PetAffectionMax") or DEFAULT_MAX,
		LastChangeUnix = player:GetAttribute("PetAffectionLastChangeUnix") or now(),
		-- ▼▼ 재접속 복원용
		LastMaxReachedUnix = player:GetAttribute("PetAffectionMaxReachedUnix") or 0,
		LastMinReachedUnix = player:GetAttribute("PetAffectionMinReachedUnix") or 0,
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
