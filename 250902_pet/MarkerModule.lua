
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local MarkerClient = {}

-- 선택: 템플릿 폴더(없어도 동작)
local TEMPLATE_ROOT: Instance? = nil
pcall(function()
	TEMPLATE_ROOT = ReplicatedStorage:WaitForChild("UI"):WaitForChild("Markers")
end)

-- ─────────────────────────────────────────────────────
-- 유틸
local function getAnyBasePart(inst: Instance): BasePart?
	if not inst then return nil end
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then
		local m = inst :: Model
		if m.PrimaryPart and m.PrimaryPart:IsA("BasePart") then return m.PrimaryPart end
		local hrp = m:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then return hrp end
		return m:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function getModel(inst: Instance): Model?
	if not inst then return nil end
	return inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
end

local function computeTopYOffset(model: Model, extra: number?): number
	local size = model:GetExtentsSize()
	return (size.Y * 0.5) + (extra or 2.0)
end

local function ensureAnchor(model: Model, yOffset: number): Attachment?
	local base = getAnyBasePart(model); if not base then return nil end
	local att = base:FindFirstChild("MarkerAnchor") :: Attachment
	if not att then
		att = Instance.new("Attachment")
		att.Name = "MarkerAnchor"
		att.Parent = base
	end
	att.Position = Vector3.new(0, yOffset, 0)
	return att
end

local function createBillboard(name: string, size: UDim2, z: number, alwaysOnTop: boolean): BillboardGui
	local bg = Instance.new("BillboardGui")
	bg.Name = name
	bg.Size = size
	bg.AlwaysOnTop = alwaysOnTop
	bg.LightInfluence = 0
	bg.MaxDistance = 200
	bg.StudsOffsetWorldSpace = Vector3.zero
	bg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	bg.ResetOnSpawn = false

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ZIndex = z
	holder.Parent = bg

	return bg
end

-- ReplicatedStorage에서 이름으로 ImageLabel 템플릿 찾기
local function findTemplateByName(name: string): Instance?
	local cand = ReplicatedStorage:FindFirstChild(name)
	if cand then return cand end
	if TEMPLATE_ROOT then
		local t = TEMPLATE_ROOT:FindFirstChild(name)
		if t then return t end
	end
	return nil
end

-- 기존 createImage 대체
local function createImage(holder: Instance, opts)
	local img = Instance.new("ImageLabel")
	img.Name = "Icon"
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromScale(1, 1)
	img.BackgroundTransparency = 1
	img.ImageTransparency = math.clamp(tonumber(opts.transparency) or 0.15, 0, 1)
	img.ZIndex = holder:IsA("GuiObject") and holder.ZIndex or 2

	-- ① preset(template) 우선: ReplicatedStorage/UI/Markers/Click Icon 등
	local presetName = opts.preset or opts.template or "Click Icon"
	local tmpl = (type(presetName)=="string") and findTemplateByName(presetName) or nil
	if tmpl then
		if tmpl:IsA("ImageLabel") or tmpl:IsA("ImageButton") then
			img.Image = (tmpl :: any).Image
			img.ImageRectOffset = (tmpl :: any).ImageRectOffset
			img.ImageRectSize   = (tmpl :: any).ImageRectSize
			img.ScaleType       = (tmpl :: any).ScaleType
		elseif tmpl:IsA("Decal") or tmpl:IsA("Texture") then
			img.Image = (tmpl :: any).Texture
		end
	end

	-- ② 직접 이미지 ID 제공 시 덮어쓰기
	if typeof(opts.image) == "string" and #opts.image > 0 then
		img.Image = opts.image -- ex) "rbxassetid://123456789"
	end

	-- 색상/회전
	if typeof(opts.imageColor) == "Color3" then img.ImageColor3 = opts.imageColor end
	if typeof(opts.rotation) == "number" then img.Rotation = opts.rotation end

	img.Parent = holder
	return img
end


local function applyPulse(img: ImageLabel, period: number?)
	local dur = tonumber(period) or 0.8
	local tween = TweenService:Create(
		img,
		TweenInfo.new(dur, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, true),
		{ ImageTransparency = math.clamp(img.ImageTransparency + 0.25, 0, 1) }
	)
	tween:Play()
	return tween
end

-- ─────────────────────────────────────────────────────
-- 공개 API

-- opts:
--   key, preset(또는 template), image, size, transparency, imageColor, rotation,
--   alwaysOnTop, offsetY, pulse, pulsePeriod
function MarkerClient.show(target: Instance, opts)
	opts = opts or {}
	local model = getModel(target); if not model then return end
	local key = tostring(opts.key or "default")

	-- 마커 컨테이너
	local folder = model:FindFirstChild("_Markers")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "_Markers"
		folder.Parent = model
	end

	-- 이미 있으면 활성화만
	local existing = folder:FindFirstChild("Marker_"..key)
	if existing and existing:IsA("BillboardGui") then
		existing.Enabled = true
		return existing
	end

	local yOffset = computeTopYOffset(model, tonumber(opts.offsetY) or 2.0)
	local anchor = ensureAnchor(model, yOffset); if not anchor then return end

	local size = (typeof(opts.size) == "UDim2") and opts.size or UDim2.fromOffset(64, 64)
	local bg = createBillboard("Marker_"..key, size, 2, (opts.alwaysOnTop ~= false))
	bg.Adornee = anchor
	bg.Parent = folder

	local holder = bg:FindFirstChild("Holder") :: Frame
	local img = createImage(holder, opts)

	if opts.pulse ~= false then
		applyPulse(img, opts.pulsePeriod)
	end

	return bg
end

function MarkerClient.hide(target: Instance, key: string?)
	local model = getModel(target); if not model then return end
	local folder = model:FindFirstChild("_Markers"); if not folder then return end
	local name = "Marker_"..(key or "default")
	local gui = folder:FindFirstChild(name)
	if gui and gui:IsA("BillboardGui") then
		gui:Destroy()
	end
end

function MarkerClient.hideAll(target: Instance)
	local model = getModel(target); if not model then return end
	local folder = model:FindFirstChild("_Markers"); if not folder then return end
	for _, ch in ipairs(folder:GetChildren()) do
		if ch:IsA("BillboardGui") then ch:Destroy() end
	end
end

return MarkerClient
