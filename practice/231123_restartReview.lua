
script.Parent.Transparency = 0
script.Parent.Name = "창문"
script.Parent.Anchored = true
script.Parent.Material = Enum.Material.Brick

for i=1, 50 do
    local part = game.ServerStorage.test01
    local clone = part:Clone()
    clone.Parent = workspace
    wait()	
    end

    
local function ClonePart(part, location)
    local clone = part:Clone()
    clone.Parent = location
    end

for i=1, 50 do
    ClonePart(game.ServerStorage.test01, workspace)
    wait()
end

-- true 를 넣어서 이중삼중 폴더 밑에 있는 개체까지 찾게 한다
local part = workspace:FindFirstChild("Part", true)



local part = script.Parent
local function kill(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid then
		--humanoid.Health = 0   --kill part
		humanoid.Health -= 5     --damage Part
	end	
end

part.Touched:Connect(kill)


-- 이벤트 쿨타임
local part = script.Parent
local Enabled = true

part.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid and Enabled then
		Enabled = false
		--humanoid.Health = 0   --kill part
		humanoid.Health -= 5     --damage Part
		wait(1)
		Enabled = true
	end
end)