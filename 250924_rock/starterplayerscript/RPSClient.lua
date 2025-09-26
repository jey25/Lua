--!strict
-- StarterPlayerScripts/RPSClient.client.lua
-- 구성: 서비스/상수 -> 유틸(SFX/GUI) -> 대기문구 폴백 -> 보드/카운트다운/결과 -> 이벤트

-- ===== Services / Constants =====
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local VictoryFX = require(RS:WaitForChild("VictoryFX"))
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local CAS = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local myUserId = player.UserId
local oppUserId: number? = nil

local didShowStartOnce = false

-- Hands 상태 모듈(안전 로드)
local HandsState
do
	local ok, mod = pcall(function() return require(RS:WaitForChild("HandsClientState")) end)
	HandsState = ok and mod or { Get = function(_: number) return nil end }
end

-- Workspace.TwoSeat 폴더 이름 (좌석 감지용)
local TWO_SEAT_FOLDER_NAME = "TwoSeat"

-- ===== Remotes =====
local uiEvent     = RS:WaitForChild("TwoSeatUI") :: RemoteEvent
local startEvent  = RS:WaitForChild("TwoSeatStart") :: RemoteEvent
local roundStart  = RS:WaitForChild("RPS_RoundStart") :: RemoteEvent
local chooseEv    = RS:WaitForChild("RPS_Choose") :: RemoteEvent
local resultEv    = RS:WaitForChild("RPS_Result") :: RemoteEvent
local reqCancel   = RS:WaitForChild("RPS_RequestCancel") :: RemoteEvent
local cancelledEv = RS:WaitForChild("RPS_Cancelled") :: RemoteEvent

-- ===== SFX =====
local SFXF = RS:WaitForChild("SFX")
local SFX: {[string]: Sound} = {}
local function ensureSFX()
	local spec = {
		Countdown = {"Countdown","countdown"},
		Choice    = {"Choice","choice"},
		Result    = {"Result","result"},
		Start     = {"Start","start"},
		Spring    = {"Spring","spring"},
	}
	for key, names in pairs(spec) do
		if not SFX[key] or not SFX[key].Parent then
			local found: Sound? = nil
			for _, n in ipairs(names) do
				local c = SFXF:FindFirstChild(n)
				if c and c:IsA("Sound") then found = c break end
			end
			if not found then
				found = Instance.new("Sound")
				found.Name = "Fallback_"..key
				found.SoundId = ""
			end
			local s = found:Clone()
			s.Name = "RPS_"..key
			if key == "Spring" then s.Looped = true end
			s.Parent = SoundService
			SFX[key] = s
		end
	end
end
ensureSFX()
if not SFX.Spring.IsPlaying then SFX.Spring:Play() end




-- ===== UI Helpers =====
local function ensureLayer(name: string): ScreenGui
	local g = playerGui:FindFirstChild(name) :: ScreenGui?
	if not g then
		g = Instance.new("ScreenGui")
		g.Name = name
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = true
		g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		-- 결과 팝업이 가려지지 않도록 기본 DisplayOrder 조금 올림
		if name == "RPS_Pop" then g.DisplayOrder = 1001 end
		g.Parent = playerGui
	end
	return g
end

local function stylizeRichLabel(lbl: TextLabel)
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextStrokeTransparency = 0.1
	lbl.TextStrokeColor3 = Color3.fromRGB(35, 25, 0)
	if not lbl:FindFirstChild("GoldGradient") then
		local grad = Instance.new("UIGradient")
		grad.Name = "GoldGradient"
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 245, 200)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 215, 90)),
			ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 245, 200)),
		})
		grad.Parent = lbl
	end
	if not lbl:FindFirstChildOfClass("UIScale") then
		local sc = Instance.new("UIScale")
		sc.Scale = 1
		sc.Parent = lbl
		lbl.ZIndex += 1
	end
end

local function pulseLabel(lbl: TextLabel)
	local sc = lbl:FindFirstChildOfClass("UIScale")
	if not sc then return end
	local t1 = TweenService:Create(sc, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1.10})
	local t2 = TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),  {Scale = 1.00})
	t1:Play(); t1.Completed:Once(function() t2:Play() end)
end

