-- StarterPlayerScripts/PetQuestClient.client.lua
-- 좌측 HUD(2D) + 펫 Billboard(3D) + NPC(StreetFood, Wang) 연동 통합 버전 (ClickDetector 없음)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local RemoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents")

-- Wang 3회-클릭 취소(Remote) — 서버에서만 카운트/판정
local WangCancelClick = RemoteFolder:WaitForChild("WangCancelClick")

-- Billboard GUI 이름 (펫 모델 하위에 붙는 Gui 이름)
local PET_GUI_NAME = "petGui"

-- ========= [펫 Billboard 탐색 및 관리] =========
local bubble: BillboardGui? = nil
local textLabel: TextLabel? = nil
local currentPet: Model? = nil
local savedBubble: string? = nil

local function findMyPet(): Model?
	local uid = LocalPlayer.UserId
	local best: Model? = nil
	local bestDist = math.huge
	local char = LocalPlayer.Character
	local charPos = char and char.PrimaryPart and char.PrimaryPart.Position
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Model") and inst:GetAttribute("OwnerUserId") == uid then
			local pp = inst.PrimaryPart
			if pp then
				if charPos then
					local d = (pp.Position - charPos).Magnitude
					if d < bestDist then best, bestDist = inst, d end
				else
					return inst
				end
			end
		end
	end
	return best
end

local function resolvePetAndBillboard()
	currentPet = findMyPet()
	bubble, textLabel = nil, nil
	if not currentPet then return end

	local gui = currentPet:FindFirstChild(PET_GUI_NAME, true)
	if not (gui and gui:IsA("BillboardGui")) then return end
	bubble = gui

	-- 우선 이름으로, 없으면 재귀 탐색, 최종 폴백 전체탐색
	local candidate = bubble:FindFirstChild("TextLabel")
	if not candidate then
		local ok, res = pcall(function()
			return bubble:FindFirstChildWhichIsA("TextLabel", true)
		end)
		if ok then candidate = res end
	end
	if not candidate then
		for _, d in ipairs(bubble:GetDescendants()) do
			if d:IsA("TextLabel") then candidate = d; break end
		end
	end
	if candidate and candidate:IsA("TextLabel") then
		textLabel = candidate
	end
end

local function ensureResolvedSoon()
	if bubble and textLabel and currentPet then return end
	resolvePetAndBillboard()
	if not (bubble and textLabel) then
		task.defer(resolvePetAndBillboard)
	end
end

-- 런타임 훅 (펫/GUI 생길 때 포인터 갱신)
Workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("Model") and inst:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
		task.defer(resolvePetAndBillboard)
	elseif inst:IsA("BillboardGui") and inst.Name == PET_GUI_NAME then
		local p = inst:FindFirstAncestorOfClass("Model")
		if p and p:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
			task.defer(resolvePetAndBillboard)
		end
	end
end)
LocalPlayer.CharacterAdded:Connect(function()
	task.defer(resolvePetAndBillboard)
end)
task.defer(resolvePetAndBillboard)

-- ========= [Clear 이펙트 실행 (명시적 신호에만)] =========
local function runClearEffect()
	local ok, ClearModule = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ClearModule"))
	end)
	if ok and ClearModule and ClearModule.showClearEffect then
		pcall(function() ClearModule.showClearEffect(LocalPlayer) end)
	end
end

-- ========= [좌측 HUD(2D)] =========
local function getOrCreateHud()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = playerGui:FindFirstChild("PetHUD") :: ScreenGui
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "PetHUD"
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.Parent = playerGui
	end

	local bg = screenGui:FindFirstChild("BG") :: Frame
	if not bg then
		bg = Instance.new("Frame")
		bg.Name = "BG"
		bg.Size = UDim2.new(0, 320, 0, 52)
		bg.Position = UDim2.new(0, 20, 0.4, 0)
		bg.BackgroundColor3 = Color3.fromRGB(0,0,0)
		bg.BackgroundTransparency = 0.35
		bg.BorderSizePixel = 0
		bg.Parent = screenGui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = bg
	end

	local label = bg:FindFirstChild("Text") :: TextLabel
	if not label then
		label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -16, 1, 0)
		label.Position = UDim2.new(0, 8, 0, 0)
		label.TextColor3 = Color3.fromRGB(234, 234, 234)
		label.Font = Enum.Font.SourceSansBold
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = bg
	end
	return screenGui, bg, label
