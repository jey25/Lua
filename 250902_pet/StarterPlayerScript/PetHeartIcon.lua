--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Remotes
local RemoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local HeartEvent = RemoteFolder:WaitForChild("PetAffectionHeart")
local ZeroEvent  = RemoteFolder:WaitForChild("PetAffectionZero")

-- Icons
local IconsFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Icons")
local HeartIconTemplate = IconsFolder:WaitForChild("HeartIcon") :: Instance
local SuckIconTemplate  = IconsFolder:WaitForChild("SuckIcon")  :: Instance

-- Config
local STUDS_OFFSET = Vector3.new(0, 2.2, 0)
local GUI_SIZE     = UDim2.new(2, 0, 2, 0)
local HEART_BB_NAME = "PetHeartBillboard"
local ZERO_BB_NAME  = "PetZeroBillboard"

local function isMyPet(model: Instance): boolean
	if not model:IsA("Model") then return false end
	local owner = model:GetAttribute("OwnerUserId")
	return typeof(owner) == "number" and owner == player.UserId
end

local function getPetHeadOrPP(m: Model): BasePart?
	local head = m:FindFirstChild("Head")
	if head and head:IsA("BasePart") then return head end
	local pp = m.PrimaryPart
	if pp and pp:IsA("BasePart") then return pp end
	return m:FindFirstChildWhichIsA("BasePart", true)
end

local function ensureIconOnPet(pet: Model, bbName: string, template: Instance)
	if not isMyPet(pet) then return end
	if pet:FindFirstChild(bbName) then return end
	local adornee = getPetHeadOrPP(pet); if not adornee then return end

	local bb = Instance.new("BillboardGui")
	bb.Name = bbName
	bb.Size = GUI_SIZE
	bb.AlwaysOnTop = true
	bb.StudsOffset = STUDS_OFFSET
	bb.Adornee = adornee
	bb.Parent = pet

	local img = template:Clone()
	if img:IsA("ImageLabel") then
		img.Size = UDim2.new(1, 0, 1, 0)
		img.BackgroundTransparency = 1
		img.Parent = bb
	else
		local il = Instance.new("ImageLabel")
		il.Size = UDim2.new(1, 0, 1, 0)
		il.BackgroundTransparency = 1
		(il :: any).Image = (img :: any).Image or ""
		il.Parent = bb
	end
end

local function attachIconToAll(bbName: string, template: Instance)
	for _, m in ipairs(workspace:GetDescendants()) do
		if m:IsA("Model") and isMyPet(m) then
			ensureIconOnPet(m, bbName, template)
		end
	end
end

local function removeIconAll(bbName: string)
	for _, m in ipairs(workspace:GetDescendants()) do
		if m:IsA("Model") and isMyPet(m) then
			local bb = m:FindFirstChild(bbName)
			if bb then (bb :: Instance):Destroy() end
		end
	end
end

local heartActive, zeroActive = false, false

-- 새 펫 스폰 시 자동 부착(활성 상태일 때)
workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("Model") and isMyPet(inst) then
		task.defer(function()
			if heartActive then ensureIconOnPet(inst, HEART_BB_NAME, HeartIconTemplate) end
			if zeroActive  then ensureIconOnPet(inst, ZERO_BB_NAME,  SuckIconTemplate ) end
		end)
	end
end)

HeartEvent.OnClientEvent:Connect(function(payload)
	local show = payload and payload.show
	if show then
		heartActive = true
		attachIconToAll(HEART_BB_NAME, HeartIconTemplate)
		-- Heart와 Zero는 동시에 켜질 일이 사실상 없지만 안전하게 Zero는 끕니다.
		zeroActive = false
		removeIconAll(ZERO_BB_NAME)
	else
		heartActive = false
		removeIconAll(HEART_BB_NAME)
	end
end)

ZeroEvent.OnClientEvent:Connect(function(payload)
	local show = payload and payload.show
	if show then
		zeroActive = true
		attachIconToAll(ZERO_BB_NAME, SuckIconTemplate)
		-- Zero on이면 Heart는 꺼둠
		heartActive = false
		removeIconAll(HEART_BB_NAME)
	else
		zeroActive = false
		removeIconAll(ZERO_BB_NAME)
	end
end)
