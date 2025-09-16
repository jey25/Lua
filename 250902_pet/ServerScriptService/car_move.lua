local TweenService = game:GetService("TweenService")

-- 자동차 설정 목록
local carSettings = {
	{
		modelName = "Schoolbus",
		spawnPosition = Vector3.new(-1038, 261.896, 465),
		endPosition = Vector3.new(291, 261.896, 465),
		moveTime = 7,
		waitTime = 4,
	},
	{
		modelName = "Schoolbus1",
		spawnPosition = Vector3.new(-949.5, 261.896, 1021),
		endPosition = Vector3.new(291, 261.896, 1021),
		moveTime = 20,
		waitTime = 2,
	},
	{
		modelName = "meshCar",
		spawnPosition = Vector3.new(-853.882, 265.014, 775.82),
		endPosition = Vector3.new(293.118, 265.014, 775.82),
		moveTime = 10,
		waitTime = 3,
	},
}

-- 모델 전체를 이동시키는 함수
local function tweenModel(model, startPos, endPos, duration)
	local offset = endPos - startPos
	local steps = 60 * duration -- 60 FPS 기준
	local stepSize = offset / steps

	for i = 1, steps do
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CFrame = part.CFrame + stepSize
			end
		end
		task.wait(1/60)
	end
end

-- 각 자동차에 대해 반복 동작 처리
for _, settings in ipairs(carSettings) do
	task.spawn(function()
		while true do
			local carModel = game.ServerStorage:FindFirstChild(settings.modelName)
			if not carModel then
				warn("모델을 찾을 수 없습니다: " .. settings.modelName)
				return
			end

			local car = carModel:Clone()
			car.Parent = workspace


			local rotation = CFrame.Angles(0, math.rad(-90), 0)
			local rotatedCFrame = CFrame.new(settings.spawnPosition) * rotation
			car:PivotTo(rotatedCFrame)


			-- 서서히 이동
			tweenModel(car, settings.spawnPosition, settings.endPosition, settings.moveTime)

			-- 대기 후 제거
			wait(settings.waitTime)
			car:Destroy()
		end
	end)
end

