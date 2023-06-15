
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


-- 0603 엔진 테스트

1. workspace - script - print function - script error

2. print(scritp.Parent) - workspace
script.Parent.Parent.part
workspace.part.script
print(workspace.Parent)
Services.workspace
workspace.part.Name - 이름이 겹칠 때 상황 check
객체의 이름이 규칙에 어긋날 때 상황 - 숫자, 띄어쓰기, 한글, 특수문자

3. script 를 통한 속성 편집
script.Parent.Name
script.Parent.Size?
잘못된 자료형을 입력했을 때의 처리

4. script.Parent.Anchored = true, false
script.Parent.Material = Enum.Material.Brick
자동완성 되지 않는 항목들 목록 기록

5. workspace.Camera
workspace.Terrain
workspace.PlayerSpawner

6. workspace.part.BrickColor = BrickColor.new("New Yeller")
BrickColor.Random()
BrickColor.Red

7. 로블록스 엔진 가이드를 불카누스로 재현해보기
	- 모델링, 환경, 효과, 애니메이션 등
	https://create.roblox.com/docs/tutorials




-- GUI Button 
local button = script.Parent

local function onButtonActivated()
    print("Button activated!")
    -- Perform expected button action(s) here

end

button.Activated:Connect(onButtonActivated)


--proximity Prompt 상호작용
local ProximityPromptService = game:GetService("ProximityPromptService")
local ServerScriptService = game:GetService("ServerScriptService")

local ObjectActions = require(ServerScriptService.ObjectActions)

-- Detect when prompt is triggered
local function onPromptTriggered(promptObject, player)
	ObjectActions.promptTriggeredActions(promptObject, player)
end

-- Detect when prompt hold begins
local function onPromptHoldBegan(promptObject, player)
	ObjectActions.promptHoldBeganActions(promptObject, player)
end

-- Detect when prompt hold ends
local function onPromptHoldEnded(promptObject, player)
	ObjectActions.promptHoldEndedActions(promptObject, player)
end

-- Connect prompt events to handling functions
ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
ProximityPromptService.PromptButtonHoldBegan:Connect(onPromptHoldBegan)
ProximityPromptService.PromptButtonHoldEnded:Connect(onPromptHoldEnded)


local SoundService = game:GetService("SoundService")
local backgroundMusic = SoundService.BackgroundMusic

backgroundMusic:Play()


local pickupObjects = game.Workspace.Collectables.Objects
local objectsArray = pickupObjects:GetChildren()

local function partTouched(otherPart, objectPart)
    local whichCharacter = otherPart.Parent
    local humanoid = whichCharacter:FindFirstChildWhichIsA("Humanoid")

    if humanoid and objectPart.CanCollide == true then

    end
end

-- Binds every object part to the touch function so it works on all parts
for objectIndex = 1, #objectsArray do
    local objectPart = objectsArray[objectIndex]
    objectPart.Touched:Connect(function(otherPart)
        partTouched(otherPart, objectPart)
    end)
end

local laserTrap = script.Parent
local collisionBox = laserTrap:FindFirstChild("CollisionBox")

-- Hide the collision box
collisionBox.Transparency = 1

local function onTouch(otherPart)
  local character = otherPart.Parent
  local humanoid = character:FindFirstChildWhichIsA("Humanoid")

  if humanoid then
    humanoid.Health = 0
  end
end

collisionBox.Touched:Connect(onTouch)


local trapObject = script.Parent
local particleEmitter = trapObject:FindFirstChild("Explosion")

local EMIT_AMOUNT= 100

local function killPlayer(otherPart)
    local character = otherPart.Parent
    local humanoid = character:FindFirstChildWhichIsA("Humanoid")

    if humanoid then
        humanoid.Health = 0
        particleEmitter:Emit(EMIT_AMOUNT)
    end
end

trapObject.Touched:Connect(killPlayer)


--players 예시
local Players = game:GetService("Players")

local function onCharacterAdded(character)
	-- Give them sparkles on their head if they don't have them yet
	if not character:FindFirstChild("Sparkles") then
		local sparkles = Instance.new("Sparkles")
		sparkles.Parent = character:WaitForChild("Head")
	end
end

local function onPlayerAdded(player)
	-- Check if they already spawned in
	if player.Character then
		onCharacterAdded(player.Character)
	end
	-- Listen for the player (re)spawning
	player.CharacterAdded:Connect(onCharacterAdded)
end

Players.PlayerAdded:Connect(onPlayerAdded)