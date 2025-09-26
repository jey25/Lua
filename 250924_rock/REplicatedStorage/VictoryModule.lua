-- ReplicatedStorage/Modules/VictoryFX.lua
--!strict
local TweenService = game:GetService("TweenService")
local Debris       = game:GetService("Debris")
local Players      = game:GetService("Players")

local module = {}

-- 파티클 텍스처만 사용 (사운드 없음)
local CONFETTI_TEX = "rbxassetid://13879884748"

local function playTextGui(pgui: PlayerGui, text: string)
	local gui = Instance.new("ScreenGui")
	gui.Name = "VictoryFXGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 3000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = pgui

	local box = Instance.new("Frame")
	box.Name = "Box"
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0.10, 0)
	box.Size = UDim2.fromOffset(480, 96)
	box.BackgroundTransparency = 1
	box.Parent = gui

	local sc = Instance.new("UIScale")
	sc.Scale = 0.2
	sc.Parent = box

	-- pop-in → 유지 → 페이드아웃
	TweenService:Create(sc, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.0}):Play()
	task.delay(1.2, function()
		local tweenOut1 = TweenService:Create(box,   TweenInfo.new(0.25), {BackgroundTransparency = 1})
		local tweenOut2 = TweenService:Create(label, TweenInfo.new(0.25), {TextTransparency = 1, TextStrokeTransparency = 1})
		tweenOut1:Play(); tweenOut2:Play()
	end)

	Debris:AddItem(gui, 1.6)
end

local function playParticles(hrp: BasePart)
	-- 클라 로컬 전용 이펙트 (Workspace에 남는 Part 생성하지 않음)
	local att = Instance.new("Attachment")
	att.Name = "VictoryFX_Att"
	att.Parent = hrp

	local p = Instance.new("ParticleEmitter")
	p.Name = "Confetti"
	p.Parent = att
	p.Texture = CONFETTI_TEX
	p.Lifetime = NumberRange.new(1.0, 1.8)
	p.Speed    = NumberRange.new(6, 14)
	p.Rate     = 0
	p.Rotation   = NumberRange.new(0, 360)
	p.RotSpeed   = NumberRange.new(-120, 120)
	p.SpreadAngle= Vector2.new(180, 180)
	p.Acceleration = Vector3.new(0, 10, 0)
	p.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0.00, 1.0),
		NumberSequenceKeypoint.new(1.00, 0.7),
	}
	p.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0.00, 0.05),
		NumberSequenceKeypoint.new(1.00, 1.00),
	}

	p:Emit(120)
	Debris:AddItem(att, 2.2)
end

function module.play(localPlayer: Player, text: string?)
	local char = localPlayer.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (hrp and localPlayer.PlayerGui) then return end

	playTextGui(localPlayer.PlayerGui, text or "VICTORY!")
	playParticles(hrp)
end

return module
