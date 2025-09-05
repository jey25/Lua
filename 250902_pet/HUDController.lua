-- StarterPlayer/StarterPlayerScripts/HUDController (LocalScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local LevelSync = ReplicatedStorage:WaitForChild("LevelSync")



-- 간단 HUD 생성(원하면 Studio에서 디자인해도 됨)
-- StarterPlayer/StarterPlayerScripts/HUDController (일부) 
-- 기존 createHUD() 교체용


local function createHUD()
	local screen = Instance.new("ScreenGui")
	screen.Name = "XP_HUD"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = player:WaitForChild("PlayerGui")

	-- [중앙 하단 도킹 컨테이너]
	local dock = Instance.new("Frame")
	dock.Name = "HUDDock"
	dock.BackgroundTransparency = 1
	dock.AnchorPoint = Vector2.new(0.5, 1)           -- 가운데/하단 기준점
	dock.Position = UDim2.new(0.5, 0, 1, -20)        -- 항상 화면 하단에서 20px 위
	dock.Size = UDim2.new(1, 0, 0, 40)               -- 높이만 고정, 가로는 화면 너비 따라감
	dock.Parent = screen

	-- 도킹 내부 가로 정렬
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 12)                   -- 요소 간 간격
	list.Parent = dock

	-- 좌측: Lv 라벨(카드 형태)
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.BackgroundTransparency = 0.2
	levelLabel.BackgroundColor3 = Color3.fromRGB(0,0,0)
	levelLabel.TextColor3 = Color3.fromRGB(255,255,255)
	levelLabel.TextScaled = true
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.Text = "Lv 1"
	levelLabel.Size = UDim2.fromOffset(120, 36)      -- 카드 크기 고정
	levelLabel.Parent = dock

	local levelCorner = Instance.new("UICorner")
	levelCorner.CornerRadius = UDim.new(0, 8)
	levelCorner.Parent = levelLabel

	-- 우측: EXP 게이지 바(반응형 폭)
	local barFrame = Instance.new("Frame")
	barFrame.Name = "ExpBar"
	barFrame.BackgroundColor3 = Color3.fromRGB(35,35,35)
	barFrame.BorderSizePixel = 0
	-- 화면 너비의 30%를 기본 폭으로, 최소/최대는 제약으로 제한
	barFrame.Size = UDim2.new(0.30, 0, 0, 24)
	barFrame.Parent = dock

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(260, 24)
	sizeConstraint.MaxSize = Vector2.new(520, 24)
	sizeConstraint.Parent = barFrame

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, 8)
	uiCorner.Parent = barFrame

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)                 -- 0%로 시작, Tween으로 채움
	fill.BackgroundColor3 = Color3.fromRGB(95, 155, 255)
	fill.BorderSizePixel = 0
	fill.Parent = barFrame

	local uiCornerFill = Instance.new("UICorner")
	uiCornerFill.CornerRadius = UDim.new(0, 8)
	uiCornerFill.Parent = fill

	local expText = Instance.new("TextLabel")
	expText.Name = "ExpText"
	expText.AnchorPoint = Vector2.new(0.5, 0.5)
	expText.Position = UDim2.new(0.5, 0, 0.5, 0)
	expText.Size = UDim2.new(1, -8, 1, 0)
	expText.BackgroundTransparency = 1
	expText.TextColor3 = Color3.fromRGB(255,255,255)
	expText.TextScaled = true
	expText.Font = Enum.Font.Gotham
	expText.Text = "0 / 100"
	expText.Parent = barFrame

	return screen
end


local ui = createHUD()
-- ✅ (정상) HUDDock → 그 밑에서 찾기

local dock = ui:WaitForChild("HUDDock") :: Frame
local levelLabel = dock:WaitForChild("LevelLabel") :: TextLabel
local bar = dock:WaitForChild("ExpBar") :: Frame
local fill = bar:WaitForChild("Fill") :: Frame
local expText = bar:WaitForChild("ExpText") :: TextLabel


-- 스무스 애니메이션
local TweenService = game:GetService("TweenService")

local function tweenFill(ratio: number)
	ratio = math.clamp(ratio, 0, 1)
	local goal = { Size = UDim2.new(ratio, 0, 1, 0) }
	TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end


