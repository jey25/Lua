--!strict
-- ServerScriptService/PoliceService.lua
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

-- Remotes 준비
local folder = RS:FindFirstChild("PoliceRemotes") :: Folder?
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "PoliceRemotes"
	folder.Parent = RS
end

local PoliceChoice = folder:FindFirstChild("PoliceChoice") :: RemoteEvent?
if not PoliceChoice then
	PoliceChoice = Instance.new("RemoteEvent")
	PoliceChoice.Name = "PoliceChoice"
	PoliceChoice.Parent = folder
end

-- 선택 처리(단 한 번만)
PoliceChoice.OnServerEvent:Connect(function(player: Player, choice: string)
	local current = PlayerDataService:GetCivicStatus(player)
	if current ~= "none" then
		-- 이미 결정된 플레이어는 무시(중복/변조 방지)
		return
	end

	local setTo: string? = nil
	if choice == "ok1" then
		setTo = "good"         -- good citizen
	elseif choice == "ok2" then
		setTo = "suspicious"   -- suspicious person
	else
		return -- 알 수 없는 입력
	end

	PlayerDataService:SetCivicStatus(player, setTo :: string)
	-- 바로 저장(이벤트성): 재접속해도 유지
	PlayerDataService:Save(player.UserId, "police-choice")
end)

-- 플레이어 입장 시 데이터는 PlayerDataService:Load() 과정에서 Attribute로 이미 싱크됨.
Players.PlayerAdded:Connect(function(plr)
	-- 강제 로드해서 속성 세팅 보장(안전)
	PlayerDataService:Load(plr)
end)