end

local function clearHud()
	local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
	local hud = playerGui and playerGui:FindFirstChild("PetHUD")
	if hud then hud:Destroy() end
end

-- ========= [퀘스트 마커 관리] =========
local QuestMarkers: {[Instance]: BillboardGui} = {}

local function getAnyBasePart(inst: Instance): BasePart?
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then
		local m = inst
		if m.PrimaryPart then return m.PrimaryPart end
		local hrp = m:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then return hrp end
		return m:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function showMarkerOn(target: Instance)
	if not target or not target.Parent then return end
	if QuestMarkers[target] and QuestMarkers[target].Parent then
		QuestMarkers[target].Enabled = true
		return
	end
	local base = getAnyBasePart(target)
	if not base then return end

	local bb = Instance.new("BillboardGui")
	bb.Name = "QuestMarker_Local"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(0, 52, 0, 52)

	local offsetY = 4
	if target:IsA("Model") then
		local ok, size = pcall(function() return (target :: Model):GetExtentsSize() end)
		if ok and size then offsetY = math.max(3, size.Y * 0.55) end
	end
	bb.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	bb.Parent = base

	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Text = "?"
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBlack
	tl.TextColor3 = Color3.fromRGB(255, 224, 79)

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(0,0,0)
	stroke.Transparency = 0.15
	stroke.Parent = tl

	local bg = Instance.new("Frame")
	bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	bg.BackgroundTransparency = 0.35
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = tl
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 24)
	corner.Parent = bg
	bg.ZIndex = 0
	tl.ZIndex = 1

	tl.Parent = bb
	QuestMarkers[target] = bb
end

local function hideMarkerOn(target: Instance)
	local bb = QuestMarkers[target]
	if bb then
		bb:Destroy()
		QuestMarkers[target] = nil
	end
end

local function showMarkersOn(list)
	if typeof(list) ~= "table" then return end
	for _, t in ipairs(list) do
		if typeof(t) == "Instance" then showMarkerOn(t) end
	end
end

local function hideMarkersOn(list)
	if typeof(list) ~= "table" then return end
	for _, t in ipairs(list) do
		if typeof(t) == "Instance" then hideMarkerOn(t) end
	end
end

-- ========= [PetQuest 이벤트 처리] =========
local PetQuestEvent = RemoteFolder:WaitForChild("PetQuestEvent")

PetQuestEvent.OnClientEvent:Connect(function(action, data)
	if action == "StartQuest" then
		local phrase = (data and data.phrase) or ""
		local _, _, label = getOrCreateHud()
		label.Text = phrase

		ensureResolvedSoon()
		if textLabel then textLabel.Text = phrase end
		if bubble then bubble.Enabled = true end

	elseif action == "CompleteQuest" then
		-- 일반 퀘스트 클리어 연출만 여기서 실행
		runClearEffect()
		clearHud()
		if textLabel then textLabel.Text = "" end

	elseif action == "ShowQuestMarkers" then
		showMarkersOn(data and data.targets)
	elseif action == "HideQuestMarkers" then
		hideMarkersOn(data and data.targets)
	elseif action == "ShowQuestMarker" then
		if data and data.target then showMarkerOn(data.target) end
	elseif action == "HideQuestMarker" then
		if data and data.target then hideMarkerOn(data.target) end
	end
end)