-- 공통: 부드러운 외곽선
local function addStroke(gui: GuiObject, color: Color3, thickness: number, transparency: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = gui
	return s
end

-- 공통: 9-슬라이스 드롭섀도 (가벼운 그림자)
-- * 대체 가능한 일반 섀도 이미지 (Roblox 기본 스타일): 5028857479
local function addShadow(under: GuiObject, pad: number?)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 1, 0)
	holder.Position = UDim2.new(0, 0, 0, 0)
	holder.ZIndex = under.ZIndex - 1
	holder.Parent = under

	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = "rbxassetid://5028857479"
	img.ScaleType = Enum.ScaleType.Slice
	img.SliceCenter = Rect.new(24, 24, 276, 276)
	img.ImageTransparency = 0.35
	img.ImageColor3 = Color3.fromRGB(0, 0, 0)
	img.Size = UDim2.new(1, pad or 16, 1, pad or 16) -- 살짝 더 크게
	img.Position = UDim2.new(0.5, 0, 0.5, 0)
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Parent = holder

	return holder
end

-- 공통: 살짝 확대되는 펄스
local function pulse(gui: GuiObject, scaleUp: number, t: number)
	local sc = gui:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	sc.Parent = gui
	local tween1 = TweenService:Create(sc, TweenInfo.new(t/2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = scaleUp})
	local tween2 = TweenService:Create(sc, TweenInfo.new(t/2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 1})
	tween1:Play()
	tween1.Completed:Connect(function() tween2:Play() end)
end

-- === 🎨 팔레트 & HUD 스타일 적용 ===
-- 추천 팔레트: 다크 베이스 + 블루-시안 그라데이션
levelLabel.BackgroundTransparency = 0.1
levelLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

-- 레벨 라벨 스트로크 & 섀도
addStroke(levelLabel, Color3.fromRGB(255,255,255), 1.2, 0.7)
addShadow(levelLabel, 12)

-- 레벨 라벨 안쪽 아이콘 추가 (선택)
do
	local icon = Instance.new("ImageLabel")
	icon.Name = "LevelIcon"
	icon.BackgroundTransparency = 1
	icon.Image = "rbxassetid://3926305904" -- 시스템 아이콘 스프라이트
	icon.ImageRectOffset = Vector2.new(644, 204) -- ⭐ 모양 (필요 시 바꿔도 됨)
	icon.ImageRectSize = Vector2.new(36, 36)
	icon.Size = UDim2.fromOffset(20, 20)
	icon.Position = UDim2.new(0, 8, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Parent = levelLabel

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 32)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = levelLabel
end

-- EXP 바 카드 톤 업
bar.BackgroundTransparency = 0
bar.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
addStroke(bar, Color3.fromRGB(255,255,255), 1, 0.85)
addShadow(bar, 18)

-- 채움(필) 그라데이션 + 흐르는 하이라이트
fill.BackgroundColor3 = Color3.fromRGB(60, 135, 255)

-- 메인 그라데이션
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(60,135,255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70,205,255)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(60,135,255))
}
grad.Rotation = 0
grad.Parent = fill

-- 움직이는 광택(샤인) 레이어
local shine = Instance.new("Frame")
shine.Name = "Sheen"
shine.BackgroundTransparency = 1
shine.Size = UDim2.new(0.25, 0, 1.2, 0)
shine.Position = UDim2.new(-0.3, 0, -0.1, 0)
shine.Parent = fill
local shineGrad = Instance.new("UIGradient")
shineGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255,255,255)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,255,255)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255,255,255))
}
shineGrad.Transparency = NumberSequence.new{
	NumberSequenceKeypoint.new(0.0, 1.0),
	NumberSequenceKeypoint.new(0.5, 0.75),
	NumberSequenceKeypoint.new(1.0, 1.0)
}
shineGrad.Rotation = 20
shineGrad.Parent = shine

-- EXP 텍스트 가독성 업
expText.Font = Enum.Font.GothamMedium
expText.TextTransparency = 0
expText.TextStrokeTransparency = 0.4
expText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

