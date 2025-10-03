--!strict
local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local Debris  = game:GetService("Debris")

local player = Players.LocalPlayer
local RemotesFolder = RS:WaitForChild("BadgeRemotes")
local ToastRE       = RemotesFolder:WaitForChild("Toast") :: RemoteEvent
local UnlockSyncRE  = RemotesFolder:WaitForChild("UnlockSync") :: RemoteEvent

local billboardTemplate = RS:WaitForChild("playerGui") :: BillboardGui

-- ===== BadgeEffect 로딩 보장 (없으면 폴백 이펙트 사용) =====
local BadgeEffect: any = nil
local function tryRequireBadgeEffect(): boolean
	local moduleFolder = RS:FindFirstChild("Modules")
	if not moduleFolder then return false end
	local src = moduleFolder:FindFirstChild("BadgeEffect")
	if not src then return false end
	if not BadgeEffect then
		local ok, mod = pcall(require, src)
		if ok then BadgeEffect = mod end
	end
	return BadgeEffect ~= nil
end

-- ===== 최근 토스트 디듀프 =====
local recent: {[string]: number} = {}
local function shouldDrop(payload): boolean
	local k = "toast"
	if typeof(payload) == "table" then
		k = (payload.key and tostring(payload.key)) or (payload.text and tostring(payload.text)) or "toast"
	end
	local now = os.clock()
	local last = recent[k] or 0
	if now - last < 0.8 then return true end
	recent[k] = now
	return false
end

local function waitForCharacter(): Model
	return player.Character or player.CharacterAdded:Wait()
end
local function getBillboardAnchor(): BasePart?
	local char = waitForCharacter()
	return (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")) :: BasePart?
end

local activeCount = 0
local function showBadgeBalloon(text: string, duration: number?)
	local anchor = getBillboardAnchor()
	if not anchor then return end

	local gui = billboardTemplate:Clone()
	gui.Name = "BadgeToast"
	gui.Adornee = anchor
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = gui:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		label.Text = text or "Badge Unlocked!"
	end

	activeCount += 1
	local baseYOffset, stackStep = 2.0, 1.2
	gui.StudsOffsetWorldSpace = Vector3.new(0, baseYOffset + (activeCount-1)*stackStep, 0)

	local life = (typeof(duration) == "number" and duration or 3)
	Debris:AddItem(gui, life)
	task.delay(life, function()
		activeCount = math.max(0, activeCount - 1)
	end)
end

-- 폴백 이펙트 (BadgeEffect 모듈이 없을 때)
local function fallbackEffect(text: string, duration: number)
	local anchor = getBillboardAnchor()
	-- 화면 중앙 텍스트
	local sg = Instance.new("ScreenGui")
	sg.Name = "BadgeEffectFallback"
	sg.IgnoreGuiInset = true
	sg.ResetOnSpawn = false
	sg.Parent = player:WaitForChild("PlayerGui")

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0, 200, 0, 50)
	lbl.Position = UDim2.new(0.5, -100, 0.5, -25)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextSize = 160
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(255,255,0)
	lbl.TextStrokeColor3 = Color3.fromRGB(255,0,0)
	lbl.TextStrokeTransparency = 0.2
	lbl.Parent = sg

	-- 간단 파티클/사운드
	if anchor then
		local p = Instance.new("Part")
		p.Size = Vector3.new(7,7,1)
		p.Transparency = 1
		p.CanCollide = false
		p.Anchored = true
		p.CFrame = anchor.CFrame * CFrame.new(0,5,-3)
		p.Parent = workspace

		local pe = Instance.new("ParticleEmitter")
		pe.Lifetime = NumberRange.new(1,2)
		pe.Size = NumberSequence.new{ NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,3) }
		pe.Speed = NumberRange.new(5,15)
		pe.Rotation = NumberRange.new(0,360)
		pe.SpreadAngle = Vector2.new(180,180)
		pe.Acceleration = Vector3.new(0,5,0)
		pe.Parent = p
		pe:Emit(100)

		local s = Instance.new("Sound")
		s.SoundId = "rbxassetid://3120909354"
		s.Volume = 1.5
		s.PlaybackSpeed = 1
		s.Parent = p
		s:Play()

		Debris:AddItem(p, duration)
	end

	Debris:AddItem(sg, duration)
end

-- === Remotes ===
ToastRE.OnClientEvent:Connect(function(payload)
	if shouldDrop(payload) then return end  -- ★ 중복 방지

	local text = "Badge Unlocked!"
	if typeof(payload) == "table" and typeof(payload.text) == "string" then
		text = payload.text
	end
	local dur = 3
	if typeof(payload) == "table" and typeof(payload.duration) == "number" and payload.duration > 0 then
		dur = payload.duration
	end

	showBadgeBalloon(text, dur)

	-- 이펙트: 모듈 있으면 모듈, 없으면 폴백
	if tryRequireBadgeEffect() and BadgeEffect and type(BadgeEffect.showBadgeEffect) == "function" then
		task.spawn(function()
			BadgeEffect.showBadgeEffect("Got the badge !!", dur)
		end)
	else
		fallbackEffect("Got the badge !!", dur)
	end
end)

UnlockSyncRE.OnClientEvent:Connect(function(payload)
	local storeMod = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("BadgeClient")
	if storeMod then
		local ok, mod = pcall(require, storeMod)
		if ok and typeof(payload) == "table" and typeof(payload.tags) == "table" then
			mod._setTags(payload.tags)
		end
	end
end)
