--!strict
-- StarterPlayerScripts/RPSClient.client.lua
-- 구성: 서비스/상수 -> 유틸(SFX/GUI) -> 대기 폴백 -> 보드/카운트다운/결과 -> 이벤트

-- ===== Services / Constants =====
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local CAS = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local myUserId = player.UserId
local oppUserId: number? = nil
local exitReq    = RS:WaitForChild("Game_ExitRequest") :: RemoteEvent


-- 선택적 데이터 소스(있으면 사용)
local HandsState do
	local ok, mod = pcall(function() return require(RS:WaitForChild("HandsClientState")) end)
	HandsState = ok and mod or { Get = function(_: number) return nil end, Set = function() end }
end
local HANDS_PUBLIC: Folder? = RS:FindFirstChild("HandsPublic") :: Folder?

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

-- 추가: 블록/리더보드 브로드캐스트 (서버 BlockService.lua)
local blocksEv    = RS:WaitForChild("Blocks_Update") :: RemoteEvent

-- (옵션) 호환 브로드캐스트: 서버가 장착 변경을 알려줌
local Remotes = RS:FindFirstChild("Remotes")
local EquipChanged: RemoteEvent? = Remotes and Remotes:FindFirstChild("HandsEquipChanged") :: RemoteEvent

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
		-- 팝업이 항상 맨 위에 오도록
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
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextColor3 = Color3.fromRGB(255, 226, 0)
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
		lbl.Font = Enum.Font.GothamBlack
		lbl.TextColor3 = Color3.fromRGB(255, 230, 0)
		lbl.Text = "게임 시작!"
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
	local hold = 0.7
	task.wait(0.2 + hold)
	local tOut = TweenService:Create(lbl, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {TextTransparency = 1})
	tOut:Play()
	if strokeObj then
		TweenService:Create(strokeObj, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Transparency = 1}):Play()
	end
	tOut.Completed:Wait()
	lbl.Visible = false
	return 0.2 + hold + 0.35
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
	lbl.Text = "다른 플레이어를 기다리는 중…"
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

-- 기본 보드(ReplicatedStorage.board)에서 이미지 가져오기
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

-- HandsPublic에서 theme 이미지 얻기(폴백 포함)
local function getImagesFromPublic(theme: string): {[string]: string}
	local fb = {
		paper = getTexture("paper"),
		rock = getTexture("rock"),
		scissors = getTexture("scissors"),
	}
	local root = HANDS_PUBLIC
	if not root then return fb end
	local tf = root:FindFirstChild(theme)
	if not tf or not tf:IsA("Folder") then return fb end

	local function norm(s: string): string
		if s == "" then return "" end
		if s:match("^%d+$") then return "rbxassetid://"..s end
		return s
	end
	local function val(name: string): string
		local inst = tf:FindFirstChild(name)
		if inst and inst:IsA("StringValue") then return norm(inst.Value) end
		return ""
	end

	local paper = val("paper");    if paper == "" then paper = fb.paper end
	local rock = val("rock");      if rock == "" then rock = fb.rock end
	local scissors = val("scissors"); if scissors == "" then scissors = fb.scissors end
	return {paper = paper, rock = rock, scissors = scissors}
end

-- 내 보드 버튼에 현재 스킨 적용
local function refreshBoardImages()
	local pack = HandsState.Get(myUserId)
	if not pack or not pack.images then
		-- HandsState 미동기 시 Attribute + HandsPublic로 보강
		local theme = player:GetAttribute("HandsTheme")
		if theme and type(theme) == "string" then
			local imgs = getImagesFromPublic(theme)
			if HandsState.Set then HandsState.Set(myUserId, {theme = theme, images = imgs}) end
			pack = { theme = theme, images = imgs }
		end
	end
	if not pack or not pack.images then return end
	for name, btn in pairs(buttons) do
		local img = pack.images[name]
		if img and img ~= "" then
			btn.Image = img
		end
	end
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
	for _, name in ipairs({"rock","paper","scissors"}) do
		local img = getTexture(name)
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

	-- 방금 만든 버튼에 현재 스킨 적용(초기 1회)
	refreshBoardImages()
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

