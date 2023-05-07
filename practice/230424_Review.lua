

local ball1 = game.ServerStorage:FindFirstChild("rollingStone1")
local ball2 = game.ServerStorage:FindFirstChild("rollingStone2")
local ball3 = game.ServerStorage:FindFirstChild("rollingStone3")

local balls = {ball1, ball2, ball3}

local destroyHeight = 30


while true do
	for i=1, 3 do	
		balls[i].Parent = workspace
		balls[i].Position = Vector3.new(-150, 90, 363)
		wait(1.5)
		balls[i].Parent = workspace
		balls[i].Position = Vector3.new(-170, 90, 363)
		wait(1.5)
		balls[i].Parent = workspace
		balls[i].Position = Vector3.new(-183, 90, 363)
		
		if balls[i].Position.Y <= destroyHeight then -- Y값이 일정 높이 이하일 경우
			balls[i]:Destroy() -- Part를 파괴합니다.
		end
		wait(.5)
	end
end

local friction = 0.5 -- 마찰력 값을 조절합니다.
local debounce = false

function onTouched(hit)
    if debounce then return end
    debounce = true
    local humanoid = hit.Parent:FindFirstChild("Humanoid")
    if humanoid then
        local floor = workspace.Terrain:FindPartOnRay(Ray.new(hit.Position, Vector3.new(0, -1, 0)), humanoid.Parent)
        if floor and floor == script.Parent then
            humanoid.PlatformStand = true
            wait()
            humanoid.PlatformStand = false
            humanoid.Sit = true
            wait()
            humanoid.Sit = false
            humanoid.WalkSpeed = humanoid.WalkSpeed * (1 - friction)
        end
    end
    debounce = false
end

script.Parent.Touched:Connect(onTouched)


-- Part 에 닿은 것이 Humanoid 일 때만 블럭이 3초간 사라짐

local part = script.Parent
local isTouched = false

part.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if not isTouched and humanoid then
		isTouched = true
		for i = 0, 10, 1 do
			part.Transparency = i/10
			wait(0.1)
		end
		part.CanCollide = false
		wait(3)
		part.CanCollide = true
		part.Transparency = 0
		isTouched = false
	end
end)


-- 무한이동 킬 파트

function lavaControl()
	local lava = script.Parent
	-- 이동할 위치와 원래 위치를 지정합니다.
	local newPosition = Vector3.new(-105, 90.25, 847.75)
	local originalPosition = lava.Position

	-- part를 서서히 이동시키는 TweenService 인스턴스를 생성합니다.
	-- Duration 은 이동에 걸리는 시간 입력
	local tweenService = game:GetService("TweenService")
	local tweenInfo = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = tweenService:Create(lava, tweenInfo, {Position = newPosition})

	-- part가 이동한 후, 다시 원래 위치로 서서히 돌아오는 TweenService 인스턴스를 생성합니다.
	local returnTweenInfo = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local returnTween = tweenService:Create(lava, returnTweenInfo, {Position = originalPosition})

	-- part를 서서히 이동시키는 Tween을 시작합니다.
	tween:Play()

	wait(3) -- part가 이동하는 동안 대기합니다.
	returnTween:Play()
	
end

while true do
	wait(2.5)
	lavaControl()	
end


local part = script.Parent
local targetScale = Vector3.new(1.5, 1, 30) -- 목표 스케일
local shrinkDuration = 3 -- 줄어들기 애니메이션에 걸리는 시간 (초)
local expandDuration = 2 -- 늘어나기 애니메이션에 걸리는 시간 (초)
local waitTime = 1 -- 줄어들고 난 후 대기 시간 (초)

local originalScale = part.Size

while true do
	-- 첫 번째 Tween: 파트를 일정 길이까지 줄이는 Tween 생성
	local shrinkTween = game:GetService("TweenService"):Create(part, TweenInfo.new(shrinkDuration, Enum.EasingStyle.Linear), {Size = targetScale})
	shrinkTween:Play()
	shrinkTween.Completed:Wait() -- 첫 번째 Tween이 완료될 때까지 대기

	wait(1) -- 일정 시간 대기

	-- 두 번째 Tween: 파트를 원래 크기로 되돌리는 Tween 생성
	local expandTween = game:GetService("TweenService"):Create(part, TweenInfo.new(expandDuration, Enum.EasingStyle.Linear), {Size = originalScale})
	expandTween:Play()
	expandTween.Completed:Wait()
end

print("gogo")
print(2 + 2 *2 <= 7)

