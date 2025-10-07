--!strict
-- === 커맨드바에서 실행 ===
local USER_ID = 3857750238
local SCOPE   = ""

local Players = game:GetService("Players")
local DSS     = game:GetService("DataStoreService")
local RS      = game:GetService("ReplicatedStorage")
local SSS     = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local function _ds(scope:string) return (scope ~= "" and scope) or nil end
local function removeKey(storeName:string, key:string)
	local ds = DSS:GetDataStore(storeName, _ds(SCOPE))
	local ok, err = pcall(function() ds:RemoveAsync(key) end)
	print(("[DS] %s RemoveAsync(%s) -> %s %s"):format(storeName, key, tostring(ok), err or ""))
	return ok
end

-- 1) 영구 저장소 정리
removeKey("PlayerData_v2",     "u_"..USER_ID)
removeKey("PlayerProgress_v1", "u_"..USER_ID)
removeKey("GameCoins_v2",      "p:"..USER_ID)
removeKey("PlayerData",        tostring(USER_ID))
removeKey("PlayerData",        "u_"..USER_ID)
removeKey("PetPout_v1",        "u_"..USER_ID)
removeKey("BadgeState_v1",     "u_"..USER_ID)
removeKey("Attendance_v1",     "u_"..USER_ID)
removeKey("PlayDay_v1",        "u_"..USER_ID)

if not RunService:IsRunning() then
	print("[RESET] Not in Play. Persistent cleared; fresh on next join.")
	return
end

-- 2) 모듈 로드
local function safeRequire(name:string)
	local inst = SSS:FindFirstChild(name)
	if not inst then
		for _, d in ipairs(SSS:GetDescendants()) do
			if d:IsA("ModuleScript") and d.Name == name then inst = d; break end
		end
	end
	assert(inst and inst:IsA("ModuleScript"), "Module "..name.." not found")
	local ok, mod = pcall(require, inst)
	assert(ok, "require("..inst:GetFullName()..") failed: "..tostring(mod))
	return mod
end

local PDS = safeRequire("PlayerDataService")
local CoinService = (function() local ok,m=pcall(safeRequire,"CoinService"); return ok and m or nil end)()
local BuffService = (function() local ok,m=pcall(safeRequire,"BuffService"); return ok and m or nil end)()
-- === Zone 입장 기록(쿨타임) 초기화 ===
local Affection = (function() local ok,m=pcall(safeRequire,"PetAffectionService"); return ok and m or nil end)()

-- 3) 대상 플레이어
local plr = Players:GetPlayerByUserId(USER_ID)
if not plr then
	print("[LIVE] Player offline. Fresh on next join.")
	return
end

-- 1) 항상 DS(저장소)도 초기화
local okDS = Affection:ResetZoneCooldownsByUserId(USER_ID)

if RunService:IsRunning() and plr and Affection and Affection.ResetZoneCooldowns then
	-- 온라인 플레이어: 런타임+DS 동시 초기화
	local ok1 = Affection:ResetZoneCooldowns(plr, {stopSession=true, save=true})
	print("[RESET] ZoneCooldowns (runtime+DS) reset for", USER_ID, ok1)
else
	-- 오프라인이거나 API가 없을 때: DS만 초기화 (다른 필드는 보존)
	local ds = DSS:GetDataStore("PetAffection_v1", _ds(SCOPE))
	local ok2, err2 = pcall(function()
		ds:UpdateAsync("u_"..USER_ID, function(old)
			if type(old) ~= "table" then old = {} end
			old.ZoneCooldowns = {}
			return old
		end)
	end)
	print(("[RESET] ZoneCooldowns(DS-only) -> %s %s"):format(tostring(ok2), err2 or ""))
end

local okRT = true
if plr then
	okRT = Affection:ResetZoneCooldowns(plr, { stopSession = true, save = true })
end

print(("[ZONE RESET] DS=%s, RUNTIME=%s"):format(tostring(okDS), tostring(okRT)))

