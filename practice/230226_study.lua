print("Start")
print("I complexibity in my mind")

print(workspace.Car.Color111.script)
print(workspace.1x1 Curve Boulevard)
print(workspace["1x1 Curve Boulevard"])
print(workspace["한국어"])

script.Parent.Transparency = 0.5
script.Parent.Anchored = false
script.Parent.Material = Enum.Material.Brick
script.Parent.BackSurface = Enum.SurfaceType.Smooth

workspace.Cube.BrickColor = BrickColor.new("New Yeller")
workspace.Cube.BrickColor = BrickColor.Random()
workspace.Cube.BrickColor = BrickColor.red()

print(workspace.Car.PrimaryPart)
workspace.Car.PrimaryPart = nil

if workspace.Car.PrimaryPart then
 if workspace.Car.PrimaryPart.Anchored then
  print("aaaaaaaaaaaaa")
 end
end

if workspace.Car.PrimaryPart and workspace.Car.PrimaryPart.Anchored  then
 print("aaaaaaaaaaaaa")
end

if workspace.Car.PrimaryPart or workspace.Car.PrimaryPart.Anchored  then
 print("aaaaaaaaaaaaa")
end

if true and (true or true) then
 print("aaaaaaaaaaaaa")
end

workspace.Part.Size = Vector3.new(8, 2, 4)
workspace.Part.Size = Vector3.new(4, 1, 2) * 2
workspace.Part.Size = workspace.Part.Size * 2
workspace.Part.Size = workspace.Part.Size + Vector3.new(0, 1, 0)

repeat
    wait(.5)
until workspace.Car.PrimaryPart

if workspace.Car.PrimaryPart then
    print("aaaaaaaaaaaa")
end

repeat
    workspace.Baseplate.Size = workspace.Baseplate.Size + Vector3.new(0,.5,0)
    wait(.5)
until   workspace.Baseplate.Size.Y == 30

while wait(1) do
    print("oooooooooooooooo")
end

if true then
    a = 1
   end
   print(a)
   --------
   local a
   if true then
    a = 1
   end
   print(a)
   -------
   local a
   if true then
    local a = 1
    print(a) -- 1 뜸
   end
   print(a) -- nil 뜸
   -------
   local a = 2
   if true then
    local a = 1
    print(a)
   end
   print(a)


for i = 1, 7 do
	print(i, "번째 반복입니다.")
end

for i = 0, 10, 1 do
	wait(0.1)
	print(i/10)
end


for i=1, 50 do
	local part = Instance.new("Part", workspace)
	part.Position = workspace.ColorPart.Position
	part.BrickColor = BrickColor.Random()
	part.Shape = Enum.PartType.Ball
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	wait()
end


local part = workspace.Part
part:Destroy()

local mass = part.Mass
print(mass)


wait(5)
script.Parent:Destroy()

for i=1, 50 do
	local part = game.ServerStorage.Part
	local clone = part:Clone()
	clone.Parent = workspace
	clone.BrickColor = BrickColor.Blue()
	wait()
end


local function ClonePart()
	local part = game.ServerStorage.Part
	local clone = part:Clone()
	clone.Parent = workspace
	clone.BrickColor = BrickColor.Blue()
	wait()
end

for i=1, 50 do
	ClonePart()
	wait()
end

local function ClonePart(part, location)
	local clone = part:Clone()
	clone.Parent = location
	wait()
	return clone
end

for i=1, 50 do
	local clone = ClonePart(game.ServerStorage.Part, workspace)
	clone.BrickColor = BrickColor.Random()
	wait()
end

local part = script.Parent

part.Touched:Wait()
part.BrickColor = BrickColor.Random()


local part = script.Parent

function ChangeColor()
	part.BrickColor = BrickColor.Random()
end

part.Touched:Connect(ChangeColor)


local part = workspace:FindFirstChild("touchedtest")
print(part)


--닿은 파트가 humanoid 인 경우에만 part 컬러 변경
local part = script.Parent