local function shimmerText(lbl: TextLabel)
	local fr = Instance.new("Frame")
	fr.Name = "TextShimmer"
	fr.BackgroundColor3 = Color3.new(1,1,1)
	fr.BackgroundTransparency = 0
	fr.Size = UDim2.fromScale(1.2, 1.2)
	fr.Position = UDim2.fromScale(-0.1, -0.1)
	fr.ZIndex = lbl.ZIndex + 2
	fr.Parent = lbl
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   1),
		NumberSequenceKeypoint.new(0.45,1),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(0.55,1),
		NumberSequenceKeypoint.new(1,   1),
	})
	g.Rotation = 20
	g.Offset = Vector2.new(-1,0)
	g.Parent = fr
	local tw = TweenService:Create(g, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Offset = Vector2.new(1,0)})
	tw:Play()
	tw.Completed:Once(function() fr:Destroy() end)
end

local function ensureBigLabel(layerName: string): TextLabel
	local root = ensureLayer(layerName)
	local lbl = root:FindFirstChild("CenterText") :: TextLabel?
	if not lbl then
		lbl = Instance.new("TextLabel")
		lbl.Name = "CenterText"
		lbl.AnchorPoint = Vector2.new(0.5, 0.5)
		lbl.Position = UDim2.fromScale(0.5, 0.45)
		lbl.Size = UDim2.fromScale(0.6, 0.25)
		lbl.BackgroundTransparency = 1
		lbl.TextScaled = true
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextColor3 = Color3.fromRGB(255, 255, 0)
		lbl.TextStrokeColor3 = Color3.fromRGB(255, 0, 0)
		lbl.TextStrokeTransparency = 0.2
		
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.new(0,0,0)
		stroke.Parent = lbl
		lbl.Parent = root
		stylizeRichLabel(lbl)

	end
	return lbl
end

local function ensureBigTextGui(pGui: PlayerGui): TextLabel
	local root = pGui:FindFirstChild("StartFlashGui") :: ScreenGui?
	if not root then
		root = Instance.new("ScreenGui")
		root.Name = "StartFlashGui"
		root.ResetOnSpawn = false
		root.IgnoreGuiInset = true
		root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		root.Parent = pGui
	end
	local lbl = root:FindFirstChild("FlashText") :: TextLabel?
	if not lbl then
		lbl = Instance.new("TextLabel")
		lbl.Name = "FlashText"
		lbl.AnchorPoint = Vector2.new(0.5, 0.5)
		lbl.Position = UDim2.fromScale(0.5, 0.5)
		lbl.Size = UDim2.fromScale(0.8, 0.2)
		lbl.BackgroundTransparency = 1
		lbl.TextScaled = true
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextColor3 = Color3.fromRGB(255, 255, 0)
		lbl.TextStrokeColor3 = Color3.fromRGB(255, 0, 0)
		lbl.TextStrokeTransparency = 0.2
		lbl.Text = "Game Start!"
		lbl.ZIndex = 1000
		
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.new(0,0,0)
		stroke.Transparency = 0
		stroke.Parent = lbl
		lbl.Parent = root
		stylizeRichLabel(lbl)
	end
	return lbl
end

local function flashStartText(pGui: PlayerGui, text: string?): number
	local lbl = ensureBigTextGui(pGui)
	if text then lbl.Text = text end
	lbl.TextTransparency = 1
	for _, v in ipairs(lbl:GetChildren()) do
		if v:IsA("UIStroke") then v.Transparency = 1 end
	end
	lbl.Visible = true
	local tIn = TweenService:Create(lbl, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {TextTransparency = 0})
	tIn:Play()
	local strokeObj: UIStroke? = lbl:FindFirstChildOfClass("UIStroke")
	if strokeObj then
		TweenService:Create(strokeObj, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Transparency = 0}):Play()
	end

	task.wait(0.2)
	local tOut = TweenService:Create(lbl, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {TextTransparency = 1})
	tOut:Play()
	if strokeObj then
		TweenService:Create(strokeObj, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Transparency = 1}):Play()
	end
	tOut.Completed:Wait()
	lbl.Visible = false
	return 0.2 + 0.35
end

