
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Debris           = game:GetService("Debris")
local LocalPlayer       = Players.LocalPlayer
local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")

-- 이벤트
local BuffFolder  = ReplicatedStorage:WaitForChild("BuffEvents")
local BuffApplied = BuffFolder:WaitForChild("BuffApplied") :: RemoteEvent

-- 하단 중앙 배치용 오프셋(px) — 필요시 조절
local BOTTOM_OFFSET = 64

-- ReplicatedStorage/Assets/Icons/{SpeedIcon, HeartIcon, Exp2xIcon} 를 가정
local Assets     = ReplicatedStorage:FindFirstChild("Assets")
local Icons      = Assets and Assets:FindFirstChild("Icons")
local SpeedIcon  = Icons and Icons:FindFirstChild("SpeedIcon")
local HeartIcon  = Icons and Icons:FindFirstChild("HeartIcon")
local Exp2xIcon  = Icons and Icons:FindFirstChild("Exp2xIcon")


-- ===== 레이아웃/스타일 상수 (가독성 강화) =====
local BAR_HEIGHT      = 52          -- 버프바 높이 ↑
local BAR_PADDING_X   = 14          -- 바 좌우 패딩
local ICON_SIZE       = 48          -- 아이콘 크기 ↑
local CORNER_RADIUS   = 16          -- 모서리 둥글기
local STROKE_THICK    = 2           -- 외곽선 두께 ↑
local BOTTOM_OFFSET   = 78          -- 하단에서 위로 띄우기
local TOAST_MARGIN    = 14          -- 토스트와 버프바 사이
local TIMER_COLOR   = Color3.fromRGB(255,255,255)  -- 타이머/토스트 공통 텍스트 컬러


-- 글래스+외곽선 (옵션 추가: skipGradient)
local function applyGlass(frame: Instance, cornerPx: number?, strokeThick: number?, opts: {skipGradient: boolean}? )
	opts = opts or {}
	-- 둥근 모서리
	local corner = frame:FindFirstChild("Corner") :: UICorner
	if not corner then
		corner = Instance.new("UICorner")
		corner.Name = "Corner"
		corner.Parent = frame
	end
	corner.CornerRadius = UDim.new(0, cornerPx or CORNER_RADIUS)

	-- 흰색 외곽선
	local stroke = frame:FindFirstChild("Stroke") :: UIStroke
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "Stroke"
		stroke.Parent = frame
	end
	stroke.Thickness = strokeThick or STROKE_THICK
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.35
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	-- 🔴 TextLabel 등에는 그라데이션/투명도 적용하지 않기
	if not opts.skipGradient then
		local grad = frame:FindFirstChild("Shine") :: UIGradient
		if not grad then
			grad = Instance.new("UIGradient")
			grad.Name = "Shine"
			grad.Parent = frame
		end
		grad.Rotation = 90
		grad.Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(255,255,255))
		grad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0.0, 0.88),
			NumberSequenceKeypoint.new(0.5, 0.92),
			NumberSequenceKeypoint.new(1.0, 0.95),
		})
	end
end




-- ===== UI 생성 =====
local function ensureRoot(): ScreenGui
	local gui = PlayerGui:FindFirstChild("BuffUI") :: ScreenGui
	if gui then return gui end
	gui = Instance.new("ScreenGui")
	gui.Name = "BuffUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = PlayerGui
	return gui
end




-- 하단 버프바 (가독성 ↑)
local function ensureBuffBar(parent: ScreenGui): Frame
	local bar = parent:FindFirstChild("BuffBar") :: Frame
	if not bar then
		bar = Instance.new("Frame")
		bar.Name = "BuffBar"
		bar.Parent = parent

		local pad = Instance.new("UIPadding")
		pad.Name = "Pad"
		pad.PaddingLeft  = UDim.new(0, BAR_PADDING_X)
		pad.PaddingRight = UDim.new(0, BAR_PADDING_X)
		pad.Parent = bar

		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Left
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Padding = UDim.new(0, 10)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = bar
	end

	bar.AnchorPoint    = Vector2.new(0.5, 1)
	bar.Position       = UDim2.new(0.5, 0, 1, -BOTTOM_OFFSET)
	bar.Size           = UDim2.new(0, 0, 0, BAR_HEIGHT)
	bar.AutomaticSize  = Enum.AutomaticSize.X
	-- 배경 더 진하게 + 살짝 투명
	bar.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
	bar.BackgroundTransparency = 0.08
	bar.ZIndex         = 30

	applyGlass(bar)
	
	-- 바 외곽선 숨김
	local s = bar:FindFirstChild("Stroke")
	if s then s.Transparency = 1 end

	return bar
