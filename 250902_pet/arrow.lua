local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local PetEvents = ReplicatedStorage:WaitForChild("PetEvents")
local ShowArrowEvent = PetEvents:WaitForChild("ShowArrow")

-- Arrow 3D BillboardGui 템플릿
local arrowBillboard = ReplicatedStorage:WaitForChild("ArrowBillboard") -- BillboardGui 안에 ImageLabel or MeshPart

local arrowGui
local targetPart
local hideDistance = 10

ShowArrowEvent.OnClientEvent:Connect(function(data)
	local char = player.Character or player.CharacterAdded:Wait()
	local head = char:WaitForChild("Head")

	-- 기존 것 제거
	if arrowGui then
		arrowGui:Destroy()
	end

	-- BillboardGui 복제해서 플레이어 머리 위에 붙임
	arrowGui = arrowBillboard:Clone()
	arrowGui.Parent = head
	arrowGui.Enabled = true
	arrowGui.Size = UDim2.new(0, 100, 0, 100)  -- 100x100 픽셀

	-- 머리 위쪽 중앙으로 오프셋
	arrowGui.StudsOffset = Vector3.new(0, 4, 0) -- y 값만 조정해서 위로 띄움
	arrowGui.AlwaysOnTop = true -- 다른 오브젝트 뒤에 가리지 않도록
	
	local arrowImage = arrowGui:FindFirstChild("ImageLabel", true)
	if arrowImage then
		arrowImage.AnchorPoint = Vector2.new(0.5, 0.5) -- 중앙 기준
		arrowImage.Size = UDim2.new(1, 0, 1, 0)        -- 부모 BillboardGui 전체 사용
		arrowImage.Position = UDim2.new(0.5, 0, 0.5, 0)
	end



	targetPart = data.Target
	hideDistance = data.HideDistance or 10
end)

RunService.RenderStepped:Connect(function()
	if arrowGui and targetPart and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		local head = player.Character:FindFirstChild("Head")
		local charPos = head.Position
		local targetPos = targetPart.Position

		-- 거리 체크: 가까우면 제거
		if (targetPos - charPos).Magnitude <= hideDistance then
			arrowGui:Destroy()
			arrowGui = nil
			targetPart = nil
			return
		end

		-- 머리 위치 기준 NPC 방향 계산 (XZ 평면)
		local direction = (targetPos - charPos)
		local angle = math.deg(math.atan2(direction.Z, direction.X)) - 90

		-- BillboardGui 내부 ImageLabel 회전
		local arrowImage = arrowGui:FindFirstChild("ArrowImage", true)
		if arrowImage then
			arrowImage.Rotation = angle
		end
	end
end)
