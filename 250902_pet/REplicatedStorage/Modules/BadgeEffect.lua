--!strict
-- ReplicatedStorage/Module/BadgeEffect.lua
-- ClearModule 스타일 이펙트를 배지 전용으로 재사용 (텍스트만 변경)

local Players = game:GetService("Players")

local M = {}

local function getLocalPlayer(): Player?
	return Players.LocalPlayer
end

local function getAnchor(player: Player?): BasePart?
	player = player or getLocalPlayer()
	if not player then return nil end
	local char = player.Character or player.CharacterAdded:Wait()
	return (char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head"))) :: BasePart?
end

-- 사용법:
--   M.showBadgeEffect("Got the badge !!", 3)
--   M.showBadgeEffect(player, "Got the badge !!", 3) -- (호환) 첫 인자를 Player로 줄 수도 있음
function M.showBadgeEffect(a: any, b: any?, c: any?)
	local player: Player? = nil
	local text: string? = nil
	local duration: number? = nil

	if typeof(a) == "Instance" and a:IsA("Player") then
		player = a; text = (typeof(b)=="string" and b) or nil; duration = (typeof(c)=="number" and c) or nil
	else
		text = (typeof(a)=="string" and a) or nil; duration = (typeof(b)=="number" and b) or nil
	end

	text = text and #text > 0 and text or "Got the badge !!"
	duration = (typeof(duration)=="number" and duration or 3)
	local anchor = getAnchor(player)
	-- GUI
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BadgeEffectGui"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	(getLocalPlayer() :: Player):WaitForChild("PlayerGui") -- 보장
	screenGui.Parent = (getLocalPlayer() :: Player).PlayerGui

	local label = Instance.new("TextLabel")
	label.Parent = screenGui
	label.Text = text
	label.Size = UDim2.new(0, 200, 0, 50)
	label.Position = UDim2.new(0.5, -100, 0.5, -25)
	label.TextSize = 160
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 255, 0)
	label.TextStrokeColor3 = Color3.fromRGB(255, 0, 0)
	label.TextStrokeTransparency = 0.2

	-- 파티클/사운드용 파트 (클라에서 Workspace에 넣으면 로컬 전용)
	if anchor then
		local part = Instance.new("Part")
		part.Size = Vector3.new(7, 7, 1)
		part.Transparency = 1
		part.CanCollide = false
		part.Anchored = true
		part.Position = anchor.Position + Vector3.new(0, 5, -3)
		part.Parent = workspace

		local pe = Instance.new("ParticleEmitter")
		pe.Parent = part
		pe.Texture = "rbxassetid://13879884748"
		pe.Lifetime = NumberRange.new(1, 2)
		pe.Size = NumberSequence.new{
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 3)
		}
		pe.Speed = NumberRange.new(5, 15)
		pe.Rotation = NumberRange.new(0, 360)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Acceleration = Vector3.new(0, 5, 0)
		pe:Emit(100)

		local sound = Instance.new("Sound")
		sound.Parent = part
		sound.SoundId = "rbxassetid://3120909354"
		sound.Volume = 1.5
		sound.PlaybackSpeed = 1
		sound:Play()

		task.delay(duration, function()
			if screenGui then screenGui:Destroy() end
			if part then part:Destroy() end
		end)
	else
		-- 앵커를 못 찾았을 때도 GUI는 일정 시간 후 정리
		task.delay(duration, function()
			if screenGui then screenGui:Destroy() end
		end)
	end
end

-- (호환) 예전 ClearModule 스타일로도 호출 가능
function M.showClearEffect(player: Player)
	return M.showBadgeEffect(player, "Got the badge !!", 3)
end

return M

