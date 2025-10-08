-- StarterPlayerScripts/PetQuestClient.client.lua
-- 좌측 HUD(2D) + 펫 Billboard(3D) + NPC(StreetFood, Wang) 연동 통합 버전 (ClickDetector 없음)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local RemoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents")

-- (추가) 모바일 터치 릴레이
local QuestTapRelay = RemoteFolder:FindFirstChild("QuestTapRelay") or Instance.new("RemoteEvent")
if not QuestTapRelay.Parent then
	QuestTapRelay.Name = "QuestTapRelay"
	QuestTapRelay.Parent = RemoteFolder
end

-- (추가) StreetFood 모바일 탭 릴레이
local StreetFoodTapRelay = RemoteFolder:FindFirstChild("StreetFoodTapRelay") or Instance.new("RemoteEvent")
if not StreetFoodTapRelay.Parent then
	StreetFoodTapRelay.Name = "StreetFoodTapRelay"
	StreetFoodTapRelay.Parent = RemoteFolder
end


-- Wang 3회-클릭 취소(Remote) — 서버에서만 카운트/판정
local WangCancelClick = RemoteFolder:WaitForChild("WangCancelClick")

-- Billboard GUI 이름 (펫 모델 하위에 붙는 Gui 이름)
local PET_GUI_NAME = "petGui"

-- === HUD 크기/위치 튜닝(좌측 상단, 반응형 축소) ===
local HUD_LEFT_PX      = 12
local HUD_TOP_PX       = 10
local BASE_SHORT_EDGE  = 1179  -- iPhone 14 Pro 기준
local HUD_MIN_SCALE    = 0.80
local HUD_MAX_SCALE    = 1.00


local function hudScale(): number
	local cam = workspace.CurrentCamera
	local vs  = cam and cam.ViewportSize or Vector2.new(BASE_SHORT_EDGE, 2556)
	local short = math.min(vs.X, vs.Y)
	return math.clamp(short / BASE_SHORT_EDGE, HUD_MIN_SCALE, HUD_MAX_SCALE)
end

local function applyQuestHudLayout(bg: Frame, label: TextLabel)
	local s = hudScale()
	local width  = math.floor(260 * s)
	local height = math.floor(40  * s)

	bg.Size     = UDim2.new(0, width, 0, height)

	-- 기존: UDim2.new(0, HUD_LEFT_PX, 0, HUD_TOP_PX)
	-- 변경: 왼쪽(0) + 약간 여백, 세로는 화면 0.25 지점쯤 (= 위에서 25%)
	bg.Position = UDim2.new(0, HUD_LEFT_PX, 0.25, 0)

	label.Size     = UDim2.new(1, -16, 1, 0)
	label.Position = UDim2.new(0, 8, 0, 0)
end



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

local function findPetById(petId: string): Model?
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Model")
			and inst:GetAttribute("OwnerUserId") == LocalPlayer.UserId
			and inst:GetAttribute("PetId") == petId then
			return inst
		end
	end
	return nil
end

local function setBubbleTextForPet(petId: string, text: string)
	local m = findPetById(petId)
	if not m then return end
	local gui = m:FindFirstChild(PET_GUI_NAME, true)
	if not (gui and gui:IsA("BillboardGui")) then return end
	local label = gui:FindFirstChildWhichIsA("TextLabel", true)
	if label then label.Text = text or "" end
	gui.Enabled = (text and text ~= "")
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
		screenGui.IgnoreGuiInset = false  -- (변경) 상단 안전영역 존중
		screenGui.Parent = playerGui
	end

	local bg = screenGui:FindFirstChild("BG") :: Frame
	if not bg then
		bg = Instance.new("Frame")
		bg.Name = "BG"
		bg.Size = UDim2.new(0, 260, 0, 40)           -- (변경) 기본 크기 축소
		bg.Position = UDim2.new(0, 12, 0, 10)        -- (변경) 좌측 상단으로 올림
		bg.BackgroundColor3 = Color3.fromRGB(0,0,0)
		bg.BackgroundTransparency = 0.35
		bg.BorderSizePixel = 0
		bg.Visible = false                -- ✅ 기본은 숨김
		bg.Parent = screenGui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = bg
	end
	
	-- (선택) 좀 더 소프트하게 보이도록 스트로크/패딩 추가
	local stroke = bg:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Thickness = 1; stroke.Transparency = 0.85; stroke.Color = Color3.fromRGB(255,255,255); stroke.Parent = bg
	local pad = bg:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0,8); pad.PaddingRight = UDim.new(0,8); pad.Parent = bg

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
		label.TextScaled = true                          -- 유지
		local maxSz = label:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
		maxSz.MaxTextSize = 22                           -- (추가) 너무 커지는 거 방지
		maxSz.MinTextSize = 14                           -- (선택) 너무 작아지지 않게
		maxSz.Parent = label
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = ""                   -- ✅ 기본 텍스트 없음
		label.Parent = bg
	end
	
	-- getOrCreateHud() 맨 끝쯤에 추가
	applyQuestHudLayout(bg, label)

	local cam = workspace.CurrentCamera
	if cam and not bg:GetAttribute("HudLayoutHooked") then
		bg:SetAttribute("HudLayoutHooked", true)
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			applyQuestHudLayout(bg, label)
		end)
	end
	
	return screenGui, bg, label
	