-- ===== Waiting GUI (최상단 + 폴백) =====
local function ensureWaitingGui(): (ScreenGui, TextLabel)
	local existing = playerGui:FindFirstChild("TwoSeatWaitingGui") :: ScreenGui?
	if existing then
		return existing, (existing:FindFirstChild("Text") :: TextLabel)
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "TwoSeatWaitingGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 999

	local lbl = Instance.new("TextLabel")
	lbl.Name = "Text"
	lbl.AnchorPoint = Vector2.new(0.5, 0.5)
	lbl.Position = UDim2.fromScale(0.5, 0.85)
	lbl.Size = UDim2.fromOffset(600, 60)
	lbl.Text = "Waiting for players…"
	lbl.TextScaled = true
	lbl.BackgroundTransparency = 0.3
	lbl.BackgroundColor3 = Color3.new(0, 0, 0)
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.BorderSizePixel = 0
	lbl.ZIndex = 999
	lbl.Visible = false
	lbl.Parent = gui

	gui.Parent = playerGui
	return gui, lbl
end

local _, waitingLabel = ensureWaitingGui()
local function showWaiting() waitingLabel.Visible = true end
local function hideWaiting() waitingLabel.Visible = false end

-- ===== TwoSeat 좌석 폴백 감지 =====
local twoSeatFolder = workspace:FindFirstChild(TWO_SEAT_FOLDER_NAME)
local twoSeatSet: {[BasePart]: boolean} = {}

local function rebuildTwoSeatSet()
	table.clear(twoSeatSet)
	local root = twoSeatFolder
	if not root then return end
	for _, ch in ipairs(root:GetDescendants()) do
		if ch:IsA("Seat") or ch:IsA("VehicleSeat") then
			twoSeatSet[ch] = true
		end
	end
end
rebuildTwoSeatSet()
if twoSeatFolder then
	twoSeatFolder.DescendantAdded:Connect(function(obj)
		if obj:IsA("Seat") or obj:IsA("VehicleSeat") then twoSeatSet[obj] = true end
	end)
	twoSeatFolder.DescendantRemoving:Connect(function(obj)
		if twoSeatSet[obj] then twoSeatSet[obj] = nil end
	end)
end

local function seatBelongsToTwoSeat(seatPart: BasePart?): boolean
	if not seatPart then return false end
	if twoSeatSet[seatPart] then return true end
	local a = seatPart
	for _ = 1, 6 do
		if not a.Parent then break end
		a = a.Parent
		if a == twoSeatFolder then return true end
	end
	return false
end

local inMatch = false
local function hookHumanoidForWaiting(hum: Humanoid)
	hum.Seated:Connect(function(active: boolean, seatPart: BasePart?)
		if inMatch then return end
		if active and seatBelongsToTwoSeat(seatPart) then showWaiting() else hideWaiting() end
	end)
end

local function onCharacterAdded(char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hookHumanoidForWaiting(hum)
end
if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)

RunService.Heartbeat:Connect(function()
	if inMatch then return end
	local char = player.Character
	local hum = char and (char:FindFirstChildOfClass("Humanoid") :: Humanoid)
	local seat = hum and hum.SeatPart
	if hum and hum.Sit and seat and seatBelongsToTwoSeat(seat) then showWaiting() else hideWaiting() end
end)

-- ===== Board / Choice =====
local boardGui: ScreenGui? = nil
local buttons: {[string]: ImageButton} = {}
local selected: string? = nil
local locked = false
local currentRound = 0

local function getTexture(choice: string): string
	local folder = RS:WaitForChild("board")
	local ch = folder:FindFirstChild(choice)
	if ch and (ch:IsA("ImageLabel") or ch:IsA("ImageButton")) then
		return (ch :: any).Image
	elseif ch and (ch:IsA("Decal") or ch:IsA("Texture")) then
		return (ch :: any).Texture
	end
	return ""
end

local function applyFancyStroke(gui: GuiObject, thickness: number)
	local gold = gui:FindFirstChild("GoldStroke") :: UIStroke
	if not gold then
		gold = Instance.new("UIStroke")
		gold.Name = "GoldStroke"
		gold.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		gold.LineJoinMode = Enum.LineJoinMode.Round
		gold.Parent = gui
	end
	gold.Thickness = thickness
	gold.Color = Color3.fromRGB(255, 215, 90)
	gold.Transparency = 0

	local inner = gui:FindFirstChild("InnerStroke") :: UIStroke
	if not inner then
		inner = Instance.new("UIStroke")
		inner.Name = "InnerStroke"
		inner.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		inner.LineJoinMode = Enum.LineJoinMode.Round
		inner.Parent = gui
	end
	inner.Thickness = math.max(0, math.floor(thickness * 0.35))
	inner.Color = Color3.fromRGB(255,255,255)
	inner.Transparency = 0.4
end

