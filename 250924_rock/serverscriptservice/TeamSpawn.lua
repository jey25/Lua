-- ServerScriptService/TeamSpawn.server.lua
local Players = game:GetService("Players")
local Teams   = game:GetService("Teams")

-- 1) 팀 보장(없으면 자동 생성)
local blackTeam = Teams:FindFirstChild("black") or Instance.new("Team")
blackTeam.Name = "black"
blackTeam.TeamColor = BrickColor.new("Black")
blackTeam.AutoAssignable = false
blackTeam.Parent = Teams

local whiteTeam = Teams:FindFirstChild("white") or Instance.new("Team")
whiteTeam.Name = "white"
whiteTeam.TeamColor = BrickColor.new("White")
whiteTeam.AutoAssignable = false
whiteTeam.Parent = Teams

-- 2) 스폰(SpawnLocation) -> 팀 매핑
local function setupSpawn(spawn, team)
	if not (spawn and spawn:IsA("SpawnLocation")) then return end
	spawn.Neutral = false
	spawn.TeamColor = team.TeamColor
	spawn.AllowTeamChangeOnTouch = false
	-- spawn.Duration = 0 -- 보호막 제거 원하면 주석 해제
end

local container = workspace:FindFirstChild("TwoSeat") or workspace
setupSpawn(container:FindFirstChild("black"), blackTeam)
setupSpawn(container:FindFirstChild("white"), whiteTeam)

-- 3) 팀 균형 배정(동시 접속에도 서로 다른 팀으로)
local function count(team)
	local n = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Team == team then n += 1 end
	end
	return n
end

local function assignTeam(plr)
	local b, w = count(blackTeam), count(whiteTeam)
	local chosen
	if b == w then
		-- 동률이면 UserId 홀짝으로 안정적 분배
		chosen = (plr.UserId % 2 == 0) and blackTeam or whiteTeam
	else
		chosen = (b < w) and blackTeam or whiteTeam
	end
	plr.Team = chosen

	-- 팀 설정이 늦게 반영된 경우를 대비해 즉시 올바른 스폰으로 리스폰
	if plr.Character then plr:LoadCharacter() end
end

Players.PlayerAdded:Connect(assignTeam)

