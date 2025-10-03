-- ServerScriptService/VaccinationServer.lua  (이름은 임의)
--!strict
local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")

-- RemoteFunction: 접종 시도
local TryVaccinate = RS:FindFirstChild("DoctorTryVaccinate") :: RemoteFunction
if not TryVaccinate then
	TryVaccinate = Instance.new("RemoteFunction")
	TryVaccinate.Name = "DoctorTryVaccinate"
	TryVaccinate.Parent = RS
end

-- RemoteEvents/VaccinationFX: 클라 이펙트 트리거 (미리 생성해 두어 레이스 방지)
local Remotes = RS:FindFirstChild("RemoteEvents") or Instance.new("Folder")
Remotes.Name = "RemoteEvents"
Remotes.Parent = RS

local VaccinationFX = Remotes:FindFirstChild("VaccinationFX") :: RemoteEvent
if not VaccinationFX then
	VaccinationFX = Instance.new("RemoteEvent")
	VaccinationFX.Name = "VaccinationFX"
	VaccinationFX.Parent = Remotes
end

-- 서버 상태(세션 메모리용)
local MAX_VACCINES = 5
local TWO_WEEKS    = 14 * 24 * 60 * 60  -- 1209600

local counts: {[number]: number} = {}
local lastAt: {[number]: number} = {}

-- 접속 시 클라 HUD 초기값 동기화
Players.PlayerAdded:Connect(function(p)
	p:SetAttribute("VaccinationCount", counts[p.UserId] or 0)
end)

TryVaccinate.OnServerInvoke = function(player: Player, action: string)
	if action ~= "try" then
		return { ok=false, reason="bad_request" }
	end

	local uid = player.UserId
	local now = os.time()
	local c   = counts[uid] or 0
	local t   = lastAt[uid] or 0

	-- 최대치
	if c >= MAX_VACCINES then
		return { ok=false, reason="max", count=c }   -- ★ 클라와 키 통일
	end
	-- 쿨다운
	local elapsed = now - t
	if elapsed < TWO_WEEKS then
		return {
			ok=false,
			reason="wait",                             -- ★ 키 통일
			count=c,
			wait = TWO_WEEKS - elapsed                 -- 남은 초
		}
	end

	-- 성공 처리
	c += 1
	counts[uid] = c
	lastAt[uid] = now

	-- Attribute 반영 → 클라 HUD 즉시 갱신
	player:SetAttribute("VaccinationCount", c)

	-- 클라 FX 트리거 (첫 접종 포함 항상 발사)
	VaccinationFX:FireClient(player, { count = c })

	return { ok=true, reason="ok", count=c }
end