end



--중앙에 버프 효과 알려주는 표시 잠시동안 팝업
local function showToast(text: string)
	local root = ensureRoot()
	local bar  = ensureBuffBar(root)

	-- 컨테이너
	local container = root:FindFirstChild("ToastContainer") :: Frame
	if not container then
		container = Instance.new("Frame")
		container.Name = "ToastContainer"
		container.AnchorPoint = Vector2.new(0.5, 1)
		container.BackgroundTransparency = 1
		container.Size = UDim2.new(1, 0, 0, 0)
		container.AutomaticSize = Enum.AutomaticSize.Y
		container.Position = UDim2.new(0.5, 0, 1, -(BOTTOM_OFFSET + BAR_HEIGHT + TOAST_MARGIN))
		container.ZIndex = 60
		container.Parent = root

		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Vertical
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Bottom
		list.Padding = UDim.new(0, 8)
		list.Parent = container
	end

	-- 토스트 한 줄 (더 진하고 선명)
	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AutomaticSize = Enum.AutomaticSize.XY
	toast.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	toast.BackgroundTransparency = 0.04      -- 덜 투명
	toast.TextColor3 = TIMER_COLOR

	toast.Text = text
	toast.Font = Enum.Font.GothamBlack        -- 두껍게
	toast.TextSize = 48                        -- 기본 크기 ↑ (TextScaled 대신 고정 + 제약)
	toast.BorderSizePixel = 0
	toast.ZIndex = container.ZIndex + 1

	-- 텍스트 외곽선으로 가독성 ↑
	toast.TextStrokeColor3 = Color3.new(0,0,0)
	toast.TextStrokeTransparency = 0.45

	-- 패딩 (pill)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft  = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.PaddingTop   = UDim.new(0, 10)
	pad.PaddingBottom= UDim.new(0, 10)
	pad.Parent = toast

	-- 기존: applyGlass(toast, CORNER_RADIUS, STROKE_THICK)
	applyGlass(toast, CORNER_RADIUS, STROKE_THICK, { skipGradient = true })

	toast.Parent = container

	-- 등장/퇴장 (덜 사라지게)
	toast.TextTransparency = 0
	toast.BackgroundTransparency = 0.25
	toast.AnchorPoint = Vector2.new(0.5, 1)
	toast.Position = UDim2.new(0.5, 0, 1, 10)

	local tIn = TweenService:Create(toast, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		BackgroundTransparency = 0.08,
		Position = UDim2.new(0.5, 0, 1, 0),
	})
	tIn:Play()

	task.delay(1.4, function()
		local tOut = TweenService:Create(toast, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 0.3,          -- 완전 투명 X (살짝 남김)
			BackgroundTransparency = 0.25,
		})
		tOut:Play()
		tOut.Completed:Wait()
		toast:Destroy()
	end)
end



-- 머리 위 하트 팝업(코인 마커와 동일한 방식)
local function showHeartPopup()
	local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local head = character:FindFirstChild("Head") or character:WaitForChild("Head")

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "AffectionPopup"
	billboard.Size = UDim2.new(2, 0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.Adornee = head
	billboard.Parent = head

	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Parent = billboard

	-- 아이콘 연결(없으면 이모지 텍스트 대체)
	if HeartIcon and HeartIcon:IsA("ImageLabel") then
		img.Image = HeartIcon.Image
	else
		img.Image = "rbxassetid://134581752"
		local txt = Instance.new("TextLabel")
		txt.BackgroundTransparency = 0
		txt.Size = UDim2.fromScale(1,1)
		txt.Text = "❤"
		txt.TextScaled = true
		txt.TextColor3 = Color3.fromRGB(255,255,255)
		txt.Font = Enum.Font.FredokaOne
		txt.Parent = img
	end

	-- 살짝 커졌다가 줄어드는 애니메이션
	img.ScaleType = Enum.ScaleType.Fit
	local start = Instance.new("UIScale", img); start.Scale = 0.5
	local t = TweenService:Create(start, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1})
	t:Play()

	Debris:AddItem(billboard, 1.6)
end

-- ===== 버프바 관리 =====
type BuffEntry = { frame: Frame, icon: ImageLabel, timer: TextLabel, expiresAt: number }

local buffs : {[string]: BuffEntry} = {}

local function hms(secs: number): string
	if secs < 0 then secs = 0 end
	local m = math.floor(secs / 60)
	local s = secs % 60
	return string.format("%d:%02d", m, s)
end


