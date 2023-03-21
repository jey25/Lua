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
	wait()
end

