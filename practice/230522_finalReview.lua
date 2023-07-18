
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


-- 0619
1. print 잘못 썼을 때 (문법 등) 에러 로그 띄워주는 부분
2. 개체 이름이 동일할 것이 겹칠 때의 에러 처리
3. 개체 이름 숫자로 시작, 띄어쓰기 있을 때, 한국어로 되어 있을 때, 특수문자로 시작할 때
4. Part.Transparency 속성에 추가 요청하기

script.Parent.Transparency = 0.5
script.Parent.Name = "한글"


5. 속성 변경 시 형식에 맞지 않는 값을 넣어줬을 때의 처리

script.Parent.Anchored = false
script.Parent.Material = Enum.Material.Brick
script.Parent.BackSurface = Enum.SurfaceType.Smooth
script.Parent.BrickColor = BrickColor.Random()

6. 기본적인 사칙연산
+, - , *, / , %, ==, <=, >=, ~=, 

7.elseif  then

-- part 사이즈 변경
-- 8. workspace.Part.Size = Vector3.new(10,5,20)

-- 9. Script 에서의 for 반복문 출력 (Print)

-- 10. workspace.Part.Position = workspace.Part.Position + Vector3.new(1, 0, 0)


11. 파트 생성
for i=1, 50 do
	Instance.new("Part", workspace)
	wait()
end

-- 12. 파트 파괴
local part = script.Parent
wait(2)
part:Destroy()

-- 13. 파트 복사
local part = game.ServerStorage.Part

local clone = part:Clone()
clone.Parent = workspace

-- 14. 파트 복사
for i=1, 10 do
	local part = game.ServerStorage.Part

	local clone = part:Clone()
	clone.Parent = workspace
	clone.BrickColor = BrickColor.Black()
	wait()
end	

15. Move to?

moveforward()


16. 서버 스크립트에서는 LocalPlayer 못 쓰는 부분


17. 서버 스크립트에서는 GetPLayer 로 플레이어 구하기


18. remoteEvent

local remoteEvent = game.ReplicatedStorage:WaitForChild("RemoteEvent")
remoteEvent:FireServer()

local remoteEvent = game.ReplicatedStorage.RemoteEvent
remoteEvent.OnServerEvent:Connect(function()
	
end)


-- 19. starterGUI - ScreenGUI - Frame - Script, TextLabel 을 이용한 인트로 만들기

local intro = script.Parent
wait(2)

local tween = game:GetService("TweenService")
local timeToFade = 5
local tweenInfo = TweenInfo.new(timeToFade)

local goal = {}
goal.BackgroundTransparency = 1
local tween = tweenService:Create(intro, tweenInfo, goal)
tween:Play()

local text = {}
text.TextTransparency = 1
local tweenText = tweenService:Create(intro.TextLabel, tweenInfo, text)
tweenText:Play()

wait(timeToFade)
intro:Destroy()

-- 20. Part - BillboardGUI - Text 로 짜는 머리 위에 팀 그룹 역할 표시 (서버 스토리지)
-- 모든 사이즈를 Scale 로 맞춰주는게 핵심



local overheadDisplay = game:GetService("ServerStorage"):WaitForChild("BillboardGui")
local GROUP_ID = 42 -- change your groupID
local function addLabel(player)
	player.CharacterAdded:Connect(function(character)
		local playerDisplay = overheadDisplay:Clone()
		playerDisplay.Name.Text = player.Name

		if player.Team then
			local TeamString = player.Team.Name
			playerDisplay.Team.Text = TeamString
		end

		local RoleString = player:GetRoleInGroup(GROUP_ID)
		playerDisplay.Role.Text = RoleString
		
		playerDisplay.Parent = game.workspace:WaitForChild(player.Name).Head
		character.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end)
end

game.Players.PlayerAdded:Connect(addLabel)



-- 코인 획득 스크립트

local coinSound = game.ServerStorage:FindFirstChild('coin')

local folder = script.Parent
local parts = folder:GetChildren()

for i=1, #parts do
	if parts[i]:IsA("BasePart") then
		parts[i].Touched:Connect(function(hit)
			local humanoid = hit.Parent:FindFirstChild("Humanoid")
			if humanoid then
				parts[i]:Destroy()
				local audio = coinSound:Clone()
				audio.Parent = workspace
				audio:Play()
				wait(.5)
				audio:Destroy()
			end

			local player = game.Players:GetPlayerFromCharacter(hit.Parent)
			
			if player then
				local score = player.leaderstats.Score.Value + 1
				player.leaderstats.Score.Value = score
			end
		end)
	end
end


-- 리더보드 스크립트 

local Players = game:GetService("Players")


local function onCharacterAdded(character, player)
	player:SetAttribute("IsAlive", true)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.Died:Connect(function()
		local points = player.leaderstats.Points
		points.Value = 0
		player:SetAttribute("IsAlive", false)
	end)
end

local function onPlayerAdded(player)
	
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	
	local points = Instance.new("IntValue")
	points.Name = "Points"
	points.Value = 0
	points.Parent = leaderstats
	
	local score = Instance.new("IntValue")
	score.Name = "Score"
	score.Value = 0
	score.Parent = leaderstats
	
	player:SetAttribute("IsAlive", false)
	
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(character, player)
	end)
end

game.Players.PlayerAdded:Connect(onPlayerAdded)


while true do

	wait(1)
	local playerlist = Players:GetPlayers()
	for currentPlayer = 1, #playerlist do
		local player = playerlist[currentPlayer]
		--만약 SetAttribute 값 IsAlive 가 True 이면 그때만 포인트를 증가시킨다
		if player:GetAttribute("IsAlive") then
			local points = player.leaderstats.Points
			points.Value = points.Value + 1
			end
	end
end
