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


