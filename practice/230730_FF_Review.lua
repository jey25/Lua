
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

