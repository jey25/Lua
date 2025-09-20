-- ▶ Command Bar (Studio, SERVER, API Services ON)
local Players            = game:GetService("Players")
local DataStoreService   = game:GetService("DataStoreService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerScriptService= game:GetService("ServerScriptService")
local RunService         = game:GetService("RunService")

-- ====== 🔧 설정 ======
local USER_ID = 3857750238        -- 초기화할 대상 UserId
local SCOPE   = ""                 -- DataStore 스코프 (없으면 빈 문자열)
local OPEN_PET_SELECTION_UI = true -- 리셋 직후 펫 선택창 열기 여부

-- ====== 🧹 DataStore 키 제거 유틸 ======
local function ds(scope)
	return (scope ~= "" and scope) or nil
end

local function removeKey(storeName, key)
	local dsObj = DataStoreService:GetDataStore(storeName, ds(SCOPE))
	local ok, err = pcall(function()
		dsObj:RemoveAsync(key)
	end)
	print(("[DS] %s : RemoveAsync(%s) -> %s %s"):format(storeName, key, tostring(ok), err or ""))
	return ok
end

-- 메인/레거시 후보 모두 제거
removeKey("PlayerData_v2",   "u_"..tostring(USER_ID))  -- PlayerDataService 메인 저장소
removeKey("PlayerProgress_v1","u_"..tostring(USER_ID)) -- 레거시 EXP/LEVEL
removeKey("GameCoins_v2",     "p:"..tostring(USER_ID)) -- 레거시 코인
removeKey("PlayerData",       tostring(USER_ID))       -- 레거시 일반 저장소(직접 키)
removeKey("PlayerData",       "u_"..tostring(USER_ID)) -- 혹시 몰라 같이 정리

-- ====== 👤 접속 중 플레이어 실시간 리셋 ======
local plr = Players:GetPlayerByUserId(USER_ID)
if not plr then
	print("[LIVE] 대상 플레이어가 현재 접속 중이 아닙니다. (데이터스토어는 이미 정리됨)")
	return
end

-- 모듈 로드
local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))
local CoinService       = require(ServerScriptService:WaitForChild("CoinService"))
local ExperienceService = require(ServerScriptService:WaitForChild("ExperienceService"))

-- Remotes
local LevelSync = ReplicatedStorage:FindFirstChild("LevelSync")
local RemoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder", ReplicatedStorage)
RemoteEvents.Name = "RemoteEvents"
local CoinUpdate = RemoteEvents:FindFirstChild("CoinUpdate") or Instance.new("RemoteEvent", RemoteEvents)
CoinUpdate.Name = "CoinUpdate"

-- 1) PlayerDataService 프로필 강제 로드 (없으면 기본값 생성)
local data = PlayerDataService:Load(plr)

-- 2) 값 전부 초기화 (코인/레벨/EXP/백신/펫)
-- 코인 0
CoinService:SetBalance(plr, 0)  -- CoinUpdate 클라 반영 포함

-- 레벨/EXP 1,0 + ExpToNext 재계산
local function ExpToNext(level:number) return math.floor(100 + 50*(level-1)*(level-1)) end
local newLevel, newExp = 1, 0
local newGoal = ExpToNext(newLevel)
PlayerDataService:SetLevelExp(plr, newLevel, newExp)
plr:SetAttribute("Level", newLevel)
plr:SetAttribute("Exp", newExp)
plr:SetAttribute("ExpToNext", newGoal)
if LevelSync then
	LevelSync:FireClient(plr, {Level = newLevel, Exp = newExp, ExpToNext = newGoal})
end

-- 백신 카운트 0 (Attribute도 동기화되어 우상단 카운터가 즉시 갱신됨)
PlayerDataService:SetVaccineCount(plr, 0)

-- 보유 펫 초기화 + 선택 펫 제거
-- 보유 펫 초기화 + 선택 펫 제거 + 버프 초기화
do
	local d = PlayerDataService:Get(plr)
	d.ownedPets = {}
	d.selectedPetName = nil
	d.lastVaxAt = 0
	d.nextVaxAt = 0
	d.buffs = {}  -- ⬅⬅ 버프 초기화 추가
	PlayerDataService:MarkDirty(plr)
	PlayerDataService:Save(plr.UserId, "manual-reset")
end

-- 버프 초기화 (런타임/Attribute 포함)
local function resetBuffs(plr: Player)
	-- 테이블 클리어
	speedBuffUntil[plr] = nil
	munchiesUntil[plr]  = nil

	-- Exp 버프 해제 알림
	plr:SetAttribute("ExpMultiplier", 1)

	-- Speed 버프 해제
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		local base = tonumber(plr:GetAttribute("BaseWalkSpeed")) or 16
		hum.WalkSpeed = base
	end

	-- 클라이언트 UI 갱신 (버프바에서 지워주려면 필요)
	BuffApplied:FireClient(plr, {
		kind = "Exp2x",
		text = "Expired",
		expiresAt = os.time(),
		duration = 0,
	})
	BuffApplied:FireClient(plr, {
		kind = "Speed",
		text = "Expired",
		expiresAt = os.time(),
		duration = 0,
	})
end

-- PlayerData 초기화 이후
resetBuffs(plr)



-- 월드에 펼쳐진 펫 모델 제거(OwnerUserId == USER_ID)
for _, m in ipairs(workspace:GetDescendants()) do
	if m:IsA("Model") and m:GetAttribute("OwnerUserId") == USER_ID then
		pcall(function() m:Destroy() end)
	end
end

-- 애정도 Attribute 초기화 (HUD에서 사용한다면)
plr:SetAttribute("PetAffection", 0)
plr:SetAttribute("PetAffectionMax", 10)
plr:SetAttribute("ExpMultiplier", 1)
plr:SetAttribute("SpeedMultiplier", 1)

-- 3) 선택: 즉시 펫 선택 GUI 열기
if OPEN_PET_SELECTION_UI then
	local PetEvents = ReplicatedStorage:FindFirstChild("PetEvents") or Instance.new("Folder", ReplicatedStorage)
	PetEvents.Name = "PetEvents"
	local ShowPetGuiEvent = PetEvents:FindFirstChild("ShowPetGui") or Instance.new("RemoteEvent", PetEvents)
	ShowPetGuiEvent.Name = "ShowPetGui"
	ShowPetGuiEvent:FireClient(plr)
end

-- 4) 클라이언트 쪽 남아있는 런타임 GUI 정리(있으면)
local pg = plr:FindFirstChildOfClass("PlayerGui")
if pg then
	for _, guiName in ipairs({ "VaccinationCountGui", "petdoctor_runtime", "NPCClickGui" }) do
		local g = pg:FindFirstChild(guiName)
		if g then pcall(function() g:Destroy() end) end
	end
	-- HUD는 유지하고 싶다면 주석 처리. 완전 초기화하려면 아래도 제거.
	-- local hud = pg:FindFirstChild("XP_HUD")
	-- if hud then pcall(function() hud:Destroy() end) end
end

-- 5) 저장 강제 커밋
PlayerDataService:Save(USER_ID, "manual-reset")

print("[LIVE] 플레이어 실시간 리셋 완료: coins=0, level=1, exp=0, vaccines=0, pets cleared.")
