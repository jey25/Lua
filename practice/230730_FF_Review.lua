
-- module script 기초

local module = {}

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