local function pulseStroke(gui: GuiObject)
	local gold = gui:FindFirstChild("GoldStroke") :: UIStroke
	if not gold then return end
	local base = gold.Thickness
	local t1 = TweenService:Create(gold, TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Thickness = base + 3})
	local t2 = TweenService:Create(gold, TweenInfo.new(0.14, Enum.EasingStyle.Sine, Enum.EasingDirection.In),  {Thickness = base})
	t1:Play(); t1.Completed:Once(function() t2:Play() end)
end

local function ensureBoard()
	if boardGui and boardGui.Parent then return end
	local root = ensureLayer("board_runtime")
	root:ClearAllChildren()

	local frame = Instance.new("Frame")
	frame.Name = "Container"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.82)
	frame.Size = UDim2.fromScale(0.75, 0.22)
	frame.BackgroundTransparency = 1
	frame.Parent = root

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 24)
	list.Parent = frame

	buttons = {}
	local myPack = HandsState.Get(player.UserId)  -- <-- 내 Hands 상태 가져오기
	local images = (myPack and myPack.images) or {}

	for _, name in ipairs({"rock","paper","scissors"}) do
		local img = images[name] or getTexture(name)  -- <-- 구매한 이미지가 있으면 사용
		local btn = Instance.new("ImageButton")
		btn.Name = name
		btn.Size = UDim2.fromOffset(170, 170)
		btn.BackgroundTransparency = 1
		btn.Image = img
		btn.AutoButtonColor = false
		applyFancyStroke(btn, 0)

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 0
		stroke.Color = Color3.fromRGB(255, 226, 0)
		stroke.Parent = btn

		btn.Parent = frame
		buttons[name] = btn

		btn.MouseButton1Click:Connect(function()
			if locked then return end
			selected = name
			chooseEv:FireServer(currentRound, selected)
			for cname, b in pairs(buttons) do
				local s = b:FindFirstChildOfClass("UIStroke") :: UIStroke?
				if s then s.Thickness = 0 end
				if cname == selected then
					applyFancyStroke(b, 10)
					pulseStroke(b)
					b.ImageColor3 = Color3.new(1,1,1)
				else
					applyFancyStroke(b, 0)
					b.ImageColor3 = Color3.fromRGB(150,150,150)
				end
			end
			SFX.Choice:Stop(); SFX.Choice.TimePosition = 0; SFX.Choice:Play()
		end)
	end

	boardGui = root
end


local function setButtonsLocked(state: boolean)
	locked = state
	for name, b in pairs(buttons) do
		if state then
			if name ~= selected then b.ImageColor3 = Color3.fromRGB(150,150,150) end
			b.Active = (name == selected)
		else
			b.ImageColor3 = Color3.new(1,1,1)
			b.Active = true
		end
	end
end

-- ===== Result icon responsive styling =====
local BASE_SHORT_EDGE = 1179  -- iPhone 14 Pro 세로 기준


local function _vpShort()
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(BASE_SHORT_EDGE, 2556)
	return math.min(vs.X, vs.Y)
end

local function _resultPx()
	-- 기준 140px, 기기 작으면 축소 / 크면 과대 확장 방지
	local px = math.floor(140 * _vpShort() / BASE_SHORT_EDGE)
	return math.clamp(px, 130, 150)
end

local function styleResultImage(img: ImageLabel?)
	if not (img and img.Parent) then return end

	-- 테두리(검은색) 제거
	for _, ch in ipairs(img:GetChildren()) do
		if ch:IsA("UIStroke") then ch:Destroy() end
	end

	-- 비율 고정 + 원본비 유지
	img.ScaleType = Enum.ScaleType.Fit
	local ar = img:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.DominantAxis = Enum.DominantAxis.Width
	ar.Parent = img

	-- 최대 크기 캡 + 즉시 스냅
	local cap = img:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
	local px = _resultPx()
	cap.MaxSize = Vector2.new(px, px)
	cap.MinSize = Vector2.new(0, 0)
	cap.Parent = img
	img.Size = UDim2.fromOffset(px, px)
end


-- 기존 함수 바디 교체
local function ensurePopImage(which: "top"|"bottom"): ImageLabel
	local root = ensureLayer("RPS_Pop")
	local name = (which == "top") and "Top" or "Bottom"
	local img = root:FindFirstChild(name) :: ImageLabel?
	if not img then
		img = Instance.new("ImageLabel")
		img.Name = name
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, (which == "top") and 0.22 or 0.82)
		img.BackgroundTransparency = 1
		img.Visible = false
		img.Parent = root
	end
	-- ★ 생성/재사용 시마다 스타일 보증
	styleResultImage(img)
	return img