end


local function setQuestHudText(phrase: string)
	local _, bg, label = getOrCreateHud()
	label.Text = phrase or ""
	bg.Visible = (label.Text ~= nil and label.Text ~= "")
end

-- 모델 아래에 BasePart가 하나도 없을 때 로컬용 앵커 파트를 만들어 반환
local function ensureAnchorPartForModel(m: Model): BasePart?
	-- 혹시라도 나중에 생긴 파츠가 있으면 그대로 사용
	local exist = m:FindFirstChildWhichIsA("BasePart", true)
	if exist then return exist end

	-- 로컬 전용 투명 파트 생성
	local p = Instance.new("Part")
	p.Name = "__QuestMarkerAnchor_Local"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)

	-- 위치 잡기: 가능하면 바운딩박스, 실패시 피벗, 그래도 안되면 약간 공중
	local ok, cf, sz = pcall(function()
		local cframe, size = m:GetBoundingBox()
		return cframe, size
	end)
	if ok and cf then
		p.CFrame = cf
	else
		local ok2, pivot = pcall(function() return m:GetPivot() end)
		p.CFrame = ok2 and pivot or CFrame.new(0, 5, 0)
	end

	p.Parent = m -- 로컬만 보임
	return p
end


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


-- 기존: local QuestMarkers: {[Instance]: BillboardGui} = {}
-- 교체: 앵커( Model 또는 BasePart )를 키로 사용
local QuestMarkersByAnchor: {[Instance]: BillboardGui} = {}

-- 기존 getRootModel 함수 삭제하고 이걸로 교체
local function getRootModel(inst: Instance?): Model?
	if not inst then return nil end
	local m: Model? = (inst:IsA("Model") and inst) or inst:FindFirstAncestorOfClass("Model")
	if not m then return nil end
	-- 부모가 Model이면 끝까지 위로 상승
	while m.Parent and m.Parent:IsA("Model") do
		m = m.Parent :: Model
	end
	return m
end


-- 기존 getAnchor 함수 통째로 교체
local function getAnchor(inst: Instance?): Instance?
	if not inst then return nil end
	local top = getRootModel(inst)
	if top then return top end
	-- 모델이 전혀 없을 때만 파츠로 대체
	if inst:IsA("BasePart") then return inst end
	local base = inst:FindFirstAncestorWhichIsA("BasePart") or getAnyBasePart(inst)
	return base
end


-- 유틸: 입력 리스트를 앵커로 변환하며 중복 제거
local function uniqueAnchorsFrom(list): {Instance}
	if typeof(list) ~= "table" then return {} end
	local seen: {[Instance]: boolean} = {}
	local out: {Instance} = {}
	for _, t in ipairs(list) do
		if typeof(t) == "Instance" then
			local a = getAnchor(t)
			if a and not seen[a] then
				seen[a] = true
				table.insert(out, a)
			end
		end
	end
	return out
end


local function showMarkerOn(target: Instance)
	if not target or not target.Parent then return end

	local anchor = getAnchor(target)
	if not anchor then return end

	-- 이미 등록된 마커가 있으면 재사용
	local existing = QuestMarkersByAnchor[anchor]
	if existing and existing.Parent then
		existing.Enabled = true
		return
	end

	-- 과거에 남아 있던 마커가 있으면 잡아서 재사용
	local stray: BillboardGui? = nil
	if anchor:IsA("Model") then
		stray = (anchor :: Model):FindFirstChild("QuestMarker_Local", true)
	elseif anchor:IsA("BasePart") then
		stray = anchor:IsA("BasePart") and anchor:FindFirstChild("QuestMarker_Local") or nil
	end
	if stray and stray:IsA("BillboardGui") then
		stray.Enabled = true
		QuestMarkersByAnchor[anchor] = stray
		return
	end

	local createdAnchor: BasePart? = nil  -- 추가

	-- Billboard를 붙일 파츠 결정
	local base: BasePart? = nil
	if anchor:IsA("Model") then
		base = getAnyBasePart(anchor)
		if not base then
			base = ensureAnchorPartForModel(anchor)  -- 추가: 폴백 생성
			createdAnchor = base
		end
	elseif anchor:IsA("BasePart") then
		base = anchor
	end
	if not base then return end


	-- 생성
	local bb = Instance.new("BillboardGui")
	bb.Name = "QuestMarker_Local"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(0, 44, 0, 44)

	-- 높이 오프셋 계산: Model이면 ExtentsSize, 아니면 파츠 높이
	local offsetY = 4
	if anchor:IsA("Model") then
		local ok, size = pcall(function() return (anchor :: Model):GetExtentsSize() end)
		if ok and size then offsetY = math.max(3, size.Y * 0.55) end
	elseif anchor:IsA("BasePart") then
		offsetY = math.max(2.5, (base.Size.Y or 1) * 0.5)
	end
	bb.StudsOffsetWorldSpace = Vector3.new(0, offsetY + 1.0, 0)
	bb.Parent = base

	-- 안쪽 UI
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

	QuestMarkersByAnchor[anchor] = bb

	-- 앵커 범위에서 중복 청소(선택)
	if anchor:IsA("Model") then
		for _, d in ipairs(anchor:GetDescendants()) do
			if d ~= bb and d:IsA("BillboardGui") and d.Name == "QuestMarker_Local" then
				d:Destroy()
			end
		end
	elseif anchor:IsA("BasePart") then
		for _, d in ipairs(anchor:GetChildren()) do
			if d ~= bb and d:IsA("BillboardGui") and d.Name == "QuestMarker_Local" then
				d:Destroy()
			end
		end
	end

	bb.Destroying:Once(function()
		if QuestMarkersByAnchor[anchor] == bb then
			QuestMarkersByAnchor[anchor] = nil
		end
		if createdAnchor and createdAnchor.Parent then
			createdAnchor:Destroy() -- 로컬 더미 파트 청소
		end
	end)

