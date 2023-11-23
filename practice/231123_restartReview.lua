
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