-- ===== Result popup =====
local function ensurePopImage(which: "top"|"bottom"): ImageLabel
	local root = ensureLayer("RPS_Pop")
	local name = (which == "top") and "Top" or "Bottom"
	local img = root:FindFirstChild(name) :: ImageLabel?
	if not img then
		img = Instance.new("ImageLabel")
		img.Name = name
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, (which == "top") and 0.22 or 0.82)
		img.Size = UDim2.fromOffset(220, 220)
		img.BackgroundTransparency = 1
		img.Visible = false
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.new(0,0,0)
		stroke.Parent = img
		img.Parent = root
	end
	return img
end

-- 결과 아이콘 선택(Hands → 기본 보드 폴백)
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

	-- 내 아이콘
	if myChoice then
		local img = pickHandImage(myUserId, (myChoice :: any))
		bottomImg.Image = img
		bottomImg.Visible = (img ~= "")
	else
		bottomImg.Visible = false
	end

	-- 상대 아이콘
	if oppChoice then
		local img = pickHandImage(oppUserId, (oppChoice :: any))
		topImg.Image = img
		topImg.Visible = (img ~= "")
	else
		topImg.Visible = false
	end

	-- 결과 텍스트
	local lbl = ensureBigLabel("RPS_Result")
	lbl.TextTransparency = 0
	if outcome == "win" then
		lbl.Text = "승리!";  lbl.TextColor3 = Color3.fromRGB(80, 255, 120)
	elseif outcome == "lose" then
		lbl.Text = "패배!";  lbl.TextColor3 = Color3.fromRGB(255, 90, 90)
	else
		lbl.Text = "무승부!"; lbl.TextColor3 = Color3.fromRGB(255, 226, 0)
	end
	lbl.Visible = true
	pulseLabel(lbl); shimmerText(lbl)

	task.delay(1.5, function()
		lbl.Visible = false
		topImg.Visible = false
		bottomImg.Visible = false
	end)
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

private function tweenCameraTo(targetCFrame: CFrame, targetFov: number, duration: number?)
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local info = TweenInfo.new(duration or 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local tween = TweenService:Create(cam, info, {CFrame = targetCFrame, FieldOfView = targetFov})
	tween:Play()
	return tween
end

-- ===== Hands 스킨 동기화 훅 (보드/결과 안정 표시) =====
-- 1) 내 HandsTheme Attribute가 바뀌면 HandsPublic 기반으로 HandsState 채우고 보드 갱신
player:GetAttributeChangedSignal("HandsTheme"):Connect(function()
	local theme = player:GetAttribute("HandsTheme")
	if type(theme) == "string" and theme ~= "" then
		local imgs = getImagesFromPublic(theme)
		if HandsState.Set then HandsState.Set(myUserId, { theme = theme, images = imgs }) end
	end
	refreshBoardImages()
end)

-- 2) (옵션) 서버 브로드캐스트 보조
if EquipChanged then
	EquipChanged.OnClientEvent:Connect(function(userId: number, themeName: string, images: {[string]: string})
		if HandsState.Set then HandsState.Set(userId, { theme = themeName, images = images }) end
		if userId == myUserId then
			refreshBoardImages()
		end
	end)
end

-- 초기 1회: Attribute 기반 보강
do
	local theme = player:GetAttribute("HandsTheme")
	if type(theme) == "string" and theme ~= "" then
		local imgs = getImagesFromPublic(theme)
		if HandsState.Set then HandsState.Set(myUserId, { theme = theme, images = imgs }) end
	end
end