end


-- Hands 스킨 → 기본보드 폴백
local function pickHandImage(uid: number?, choice: "paper"|"rock"|"scissors"): string
	if uid then
		local pack = HandsState.Get(uid)
		local img = pack and pack.images and pack.images[choice]
		if img and img ~= "" then return img end
	end
	return getTexture(choice)
end

-- ===== Countdown / Result =====
local function runCountdown(seconds: number)
	local lbl = ensureBigLabel("RPS_Countdown")
	lbl.TextColor3 = Color3.fromRGB(255, 226, 0)
	lbl.Visible = true
	for n = seconds, 1, -1 do
		lbl.Text = tostring(n)
		lbl.TextTransparency = 0
		lbl.Visible = true
		if SFX.Countdown then SFX.Countdown:Stop(); SFX.Countdown.TimePosition = 0; SFX.Countdown:Play() end
		pulseLabel(lbl)
		if n == seconds or n == 1 then shimmerText(lbl) end
		if n == 1 then
			setButtonsLocked(true)
			CAS:UnbindAction("RPS_CancelAction")
		end
		task.wait(1)
	end
	lbl.Visible = false
end

local function showResult(myChoice: string?, oppChoice: string?, outcome: string)
	if boardGui then boardGui.Enabled = false end

	local bottomImg = ensurePopImage("bottom")
	local topImg    = ensurePopImage("top")

	-- 아이콘 설정 직후에 두 줄 추가
	if myChoice then
		local img = pickHandImage(myUserId, myChoice :: any)
		bottomImg.Image = img
		bottomImg.Visible = (img ~= "")
		styleResultImage(bottomImg)         -- ★ 추가
	else
		bottomImg.Visible = false
	end

	if oppChoice then
		local img = pickHandImage(oppUserId, oppChoice :: any)
		topImg.Image = img
		topImg.Visible = (img ~= "")
		styleResultImage(topImg)            -- ★ 추가
	else
		topImg.Visible = false
	end
	

	-- 결과 텍스트
	local lbl = ensureBigLabel("RPS_Result")
	lbl.TextTransparency = 0
	if outcome == "win" then
		lbl.Text = "Win!";  lbl.TextColor3 = Color3.fromRGB(80, 255, 120)
		VictoryFX.play(player, "VICTORY!")
		-- 승리 SFX
		local sfxWin = SFXF:FindFirstChild("BlockWin") :: Sound?
		if sfxWin then
			local s = sfxWin:Clone()
			s.Parent = SoundService
			s:Play()
			task.delay(s.TimeLength, function() s:Destroy() end)
		end
	elseif outcome == "lose" then
		lbl.Text = "Lose!";  lbl.TextColor3 = Color3.fromRGB(255, 90, 90)
		-- 패배 SFX
		local sfxLose = SFXF:FindFirstChild("BlockLose") :: Sound?
		if sfxLose then
			local s = sfxLose:Clone()
			s.Parent = SoundService
			s:Play()
			task.delay(s.TimeLength, function() s:Destroy() end)
		end
	else
		lbl.Text = "Draw!"; lbl.TextColor3 = Color3.fromRGB(255, 226, 0)
	end
	lbl.Visible = true
	pulseLabel(lbl); shimmerText(lbl)

	task.delay(2.5, function()
		lbl.Visible = false
		topImg.Visible = false
		bottomImg.Visible = false
	end)
end

do
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			local pop = playerGui:FindFirstChild("RPS_Pop") :: ScreenGui?
			if not pop then return end
			local top = pop:FindFirstChild("Top") :: ImageLabel?
			local bottom = pop:FindFirstChild("Bottom") :: ImageLabel?
			styleResultImage(top)
			styleResultImage(bottom)
		end)
	end
end

-- ===== Camera =====
local function computeCameraTarget(mySeat: Seat, otherSeat: Seat): (CFrame, number)
	local char = player.Character
	local hrp = char and (char:FindFirstChild("HumanoidRootPart") :: BasePart)
	if not hrp then return CFrame.new(), 70 end
	local backDir = -hrp.CFrame.LookVector
	local rightDir = hrp.CFrame.RightVector
	local dist, left, up, fov = 1.5, -4, 2.5, 80
	local basePos = hrp.Position + backDir*dist + rightDir*left + Vector3.new(0, up, 0)
	local mid = (mySeat.CFrame.Position + otherSeat.CFrame.Position)/2
	local lookPoint = Vector3.new(mid.X, hrp.Position.Y + 1.6, mid.Z)
	return CFrame.new(basePos, lookPoint), fov
