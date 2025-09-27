-- StarterPlayerScripts/ClockGui.client.lua
--!strict
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")

local player = Players.LocalPlayer
local event  = ReplicatedStorage:WaitForChild("ClockUpdateEvent") :: RemoteEvent

-- ===== Tweakable (아이폰 14 Pro 기준) =====
local TOP_MARGIN_PX     = 10     -- 상단 여백(안전영역 아래에서 추가)
local BASE_SHORT_EDGE   = 1179   -- iPhone 14 Pro 세로모드의 짧은 변(기준 스케일)
local MIN_SCALE         = 0.82   -- 더 작은 기기에서 축소 한계
local MAX_SCALE         = 1.00   -- 너무 커지지 않게 상한
-- ========================================

-- 스케일 계산(짧은 변 기준으로 부드럽게 축소)
local function getUIScale(): number
	local cam = workspace.CurrentCamera
	local vp  = cam and cam.ViewportSize or Vector2.new(BASE_SHORT_EDGE, 2556)
	local short = math.min(vp.X, vp.Y)
	return math.clamp(short / BASE_SHORT_EDGE, MIN_SCALE, MAX_SCALE)
end

-- GUI 생성
local gui = Instance.new("ScreenGui")
gui.Name = "ClockGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true -- ← 최상단까지 붙이려면 true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")


-- 프레임(우측 상단 고정)
local frame = Instance.new("Frame")
frame.Name = "ClockContainer"
-- 1) 컨테이너 앵커/포지션: 우측→중앙
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Position    = UDim2.new(0.5, 0, 0, TOP_MARGIN_PX)
frame.BackgroundTransparency = 0.28
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
frame.BorderSizePixel = 0
frame.Parent = gui

-- 모서리 & 외곽선(소프트 느낌)
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Thickness = 1
stroke.Color = Color3.fromRGB(255, 255, 255)
stroke.Transparency = 0.85
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = frame

-- 내부 여백
local pad = Instance.new("UIPadding")
pad.PaddingTop    = UDim.new(0, 6)
pad.PaddingBottom = UDim.new(0, 6)
pad.PaddingLeft   = UDim.new(0, 10)
pad.PaddingRight  = UDim.new(0, 10)
pad.Parent = frame

-- 수직 정렬(우측 정렬)
local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Vertical
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.VerticalAlignment = Enum.VerticalAlignment.Top
list.Padding = UDim.new(0, 2)
list.Parent = frame

-- 시계 라벨(더 컴팩트, 우측 정렬)
local clockLabel = Instance.new("TextLabel")
clockLabel.Name = "ClockLabel"
clockLabel.BackgroundTransparency = 1
clockLabel.TextColor3 = Color3.fromRGB(255, 235, 165)
clockLabel.Font = Enum.Font.GothamSemibold
clockLabel.TextScaled = true
clockLabel.TextXAlignment = Enum.TextXAlignment.Center
clockLabel.TextStrokeTransparency = 0.6
clockLabel.TextStrokeColor3 = Color3.fromRGB(255, 215, 0)
clockLabel.Parent = frame

-- 은은한 그라데이션(너무 과하지 않게)
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 210, 80)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 245, 200))
}
grad.Rotation = 0
grad.Parent = clockLabel

-- 살짝 숨쉬는 애니메이션(강도 낮춤)
TweenService:Create(
	clockLabel,
	TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, true),
	{ TextStrokeTransparency = 0.75 }
):Play()

-- 날짜 라벨(톤다운)
local dateLabel = Instance.new("TextLabel")
dateLabel.Name = "DateLabel"
dateLabel.BackgroundTransparency = 1
dateLabel.TextColor3 = Color3.fromRGB(185, 215, 245)
dateLabel.Font = Enum.Font.GothamMedium
dateLabel.TextScaled = true
dateLabel.TextXAlignment = Enum.TextXAlignment.Center
dateLabel.Parent = frame

-- 렌더 함수
local function render(clockTime: number, day: number)
	local h = math.floor(clockTime) % 24
	local m = math.floor((clockTime % 1) * 60)
	local suffix = (h < 12) and "AM" or "PM"
	local h12 = ((h - 1) % 12) + 1
	clockLabel.Text = string.format("%02d:%02d %s", h12, m, suffix)
	dateLabel.Text  = "Day " .. tostring(day)
end

-- 레이아웃/스케일 적용
local function applyLayout()
	local s = getUIScale()

	-- 컨테이너 크기(가로는 고정폭, 세로는 자동)
	local width  = math.floor(168 * s)     -- 기존 220 → 168로 축소
	local timeH  = math.floor(30 * s)      -- 시계 라벨 높이
	local dateH  = math.floor(18 * s)      -- 날짜 라벨 높이

	-- (선택) 기본 "Label"이 순간 보이지 않게 비워두기
	if clockLabel.Text == "" or clockLabel.Text == nil then
		clockLabel.Text = ""
	end
	if dateLabel.Text == "" or dateLabel.Text == nil then
		dateLabel.Text = ""
	end

	clockLabel.Size = UDim2.new(0, width - 20, 0, timeH)
	dateLabel.Size  = UDim2.new(0, width - 20, 0, dateH)

	-- Frame은 내부 리스트 높이에 맞춰 계산(여백 + 패딩 포함)
	local totalH = pad.PaddingTop.Offset + timeH + list.Padding.Offset + dateH + pad.PaddingBottom.Offset
	frame.Size = UDim2.new(0, width, 0, totalH)

	-- ★ 중앙 상단 고정 (에러 원인이던 RIGHT_MARGIN_PX 사용 제거)
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position    = UDim2.new(0.5, 0, 0, TOP_MARGIN_PX)
end


-- 초기에 한 번 적용 + 화면 회전/리사이즈에도 반응
applyLayout()
task.defer(function()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyLayout)
	end
end)

-- 서버 스냅샷 수신(1초 간격 가정)
event.OnClientEvent:Connect(function(clockTime: number, day: number)
	render(clockTime, day)
end)

-- 첫 프레임 대비(서버가 아직 안쏘았을 때)
task.defer(function()
	local day = player:GetAttribute("GameDay")
	render(Lighting.ClockTime % 24, typeof(day)=="number" and day or 1)
end)