-- ===== GameOver UI/Scene =====
local function hideRpsLayers()
	for _, layerName in ipairs({"RPS_Countdown","RPS_Result","RPS_Sides"}) do
		local g = playerGui:FindFirstChild(layerName) :: ScreenGui?
		if g then
			for _,v in ipairs(g:GetChildren()) do
				if v:IsA("TextLabel") or v:IsA("ImageLabel") then v.Visible = false end
			end
		end
	end
	-- 팝업 아이콘 숨김
	local pop = playerGui:FindFirstChild("RPS_Pop") :: ScreenGui?
	if pop then
		local top = pop:FindFirstChild("Top")
		local bottom = pop:FindFirstChild("Bottom")
		if top and top:IsA("ImageLabel") then top.Visible = false end
		if bottom and bottom:IsA("ImageLabel") then bottom.Visible = false end
	end
end

local function ensureGameOverSubLabel(): TextLabel
	local layer = ensureLayer("RPS_GameOver")
	local s = layer:FindFirstChild("Sub") :: TextLabel?
	if not s then
		s = Instance.new("TextLabel")
		s.Name = "Sub"
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.fromScale(0.5, 0.60)
		s.Size = UDim2.fromScale(0.8, 0.08)
		s.BackgroundTransparency = 1
		s.TextScaled = true
		s.Font = Enum.Font.GothamBold
		s.TextColor3 = Color3.new(1,1,1)
		s.Parent = layer
	end
	return s
end

local function showGameOver(loserUserId: number?)
	-- 상태/씬 정리
	inMatch = false
	locked = true
	selected = nil
	if boardGui then boardGui.Enabled = false end
	hideWaiting()
	hideRpsLayers()
	CAS:UnbindAction("RPS_CancelAction")

	-- 카메라 복구
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom

	-- BGM/효과음
	if SFX.Spring then
		SFX.Spring.TimePosition = 0
		SFX.Spring:Play()
	end
	if SFX.Result then
		SFX.Result.TimePosition = 0
		SFX.Result:Play()
	end

	-- 표시할 이름
	local nameText = "어느 플레이어"
	if typeof(loserUserId) == "number" then
		local pl = Players:GetPlayerByUserId(loserUserId)
		if pl then nameText = pl.DisplayName or pl.Name end
	end

	-- 메인 라벨
	local main = ensureBigLabel("RPS_GameOver")
	main.Text = "게임 종료!"
	main.TextColor3 = Color3.fromRGB(255, 90, 90)
	main.Visible = true
	pulseLabel(main); shimmerText(main)

	-- 서브 라벨
	local sub = ensureGameOverSubLabel()
	sub.TextTransparency = 0
	sub.Text = string.format("%s의 블록이 0개가 되어 라운드가 종료되었습니다.", nameText)
	sub.Visible = true

	-- 잠시 보여준 뒤 정리 (원하면 유지해도 됨)
	task.delay(2.5, function()
		if main then main.Visible = false end
		if sub then sub.Visible = false end
	end)
end

-- ===== Exit Modal =====
local function ensureExitModal(): Frame
	local layer = ensureLayer("RPS_ExitModal")
	local modal = layer:FindFirstChild("Modal") :: Frame?
	if modal then return modal end

	modal = Instance.new("Frame")
	modal.Name = "Modal"
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = UDim2.fromScale(0.5, 0.28)
	modal.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	modal.BackgroundTransparency = 0.1
	modal.BorderSizePixel = 0
	modal.Parent = layer

	local uiCorner = Instance.new("UICorner"); uiCorner.CornerRadius = UDim.new(0, 16); uiCorner.Parent = modal
	local padding = Instance.new("UIPadding"); padding.PaddingTop = UDim.new(0, 18); padding.PaddingBottom = UDim.new(0, 18); padding.PaddingLeft = UDim.new(0, 22); padding.PaddingRight = UDim.new(0, 22); padding.Parent = modal

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 48)
	title.BackgroundTransparency = 1
	title.Text = "게임이 종료되었습니다"
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 230, 0)
	title.Parent = modal
	stylizeRichLabel(title)

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 0, 40)
	body.Position = UDim2.new(0, 0, 0, 56)
	body.BackgroundTransparency = 1
	body.Text = "나가기를 선택하면 로블록스 로비 화면으로 돌아갑니다."
	body.Font = Enum.Font.Gotham
	body.TextScaled = true
	body.TextColor3 = Color3.fromRGB(235, 235, 235)
	body.Parent = modal

	local btnRow = Instance.new("Frame")
	btnRow.Name = "Buttons"
	btnRow.BackgroundTransparency = 1
	btnRow.Position = UDim2.new(0, 0, 1, -64)
	btnRow.Size = UDim2.new(1, 0, 0, 48)
	btnRow.Parent = modal

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 18)
	list.Parent = btnRow

	local function makeBtn(name: string, text: string): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.AutoButtonColor = true
		b.Text = text
		b.Size = UDim2.fromOffset(220, 48)
		b.BackgroundColor3 = Color3.fromRGB(255, 215, 90)
		b.TextColor3 = Color3.fromRGB(30, 20, 0)
		b.Font = Enum.Font.GothamBold
		b.TextScaled = true
		b.Parent = btnRow
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 12); c.Parent = b
		return b
	end

	makeBtn("LeaveBtn", "나가기")
	makeBtn("StayBtn",  "머물기")

	return modal