-- 데스크톱: 마우스
local mouse = LocalPlayer:GetMouse()
mouse.Button1Down:Connect(function()
	sendCancelIfMyPetClick(mouse.Target)
end)

-- 모바일: 월드 탭
local UserInputService = game:GetService("UserInputService")
if UserInputService.TouchEnabled then
	UserInputService.TouchTapInWorld:Connect(function(_, processedByUI)
		if processedByUI then return end
		sendCancelIfMyPetClick(mouse.Target) -- 터치도 mouse.Target 갱신됨
	end)
end



-- 내 펫 모델 얻기
local function isMyPetModel(model: Instance?): boolean
	if not model then return false end
	local petModel = model:FindFirstAncestorOfClass("Model") or (model:IsA("Model") and model)
	if not petModel or not petModel:IsA("Model") then return false end
	return petModel:GetAttribute("OwnerUserId") == LocalPlayer.UserId
end

-- 어떤 파츠를 클릭하든 내 펫의 히트박스로 환산
local function resolveToMyPetHitbox(part: BasePart?): BasePart?
	if not part then return nil end
	-- 이미 히트박스를 클릭
	if part.Name == "PetClickHitbox" and isMyPetModel(part) then
		return part
	end
	-- 내 펫인지 확인
	local petModel = part:FindFirstAncestorOfClass("Model")
	if not petModel or not isMyPetModel(petModel) then return nil end
	-- 펫 안의 히트박스 찾기
	local hit = petModel:FindFirstChild("PetClickHitbox", true)
	if hit and hit:IsA("BasePart") then
		return hit
	end
	return nil
end

-- ========= [Wang: 3회-클릭 취소 — ClickDetector 없이 레이캐스트] =========
local function sendCancelIfMyPetClick(targetPart: BasePart?)
	local hitbox = resolveToMyPetHitbox(targetPart)
	if not hitbox then return end
	WangCancelClick:FireServer(hitbox)
end


-- ========= [NPC 설정 테이블] =========
local NPCs = {
	StreetFood = {
		Folder = Workspace:WaitForChild("World"):WaitForChild("dogItems"):WaitForChild("street Food"),
		PromptName = "StreetFoodPrompt",
		Relay = RemoteFolder:WaitForChild("StreetFoodProxRelay"),
		Event = RemoteFolder:WaitForChild("StreetFoodEvent"),
	},
	Wang = {
		Folder = Workspace:WaitForChild("World"):WaitForChild("dogItems"):WaitForChild("wang"),
		PromptName = "WangPrompt",
		Relay = RemoteFolder:WaitForChild("WangProxRelay"),
		Event = RemoteFolder:WaitForChild("WangEvent"),
	},
}

-- ========= [NPC별 이벤트 연결] =========
for _, cfg in pairs(NPCs) do
	-- ProximityPrompt → 서버 릴레이
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if prompt and prompt:IsDescendantOf(cfg.Folder) and prompt.Name == cfg.PromptName then
			cfg.Relay:FireServer("enter", prompt)
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if prompt and prompt:IsDescendantOf(cfg.Folder) and prompt.Name == cfg.PromptName then
			cfg.Relay:FireServer("exit", prompt)
		end
	end)

	-- 서버 → 클라 이벤트
	cfg.Event.OnClientEvent:Connect(function(action, data)
		if action == "Bubble" then
			ensureResolvedSoon()
			if not textLabel then return end
			local newText = (data and data.text) or ""
			local stash = (data and data.stash) or false
			if stash then savedBubble = textLabel.Text or "" end
			textLabel.Text = newText
			if bubble then bubble.Enabled = true end

		elseif action == "RestoreBubble" then
			ensureResolvedSoon()
			if not textLabel then return end
			textLabel.Text = savedBubble or ""
			if bubble then bubble.Enabled = (textLabel.Text ~= "") end

		elseif action == "ClearEffect" then
			-- ✅ 오직 이 신호에서만 Clear 이펙트
			runClearEffect()
		end
	end)
end
