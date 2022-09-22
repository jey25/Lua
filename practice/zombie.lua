--따라오고 공격하는 좀비 npc

local humanoid =  script.Parent:WaitForChild("Humanoid")
local rootpart = script.Parent:WaitForChild("HumanoidRootPart")

local npc = workspace:WaitForChild("Npc")

rootpart.Touched:Connect(function(hit)
	if hit.Size.Y > 2 and not hit:FindFirstChild("Humanoid") then
		humanoid.Jump = true
	end
end)

local runservice = game:GetService("RunService")
while runservice.Heartbeat:Wait() do
	local distance = 100
	local target
	for i, v in pairs(game.Players:GetPlayers())do
		if v.Character and v.Character:FindFirstChild("Humanoid") 
		and v.Character.Humanoid.Health > 0 
		and v.Character:FindFirstChild("HumanoidRootPart")then
			local d = (rootpart.Position - v.Character.HumanoidRootPart.Position).magnitude
			if distance > d then
				distance = d
				target = v.Character.HumanoidRootPart
			end
		end
	end
	for i, v in pairs(npc:GetChildren())do
		if v:FindFirstChild("zombie") == nil and v:FindFirstChild("Humanoid")
		and v.Humanoid.Health > 0 
		and v:FindFirstChild("HumanoidRootPart")then
			local d = (rootpart.Position - v.Character.HumanoidRootPart.Position).magnitude
			if distance > d then
				distance = d
				target = v.HumanoidRootPart
			end
		end
	end
	if target then
		humanoid:MoveTo(target.Position)
	end
end