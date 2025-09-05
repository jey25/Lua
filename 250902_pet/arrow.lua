
-- arrow 생성 예시 코드

local arrow = require(game.ServerScriptService.arrow)


-- 첫 퀘스트 GUI 실행
local function FirstQuestGui(player)
	local FirstQuestTemplate = ReplicatedStorage:WaitForChild("FirstQuest")
	if not FirstQuestTemplate then return end

	local nextGui = FirstQuestTemplate:Clone()
	nextGui.Parent = player:WaitForChild("PlayerGui")

	task.delay(5, function()
		if nextGui then
			nextGui:Destroy()
			-- 화살표 안내
			local doctor = workspace.World.Building:FindFirstChild("Pet Hospital")
			if doctor and doctor:FindFirstChild("Doctor") then
				arrow.createArrowPath(player, doctor.Doctor)
			end
		end
	end)
end




-- arrow Module (ServerScriptService 하위)
-- arrow.createArrowPath() 를 통해 목표 지점까지 Part 로 Arrow 를 생성하고 플레이어 캐릭터가 목표에 도달 시 제거

local arrow = {}


function arrow.createArrowFolder()
	local arrowFolder = Instance.new("Folder")
	arrowFolder.Name = "ArrowPath"
	arrowFolder.Parent = workspace  -- workspace에 추가
	return arrowFolder
end


function arrow.createArrowPart(position, direction, arrowFolder)
	local arrow = Instance.new("Part")
	arrow.Size = Vector3.new(1, 1, 1) -- 화살표 크기
	arrow.Shape = Enum.PartType.Block
	arrow.Material = Enum.Material.Neon
	arrow.BrickColor = BrickColor.new("Bright yellow")
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CFrame = CFrame.new(position, position + direction) * CFrame.Angles(0, math.rad(90), 0)
	arrow.Parent = arrowFolder  -- 화살표를 폴더에 추가
	return arrow
end


function arrow.createArrowPath(player, targetModel)
	local character = player.Character or player.CharacterAdded:Wait()

	-- 모델에 PrimaryPart가 설정되어 있는지 확인하고, 없으면 설정
	if not targetModel.PrimaryPart then
		warn("Model does not have a PrimaryPart. Attempting to set it.")
		targetModel.PrimaryPart = targetModel:FindFirstChildWhichIsA("BasePart")  -- 모델의 첫 번째 BasePart를 PrimaryPart로 설정
		if not targetModel.PrimaryPart then
			warn("No BasePart found in model.")
			return
		end
	end

	-- 모델의 Pivot을 기준으로 위치를 계산
	local targetPosition = targetModel:GetPivot().Position

	-- 화살표를 담을 폴더 생성
	local arrowFolder = arrow.createArrowFolder()  -- 폴더 생성
	if not arrowFolder then
		warn("ArrowFolder was not created properly.")
		return
	end

	local stepSize = 10  -- 화살표 간격

	-- 경로 생성
	local function generatePath()
		if not character or not character.PrimaryPart then
			warn("Character or Character.PrimaryPart not found")
			return
		end

		local startPosition = character.PrimaryPart.Position
		local direction = (targetPosition - startPosition).Unit
		local distance = (startPosition - targetPosition).Magnitude

		for i = 0, distance, stepSize do
			local arrowPosition = startPosition + direction * i
			local arrow = arrow.createArrowPart(arrowPosition, direction, arrowFolder)  -- 화살표를 폴더에 추가

			-- 반짝임 효과
			task.spawn(function()
				while arrow and arrow.Parent do
					arrow.Transparency = 0.5
					wait(0.5)
					arrow.Transparency = 0
					wait(0.5)
				end
			end)
		end
	end

	generatePath()

	-- 목표 위치 도달 여부 확인
	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function()
		if not character or not character.PrimaryPart then
			connection:Disconnect()
			return
		end

		local currentDistance = (character.PrimaryPart.Position - targetPosition).Magnitude
		if currentDistance <= 5 then  -- 목표 도달
			for _, arrow in pairs(arrowFolder:GetChildren()) do
				if arrow and arrow.Parent then
					arrow:Destroy()
				end
			end
			connection:Disconnect()
			print("Player reached the target!")
		end
	end)
end


return arrow
