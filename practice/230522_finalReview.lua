
--캐릭터가 특정 part 에 도달했을 때 SpawnLocation 을 옮겨준다
local part = script.Parent

part.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid then
		workspace.SpawnLocation.Position = Vector3.new(-16, 6.5, 18.5)
	end
end)


--플레이어의 레벨을 리더보드에 세팅한다
local function playerJoin(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	
	local level = Instance.new("IntValue")
	level.Name = "level"
	level.Value = 1
	level.Parent = leaderstats
	
end

game.Players.PlayerAdded:Connect(playerJoin)


--파트에 닿은 플레이어의 level 을 올려준다
local part = script.Parent

local function onTouched(hit)
	local player = game.Players:GetPlayerFromCharacter(hit.Parent)
	
	if player then
		player.leaderstats.level.Value += 1
	end
end

part.Touched:Connect(onTouched)


--파트에 닿은 플레이어의 레벨이 5 미만일때만 체력을 0으로 만든다
local part = script.Parent

local function onTouched(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	local player = game.Players:GetPlayerFromCharacter(hit.Parent)
	
	if player then
		if humanoid and player.leaderstats.level.Value < 5 then
			humanoid.Health = 0
	end
	end
	end

part.Touched:Connect(onTouched)



-- 2023-06-01
part.Touched:Wait()
part.Touched:Connect()


workspace:FindFirstChild("Part")
-- 캐릭터 찾기
Pawn?

local part = script.Parent

function changeName(hit)
	local chr = hit.Parent:FindFirstChild("Pawn")
	if chr then
		print("Player")
		part.Name = "Jang"
	end	
end


-- GUI Button 
local button = script.Parent

local function onButtonActivated()
    print("Button activated!")
    -- Perform expected button action(s) here

end

button.Activated:Connect(onButtonActivated)