function ChangeColor(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid then
		part.BrickColor = BrickColor.Random()
	end
end

part.Touched:Connect(ChangeColor)


local part = workspace:FindFirstChild("touchTest")
local part2 = game.ServerStorage:FindFirstChildWhichIsA("BasePart")
print(part)
print(part2)


local b = 1
b += 1
print(b)


-- kill part 원리 
local part = script.Parent

local function kill(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.Health = 0
        -- 원래 체력에서 5씩 감소하는 데미지 파트
        -- humanoid.Health -= 5\
        -- 포쓰필드가 있을때는 데미지를 주지 않는 TakeDamage함수 (같은 기능)
        -- humanoid:TakeDamage(5)
	end
end

part.Touched:Connect(kill)


--함수를 바로 Connect 함수 안에 넣어서 실행하기
local part = script.Parent

part.Touched:Connect(function(hit)
		local humanoid = hit.Parent:FindFirstChild("Humanoid")
		if humanoid then
			part.BrickColor = BrickColor.Random()
		end
	end)


--함수를 바로 Connect 함수 안에 넣어서 실행하기
local part = script.Parent

--Enabled 함수를 넣어서 1초에 한번씩만 데미지를 주게 하기
local Enabled = true

part.Touched:Connect(function(hit)
		local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid and Enabled then
		Enabled = false
		humanoid.Health -= 5
		wait(1)
		Enabled = true
		end
	end)


workspace.Model:MoveTo(Vector3.new(104, 2.5, 69))


local car = game.ServerStorage.Model
local clone = car:Clone()
clone.Parent = workspace
clone:MoveTo(Vector3.new(104, 2.5, 69))


print(workspace["0319"])
workspace.testpart.BrickColor = BrickColor.Random()
workspace.testpart.Size = workspace.testpart.Size * 2

while wait(1) do
	print("aaaaaa")
end

model = workspace.testpart

model.BrickColor = BrickColor.Blue()
model.Transparency = 0.5

for i=10 , 0, -1 do
	wait(0.1)
	print(i)
end

for i =1 , 50 do
	Instance.new("Part", workspace)
	wait()
end


for i =1 , 50 do
	local part = Instance.new("Part", workspace)
	part.Position = workspace.testpart.Position
	part.BrickColor = BrickColor.Random()
	part.Shape = Enum.PartType.Balla
	wait()
end


wait(2)
script.Parent:Destroy()

for i = 1 , 50 do
	local part = game.ServerStorage.testpart
	local clone = part:Clone()
	clone.Parent = workspace
	clone.BrickColor = BrickColor.Black()
	wait()
end

function clonePart()
	local part = game.ServerStorage.testpart
	local clone = part:Clone()
	clone.Parent = workspace
end

for i =1 , 50 do
	clonePart()
	wait()
end

local function clonePart(part, location)
	local clone = part:Clone()
	clone.Parent = location
	return clone
end

for i =1 , 50 do
	local clone = clonePart(game.ServerStorage.testpart, workspace)
	clone.BrickColor = BrickColor.Random()
	wait()
end

local part = script.Parent

function changeColor()
	part.BrickColor = BrickColor.Random()
end

part.Touched:Connect(changeColor)

script.Parent.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid then
		script.Parent:Destroy()
	end
end)

local part = script.Parent
local hit = part.Touched:Wait()

local function copy(part, location)
	local clone = part:Clone()
	clone.Parent = location
	return clone
end

for i = 1, 50 do
	local clone = copy(hit, workspace)
	--clone.BrickColor = BrickColor.Random() --확인용 색 변화
	wait()
end

-- 닿으면 파트가 복사됨
script.Parent.Touched:Connect(function(plr)
	local humanoid = plr.Parent:FindFirstChild("Humanoid")
	if humanoid then
		local clone = script.Parent:Clone()
		clone.Parent = workspace
	end
end)



local part = script.Parent

function changeColor(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid then
		part.BrickColor = BrickColor.Random()
	end
end

local part = script.Parent

function player(hit)
	local humanoid = hit.parent:FindFirstChild("Head")
	if humanoid then
		humanoid:Destroy()
	end
end

part.Touched:Connect(player)
part.Touched:Connect(changeColor)


-- 킬파트
local part = script.Parent

function kill(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.Health = 0
	end
end

part.Touched:Connect(kill)


local part = script.Parent
local Enabled = true   --조건문을 통해 함수 연속 실행 방지

part.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid and Enabled then
		Enabled = false
		humanoid.Health -= 5
		wait(1)
		Enabled = true
	end
end)


workspace.x6m:MoveTo(Vector3.new(1,0.5,-12))

local car = game.ServerStorage.x6m
local clone = car:Clone()
clone.Parent = workspace
clone:MoveTo(Vector3.new(1, 0.5, -12))

-- 텔레포트 파트
local part = script.Parent

part.Touched:Connect(function(hit)
	hit.Parent:MoveTo(Vector3.new(5, 10, 5))
end)

--네임에 해당하는 캐릭터 강제 퇴장
game.Players.PlayerAdded:Connect(function(plr)
	if plr.Name == "Name" then
		plr.Kick()
	end
end)



game.Players.PlayerAdded:Connect(function(plr) --서버에 새 플레이어가 접속했을 때
	plr.CharacterAdded:Connect(function(chr) -- 플레이어의 캐릭터가 스폰되었을 때
	end)
end)

game.Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(chr)
		chr.ChildAdded(function(cd)
			if cd.ClassName == "Tool" then
				wait()
				cd:Destroy()
			end
		end)
	end)
end)

