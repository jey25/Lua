-- StarterPlayer/StarterPlayerScripts/HUDController (LocalScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local LevelSync: RemoteEvent? = ReplicatedStorage:FindFirstChild("LevelSync")
local remoteFolder: Folder? = ReplicatedStorage:FindFirstChild("RemoteEvents")
local AffectionSync: RemoteEvent? = remoteFolder and remoteFolder:FindFirstChild("PetAffectionSync")

local Icons = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Icons")
local HeartTpl = Icons:WaitForChild("HeartIcon") :: ImageLabel
local StarTpl = Icons:WaitForChild("StarIcon") :: ImageLabel
local CoinTpl = Icons:WaitForChild("CoinIcon") :: ImageLabel
-- ===== AffBar 외곽선 깜빡임 (Suck Icon on 동안) =====
local ZeroEventHUD = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("PetAffectionZero")


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
	-- 교체
	dock.AnchorPoint = Vector2.new(0, 1)
	dock.Position    = UDim2.new(0, 8, 1, -12)          -- 좌하단 + 여백
	
	dock.Size = UDim2.new(1, 0, 0, 40)
	dock.Parent = screen

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 12)
	list.Parent = dock
	
	-- ▼ 코인 라벨 (Level 왼쪽)
	
	local coinLabel = Instance.new("TextLabel")
	coinLabel.Name = "CoinLabel"
	coinLabel.BackgroundTransparency = 0.1
	coinLabel.BackgroundColor3 = Color3.fromRGB(10,10,14)
	coinLabel.TextColor3 = Color3.fromRGB(255, 255, 180)
	coinLabel.TextScaled = true
	coinLabel.Font = Enum.Font.GothamBold
	coinLabel.Text = "0"
	coinLabel.Size = UDim2.fromOffset(90, 36)
	coinLabel.LayoutOrder = 0
	coinLabel.Parent = dock
	coinLabel.TextXAlignment = Enum.TextXAlignment.Right
	coinLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	coinLabel.Position = UDim2.new(0.52, 0, 0.5, 0) -- 0.5 → 0.52로 조정
	local coinCorner = Instance.new("UICorner"); coinCorner.CornerRadius = UDim.new(0,8); coinCorner.Parent = coinLabel

	
	-- 아이콘(템플릿 복제)
	local coinClone = CoinTpl:Clone() :: ImageLabel
	coinClone.Name = "CoinIcon"
	coinClone.BackgroundTransparency = 1
	coinClone.Size = UDim2.fromOffset(30, 30)
	coinClone.AnchorPoint = Vector2.new(0, 0.5)
	coinClone.Position = UDim2.new(0, 10, 0.5, 0)  -- 왼쪽으로 밀착, 세로 중앙
	coinClone.ZIndex = 3
	coinClone.Parent = coinLabel


	-- 좌측: Lv 카드
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.BackgroundTransparency = 0.1
	levelLabel.BackgroundColor3 = Color3.fromRGB(10,10,14)
	levelLabel.TextColor3 = Color3.fromRGB(255,255,255)
	levelLabel.TextScaled = true
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.Text = "Lv 1"
	levelLabel.Size = UDim2.fromOffset(140, 36)
	levelLabel.LayoutOrder = 1
	levelLabel.Parent = dock
	levelLabel.TextXAlignment = Enum.TextXAlignment.Right
	levelLabel.ClipsDescendants = true
	local levelCorner = Instance.new("UICorner"); levelCorner.CornerRadius = UDim.new(0,8); levelCorner.Parent = levelLabel
	

	-- 아이콘(템플릿 복제)
	local starClone = StarTpl:Clone() :: ImageLabel
	starClone.Name = "LevelIcon"
	starClone.BackgroundTransparency = 1
	starClone.Size = UDim2.fromOffset(30, 30)
	starClone.AnchorPoint = Vector2.new(0, 0.5)
	starClone.Position = UDim2.new(0, 10, 0.5, 0)  -- 왼쪽으로 밀착, 세로 중앙
	starClone.ZIndex = 3
	starClone.Parent = levelLabel
	

	-- 가운데: EXP 바
	local barFrame = Instance.new("Frame")
	barFrame.Name = "ExpBar"
	barFrame.BackgroundColor3 = Color3.fromRGB(18,18,24)
	barFrame.BorderSizePixel = 0
	barFrame.Size = UDim2.new(0.30, 0, 0, 24)
	barFrame.LayoutOrder = 2
	barFrame.ClipsDescendants = true  -- 배경만 클리핑
	barFrame.Parent = dock
	local sizeConstraint = Instance.new("UISizeConstraint"); sizeConstraint.MinSize = Vector2.new(260, 24); sizeConstraint.MaxSize = Vector2.new(520, 24); sizeConstraint.Parent = barFrame
	local uiCorner = Instance.new("UICorner"); uiCorner.CornerRadius = UDim.new(0,8); uiCorner.Parent = barFrame

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(60,135,255)
	fill.BorderSizePixel = 0
	fill.ZIndex = 0
	fill.Parent = barFrame
	local uiCornerFill = Instance.new("UICorner"); uiCornerFill.CornerRadius = UDim.new(0,8); uiCornerFill.Parent = fill

	local expText = Instance.new("TextLabel")
	expText.Name = "ExpText"
	expText.BackgroundTransparency = 1
	expText.AnchorPoint = Vector2.new(0.5,0.5)
	expText.Position = UDim2.new(0.5, 0, 0.5, 0)
	expText.Size = UDim2.new(1, -10, 1, -6) -- 위/아래 여유
	expText.TextColor3 = Color3.fromRGB(255,255,255)
	expText.TextScaled = true
	expText.Font = Enum.Font.GothamMedium
	expText.Text = "0 / 100"
	expText.ZIndex = 2
	expText.Parent = barFrame
	local expTS = Instance.new("UITextSizeConstraint"); expTS.MinTextSize = 12; expTS.MaxTextSize = 18; expTS.Parent = expText

	-- ▼ 우측: 애정도 바 (AffBar)
	local affFrame = Instance.new("Frame")
	affFrame.Name = "AffBar"
	affFrame.BackgroundColor3 = Color3.fromRGB(18,18,24)
	affFrame.BorderSizePixel = 0
	affFrame.Size = UDim2.new(0.22, 0, 0, 24)
	affFrame.LayoutOrder = 3
	affFrame.ClipsDescendants = true         -- 모서리 밖 삐짐 방지
	affFrame.Parent = dock
	local affCorner = Instance.new("UICorner"); affCorner.CornerRadius = UDim.new(0, 8); affCorner.Parent = affFrame
	
	-- ☆ 텍스트/필 전용 컨테이너 (패딩은 여기에만)
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.fromScale(1, 1)
	inner.ZIndex = 1
	inner.Parent = affFrame

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 34)        -- 하트만큼 왼쪽 공간 확보
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = inner

	-- 채움(Fill) — inner 안에 두면 텍스트와 겹쳐도 패딩으로 공간 분리
	local affFill = Instance.new("Frame")
	affFill.Name = "Fill"
	affFill.Size = UDim2.new(0, 0, 1, 0)
	affFill.BackgroundColor3 = Color3.fromRGB(255,110,160)
	affFill.BorderSizePixel = 0
	affFill.ZIndex = 0
	affFill.Parent = inner
	local affFillCorner = Instance.new("UICorner"); affFillCorner.CornerRadius = UDim.new(0,8); affFillCorner.Parent = affFill

	-- 텍스트(가운데 정렬)
	local affText = Instance.new("TextLabel")
	affText.Name = "AffText"
	affText.BackgroundTransparency = 1
	affText.AnchorPoint = Vector2.new(0.5,0.5)
	affText.Position = UDim2.new(0.5, 0, 0.5, 0)
	affText.Size = UDim2.new(1, 0, 1, -6)   -- 위/아래 3px 여유
	affText.TextColor3 = Color3.fromRGB(255,255,255)
	affText.TextScaled = true
	affText.Font = Enum.Font.GothamMedium
	affText.Text = "0 / 10"
	affText.TextXAlignment = Enum.TextXAlignment.Center  -- ★ 중앙
	affText.ZIndex = 2
	affText.Parent = inner
	local affTS = Instance.new("UITextSizeConstraint"); affTS.MinTextSize = 12; affTS.MaxTextSize = 18; affTS.Parent = affText

	-- 하트 아이콘(패딩 영향 X → AffBar의 직속 자식)
	
	local heart = Instance.new("ImageLabel")
	local heartClone = HeartTpl:Clone()
	heartClone.Name = "HeartIcon"
	heartClone.BackgroundTransparency = 1
	heartClone.Size = UDim2.fromOffset(26, 26)
	heartClone.Position = UDim2.new(0, 10, 0.5, 0)
	heartClone.AnchorPoint = Vector2.new(0,0.5)
	heartClone.ZIndex = 3
	heartClone.Parent = affFrame  

	return screen
