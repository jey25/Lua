
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


local part = script.Parent

part.Changed:Connect(function (property)
    if property then
    end
end)

game.Players.PlayerAdded:Connect(function (plr)
    plr.CharacterAdded:Connect(function (chr)
        chr.Humanoid        
    end)    
end)

-- RemoteEvent

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


-- 서버에서 보낸 신호 클라이언트에서 받기 
RemoteEvent.OnClientEvent:Connect(function(aaa)
		
end)

local RemoteEvent = game.ReplicatedStorage.ColorEvent

RemoteEvent.OnServerEvent:Connect(function(plr, key)
	if key == "R" then
		workspace.ColorPart.BrickColor = BrickColor.Red()
	elseif key == "G" then
		workspace.ColorPart.BrickColor = BrickColor.Green()
	end
end)


-- 서버에서 클라이언트로 신호 보내기
workspace.ColorPart.Touched:Connect(function(hit)
	local plr = game.Players:GetPlayerFromCharacter(hit.Parent)
	if plr then
		RemoteEvent:FireClient(plr, "aaa") --FireAllClient() 모든 클라이언트에 보내기
	end
end)






