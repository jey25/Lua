-- StarterPlayerScripts/ClockGui.client.lua
--!strict
local Players          = game:GetService("Players")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")

local player = Players.LocalPlayer
local event  = ReplicatedStorage:WaitForChild("ClockUpdateEvent") :: RemoteEvent

-- GUI 생성 (기존과 동일, 간결화)
local gui = Instance.new("ScreenGui")
gui.Name = "ClockGui"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, 90)
frame.Position = UDim2.new(0.5, -110, 0, 20)
frame.BackgroundTransparency = 0.25
frame.BackgroundColor3 = Color3.fromRGB(15,15,30)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 15)
local list = Instance.new("UIListLayout", frame)
list.FillDirection = Enum.FillDirection.Vertical
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.VerticalAlignment = Enum.VerticalAlignment.Center
list.Padding = UDim.new(0, 6)

local clockLabel = Instance.new("TextLabel")
clockLabel.Size = UDim2.new(1, -20, 0, 45)
clockLabel.BackgroundTransparency = 1
clockLabel.TextColor3 = Color3.fromRGB(255,255,180)
clockLabel.Font = Enum.Font.GothamBlack
clockLabel.TextScaled = true
clockLabel.TextStrokeTransparency = 0.2
clockLabel.TextStrokeColor3 = Color3.fromRGB(255,215,0)
clockLabel.Parent = frame
local grad = Instance.new("UIGradient", clockLabel)
grad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255,200,0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255,255,180))
}
TweenService:Create(clockLabel, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, true),
	{TextStrokeTransparency = 0.4}):Play()

local dateLabel = Instance.new("TextLabel")
dateLabel.Size = UDim2.new(1, -20, 0, 25)
dateLabel.BackgroundTransparency = 1
dateLabel.TextColor3 = Color3.fromRGB(180,220,255)
dateLabel.Font = Enum.Font.FredokaOne
dateLabel.TextScaled = true
dateLabel.Parent = frame

local function render(clockTime: number, day: number)
	local h = math.floor(clockTime) % 24
	local m = math.floor((clockTime % 1) * 60)
	clockLabel.Text = string.format("%02d:%02d", h, m)
	dateLabel.Text  = "Day " .. tostring(day)
end

-- 서버 스냅샷 수신(1초 간격)
event.OnClientEvent:Connect(function(clockTime: number, day: number)
	render(clockTime, day)
end)

-- 첫 프레임 대비(서버가 아직 안쏘았을 때)
task.defer(function()
	local day = player:GetAttribute("GameDay")
	render(Lighting.ClockTime % 24, typeof(day)=="number" and day or 1)
end)