end


local ui = createHUD()

local dock       = ui:WaitForChild("HUDDock") :: Frame
local coinLabel  = dock:WaitForChild("CoinLabel") :: TextLabel  -- ★ 추가
local levelLabel = dock:WaitForChild("LevelLabel") :: TextLabel
local bar        = dock:WaitForChild("ExpBar") :: Frame
local fill       = bar:WaitForChild("Fill") :: Frame
local expText    = bar:WaitForChild("ExpText") :: TextLabel
-- ... (AffBar 참조는 기존 그대로)


-- ▼ 추가: 애정도 참조
local affBar  = dock:WaitForChild("AffBar") :: Frame
local inner   = affBar:WaitForChild("Inner") :: Frame
local affFill = inner:WaitForChild("Fill") :: Frame
local affText = inner:WaitForChild("AffText") :: TextLabel


-- 스무스 애니메이션
local TweenService = game:GetService("TweenService")


local function tweenFill(ratio: number)
	ratio = math.clamp(ratio, 0, 1)
	TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(ratio, 0, 1, 0) }):Play()
end

-- ▼ 애정도 전용
local function tweenAff(ratio: number)
	ratio = math.clamp(ratio, 0, 1)
	TweenService:Create(affFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(ratio, 0, 1, 0) }):Play()
