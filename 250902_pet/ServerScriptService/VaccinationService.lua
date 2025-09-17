-- ServerScriptService/VaccinationService.server.lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DoctorTryVaccinate = ReplicatedStorage:FindFirstChild("DoctorTryVaccinate")
	or Instance.new("RemoteFunction", ReplicatedStorage)
DoctorTryVaccinate.Name = "DoctorTryVaccinate"

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CoinService = require(script.Parent:WaitForChild("CoinService"))

local MAX_VACCINES = 5 -- UI와 동일한 상한(필요시 조정)

DoctorTryVaccinate.OnServerInvoke = function(player: Player, payload)
	local cur = PlayerDataService:GetVaccineCount(player)
	if cur >= MAX_VACCINES then
		return { ok = false, count = cur, reason = "max" }
	end

	-- IncVaccineCount 내부에서:
	-- 1) 저장값 += 1
	-- 2) player:SetAttribute("VaccinationCount", newCount) 수행
	local newCount = PlayerDataService:IncVaccineCount(player, 1)

	-- 선택펫에도 1 올림 (선택펫이 있으면)
	local sel = PlayerDataService:Get(player).selectedPetName
	if sel then
		PlayerDataService:IncPetVaccine(player, sel, 1)
	end

	-- (선택) 코인 1 보상 (중복키 ‘VAX:n’)
	CoinService:Award(player, "VAX:"..tostring(newCount))

	return { ok = true, count = newCount }
end