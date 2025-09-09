local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local PetEvents = ReplicatedStorage:WaitForChild("PetEvents")
local ShowArrowEvent = PetEvents:WaitForChild("ShowArrow")

-- Arrow 템플릿
local arrowTemplate = ReplicatedStorage:WaitForChild("ArrowGui")

-- 상태 변수
local arrowGui
local targetPart
local hideDistance = 10

-- 퀘스트 시작 시
ShowArrowEvent.OnClientEvent:Connect(function(data)
	-- 이미 ArrowGui가 있으면 제거
	if arrowGui then
		arrowGui:Destroy()
	end

	-- 새로 복제
	arrowGui = arrowTemplate:Clone()
	arrowGui.Parent = player:WaitForChild("PlayerGui")
	arrowGui.Enabled = true

	-- 목표 파트 지정
	targetPart = data.Target
	hideDistance = data.HideDistance or 10
end)

-- 회전 및 거리 감지
RunService.RenderStepped:Connect(function()
	if arrowGui and arrowGui.Enabled and targetPart and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		local charPos = player.Character.HumanoidRootPart.Position
		local targetPos = targetPart.Position

		-- 거리 체크
		if (targetPos - charPos).Magnitude <= hideDistance then
			arrowGui:Destroy()
			arrowGui = nil
			targetPart = nil
			return
		end

		-- XZ 평면 방향 계산
		local dir = Vector3.new(targetPos.X - charPos.X, 0, targetPos.Z - charPos.Z).Unit
		local look = Vector3.new(player.Character.HumanoidRootPart.CFrame.LookVector.X, 0, player.Character.HumanoidRootPart.CFrame.LookVector.Z).Unit

		local angle = math.acos(math.clamp(look:Dot(dir), -1, 1))
		local cross = look:Cross(dir)
		if cross.Y < 0 then angle = -angle end

		-- 화살표 회전 반영
		local arrowImage = arrowGui:FindFirstChild("ArrowImage", true) -- 템플릿에서 화살표 ImageLabel 이름
		if arrowImage then
			arrowImage.Rotation = math.deg(angle)
		end
	end
end)