end


-- 코인 표시
local function setCoins(n:number?)
	coinLabel.Text = ("%d"):format(tonumber(n) or 0)
end

-- Remotes/CoinUpdate 수신 → HUD에만 반영
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
	local coinUpdate = remotes:WaitForChild("CoinUpdate")
	coinUpdate.OnClientEvent:Connect(function(newAmount)
		setCoins(newAmount)
	end)
end)



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


-- EXP 텍스트 가독성 업
expText.Font = Enum.Font.GothamMedium
expText.TextTransparency = 0
expText.TextStrokeTransparency = 0.4
expText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

-- EXP 텍스트
expText.Size = UDim2.new(1, -10, 1, -6)   -- 위·아래 3px 여유
local expSizeCon = Instance.new("UITextSizeConstraint")
expSizeCon.MinTextSize = 12
expSizeCon.MaxTextSize = 18               -- 너무 커져서 잘리는 것 방지
expSizeCon.Parent = expText

-- === 🎨 팔레트 & HUD 스타일 적용 ===
-- 추천 팔레트: 다크 베이스 + 블루-시안 그라데이션
levelLabel.BackgroundTransparency = 0.1
levelLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

-- EXP 바 카드 톤 업
bar.BackgroundTransparency = 0
bar.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
bar.ClipsDescendants = true  


-- 레벨 라벨 스트로크 & 섀도
addStroke(levelLabel, Color3.fromRGB(255,255,255), 1.2, 0.7)
addShadow(levelLabel, 12)

addStroke(bar, Color3.fromRGB(255,255,255), 1, 0.85)
addShadow(bar, 12)

addStroke(affBar,Color3.fromRGB(255,255,255), 1, 0.85)
addShadow(affBar, 12)

addStroke(coinLabel, Color3.fromRGB(255,255,255), 1.0, 0.8)
addShadow(coinLabel, 12)

-- 채움(필) 그라데이션 + 흐르는 하이라이트
fill.BackgroundColor3 = Color3.fromRGB(60, 135, 255)

-- affBar의 기존 UIStroke를 재사용(없으면 만들기)
local affStroke = affBar:FindFirstChildOfClass("UIStroke") :: UIStroke
if not affStroke then
	affStroke = addStroke(affBar, Color3.fromRGB(255,255,255), 1, 0.85)
end


-- 원래 값(효과 종료 시 복구용)
local AFF_STROKE_BASE_T     = affStroke.Transparency
local AFF_STROKE_BASE_COLOR = affStroke.Color
local AFF_STROKE_BASE_W     = affStroke.Thickness

