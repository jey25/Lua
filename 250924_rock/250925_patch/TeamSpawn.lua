--!strict
-- ServerScriptService/TeamSpawn.server.lua
local Players = game:GetService("Players")
local Teams   = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

-- ========== 1) 팀 보장 ==========
local function ensureTeam(name: string, colorName: string): Team
	local t = Teams:FindFirstChild(name) :: Team?
	if not t then
		t = Instance.new("Team")
		t.Name = name
		t.Parent = Teams
	end
	t.TeamColor = BrickColor.new(colorName)
	t.AutoAssignable = false
	return t
end

local BlackTeam = ensureTeam("black", "Black")
local WhiteTeam = ensureTeam("white", "White")

-- ========== 2) 스폰 탐색(영구 위치) ==========
local function isDescendantOf(inst: Instance, ancestor: Instance): boolean
	local cur: Instance? = inst
	while cur do
		if cur == ancestor then return true end
		cur = cur.Parent
	end
	return false
end

local function findSpawnInContainer(containerName: string, childName: string): SpawnLocation?
	local cont = Workspace:FindFirstChild(containerName)
	if not cont then return nil end
	local obj = cont:FindFirstChild(childName)
	if obj and obj:IsA("SpawnLocation") then
		return obj
	end
	return nil
end

-- TwoSeat(매치룸) 아래는 제외하고 워크스페이스 전역에서 보조 탐색
local function findSpawnGlobalByName(name: string): SpawnLocation?
	local twoSeat = Workspace:FindFirstChild("TwoSeat")
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("SpawnLocation") and inst.Name == name then
			if not (twoSeat and isDescendantOf(inst, twoSeat)) then
				return inst
			end
		end
	end
	return nil
end

local function resolveSpawns(): (SpawnLocation?, SpawnLocation?)
	-- 권장: Workspace.LobbySpawns.black/white
	local black = findSpawnInContainer("LobbySpawns", "black")
	local white = findSpawnInContainer("LobbySpawns", "white")

	-- 다음 후보: Workspace.Spawns.*
	if not black then black = findSpawnInContainer("Spawns", "black") end
	if not white then white = findSpawnInContainer("Spawns", "white") end

	-- 최후 보조: 워크스페이스 전역에서 이름 일치(단, TwoSeat 하위 제외)
	if not black then black = findSpawnGlobalByName("black") end
	if not white then white = findSpawnGlobalByName("white") end

	return black, white
end

-- ========== 3) 스폰 표준화 ==========
local function setupSpawn(spawn: SpawnLocation?, team: Team)
	if not spawn then return end
	spawn.Neutral = false
	spawn.TeamColor = team.TeamColor
	spawn.AllowTeamChangeOnTouch = false
	-- 필요하면 보호막 제거:
	-- spawn.Duration = 0
end

local function bindSpawns()
	local blackSpawn, whiteSpawn = resolveSpawns()
	if not blackSpawn then
		warn("[TeamSpawn] black 스폰을 찾지 못했습니다. Workspace.LobbySpawns 또는 Spawns 밑에 'black' SpawnLocation을 두세요.")
	else
		setupSpawn(blackSpawn, BlackTeam)
	end
	if not whiteSpawn then
		warn("[TeamSpawn] white 스폰을 찾지 못했습니다. Workspace.LobbySpawns 또는 Spawns 밑에 'white' SpawnLocation을 두세요.")
	else
		setupSpawn(whiteSpawn, WhiteTeam)
	end
end

bindSpawns()

-- (선택) 런타임에 스폰 폴더가 늦게 생기는 경우 대비해 감시
Workspace.ChildAdded:Connect(function(child)
	if child.Name == "LobbySpawns" or child.Name == "Spawns" then
		task.defer(bindSpawns)
	end
end)

-- ========== 4) 팀 균형 배정 + 첫 스폰 보정 ==========
local function teamCount(team: Team): number
	local n = 0
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Team == team then n += 1 end
	end
	return n
end

local function assignTeam(plr: Player)
	local bc, wc = teamCount(BlackTeam), teamCount(WhiteTeam)
	local chosen: Team
	if bc == wc then
		-- 동률이면 UserId 홀짝으로 안정적 분배
		chosen = (plr.UserId % 2 == 0) and BlackTeam or WhiteTeam
	else
		chosen = (bc < wc) and BlackTeam or WhiteTeam
	end
	plr.Team = chosen

	-- 팀 설정이 늦게 반영된 경우/초기 스폰 보정
	-- (Roblox가 이미 스폰시킨 뒤일 수 있으니, 즉시 올바른 스폰으로 재스폰)
	if plr.Character then
		plr:LoadCharacter()
	end
end

Players.PlayerAdded:Connect(assignTeam)