-- 4) 코인/레벨/EXP 0
if CoinService and CoinService.SetBalance then pcall(function() CoinService:SetBalance(plr, 0) end) end
if PDS.SetCoins then pcall(function() PDS:SetCoins(plr, 0) end) end

local function ExpToNext(l:number) return math.floor(100 + 50*(l-1)*(l-1)) end
local L, E = 1, 0
PDS:SetLevelExp(plr, L, E)
plr:SetAttribute("Level", L)
plr:SetAttribute("Exp", E)
plr:SetAttribute("ExpToNext", ExpToNext(L))

-- 5) 백신 카운트/쿨다운/마지막시각 완전 초기화 (+ HUD)
assert(PDS.SetVaccineCount, "PDS:SetVaccineCount missing")
PDS:SetVaccineCount(plr, 0)
PDS:SetLastVaxAt(plr, 0)
PDS:SetNextVaccinationAt(plr, 0)
plr:SetAttribute("VaccinationCount", 0)

-- 6) 프로필 필드 클린
do
	local d = PDS:Get(plr)
	d.ownedPets = {}
	d.selectedPetName = nil
	d.activePets = {}
	d.buffs = {}
	d.lastVaxAt = 0
	d.nextVaxAt = 0
	-- ✅ 경찰 판정 관련 (프로필 측면)
	d.civicStatus = "none"

	if d.vaccineCounts      ~= nil then d.vaccineCounts      = {} end
	if d.petVaccineCounts   ~= nil then d.petVaccineCounts   = {} end
	if d.petVax             ~= nil then d.petVax             = {} end
	if d.affection          ~= nil then d.affection          = {} end
	if d.petAffection       ~= nil then d.petAffection       = {} end
	if d.petAffectionMaxMap ~= nil then d.petAffectionMaxMap = {} end
	for _, k in ipairs({"day","playDay","playDays","loginDay","attendanceDays","dailyStreak","streak","lastLoginDay"}) do
		if d[k] ~= nil then d[k] = 0 end
	end
	for _, k in ipairs({"firstLoginUnix","lastLoginUnix","dailyClaimUnix"}) do
		if d[k] ~= nil then d[k] = 0 end
	end
	for _, k in ipairs({"attendance","daily","achievements","quests","questProgress"}) do
		if d[k] ~= nil then d[k] = {} end
	end

	if PDS.SetActivePets then pcall(function() PDS:SetActivePets(plr, {}) end) end
	if PDS.SetBuffs then      pcall(function() PDS:SetBuffs(plr, {}) end) end

	-- ✅ 경찰 판정 관련 (속성 측면)
	if PDS.ResetCivicStatus then
		pcall(function() PDS:ResetCivicStatus(plr) end)
	else
		-- (구버전 호환) 모듈에 함수가 없다면 수동 초기화
		plr:SetAttribute("CivicStatus", "none")
		plr:SetAttribute("IsGoodCitizen", false)
		plr:SetAttribute("IsSuspiciousPerson", false)
	end

	PDS:MarkDirty(plr)
	PDS:Save(plr.UserId, "manual-reset")
end

-- 7) 런타임 버프/속성 리셋
if BuffService and BuffService.ResetFor then
	pcall(function() BuffService:ResetFor(plr) end)
else
	plr:SetAttribute("ExpMultiplier", 1)
	plr:SetAttribute("SpeedMultiplier", 1)
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = tonumber(plr:GetAttribute("BaseWalkSpeed")) or 16 end
end

-- 8) 월드에 떠 있는 펫/부착물 제거
for _, m in ipairs(workspace:GetDescendants()) do
	if m:IsA("Model") and m:GetAttribute("OwnerUserId") == USER_ID then pcall(function() m:Destroy() end) end
end
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

-- 9) 기타 HUD 런타임
plr:SetAttribute("PetAffection", 0)
plr:SetAttribute("PetAffectionMax", 10)
plr:SetAttribute("PetAffectionMinReachedUnix", 0)

print("[RESET] COMPLETE: coins/level/exp/vax records cleared; pets/affection cleared; civicStatus reset.")