-- 깜빡임 파라미터
local BLINK_MIN_T = 0.15              -- 밝을 때(진한) 투명도
local BLINK_MAX_T = 0.85              -- 어두울 때(옅은) 투명도
local BLINK_TIME  = 0.55              -- 단일 페이드 시간(초)     -- 한 번의 페이드 시간(초)
-- 색/두께(밝을 때/어두울 때)
local COLOR_RED   = Color3.fromRGB(255, 70, 70)
local COLOR_WHITE = Color3.fromRGB(255, 255, 255)
local THICK_HI    = math.max(2.5, AFF_STROKE_BASE_W + 1.5) -- 밝을 때 더 굵게
local THICK_LO    = math.max(1, AFF_STROKE_BASE_W)         -- 어두울 때 기본 굵기

local affBlinkToken = 0

local function startAffStrokeBlink()
	affBlinkToken += 1
	local my = affBlinkToken
	local s = affStroke
	s.Enabled = true

	task.spawn(function()
		while s.Parent and affBlinkToken == my do
			-- Phase A: 밝게(두껍게, 빨간색)
			local t1 = TweenService:Create(
				s,
				TweenInfo.new(BLINK_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ Transparency = BLINK_MIN_T, Thickness = THICK_HI, Color = COLOR_RED }
			)
			t1:Play(); t1.Completed:Wait()
			if affBlinkToken ~= my or not s.Parent then break end

			-- Phase B: 어둡게(얇게, 흰색)
			local t2 = TweenService:Create(
				s,
				TweenInfo.new(BLINK_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{ Transparency = BLINK_MAX_T, Thickness = THICK_LO, Color = COLOR_WHITE }
			)
			t2:Play(); t2.Completed:Wait()
		end
	end)
end

local function stopAffStrokeBlink()
	affBlinkToken += 1
	-- 원래 상태로 복귀
	affStroke.Transparency = AFF_STROKE_BASE_T
	affStroke.Color        = AFF_STROKE_BASE_COLOR
	affStroke.Thickness    = AFF_STROKE_BASE_W
end

-- 서버 신호: Suck Icon on/off → 깜빡임 on/off
ZeroEventHUD.OnClientEvent:Connect(function(payload)
	local show = payload and payload.show
	if show then
		startAffStrokeBlink()
	else
		stopAffStrokeBlink()
	end
end)

-- 🔒 견고함 보강: 애정도 1+ → 0으로 떨어졌을 때, 서버 이벤트를 못 받아도
-- 클라가 스스로 30초 카운트 후 깜빡임을 시작한다.
local function armLocalZeroHoldTimer()
	-- 새로운 타이머만 유효하게(기존 깜빡임을 끊지 않음)
	local armToken = tick()
	task.spawn(function()
		local zeroH = player:GetAttribute("PetAffectionZeroHoldSec") or 10
		local last0 = player:GetAttribute("PetAffectionMinReachedUnix") or 0
		if last0 <= 0 then return end

		-- 서버가 os.time()으로 기록한 타임스탬프 기준
		local dueIn = math.max(0, (last0 + zeroH) - os.time())
		task.wait(dueIn)

		-- 여전히 0이면 시작(서버 이벤트와 동시 도착해도 토큰 비교로 중복 루프 방지)
		if (player:GetAttribute("PetAffection") or 0) == 0 then
			startAffStrokeBlink()
		end
	end)
end



-- 메인 그라데이션
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255,110,160)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,160,200)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255,110,160))
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

fill.ZIndex = 0
expText.ZIndex = 2
shine.ZIndex = 1                    -- ★ 추가 (샤인은 중간)


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



-- ───── 이벤트 핸들러들 ─────
local curr = {Level = 1, Exp = 0, ExpToNext = 100}
local aff  = {value = 0, max = 10}

local function refreshHUD()
	levelLabel.Text = ("Lv %d"):format(curr.Level)
	expText.Text = ("%d / %d"):format(curr.Exp, curr.ExpToNext)
	local ratio = (curr.ExpToNext > 0) and (curr.Exp / curr.ExpToNext) or 0
	tweenFill(ratio)
end

