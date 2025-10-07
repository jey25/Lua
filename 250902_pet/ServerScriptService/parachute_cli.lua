--!strict
-- Tool/GliderClient.client.lua
local tool = script.Parent
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local char: Model? = nil
local hbConn: RBXScriptConnection? = nil

-- 튜닝값
local DESCENT_SPEED = 5     -- 아래로 내려오는 속도
local FORWARD_SPEED = 16    -- 전진 속도

local function Equipped()
	char = tool.Parent
	local root = (char and char:FindFirstChild("HumanoidRootPart")) :: BasePart
	if not (char and root) then return end

	-- BodyVelocity 준비
	local force = root:FindFirstChild("ParachuteForce") :: BodyVelocity
	if not force then
		force = Instance.new("BodyVelocity")
		force.Name = "ParachuteForce"
		force.P = 10000
		force.MaxForce = Vector3.new(1e6, 1e6, 1e6)
		force.Parent = root
	end

	-- 매 프레임 전진/하강 속도 갱신
	if hbConn then hbConn:Disconnect() end
	hbConn = RunService.Heartbeat:Connect(function()
		if not char or not char.Parent then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum then return end

		local forward = hum.MoveDirection.Magnitude > 0 and hum.MoveDirection or root.CFrame.LookVector
		forward = Vector3.new(forward.X, 0, forward.Z)
		if forward.Magnitude > 0 then forward = forward.Unit end

		local horiz = forward * FORWARD_SPEED
		force.Velocity = Vector3.new(horiz.X, -DESCENT_SPEED, horiz.Z)
	end)
end

local function Unequipped()
	if hbConn then hbConn:Disconnect() hbConn = nil end
	local charNow = char
	if not charNow then return end
	local root = charNow:FindFirstChild("HumanoidRootPart")
	if root then
		local f = root:FindFirstChild("ParachuteForce")
		if f then f:Destroy() end
	end
end

tool.Equipped:Connect(Equipped)
tool.Unequipped:Connect(Unequipped)