end



local function hideMarkerOn(target: Instance)
	local anchor = getAnchor(target)
	if not anchor then return end

	local bb = QuestMarkersByAnchor[anchor]
	if bb then
		bb:Destroy()
		QuestMarkersByAnchor[anchor] = nil
		return
	end

	-- 매핑이 없어도 앵커 범위의 남은 마커 제거
	if anchor:IsA("Model") then
		local stray = anchor:FindFirstChild("QuestMarker_Local", true)
		if stray and stray:IsA("BillboardGui") then stray:Destroy() end
	elseif anchor:IsA("BasePart") then
		local stray = anchor:FindFirstChild("QuestMarker_Local")
		if stray and stray:IsA("BillboardGui") then stray:Destroy() end
	end
end


-- 교체: 중복 제거 후 한 번만 생성/제거
local function showMarkersOn(list)
	for _, anchor in ipairs(uniqueAnchorsFrom(list)) do
		showMarkerOn(anchor)
	end
end

local function hideMarkersOn(list)
	for _, anchor in ipairs(uniqueAnchorsFrom(list)) do
		hideMarkerOn(anchor)
	end
end

-- ========= [PetQuest 이벤트 처리] =========
local PetQuestEvent = RemoteFolder:WaitForChild("PetQuestEvent")

PetQuestEvent.OnClientEvent:Connect(function(action, data)
	if action == "StartQuest" then
		local phrase = (data and data.phrase) or ""
		setQuestHudText(phrase)                 -- ✅ 보임
		ensureResolvedSoon()
		if textLabel then textLabel.Text = phrase end
		if bubble then bubble.Enabled = true end

	elseif action == "CompleteQuest" then
		runClearEffect()
		setQuestHudText("")                     -- ✅ 숨김
		if textLabel then textLabel.Text = "" end
	elseif action == "StartQuestForPet" then
		local petId = data and data.petId
		local phrase = (data and data.phrase) or ""
		setBubbleTextForPet(petId, phrase)
		-- 좌측 HUD에는 "가장 최근 시작된 문구"만 보여주고 싶다면:
		setQuestHudText(phrase)

	elseif action == "CompleteQuestForPet" then
		local petId = data and data.petId
		setBubbleTextForPet(petId, "")
		runClearEffect()
		-- HUD는 해당 펫이 완료됐을 때 비워줌(단, 다른 펫이 아직 진행 중이면 필요 시 로직 보강 가능)
		setQuestHudText("")

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


-- 데스크톱: 마우스
local mouse = LocalPlayer:GetMouse()
mouse.Button1Down:Connect(function()
	sendCancelIfMyPetClick(mouse.Target)
end)



if UserInputService.TouchEnabled then
	UserInputService.TouchTapInWorld:Connect(function(_, processedByUI)
		if processedByUI then return end

		-- 1) Wang 취소(기존)
		sendCancelIfMyPetClick(mouse.Target)

		-- 2) 퀘스트 대상 터치 릴레이(신규)
		local hit = mouse.Target
		if hit and QuestTapRelay then
			-- 서버가 분류/검증 → 동일 완료 로직 실행
			QuestTapRelay:FireServer(hit)
		end
		
		-- (추가) StreetFood 탭 릴레이
		if StreetFoodTapRelay and mouse.Target then
			StreetFoodTapRelay:FireServer(mouse.Target)
		end
	end)
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