local function refreshAff()
	affText.Text = ("%d / %d"):format(aff.value, aff.max)
	local r = (aff.max > 0) and (aff.value / aff.max) or 0
	tweenAff(r)
end

local function onLevelSync(payload)
	if typeof(payload) ~= "table" then return end
	if payload.Level then curr.Level = payload.Level end
	if payload.Exp then curr.Exp = payload.Exp end
	if payload.ExpToNext then curr.ExpToNext = payload.ExpToNext end
	refreshHUD()
end

local function onAffectionSync(payload)
	if typeof(payload) ~= "table" then return end
	if payload.Affection ~= nil then aff.value = tonumber(payload.Affection) or aff.value end
	if payload.Max       ~= nil then aff.max   = tonumber(payload.Max)       or aff.max   end
	refreshAff()
	if aff.value > 0 then
		stopAffStrokeBlink()
	end
end


-- ───── 원격 이벤트 "늦게" 연결 (UI를 막지 않음) ─────
task.spawn(function()
	-- LevelSync 확보 & 연결
	LevelSync = LevelSync or ReplicatedStorage:WaitForChild("LevelSync", 10)
	if LevelSync then
		LevelSync.OnClientEvent:Connect(onLevelSync)
	else
		warn("[HUD] LevelSync not found (10s timeout)")
	end
end)


task.spawn(function()
	-- RemoteEvents / PetAffectionSync 확보 & 연결
	remoteFolder = remoteFolder or ReplicatedStorage:WaitForChild("RemoteEvents", 10)
	if remoteFolder then
		AffectionSync = AffectionSync or remoteFolder:WaitForChild("PetAffectionSync", 10)
		if AffectionSync then
			AffectionSync.OnClientEvent:Connect(onAffectionSync)
		else
			warn("[HUD] PetAffectionSync not found (10s timeout)")
		end
	else
		warn("[HUD] RemoteEvents folder not found (10s timeout)")
	end
end)


-- ===== Affection attribute hooks (deduped) =====
-- 전제: refreshAff(), armLocalZeroHoldTimer(), stopAffStrokeBlink() 이미 정의됨

local function handleAffectionChanged()
	-- PetAffection 변경 시: 값 반영 + UI 갱신 + 깜빡임 on/off 판단
	local v = player:GetAttribute("PetAffection")
	if typeof(v) == "number" then
		aff.value = v
		refreshAff()
		if v == 0 then
			-- 0이면 로컬 타이머로 30초 경과 후 깜빡임을 암(서버 신호 유실 대비)
			armLocalZeroHoldTimer()
		else
			-- 0을 벗어나면 즉시 깜빡임 해제
			stopAffStrokeBlink()
		end
	end
end

local function handleAffectionMaxChanged()
	-- 최대치 변경 시: 값 반영 + UI 갱신
	local m = player:GetAttribute("PetAffectionMax")
	if typeof(m) == "number" then
		aff.max = m
		refreshAff()
		-- (선택) 최대치 변경 시 0인 상태라면 다시 타이머 암
		if (player:GetAttribute("PetAffection") or 0) == 0 then
			armLocalZeroHoldTimer()
		end
	end
end

local function handleMinReachedUnixChanged()
	-- 서버가 0 도달 시각을 갱신했을 때: 여전히 0이면 로컬 타이머 암
	if (player:GetAttribute("PetAffection") or 0) == 0 then
		armLocalZeroHoldTimer()
	end
end

-- 연결(각 속성당 1개씩만)
player:GetAttributeChangedSignal("PetAffection"):Connect(handleAffectionChanged)
player:GetAttributeChangedSignal("PetAffectionMax"):Connect(handleAffectionMaxChanged)
player:GetAttributeChangedSignal("PetAffectionMinReachedUnix"):Connect(handleMinReachedUnixChanged)

-- 초기 1회 반영(접속 직후 상태 동기화)
handleAffectionMaxChanged()
handleAffectionChanged()
handleMinReachedUnixChanged()



-- 접속 직후 상태가 0이면(= 이미 0 유지 중) 즉시/잔여 대기 후 시작
task.defer(function()
	if (player:GetAttribute("PetAffection") or 0) == 0 then
		armLocalZeroHoldTimer()
	end
end)



-- 첫 그리기
refreshHUD()
refreshAff()



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

