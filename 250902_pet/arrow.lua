--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")

local player            = Players.LocalPlayer
local PetEvents         = ReplicatedStorage:WaitForChild("PetEvents")
local ShowArrowEvent    = PetEvents:WaitForChild("ShowArrow") -- data = {Target?:BasePart, TargetPath?:string, HideDistance?:number}

-- ReplicatedStorage.Arrow3D (Model or MeshPart)
local ArrowTemplate     = ReplicatedStorage:WaitForChild("Arrow3D")

-- 메쉬 기본 앞방향 보정: +Z가 앞이면 CFrame.new(); +Y가 앞이면 아래 줄로 바꾸세요.
-- local ORIENT_OFFSET  = CFrame.Angles(-math.pi/2, 0, 0)
local ORIENT_OFFSET     = CFrame.new()

local FOLLOW_OFFSET     = Vector3.new(0, 4, 0) -- 머리 위 높이
local arrowObj : Instance? = nil               -- Model 또는 BasePart
local targetPart : BasePart? = nil
local targetPath : string? = nil
local hideDistance = 10

local stepName = "Arrow3DFollow_" .. player.UserId
local relookupCooldown = 0.0

local function unbind()
	pcall(function() RunService:UnbindFromRenderStep(stepName) end)
end

local function destroyArrow()
	unbind()
	if arrowObj then arrowObj:Destroy() end
	arrowObj, targetPart, targetPath = nil, nil, nil
end

local function setPivot(cf: CFrame)
	if not arrowObj then return end
	if arrowObj:IsA("Model") then
		(arrowObj :: Model):PivotTo(cf)
	else
		(arrowObj :: BasePart).CFrame = cf
	end
end

-- "World/A/B/C" 경로로 Instance 찾기
local function findByPath(path: string?): Instance?
	if not path or path == "" then return nil end
	local node: Instance = workspace
	for seg in string.gmatch(path, "[^/]+") do
		local c = node:FindFirstChild(seg)
		if not c then return nil end
		node = c
	end
	return node
end

-- 받은 data로 타겟 해석/복구
local function resolveTarget(data: any)
	local t = data.Target
	if typeof(t) == "Instance" and t:IsA("BasePart") and t:IsDescendantOf(workspace) then
		targetPart = t
	else
		targetPart = nil
	end
	targetPath = data.TargetPath
	hideDistance = data.HideDistance or 10
end

-- 표시용: 모든 파트 고정/충돌 끔
local function setupArrowParts(root: Instance)
	local function setup(p: BasePart)
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = false
		p.Massless = true
	end
	if root:IsA("Model") then
		if not root.PrimaryPart then
			local first = root:FindFirstChildWhichIsA("BasePart", true)
			if first then root.PrimaryPart = first end
		end
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") then setup(d) end
		end
	else
		setup(root :: BasePart)
	end
end

-- 헬퍼: Instance(Model/Part)에서 쓸만한 BasePart 하나 뽑기
local function bestTargetPart(obj: Instance): BasePart?
	if obj:IsA("BasePart") then
		return obj
	end
	if obj:IsA("Model") then
		local m = obj :: Model
		local pp = m.PrimaryPart
		if pp then return pp end

		local hrp = m:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then return hrp :: BasePart end

		local head = m:FindFirstChild("Head")
		if head and head:IsA("BasePart") then return head :: BasePart end

		local any = m:FindFirstChildWhichIsA("BasePart", true)
		if any and any:IsA("BasePart") then return any :: BasePart end
	end
	return nil
end


ShowArrowEvent.OnClientEvent:Connect(function(data)
	local char = player.Character or player.CharacterAdded:Wait()
	local head = char:WaitForChild("Head") :: BasePart

	destroyArrow()

	local cloned = ArrowTemplate:Clone()
	setupArrowParts(cloned)
	cloned.Parent = workspace
	arrowObj = cloned

	resolveTarget(data)

	-- 즉시 한 번 머리 위에 올려놓기
	setPivot(head.CFrame + FOLLOW_OFFSET)

	-- 프레임 업데이트 시작
	RunService:BindToRenderStep(stepName, Enum.RenderPriority.Camera.Value + 1, function(dt)
		-- 캐릭터/머리 유효성
		local c = player.Character
		if not c then destroyArrow(); return end
		local h = c:FindFirstChild("Head") :: BasePart?
		if not h or not arrowObj then destroyArrow(); return end

		-- 머리 위 위치(항상 고정)
		local basePos = h.Position + FOLLOW_OFFSET

		-- 타겟 인스턴스가 없다면 주기적으로 경로로 재탐색(Streaming 대응)
		-- 타겟 인스턴스가 없다면 주기적으로 경로로 재탐색
		if (not targetPart or not targetPart:IsDescendantOf(workspace)) and targetPath and relookupCooldown <= 0 then
			local maybe = findByPath(targetPath)
			if maybe then
				targetPart = bestTargetPart(maybe)
			end
			relookupCooldown = 0.25
		else
			relookupCooldown = math.max(0, relookupCooldown - dt)
		end


		-- 가까우면 제거
		if targetPart and (targetPart.Position - basePos).Magnitude <= hideDistance then
			destroyArrow(); return
		end

		-- 타겟 향해 회전 (타겟이 아직 없으면 이전 회전 유지)
		local aimPos = targetPart and Vector3.new(targetPart.Position.X, basePos.Y, targetPart.Position.Z) or (basePos + Vector3.zAxis)
		local cf = CFrame.lookAt(basePos, aimPos, Vector3.yAxis) * ORIENT_OFFSET

		-- 즉시 적용(먼저 정확히 따라다니게) → 필요 시 Lerp로 바꾸세요.
		setPivot(cf)
	end)
end)