local localplayer = game.Players.LocalPlayer

game.Players.PlayerAdded:Connect(function(plr)
	
end)

local part = workspace.Baseplate
part.Touched:Connect(function(hit)
	local plr = game.Players:GetPlayerFromCharacter(hit.Parent)
end)

--5초동안 Baseplate 를 기다린다
local part = workspace:WaitForChild("Baseplate", 5)
part.BrickColor = BrickColor.new("Really red")


local part = workspace:WaitForChild("Part")
local surfaceGui = part:WaitForChild("SurfaceGui")
local TextLabel = surfaceGui:WaitForChild("TextLabel")

local player  = game.Players.LocalPlayer
local playerName = player.Name

TextLabel.Text = playerName.."님 하이!"


-- 스크립트 A
local binder = game.ServerStorage.binder
script.Parent.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid then
		binder:Fire(humanoid)
	end
end)

-- 스크립트 B
local binder = game.ServerStorage.binder
binder.Event:Connect(function(humanoid)
	humanoid.Health = 0
end)



-- remote Event

local contextActionSerice = game:GetService("ContextActionService")

function RPressed(actionName, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin then
		
	end
end

contextActionSerice:BindAction("RPress", RPressed, true, Enum.KeyCode.R)


game.Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(chr)
		
	end)
end)


-- remote event 활용
local contextActionService = game:GetService("ContextActionService")
local RemoteEvent = game.ReplicatedStorage:WaitForChild("ColorEvent")

