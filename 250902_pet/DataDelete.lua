-- ================== 사용자 설정 ==================
local USER_ID = 3857750238      -- 초기화 대상
local SCOPE   = ""              -- DataStore 스코프(없으면 "")

-- ================== 서비스 ==================
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

-- ================== DataStore 키 제거 ==================
local function _ds(scope) return (scope ~= "" and scope) or nil end
local function removeKey(storeName, key)
	local ds = DataStoreService:GetDataStore(storeName, _ds(SCOPE))
	local ok, err = pcall(function() ds:RemoveAsync(key) end)
	print(("[DS] %s RemoveAsync(%s) -> %s %s"):format(storeName, key, tostring(ok), err or "")) 
	return ok
end

removeKey("PlayerData_v2",     "u_"..tostring(USER_ID))  -- 메인
removeKey("PlayerProgress_v1", "u_"..tostring(USER_ID))  -- 레거시 EXP
removeKey("GameCoins_v2",      "p:"..tostring(USER_ID))  -- 레거시 코인
removeKey("PlayerData",        tostring(USER_ID))        -- 레거시 일반
removeKey("PlayerData",        "u_"..tostring(USER_ID))  -- 보조 키

-- Play가 아니면(서버 런타임 아님) 여기서 종료: 영구 저장만 정리됨
if not RunService:IsRunning() then
	print("[RESET] Not in Play (server). Persistent data cleared. Live state will reset next join.")
	return
end

-- ================== 모듈 안전 로드 ==================
local function safeRequireModule(nameInSSS)
	local inst = ServerScriptService:FindFirstChild(nameInSSS)
	if not inst then
		for _, d in ipairs(ServerScriptService:GetDescendants()) do
			if d:IsA("ModuleScript") and d.Name == nameInSSS then inst = d; break end
		end
	end
	if not inst or not inst:IsA("ModuleScript") then
		return nil, ("ModuleScript '%s' not found"):format(nameInSSS)
	end
	local ok, modOrErr = pcall(require, inst)
	if not ok then
		return nil, ("require(%s) failed: %s"):format(inst:GetFullName(), tostring(modOrErr))
	end
	return modOrErr
end

-- PlayerDataService (필수)
local PlayerDataService, errPDS = safeRequireModule("PlayerDataService")
if not PlayerDataService then
	error("[RESET] require(PlayerDataService) failed: "..tostring(errPDS))
end

-- CoinService (선택)
local CoinService = (function()
	local m, _ = safeRequireModule("CoinService")
	return m
end)()

-- ================== 대상 플레이어 ==================
local plr = Players:GetPlayerByUserId(USER_ID)
if not plr then
	print("[LIVE] Target player is offline. They will start clean next join.")
	return
end

-- Remotes 준비(없으면 생성)
local LevelSync = ReplicatedStorage:FindFirstChild("LevelSync") :: RemoteEvent
if not LevelSync then
	LevelSync = Instance.new("RemoteEvent")
	LevelSync.Name = "LevelSync"
	LevelSync.Parent = ReplicatedStorage
end

-- ================== 코인/레벨/EXP/백신/펫 ==================
-- 코인 0
if CoinService and CoinService.SetBalance then
	pcall(function() CoinService:SetBalance(plr, 0) end)
end

-- 레벨/EXP 초기화
local function ExpToNext(level:number) return math.floor(100 + 50*(level-1)*(level-1)) end
local newLevel, newExp = 1, 0
local newGoal = ExpToNext(newLevel)
PlayerDataService:SetLevelExp(plr, newLevel, newExp)
plr:SetAttribute("Level", newLevel)
plr:SetAttribute("Exp", newExp)
plr:SetAttribute("ExpToNext", newGoal)
LevelSync:FireClient(plr, {Level=newLevel, Exp=newExp, ExpToNext=newGoal})

-- 백신 카운트 0
PlayerDataService:SetVaccineCount(plr, 0)

-- 펫/접종 타임스탬프 초기화 + 저장
do
	local d = PlayerDataService:Get(plr)
	d.ownedPets = {}
	d.selectedPetName = nil
	d.lastVaxAt = 0
	d.nextVaxAt = 0
	PlayerDataService:MarkDirty(plr)
	PlayerDataService:Save(plr.UserId, "manual-reset")
end

-- 월드 펫 모델 제거
for _, m in ipairs(workspace:GetDescendants()) do
	if m:IsA("Model") and m:GetAttribute("OwnerUserId") == USER_ID then
		pcall(function() m:Destroy() end)
	end
end

-- 기타 Attribute 초기화
plr:SetAttribute("PetAffection", 0)
plr:SetAttribute("PetAffectionMax", 10)

-- (버프 관련 초기화 코드는 제거됨: 버프는 세션 한정 + 퇴장 시 자동 초기화)

print("[RESET] Done: coins=0, level=1, exp=0, vaccines=0, pets cleared. (Buffs are ephemeral and reset on leave)")