-- Property 에서 Reflectance 가 1이면 브릭컬러가 적용이 안됨

if workspace.Baseplate == nil then
	print("Baseplate False")
else
	print("Baseplate True")
end


--로컬 스크립트 SHIFT 달리기

local player = game.player.LocalPlayer
local Player2 = player.Character
local service = game:GetService("UserInputState")

service.InputBegan:Connect(function(SHIFT)
	if SHIFT.KeyCode == Enum.KeyCode.LeftShift then
		Player2.Humanoid.WalkSpeed = 30
	end
end)

service.InputEnded:Connect(function (Shift)
	if Shift.KeyCode == Enum.KeyCode.LeftShift then
		Player2.Humanoid.WalkSpeed = 16
	end
end)


-- 2초 뒤 파트 제거
wait(2)
local part = script.Parent
part:Destroy()

--Serversstorage 안에 있는 파트 10개 클론
for i=1, 10 do
	local part = game.ServerStorage.Part
	local clone = part:clone()
	clone.Parent = workspace
	clone.BrickColor = BrickColor.Black()
	wait()
end

--함수
local function ClonePart(part, location)
	local clone = part:Clone()
	clone.Parent = location
	return clone
end

print("test")
wait(2)

local clone = ClonePart(game.ServerStorage.Part,  workspace)
clone.BrickColor = BrickColor.Random()


--StarterGUI Local script
local GameMessage = game.ReplicatedStorage.GameMessage
local GameState = script.Parent.GameState


GameMessage.Changed:Connect(function()
	GameState.Text = GameMessage.Value
end)





--SwordMan Main Script

--플레이어 인원수가 1명 이하면 대기, 1명 이상이면 10부터 카운트 후 1초가 되면 GameStarted value 값이 1로 변경

GameStarted = game.ReplicatedStorage.GameStarted
GameMessage = game.ReplicatedStorage.GameMessage

-- spawnpoint 를 가져옴
local SpawnPoint = game.Workspace.Fight.Spawnpoints:GetChildren()

local function UpdateLobby()
	while GameStarted.Value == false do
		local players = game.Players:GetChildren()
		local playerCount = #players
		
		if playerCount < 1 then
			GameMessage.Value = "플레이어 대기중..."
		else 
			for i = 10, 1, -1 do
				GameMessage.Value = "게임 시작까지 " .. i .. "초"
				wait(1)
			end
			
			GameStarted.Value = true
			return
				
		end
		
		wait(1)
	end
end

--FightPlate 에서 카운트 30초 시작
local function UpdateFightplate()
	for i = 10, 1, -1 do
		GameMessage.Value = i .. "초가 남았습니다."
		wait(1)
	end
	
	GameStarted.Value = false
end

-- GameStarted 가 true 로 변경되면 캐릭터들을 spawnpoint 로 이동시킴
GameStarted.Changed:Connect(function()
	if GameStarted.Value == true then
		for i, player in pairs(game.Players:GetChildren()) do
			local character = player.Character
			local position = SpawnPoint[i].CFrame
			position = position + Vector3.new(0, 10, 0)
			character.HumanoidRootPart.CFrame = position
			
			--검 지급
			local tool = game.ReplicatedStorage.ClassicSword:Clone()
			tool.Parent = player.Backpack
			character.Humanoid:EquipTool(tool)
			
		end
		
		UpdateFightplate()
	else
		for i, player in pairs(game.Players:GetChildren()) do
			local character = player.Character
			local position = game.Workspace.Lobby.SpawnLocation.CFrame
			position = position + Vector3.new(0, 10, 0)
			character.HumanoidRootPart.CFrame = position
			
			--검 회수
			for _, obj in pairs(character:GetChildren()) do
				if obj:IsA("Tool") then
					obj:Destroy()
				end
			end
			
			for _, obj in pairs(player.Backpack:GetChildren()) do
				if obj:IsA("Tool") then
					obj:Destroy()
				end
			end
			
		end
		
		UpdateLobby()
	end
end)

UpdateLobby()


--점프 파트
local trampoline = script.Parent

--Y Position Velocity 값을 IntValue 값으로 설정
trampoline.Velocity = Vector3.new(0, trampoline.Configuration.BounceSpeed.Value, 0)
trampoline.SurfaceGui.Enabled = false



--Shift 달리기 LocalScript

------------------------------------------------------------
-- 달리기
------------------------------------------------------------
local UserInput = game:GetService('UserInputService')
local LocalPlayer = game:GetService("Players").LocalPlayer