-- === ⏱️ 애니메이션 업그레이드 ===
-- 1) 채움 비율 트윈 (원래 함수 확장)
local function tweenFillPretty(ratio: number)
	ratio = math.clamp(ratio, 0, 1)
	local goal = { Size = UDim2.new(ratio, 0, 1, 0) }
	-- 살짝 더 부드럽게
	local tw = TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), goal)
	tw:Play()
	-- 비율이 크게 오르면 펄스
	if ratio > 0.05 then
		pulse(bar, 1.03, 0.18)
	end
end

-- 2) 그라데이션 살짝 흐르게 (루프)
task.spawn(function()
	while fill.Parent do
		local t1 = TweenService:Create(grad, TweenInfo.new(2.4, Enum.EasingStyle.Linear), {Rotation = 10})
		local t2 = TweenService:Create(grad, TweenInfo.new(2.4, Enum.EasingStyle.Linear), {Rotation = 0})
		t1:Play(); t1.Completed:Wait(); t2:Play(); t2.Completed:Wait()
	end
end)

-- 3) 샤인 스윕 주기적으로
task.spawn(function()
	while shine.Parent do
		shine.Position = UDim2.new(-0.35, 0, -0.1, 0)
		local sw = TweenService:Create(shine, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Position = UDim2.new(1.1, 0, -0.1, 0)})
		sw:Play()
		sw.Completed:Wait()
		task.wait(1.4) -- 쿨타임
	end
end)

-- === 📈 XP 업데이트 & 레벨업 이펙트 ===
local function updateXP(curr: number, max: number, level: number, didLevelUp: boolean?)
	max = math.max(1, max)
	local ratio = curr / max

	-- 텍스트
	expText.Text = string.format("%d / %d  (%.0f%%)", curr, max, ratio * 100)
	levelLabel.Text = ("Lv %d"):format(level)

	-- 채우기
	tweenFillPretty(ratio)

	-- 레벨업 연출
	if didLevelUp then
		local ring = Instance.new("Frame")
		ring.BackgroundTransparency = 1
		ring.Size = UDim2.new(1, 12, 1, 12)
		ring.Position = UDim2.new(0.5, 0, 0.5, 0)
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.ZIndex = bar.ZIndex + 2
		ring.Parent = levelLabel

		local ringStroke = Instance.new("UIStroke")
		ringStroke.Color = Color3.fromRGB(255, 220, 120)
		ringStroke.Thickness = 2
		ringStroke.Transparency = 0.2
		ringStroke.Parent = ring

		pulse(levelLabel, 1.08, 0.35)
		task.delay(0.4, function() ring:Destroy() end)
	end
end

-- 사용 예시:
-- updateXP(currentExp, maxExp, level, didLevelUpBool)



-- HUD 반영
local curr = {Level = 1, Exp = 0, ExpToNext = 100}

local function refreshHUD()
	levelLabel.Text = ("Lv %d"):format(curr.Level)
	expText.Text = ("%d / %d"):format(curr.Exp, curr.ExpToNext)
	local ratio = (curr.ExpToNext > 0) and (curr.Exp / curr.ExpToNext) or 0
	tweenFill(ratio)
end

-- 서버 동기화 이벤트 수신
LevelSync.OnClientEvent:Connect(function(payload)
	if typeof(payload) == "table" then
		if payload.Level then curr.Level = payload.Level end
		if payload.Exp then curr.Exp = payload.Exp end
		if payload.ExpToNext then curr.ExpToNext = payload.ExpToNext end
		refreshHUD()
	end
end)

-- Attributes 변화를 직접 감지(선호 시)
local function hookAttributes()
	local function onChange(attr)
		if attr == "Level" then curr.Level = player:GetAttribute("Level") or curr.Level end
		if attr == "Exp" then curr.Exp = player:GetAttribute("Exp") or curr.Exp end
		if attr == "ExpToNext" then curr.ExpToNext = player:GetAttribute("ExpToNext") or curr.ExpToNext end
		refreshHUD()
	end
	player:GetAttributeChangedSignal("Level"):Connect(function() onChange("Level") end)
	player:GetAttributeChangedSignal("Exp"):Connect(function() onChange("Exp") end)
	player:GetAttributeChangedSignal("ExpToNext"):Connect(function() onChange("ExpToNext") end)
end

hookAttributes()
-- 첫 그리기(서버가 곧바로 LevelSync를 쏨)
refreshHUD()

