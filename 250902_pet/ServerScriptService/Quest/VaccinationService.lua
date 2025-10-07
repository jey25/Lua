-- ServerScriptService/VaccinationService.server.lua
--!strict
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Remotes 안전 생성
local DoctorTryVaccinate = ReplicatedStorage:FindFirstChild("DoctorTryVaccinate") :: RemoteFunction?
if not DoctorTryVaccinate then
	DoctorTryVaccinate = Instance.new("RemoteFunction")
	DoctorTryVaccinate.Name = "DoctorTryVaccinate"
	DoctorTryVaccinate.Parent = ReplicatedStorage
end

local RemoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents") :: Folder?
if not RemoteEvents then
	RemoteEvents = Instance.new("Folder")
	RemoteEvents.Name = "RemoteEvents"
	RemoteEvents.Parent = ReplicatedStorage
end

local VaccinationFX = RemoteEvents:FindFirstChild("VaccinationFX") :: RemoteEvent?
if not VaccinationFX then
	VaccinationFX = Instance.new("RemoteEvent")
	VaccinationFX.Name = "VaccinationFX"
	VaccinationFX.Parent = RemoteEvents
end

local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataService = require(ServerScriptService:WaitForChild("PlayerDataService"))
local CoinService       = require(ServerScriptService:WaitForChild("CoinService"))
local ExperienceService = require(ServerScriptService:WaitForChild("ExperienceService"))


local VaccinationService = { _locks = {} :: {[number]: boolean} }

local MAX_VACCINES  = 5
local COOLDOWN_SECS = 7 * 24 * 60 * 60 -- 2주

-- ▶ 조절 가능한 값
local EXP_PER_VACCINE = 500  -- 접종 1회 EXP
local AFFECTION_DECAY = 1    -- 접종 1회 애정도 감소

-- 단일 처리 함수(성공/실패 모두 여기서 결정)
local function doVaccinate(player: Player)
	local cur = PlayerDataService:GetVaccineCount(player)
	if cur >= MAX_VACCINES then
		return { ok=false, count=cur, reason="max" }
	end

	local nowTs  = os.time()
	local nextAt = PlayerDataService:GetNextVaccinationAt(player)
	if nextAt == 0 then
		-- 과거 저장과의 호환: lastVaxAt + cooldown 으로 보정
		local lastTs = PlayerDataService:GetLastVaxAt(player)
		nextAt = lastTs + COOLDOWN_SECS
	end
	if nextAt > nowTs then
		return { ok=false, count=cur, reason="wait", wait=(nextAt - nowTs) }
	end

	local newCount = PlayerDataService:IncVaccineCount(player, 1)

	local data = PlayerDataService:Get(player)
	local sel = data.selectedPetName
	if sel then
		PlayerDataService:IncPetVaccine(player, sel, 1)
		if AFFECTION_DECAY > 0 then PlayerDataService:AddAffection(player, sel, -AFFECTION_DECAY) end
	end

	-- ⬇ 쿨다운 타임스탬프 갱신(둘 다 유지)
	PlayerDataService:SetLastVaxAt(player, nowTs)
	PlayerDataService:SetNextVaccinationAt(player, nowTs + COOLDOWN_SECS)

	if EXP_PER_VACCINE > 0 then
		local ok, err = pcall(function()
			ExperienceService.AddExp(player, EXP_PER_VACCINE)
		end)
		if not ok then
			warn("[VaccinationService] AddExp failed:", err)
		end
	end


	-- 즉시 저장(쓰로틀 예외 허용됨)
	PlayerDataService:Save(player.UserId, "vaccinate")

	pcall(function() CoinService:Award(player, "VAX:"..tostring(newCount)) end)
	pcall(function() VaccinationFX:FireClient(player, { count = newCount }) end)

	return { ok=true, count=newCount }
end

-- RemoteFunction 진입점(락으로 중복 호출 방지)
DoctorTryVaccinate.OnServerInvoke = function(player: Player, payload: any)
	local uid = player.UserId
	if VaccinationService._locks[uid] then
		return { ok = false, count = PlayerDataService:GetVaccineCount(player), reason = "busy" }
	end
	VaccinationService._locks[uid] = true
	local result
	local ok, err = pcall(function()
		result = doVaccinate(player)
	end)
	VaccinationService._locks[uid] = nil

	if ok and result then return result end
	warn("[VaccinationService] error:", err)
	return { ok = false, count = PlayerDataService:GetVaccineCount(player), reason = "error" }
end

return VaccinationService
