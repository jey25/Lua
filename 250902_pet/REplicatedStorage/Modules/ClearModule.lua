local module = {}

function module.showClearEffect(player)
	-- GUI 생성
	local screenGui = Instance.new("ScreenGui")
	screenGui.Parent = player.PlayerGui

	-- Clear 텍스트 설정
	local clearLabel = Instance.new("TextLabel")
	clearLabel.Parent = screenGui
	clearLabel.Text = "Clear !!"
	clearLabel.Size = UDim2.new(0, 200, 0, 50)
	clearLabel.Position = UDim2.new(0.5, -100, 0.5, -25)
	clearLabel.TextSize = 160
	clearLabel.BackgroundTransparency = 1
	clearLabel.Font = Enum.Font.FredokaOne
	clearLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
	clearLabel.TextStrokeColor3 = Color3.fromRGB(255, 0, 0)
	clearLabel.TextStrokeTransparency = 0.2

	-- 🟢 카메라 앞에 Part 생성 (파티클 & 사운드 용)
	local char = player.Character
	if not char then return end

	local rootPart = char:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local part = Instance.new("Part")
	part.Size = Vector3.new(7, 7, 1)  -- 크기 조절 가능
	part.Transparency = 1  -- 보이지 않도록 설정
	part.CanCollide = false
	part.Anchored = true
	part.Parent = game.Workspace

	-- 플레이어 앞에 배치
	part.Position = rootPart.Position + Vector3.new(0, 5, -3)

	-- 🔥 파티클 이펙트 추가
	local particleEmitter = Instance.new("ParticleEmitter")
	particleEmitter.Parent = part
	particleEmitter.Texture = "rbxassetid://13879884748" -- 파티클 텍스처
	particleEmitter.Lifetime = NumberRange.new(1, 2)  -- 입자 생명 주기 증가
	particleEmitter.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 1),  -- 초기 크기 1
		NumberSequenceKeypoint.new(1, 3)   -- 점점 커져서 3까지 증가
	}
	particleEmitter.Speed = NumberRange.new(5, 15)  -- 속도 증가 (더 빠르게 확산)
	particleEmitter.Rotation = NumberRange.new(0, 360)
	particleEmitter.SpreadAngle = Vector2.new(180, 180)  -- 모든 방향으로 퍼짐
	particleEmitter.Acceleration = Vector3.new(0, 5, 0)  -- 위로 상승하는 효과 추가

	-- ✅ 즉시 많은 파티클 방출
	particleEmitter:Emit(100)

	-- 🔊 효과음 추가
	local sound = Instance.new("Sound")
	sound.Parent = part
	sound.SoundId = "rbxassetid://3120909354" -- 원하는 효과음 ID 입력
	sound.Volume = 1.5
	sound.PlaybackSpeed = 1
	sound:Play()

	-- 3초 후 삭제
	task.wait(3)
	clearLabel:Destroy()
	screenGui:Destroy()
	part:Destroy()
end

return module