end

local function showExitModal()
	local modal = ensureExitModal()
	modal.Visible = true

	local leave = modal:FindFirstChild("Buttons"):FindFirstChild("LeaveBtn") :: TextButton
	local stay  = modal:FindFirstChild("Buttons"):FindFirstChild("StayBtn")  :: TextButton

	-- 중복 연결 방지
	for _, b in ipairs({leave, stay}) do
		for _, c in ipairs(b:GetConnections()) do
			-- (Studio에서는 GetConnections가 제한될 수 있어 보통은 새로 연결만 둬도 무방)
		end
	end

	leave.MouseButton1Click:Connect(function()
		exitReq:FireServer("leave")
		leave.Active = false; stay.Active = false
	end)

	stay.MouseButton1Click:Connect(function()
		modal.Visible = false
	end)
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

	-- 보드 표시 규칙
	local br = playerGui:FindFirstChild("board_runtime") :: ScreenGui?
	if roundNum == 1 then
		if br then br.Enabled = false end
		locked = true
	else
		ensureBoard()
		if boardGui then
			boardGui.Enabled = true
			-- 라운드 시작 시점에 한 번 더 적용(장착 직후 케이스)
			refreshBoardImages()
		end
		setButtonsLocked(false)
	end

	-- 팝업 초기화
	do
		local pop = playerGui:FindFirstChild("RPS_Pop") :: ScreenGui?
		if pop then
			local top = pop:FindFirstChild("Top")
			local bottom = pop:FindFirstChild("Bottom")
			if top and top:IsA("ImageLabel") then top.Visible = false end
			if bottom and bottom:IsA("ImageLabel") then bottom.Visible = false end
		end
	end

	task.spawn(function() runCountdown(math.floor(duration)) end)
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

	local _total = flashStartText(playerGui, "게임 시작!")
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
end)

-- ===== Blocks / Gameover wiring =====
blocksEv.OnClientEvent:Connect(function(kind: string, a: any, _b: any, _c: any)
	-- 서버: BlocksEvent:FireAllClients("gameover", loserUserId)
	if kind == "gameover" then
		local loserUserId = (typeof(a) == "number") and (a :: number) or nil
		showGameOver(loserUserId)
		showExitModal()            -- ➜ 종료 선택 모달
	-- (참고) 아래 분기들은 필요하면 채우세요.
	-- elseif kind == "full" then
	-- elseif kind == "delta" then
	-- elseif kind == "leave" then
	end
end)


resultEv.OnClientEvent:Connect(function(roundNum: number, myChoice: string?, oppChoice: string?, outcome: string)
	if roundNum == 1 then return end
	if roundNum ~= currentRound then return end
	showResult(myChoice, oppChoice, outcome)
	if SFX.Result then SFX.Result.TimePosition = 0; SFX.Result:Play() end
end)