------------------------------------------------------------
-- 변수
------------------------------------------------------------
local Humanoid = script.Parent:WaitForChild('Humanoid')

local WalkSpeed = 16
local RunSpeed = 30


------------------------------------------------------------
-- 플레이어 속도 조절
------------------------------------------------------------
local function ChangeSpeed(speed)
	Humanoid.WalkSpeed = speed
end


------------------------------------------------------------
-- 버튼 입력이 들어올 때.
------------------------------------------------------------
UserInput.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.LeftShift then -- 입력한 키가 Shift 라면,
				ChangeSpeed(RunSpeed)
			end
		end
	end
end)


------------------------------------------------------------
-- 버튼 입력이 끝날 때.
------------------------------------------------------------
UserInput.InputEnded:Connect(function(input, gameProcessed)
	if not gameProcessed then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.LeftShift then -- 입력한 키가 Shift 라면,
				ChangeSpeed(WalkSpeed)
			end
		end
	end
end)



-- 위아래 움직이는 파트
local model = script.Parent
local pc = model.part.PrismaticConstraint

while true do
	if math.ceil((model.part.Position-model.anchor.Position).Magnitude) >= math.abs(pc.TargetPosition) then
		pc.TargetPosition = -pc.TargetPosition
        wait(1)
    end
    wait()
end


-- 좌우 움직이는 파트
local model = script.Parent
local pc = model.part.PrismaticConstraint

while true do
	if math.ceil((model.part.Position-model.anchor.Position).Magnitude) >= math.abs(pc.TargetPosition) then
		pc.TargetPosition = -pc.TargetPosition
        wait(1)
    end
    wait()
end


-- 접속한 플레이어의 이름을 텍스트로 표현
-- workspace 에 part - surfaceGui - Textlabel 생성
-- starterPlayerScript > LocalScript

local namePart = workspace:WaitForChild("namePart")
local surfaceGui = namePart:WaitForChild("SurfaceGui")
local textLabel = surfaceGui:WaitForChild("TextLabel")

local player = game.Players.LocalPlayer
local name = player.Name

textLabel.Text = name.."Hi"


-- 파트를 이동시키며 회전까지 시킴
workspace.Part.CFrame = CFrame.new(5,5,5) * CFrame.Angles(1,1,1)
workspace.Part.CFrame = workspace.Part.CFrame * CFrame.Angles(math.rad(30), 0, 0)



-- 고급

-- GUIService 하위의 image 에 Localscript 로 이미지 회전
local runService = game:GetService("RunService")

function update(step)
	script.Parent.Rotation += step * 60
end

runService.RenderStepped:Connect(update)


--localscript 로 RenderStepped 사용하여 파트 회전
local part = workspace:WaitForChild("rotate")
local runSerivce = game:GetService("RunService")

function update(step)
	part.CFrame *= CFrame.Angles(0,math.rad(180)*step ,0)
end

runSerivce.RenderStepped:Connect(update)



--모듈 스크립트 기초 , 킬파트

local killpart = {}

killpart.Enabled = true

function killpart.kill(hit)
	local humanoid = hit.parent:FindFirstChild("Humanoid")
	if humanoid and killpart.Enabled then
		humanoid.Health = 0
	end
end

return killpart


local killpart = require(workspace.killpart)

script.Parent.Touched:Connect(function(hit)
	killpart.kill(hit)
end)


--Module Script 에 함수가 하나 있을 때 함수 이름 자체가 모듈 스크립트가 되는 경우
function killpart(hit)
	local humanoid = hit.parent:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.Health = 0
	end
end

return killpart


--part 간 거리를 구하는 Magnitude
local pos = workspace.part2.Position - workspace.part1.Position

print(pos.Magnitude)



--coroutine 함수를 사용해 한 script 에서 여러개 코드 동시 실행

local function ChangeColor(part)
	for i=0, 100 do
		wait()
		part.BrickColor = BrickColor.Random()
	end
	return part
end

--ChangeColor(workspace.Part1)
--ChangeColor(workspace.Part2)
--ChangeColor(workspace.Part3)


--local c1 = coroutine.create(ChangeColor)
--coroutine.resume(c1, workspace.Part1)

--wrap 으로 쓰면 create, resume  안써도 됨
local c3 = coroutine.wrap(ChangeColor)
c3(workspace.Part1)

local c2 = coroutine.create(ChangeColor)
coroutine.resume(c2, workspace.Part2)

ChangeColor(workspace.Part3)

