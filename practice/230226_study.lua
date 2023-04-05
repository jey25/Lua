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

local part = script.Parent


--닿은 파트가 humanoid 인 경우에만 part 컬러 변경
function ChangeColor(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid then
		part.BrickColor = BrickColor.Random()
	end
end

part.Touched:Connect(ChangeColor)



local part = workspace:FindFirstChild("touchedtest", true)
local pare2 = game.ServerStorage:FindFirstChildWhichIsA("BasePart")
print(part)


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
lcoal part = workspace:WaitForChild("Baseplate", 5)
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

-- 텔레포트 파트
local part = script.Parent
part.Touched:Connect(function (hit)
	if hit.Parent:FindFirstChild("Humanoid") then
		hit.Parent:PivotTo(hit.Parent:GetPivot() * CFrame.new(0,0,20))
	end
end)