function RPressed(actionName, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin then
		RemoteEvent:FireServer("R")
	end
end

function GPressed(actionName, inputState, inputObject)
	if inputState == Enum.UserInputState.Begin then
		RemoteEvent:FireServer("G")
	end
end

contextActionService:BindAction("RPress", RPressed, true, Enum.KeyCode.R)
contextActionService:BindAction("GPress", GPressed, true, Enum.KeyCode.G)

-- remoteEvent 받는 workspace script
local remoteEvent = game.ReplicatedStorage.ColorChange

remoteEvent.OnServerEvent:Connect(function(plr, Key)
	if Key == "R" then
		workspace.Part.BrickColor = BrickColor.Red()
	elseif Key  == "G" then
		workspace.Part.BrickColor = BrickColor.Gray()
	end
end)

--CFrame 은 회전도까지 반영한다
workspace.Part.Position = Vector3.new(0,0,0)
workspace.Part.CFrame = CFrame.new(0,0,0)

workspace.Part1.Position = workspace.Part2.Position
workspace.Part1.CFrame = workspace.Part2.CFrame

workspace.Model:MoveTo(workspace.Part1.Position)
workspace.Model:PivotTo(workspace.Part1.CFrame)


game.Players
game.Lighting

game:GetService("Players") -- 플레이어 서비스 
game:GetService("MarketplaceService") --수익 창출 관련 서비스
game:GetService("ContextActionService") -- 마우스 키보드 입력 서비스 
game:GetService("Debris") --게임에서 발생하는 파편 관련 제어


local debris = game:GetService("Debris") --게임에서 발생하는 파편 관련 제어
debris:AddItem(workspace.Part)


-- or 함수의 사용
local part = workspace:FindFirstChild("Part") or Instance.new("Part", workspace)
part.BrickColor = BrickColor.new("Really black")


local 변수 = 조건 and a or b
local masilgeo = nuna == 'cola' and nuna or na

if nuna == "cola" then
	masilgeo = nuna
else
	masilgeo = na
end

while true do
	wait(0.5)
	workspace.Part.BrickColor = BrickColor.Random()
	if workspace.Part.BrickColor == BrickColor.new("Really red") then
		break
	end
end

-- 텔레포트 파트, Enabled 변수로 1초에 1회만 동작
local part = script.Parent
local Enabled = true

part.Touched:Connect(function(hit)
	if hit.Parent:FindFirstChild("Humanoid") and Enabled == true then
		Enabled = false
		hit.Parent:PivotTo(hit.Parent:GetPivot() * CFrame.new(0,0,-40))
		wait(1)
		Enabled = true
	end
end)


workspace.Part.CFrame = CFrame.new(5,5,5) * CFrame.Angles(math.rad(30), 0, 0)
workspace.Part.CFrame = workspace.Part.CFrame * CFrame.Angles(math.rad(30), 0, 0)



print(math.random(1,5))

if math.random(1,5) == 1 then
	print("50% 의 확률")
end

--소수 표현
local n = math.random(10,20)/10

math.huge() --무한정 큰수
math.max() --큰수
math.min() --작은수
math.round() --반올림
math.ceil() --올림
math.floor() --내림



local array = {123, "string", true,
	workspace.Baseplate.BrickColor
}

array[2] = nil
print(#array) --배열의 갯수
table.insert(array, 2, 4355) -- 배열의 특정 위치에 값을 넣는다
table.insert(array, 5555) -- 배열의 끝에 값을 넣는다
table.remove(array, 2) -- 배열의 특정 위치의 값을 지운다


--배열 안에 배열
local array = {1234}
local array2 = {array}
print(array2[1][1]) --1234 출력


--배열 안에 함수
local array = {function()
	print("aaaaa")
end}
array[1]()  -- 배열 안에 들어있는 첫번째 함수 실행


--배열 안에 수를 랜덤하게
local array = {1234, "string", true}
print(array[math.random(1, #array)])


--배열 안에 수를 하나씩 꺼내기
local array = {1234, "string", true}
for i =1, #array do
	array[i]
end

-- 3개의 part 중 하나의 CanCollide 를 랜덤하게 Off
local model = script.Parent
local parts = {model.Part1, model.Part2, model.Part3}
parts[1].CanCollide = false
parts[2].CanCollide = false
parts[3].CanCollide = false
local num = math.random(1,3)
print(num)
parts[num].CanCollide = true

local model = script.Parent
local parts = model:GetChildren() -- 모델 안의 모든 것을 배열에 넣어줌
local parts = model:GetDescendants() -- 모델 안의 2중으로 넣어진 오브젝트까지 찾아서 배열에 넣어줌
local parts = game.Players:GetPlayers()

-- 배열 안에서 파트만 찾아서 캔 콜라이더를 꺼준다
for i=1, #parts do
	if parts[i]:IsA("BasePart") then
		parts[i].CanCollide = false
	end
end

-- parts[i] 가 아닌 ipairs 를 통해 v 로 간단하게 표현 (자주 쓴다)
for i, v in ipairs(parts) do
	if v:IsA("BasePart") then
		v.CanCollide = false
		v.BrickColor = BrickColor.Random()
	end
end


local players = game.Players

script.Parent.Touched:Connect(function(hit)
	local character = hit.Parent
	local plr = players:GetPlayerFromCharacter(character)
	if plr then
		for i, v in ipairs(players:GetPlayers())do
			if v.Character then
				local humanoid = v.Character:FindFirstChild("Humanoid")
				if humanoid then
					humanoid.Health = 0
				end
			end
		end
	end
end)



local dictionary = {
	aaa = "red",
	bb  = "blue",
	c = "green",
}

local array = {"red", "blue", "green"}


local mixed = {"red", "blue", "green",
	aaa = "red",
	bb = "blue",
	c = "green",
}

for i, v in pairs(mixed) do
	print(i, v)
end


local numValue = workspace.Num
numValue.Value = 19


-- NPC 의 Head 가 나를 계속 바라보게 만든다
local npcHead = workspace:WaitForChild("Head")
local MyHead = script.Parent:WaitForChild("Head")

while wait() do
	npcHead.CFrame = CFrame.lookAt(npcHead.Position, MyHead.Position)	
end


local RunService = game:GetService("RunService")

function update()
	
end

RunService.RenderStepped:Connect(update)


--  중급 복습

-- 쿨타임 주기

local Enabled = true
if humanoid and Enabled then
	Enabled = false
	humanoid.Health -= 5
	wait(1)
	Enabled = true
end

--로컬 플레이어 구하기
local localPlayer = game.Players.LocalPlayer

--접속한 플레이어
game.Players.PlayerAdded:Connect(function(plr)
	
end)

--버튼을 클릭한 플레이어
local part = workspace.Baseplate
part.ClickDetector.MouseClick:Connect(function(plr)
	
end)


--파트를 밟은 플레이어
--플레이어가 안밟으면 
local part = workspace.Baseplate
part.Touched:Connect(function(hit)
	local plr = game.Players:GetPlayerFromCharacter(hit.Parent)
end)

-- 모델의 앞에 part 를 하나 만들어 따라다니도록
local part = Instance.new("Part", workspace)
while wait() do
	part.CFrame = script.Parent:GetPivot() * CFrame.new(0,0,-10)
end


local Player = game.Players.LocalPlayer
local Char = Player.Character or player.CharacterAdded:Wait()
script.Parent:WaitForChild("TextLabel").Text = Char:WaitForChild("Humanoid").Health



while wait(0.1) do
	local HP = ((Char.Humanoid.Health / Char.Humanoid.MaxHealth))
	script.Parent.Size = UDim2.new(HP, 0,1,0)
	script.Parent.TextLabel.Text = math.floor(Char.Humanoid.Health).."/"..math.floor
end


-- 텔레포트 파트 복습
local part = script.Parent
part.Touched:Connect(function(hit)
	if hit.Parent:FindFirstChild("Humanoid") then
		hit.Parent:PivotTo(hit.Parent:GetPivot() * CFrame.new(0,0,20))
	end
end)


workspace.Part.CFrame = CFrame.new(workspace.Part.CFrame.Position) * CFrame.Angles(math.rad(30),0,0)

local n = math.random(1,5)

if n == 1 or n == 2 then
	print("40% 확률")
end


local array = {1234, "string", true}
print(array[1])

local array = {}
array[1] = 1234
array[2] = "String"
array[3] = true


local RunService = game:GetService("RunService")

function update()
	script.Parent.Rotation += 1
end

RunService.RenderStepped:Connect(update)


-- 흔들리지 않는 편안함
local part = Instance.new("Part", workspace)

local RunService = game:GetService("RunService")
RunService.RenderStepped:Connect(function(step)
	part.CFrame = script.Parent:GetPivot() * CFrame.new(0,0, -10)
end)


local RunService = game:GetService("RunService")

function update(step)
	script.Parent.Rotation += 60 * step
end

RunService.RenderStepped:Connect(update)

-- 로컬 스크립트로 worldspace 의 파트를 회전
local part = workspace:WaitForChild("Part")
local RunService = game:GetService("RunService")

function update(step)
	part.CFrame *= CFrame.Angles(0, math.rad(180) * step, 0)
end

RunService.RenderStepped:Connect(update)


local part = Instance.new("Part", workspace)

part.Anchored = true
part.CanCollide = false

local RunService = game:GetService("RunService")
RunService.RenderStepped:Connect(function(step)
	part.CFrame = CFrame.new((script.Parent:GetPivot() * CFrame.new(0,0, -10)).Position) * (part.CFrame * CFrame.Angles(0, math.rad(180) * step, 0)).Rotation 
end)


local part = script.Parent
local isTouched = false

local function fade()
	if not isTouched then
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
end

part.Touched:Connect(fade)


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
	
	player:SetAttribute("IsAlive", false)
	
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(character, player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)

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


local MAX_HEALTH = 100
local ENABLED_TRANSPARENCY = 0.4
local DISABLED_TRANSPARENCY = 0.9
local COOLDOWN = 5


local healthPickupFolder = workspace:WaitForChild("HealthPickups")
local healthPickups = healthPickupFolder:GetChildren()

local function onTouchHealthPickup(hit, v)
	if v:GetAttribute("Enabled") then
		local humanoid = hit.Parent:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			humanoid.Health = MAX_HEALTH
			v.Transparency = DISABLED_TRANSPARENCY
			v:SetAttribute("Enabled", false)
			task.wait(COOLDOWN)
			v.Transparency = ENABLED_TRANSPARENCY
			v:SetAttribute("Enabled", true)
		end 
	end
end

for i, v in ipairs(healthPickups) do
	v:SetAttribute("Enabled", true)
	v.Touched:Connect(function(hit)
		onTouchHealthPickup(hit, v)
	end)
end


-- 모듈 스크립트 기본
local KillPartHandler = {}

--kill 파트 기능을 켜고 끌 수 있게 변수를 추가했다
KillPartHandler.Enabled = true

function KillPartHandler.KillCharacterFromPart(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid and KillPartHandler.Enabled then
		humanoid.Health = 0
	end
end

return KillPartHandler


-- 모듈 스크립트를 불러서 쓰기
local KillPartHandler = require(workspace.KillPartHandler)

script.Parent.Touched:Connect(function(hit)
	KillPartHandler.KillCharacterFromPart(hit)
end)


local module = {}


local RunService = game:GetService("RunService")

RunService:IsStudio()
if RunService:IsServer() then
	--서버
else
	--클라이언트
end


return module


--magnitude 는 두 Vector3 사이의 절대값 거리를 구할 수 있다
local pos = workspace.red.Position - workspace.blue.Position

print(pos.Magnitude)

