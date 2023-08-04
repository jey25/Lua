
-- module script 기초

local module = {}

local runService = game:GetService("RunService")
if runService:IsServer() then
    
end

return module



local KillPartHandler = {}

KillPartHandler.Enabled = true

function KillPartHandler.KillCharacterFromPart(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid and KillPartHandler.Enabled then
		humanoid.Health = 0
	end
end
	
return KillPartHandler


local KillPartHandler = require(workspace.KillPartHandler)

script.Parent.Touched:Connect(function(hit)
	KillPartHandler.KillCharacterFromPart(hit)
end)


-- 모듈 스크립트는 서버, 클라이언트 각각 따로 돌아간다

local part = script.Parent

function ChangeColor(hit)
    local humanoid = hit.Parent:FindFirstChild("Humanoid")
    if humanoid then
        part.BrickColor = BrickColor.Random() 
    end
end

part.Touched:Connect(changeColor)

local hit = part.Touched:wait()
hit:Destroy()


local Enabled = true
part.Touched:Connect(function (hit)
    local humanoid = humanoid = hit.Parent:FindFirstChild("Humanoid")
    if humanoid and Enabled then
        Enabled = false
        humanoid.Health -= 5
        wait(1)
        Enabled = true
    end
end)

workspace.Model:MoveTo(Vector3.new(3,3,3))