end

local function tweenCameraTo(targetCFrame: CFrame, targetFov: number, duration: number?)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local info = TweenInfo.new(duration or 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local tween = TweenService:Create(cam, info, {CFrame = targetCFrame, FieldOfView = targetFov})
	tween:Play()
	return tween
end

-- ===== Event wiring =====
uiEvent.OnClientEvent:Connect(function(action: string)
	if action == "showWaiting" then
		inMatch = false
		showWaiting()
	elseif action == "hideWaiting" then
		hideWaiting()
	end
end)


roundStart.OnClientEvent:Connect(function(roundNum: number, duration: number)
	currentRound = roundNum
	selected = nil

	-- 팝업(결과 아이콘) 초기화는 공통으로 먼저
	do
		local pop = playerGui:FindFirstChild("RPS_Pop") :: ScreenGui?
		if pop then
			local top = pop:FindFirstChild("Top")
			local bottom = pop:FindFirstChild("Bottom")
			if top and top:IsA("ImageLabel") then top.Visible = false end
			if bottom and bottom:IsA("ImageLabel") then bottom.Visible = false end
		end
	end

	local br = playerGui:FindFirstChild("board_runtime") :: ScreenGui?

	if roundNum == 1 then
		-- 라운드1: 보드 감추고 카운트다운만 진행 (Game Start 표시 금지)
		if br then br.Enabled = false end
		locked = true

		task.spawn(function()
			runCountdown(math.floor(duration))
		end)

	else
		-- 라운드2 이상: 보드 활성화 후, "Game Start" 1회 표시 -> 그 다음 카운트다운
		ensureBoard()
		if boardGui then boardGui.Enabled = true end
		setButtonsLocked(false)

		task.spawn(function()
			if not didShowStartOnce then
				-- Game Start를 보드가 보이는 타이밍에 1회만 노출
				flashStartText(playerGui, "Game Start!")
				didShowStartOnce = true
			end
			-- Game Start 표시가 끝난 뒤 카운트다운 시작
			runCountdown(math.floor(duration))
		end)
	end
end)


startEvent.OnClientEvent:Connect(function(seatA: Seat, seatB: Seat, p1Id: number?, p2Id: number?)
	-- 게임 시작 演出
	inMatch = true
	hideWaiting()

	-- 상대 ID 계산
	if p1Id and p2Id then
		oppUserId = (p1Id == myUserId) and p2Id or p1Id
	else
		oppUserId = nil
	end

	local targetCF, targetFov = computeCameraTarget(seatA, seatB)
	tweenCameraTo(targetCF, targetFov, 0.6)
	
	-- ★ 변경: 시작 시에는 "Game Start" 텍스트를 표시하지 않음
	didShowStartOnce = false  -- 새 매치 시작마다 초기화

	--local _total = flashStartText(playerGui, "Start!")
	if SFX.Spring.IsPlaying then SFX.Spring:Stop() end
	SFX.Start.TimePosition = 0
	SFX.Start:Play()
end)

cancelledEv.OnClientEvent:Connect(function(_reason: string)
	inMatch = false
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	local br = playerGui:FindFirstChild("board_runtime") :: ScreenGui?
	if br then br.Enabled = false end
	for _, layerName in ipairs({"RPS_Countdown","RPS_Result","RPS_Sides"}) do
		local g = playerGui:FindFirstChild(layerName) :: ScreenGui?
		if g then
			for _,v in ipairs(g:GetChildren()) do
				if v:IsA("TextLabel") or v:IsA("ImageLabel") then v.Visible = false end
			end
		end
	end
	hideWaiting()
	SFX.Spring.TimePosition = 0
	SFX.Spring:Play()
	CAS:UnbindAction("RPS_CancelAction")
	didShowStartOnce = false
end)

resultEv.OnClientEvent:Connect(function(roundNum: number, myChoice: string?, oppChoice: string?, outcome: string)
	if roundNum == 1 then return end
	if roundNum ~= currentRound then return end
	showResult(myChoice, oppChoice, outcome)
end)
