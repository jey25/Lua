-- ServerScriptService 등에 넣어주세요
local wangFolder = workspace:WaitForChild("world")
	:WaitForChild("dogItems")
	:WaitForChild("wang")

-- PrimaryPart 지정 함수
local function assignPrimaryPart(model)
	if model:IsA("Model") and not model.PrimaryPart then
		local part = model:FindFirstChild("HumanoidRootPart")
			or model:FindFirstChild("Torso")
			or model:FindFirstChildWhichIsA("BasePart")

		if part then
			model.PrimaryPart = part
			print("PrimaryPart 지정 완료:", model.Name, "→", part.Name)
		else
			warn("PrimaryPart를 지정할 수 없음 (BasePart 없음):", model.Name)
		end
	end
end

-- 기존 모델 처리
for _, model in ipairs(wangFolder:GetChildren()) do
	assignPrimaryPart(model)
end

-- 새 모델 추가 시 처리
wangFolder.ChildAdded:Connect(function(child)
	assignPrimaryPart(child)
end)

