--!strict
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
local function removeKey(storeName: string, key: string)
	local ds = DataStoreService:GetDataStore(storeName, _ds(SCOPE))
	local ok, err = pcall(function() ds:RemoveAsync(key) end)
	print(("[DS] %s RemoveAsync(%s) -> %s %s"):format(storeName, key, tostring(ok), err or "")) 
	return ok
end

-- 메인/레거시/부가 스토어 전부 제거
removeKey("PlayerData_v2",     "u_"..tostring(USER_ID))  -- 메인 프로필(owned/selected/activePets 등)
removeKey("PlayerProgress_v1", "u_"..tostring(USER_ID))  -- 레거시 EXP
removeKey("GameCoins_v2",      "p:"..tostring(USER_ID))  -- 코인 서비스(레거시)
removeKey("PlayerData",        tostring(USER_ID))        -- 더 레거시
removeKey("PlayerData",        "u_"..tostring(USER_ID))  -- 더 레거시 보조
removeKey("PetPout_v1",        "u_"..tostring(USER_ID))  -- ✅ PetZeroPout(삐짐 카운트)

-- Play가 아니면(서버 런타임 아님) 여기서 종료: 영구 저장만 정리됨
if not RunService:IsRunning() then
	print("[RESET] Not in Play (server). Persistent data cleared. Live state will reset next join.")
	return
end

-- ================== 모듈 안전 로드 ==================
local function safeRequireModule(nameInSSS: string)
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

-- 선택 모듈들(있으면 사용)
local CoinService = (function() local m,_ = safeRequireModule("CoinService"); return m end)()
local BuffService = (function() local m,_ = safeRequireModule("BuffService"); return m end)()

-- ================== 대상 플레이어 ==================
local plr = Players:GetPlayerByUserId(USER_ID)
if not plr then
	print("[LIVE] Target player is offline. They will start clean next join.")
	return
end

-- Remotes 준비(없으면 생성)
local LevelSync = ReplicatedStorage:FindFirstChild("LevelSync") :: RemoteEvent?
if not LevelSync then
	local ev = Instance.new("RemoteEvent")
	ev.Name = "LevelSync"
	ev.Parent = ReplicatedStorage
	LevelSync = ev
end

-- ================== 코인/레벨/EXP 초기화 ==================
if CoinService and CoinService.SetBalance then
	pcall(function() CoinService:SetBalance(plr, 0) end)
end

local function ExpToNext(level:number) return math.floor(100 + 50*(level-1)*(level-1)) end
local newLevel, newExp = 1, 0
local newGoal = ExpToNext(newLevel)
PlayerDataService:SetLevelExp(plr, newLevel, newExp)
plr:SetAttribute("Level", newLevel)
plr:SetAttribute("Exp", newExp)
plr:SetAttribute("ExpToNext", newGoal)
if LevelSync then LevelSync:FireClient(plr, {Level=newLevel, Exp=newExp, ExpToNext=newGoal}) end

-- ================== 백신 카운트/스케줄 초기화 ==================
PlayerDataService:SetVaccineCount(plr, 0)

-- ================== 데이터 구조(owned/selected/active/buffs 등) 초기화 + 저장 ==================
do
	local d = PlayerDataService:Get(plr)
	-- 완전 클린
	d.ownedPets = {}                 -- 보유 펫 제거
	d.selectedPetName = nil          -- 선택 펫 해제
	-- 신규 모델 필드들
	d.activePets = {}                -- ✅ 동시에 따라다닐 펫 목록 비우기
	d.buffs = {}                     -- 버프 테이블 초기화
	d.lastVaxAt = 0                  -- 백신 타임스탬프 초기화
	d.nextVaxAt = 0

	-- 서비스 레벨 API가 있으면 함께 호출(있을 때만)
	if PlayerDataService.SetActivePets then
		pcall(function() PlayerDataService:SetActivePets(plr, {}) end)
	end

	PlayerDataService:MarkDirty(plr)
	PlayerDataService:Save(plr.UserId, "manual-reset") -- 즉시 저장
end

-- ================== 버프/속성 런타임 초기화 ==================
-- 1) BuffService가 있으면 모듈에서 통합 리셋
local function resetBuffsRuntime(p: Player)
	if BuffService and BuffService.ResetFor then
		pcall(function() BuffService:ResetFor(p) end)
	else
		-- 2) 모듈이 없으면 최소한의 런타임 리셋 수행
		-- 멀티플라이어/표시값
		p:SetAttribute("ExpMultiplier", 1)
		p:SetAttribute("SpeedMultiplier", 1)

		-- 이동속도 되돌리기
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			local base = tonumber(p:GetAttribute("BaseWalkSpeed")) or 16
			hum.WalkSpeed = base
		end
	end
end
resetBuffsRuntime(plr)

-- ================== 월드 펫/부착물 제거 ==================
-- (A) 펫 모델 제거
for _, m in ipairs(workspace:GetDescendants()) do
	if m:IsA("Model") and m:GetAttribute("OwnerUserId") == USER_ID then
		pcall(function() m:Destroy() end)
	end
end

-- (B) 캐릭터 HRP에 남아 있을 수 있는 펫 부착물 제거 (CharAttach_*, PetAttach 등)
do
	local char = plr.Character or plr.CharacterAdded:Wait()
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		for _, inst in ipairs(hrp:GetChildren()) do
			if inst:IsA("Attachment") and (string.find(inst.Name, "CharAttach_", 1, true) or inst.Name == "PetAttach") then
				pcall(function() inst:Destroy() end)
			end
		end
	end
end

-- ================== 기타 플레이어 속성 초기화 ==================
plr:SetAttribute("PetAffection", 0)
plr:SetAttribute("PetAffectionMax", 10)
plr:SetAttribute("ExpMultiplier", 1)
plr:SetAttribute("SpeedMultiplier", 1)

-- PetZeroPout 관련(아이콘 ON 조건 방지)
plr:SetAttribute("PetAffectionMinReachedUnix", 0)  -- ZERO_REACHED_ATTR
-- ZERO_HOLD_ATTR 기본은 서버 로직에서 사용하므로, 여기선 건드리지 않되 '0 도달 시각'을 0으로

print("[RESET] Done: coins=0, level=1, exp=0, vaccines=0, pets cleared, activePets cleared. Fresh start ready.")