local function createBuffSlot(bar: Frame, kind: string, iconImage: string?, labelText: string?): BuffEntry
	local frame = Instance.new("Frame")
	frame.Name = "Buff_"..kind
	frame.Size = UDim2.new(0, 148, 1, 0)  -- 기본 폭 ↑
	frame.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	frame.BackgroundTransparency = 0.08    -- 덜 투명
	frame.BorderSizePixel = 0
	frame.ZIndex = bar.ZIndex + 1
	frame.Parent = bar

	applyGlass(frame, CORNER_RADIUS, STROKE_THICK)

	-- 아이콘 (왼쪽 고정)
	local ic = Instance.new("ImageLabel")
	ic.Name = "Icon"
	ic.BackgroundTransparency = 1
	ic.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
	ic.Position = UDim2.new(0, BAR_PADDING_X - 2, 0.5, -ICON_SIZE/2)
	ic.ZIndex = frame.ZIndex + 1
	ic.Parent = frame
	if iconImage and iconImage ~= "" then
		ic.Image = iconImage
	else
		ic.Image = "rbxassetid://0"
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1,1)
		t.Text = (labelText or kind)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(255,255,255)
		-- 얇은 외곽선으로 또렷하게
		t.TextStrokeColor3 = Color3.new(0,0,0)
		t.TextStrokeTransparency = 0.65
		t.Parent = ic
	end

	-- 타이머 텍스트: 프레임 “꽉 채움”
	local left = BAR_PADDING_X - 2
	local gap  = 10
	local txt = Instance.new("TextLabel")
	txt.Name = "Timer"
	txt.BackgroundTransparency = 1
	txt.Position = UDim2.new(0, left + ICON_SIZE + gap, 0, 0)
	txt.Size = UDim2.new(1, -(left + ICON_SIZE + gap + BAR_PADDING_X), 1, 0)
	txt.Font = Enum.Font.GothamBlack     -- 더 두껍게
	txt.TextColor3 = TIMER_COLOR

	txt.TextScaled = true                -- 높이 기준으로 크게
	txt.Text = "0:00"
	txt.ZIndex = frame.ZIndex + 1
	txt.TextXAlignment = Enum.TextXAlignment.Left
	txt.TextYAlignment = Enum.TextYAlignment.Center
	-- 텍스트 외곽선(가독성 ↑)
	txt.TextStrokeColor3 = Color3.fromRGB(0,0,0)
	txt.TextStrokeTransparency = 0.55
	-- 최소/최대 글자 크기 제한
	local szc = Instance.new("UITextSizeConstraint")
	szc.MinTextSize = 16
	szc.MaxTextSize = 30
	szc.Parent = txt

	txt.Parent = frame

	return { frame = frame, icon = ic, timer = txt, expiresAt = 0 }
end



local function iconOf(kind: string): string?
	if kind == "Speed" and SpeedIcon and SpeedIcon:IsA("ImageLabel") then
		return SpeedIcon.Image
	elseif kind == "Exp2x" and Exp2xIcon and Exp2xIcon:IsA("ImageLabel") then
		return Exp2xIcon.Image
	end
	return nil
end

local function upsertBuff(kind: string, expiresAt: number, label: string)
	local root = ensureRoot()
	local bar = ensureBuffBar(root)

	local entry = buffs[kind]
	if not entry then
		entry = createBuffSlot(bar, kind, iconOf(kind), label)
		buffs[kind] = entry
	end
	entry.expiresAt = math.max(expiresAt, os.time()) -- 최소 현재 이상
end

-- 1초마다 남은 시간 표시 & 만료 제거
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.time()
		for kind, entry in pairs(buffs) do
			local remain = (entry.expiresAt or 0) - now
			if remain <= 0 then
				entry.frame:Destroy()
				buffs[kind] = nil
			else
				entry.timer.Text = hms(remain)
			end
		end
	end
end)

-- ===== 이벤트 수신 =====
BuffApplied.OnClientEvent:Connect(function(payload)
	-- payload = { kind = "Speed"|"Exp2x"|"Affection", text="...", expiresAt?=unix, duration?=secs }
	local kind = tostring(payload.kind or "")
	local text = tostring(payload.text or "")

	-- 토스트는 모든 케이스에서 띄움
	if text ~= "" then showToast(text) end

	if kind == "Affection" then
		-- 하트 머리 위 팝업(비지속형, 버프바엔 추가 안 함)
		showHeartPopup()
		return
	end

	-- 지속형: 버프바 아이콘/타이머
	local expiresAt = tonumber(payload.expiresAt or 0) or 0
	if expiresAt > 0 then
		upsertBuff(kind, expiresAt, text)
	end
end)

