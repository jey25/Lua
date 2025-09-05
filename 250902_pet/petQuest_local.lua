-- StarterPlayerScripts/PetQuestClient.client.lua
-- 좌측 HUD(2D) + 우측 sideBubble은 펫 위 BillboardGui(3D)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- 템플릿(반드시 BillboardGui) - 실제 이름과 대소문자 맞추기!
local PET_GUI_NAME = "petGui"  -- 필요시 "PetGui"로 교체
local petGuiTemplate: Instance = ReplicatedStorage:WaitForChild(PET_GUI_NAME)
local PetQuestEvent: RemoteEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("PetQuestEvent")

-- 상태 (Billboard)
local bubble: BillboardGui? = nil
local textLabel: TextLabel? = nil
local currentPet: Model? = nil

-- ============ 유틸 ============

-- PrimaryPart만 사용 (모든 펫 모델은 PrimaryPart 지정 전제)
local function getPrimaryPart(inst: Instance?): BasePart?
	if not inst then return nil end
	if inst:IsA("Model") then
		return inst.PrimaryPart
	elseif inst:IsA("BasePart") then
		return inst
	end
	return nil
end



-- 내 소유 펫(OwnerUserId == LocalPlayer.UserId) 중 가장 가까운 것
local function findPlayersPetInWorkspace(): Model?
	local myId = LocalPlayer.UserId
	local best: Model? = nil
	local bestDist = math.huge
	local char = LocalPlayer.Character
	local charPos = char and char.PrimaryPart and char.PrimaryPart.Position

	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("Model") and inst:GetAttribute("OwnerUserId") == myId then
			-- 거리 기준 선택(캐릭터 없으면 첫 번째 반환)
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

-- 펫 + 펫 하위 BillboardGui('petGui') + 그 안의 TextLabel 해석
local function resolvePetAndBillboard()
	currentPet = findPlayersPetInWorkspace()
	bubble, textLabel = nil, nil
	if not currentPet then return end

	-- 서버가 스폰 시 pet 하위에 클론한 BillboardGui
	local gui = currentPet:FindFirstChild(PET_GUI_NAME, true)
	if gui and gui:IsA("BillboardGui") then
		bubble = gui
		-- TextLabel 이름이 다를 수 있으니 하위에서 첫 TextLabel을 탐색
		textLabel = bubble:FindFirstChild("TextLabel") :: TextLabel
		if not textLabel then
			textLabel = bubble:FindFirstChildWhichIsA("TextLabel", true)
		end
	end
end

-- 스폰 타이밍 대비 간단 재시도(한 번 defer)
local function ensureResolvedSoon()
	if bubble and textLabel and currentPet then return end
	resolvePetAndBillboard()
	if not (bubble and textLabel) then
		task.defer(function()
			resolvePetAndBillboard()
		end)
	end
end



-- ============ 좌측 HUD(2D) ============


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


-- ======= [추가] 퀘스트 마커 유틸 =======
local QuestMarkers = {}  -- [Instance] = BillboardGui

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
	-- 모델 높이만큼 위에 띄우기 (대략값, 필요시 조정)
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
	tl.TextColor3 = Color3.fromRGB(255, 224, 79) -- 노란색
	-- 외곽선(가독성)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(0,0,0)
	stroke.Transparency = 0.15
	stroke.Parent = tl

	-- 둥근 배경(선택)
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



-- ============ 서버 → 클라 이벤트 ============

PetQuestEvent.OnClientEvent:Connect(function(action, data)
	if action == "StartQuest" then
		local phrase = (data and data.phrase) or ""

		-- 1) 좌측 HUD 갱신/표시
		local _, _, label = getOrCreateHud()
		label.Text = phrase

		-- 2) 펫 Billboard 갱신 (서버가 만든 'petGui' 사용)
		ensureResolvedSoon()
		if textLabel then
			textLabel.Text = phrase
		end
		if bubble then
			bubble.Enabled = true -- GUI 자체는 항상 유지, 문구만 바꿔도 OK
		end

	elseif action == "CompleteQuest" then
		-- (선택) 클리어 이펙트
		local ok, ClearModule = pcall(function()
			return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ClearModule"))
		end)
		if ok and ClearModule and ClearModule.showClearEffect then
			pcall(function() ClearModule.showClearEffect(LocalPlayer) end)
		end

		-- 좌측 HUD 제거
		clearHud()

		-- 펫 Billboard는 유지 + 텍스트만 비우기
		if textLabel then
			textLabel.Text = ""
		end
		-- bubble.Enabled 는 유지(끄지 않음)
	end
	
	if action == "ShowQuestMarker" then
		local target = data and data.target
		if target then
			showMarkerOn(target)
		end

	elseif action == "HideQuestMarker" then
		local target = data and data.target
		if target then
			hideMarkerOn(target)
		end
	end
end)


-- ================= StreetFood 근접/말풍선 섹션 =================
local ProximityPromptService = game:GetService("ProximityPromptService")
local StreetFoodFolder = workspace:WaitForChild("World"):WaitForChild("dogItems"):WaitForChild("street Food")
local ProxRelay = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("StreetFoodProxRelay")
local StreetFoodEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("StreetFoodEvent")

-- 근접(보임/숨김) 서버 릴레이
ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	if prompt and prompt:IsDescendantOf(StreetFoodFolder) and prompt.Name == "StreetFoodPrompt" then
		ProxRelay:FireServer("enter", prompt)
	end
end)
ProximityPromptService.PromptHidden:Connect(function(prompt)
	if prompt and prompt:IsDescendantOf(StreetFoodFolder) and prompt.Name == "StreetFoodPrompt" then
		ProxRelay:FireServer("exit", prompt)
	end
end)


-- 서버 → 클라: 말풍선 텍스트 갱신
StreetFoodEvent.OnClientEvent:Connect(function(action, data)
	if action == "Bubble" then
		ensureResolvedSoon()
		local txt = (data and data.text) or ""
		if textLabel then textLabel.Text = txt end
		if bubble then bubble.Enabled = (txt ~= nil) end

	elseif action == "ClearEffect" then
		-- ✅ ClearModule 실행 (로컬 전용)
		local ok, ClearModule = pcall(function()
			return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ClearModule"))
		end)
		if ok and ClearModule and ClearModule.showClearEffect then
			pcall(function()
				ClearModule.showClearEffect(LocalPlayer)
			end)
		end
	end
end)


-- 런타임에 내 펫/펫GUI가 생기면 포인터 갱신
Workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("Model") and inst:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
		task.defer(resolvePetAndBillboard)
	elseif inst:IsA("BillboardGui") and inst.Name == PET_GUI_NAME then
		-- 내 펫 하위의 gui인지 확인해서 연결
		local p = inst:FindFirstAncestorOfClass("Model")
		if p and p:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
			task.defer(resolvePetAndBillboard)
		end
	end
end)

-- 재접속/리스폰 대비
LocalPlayer.CharacterAdded:Connect(function()
	task.defer(resolvePetAndBillboard)
end)
task.defer(resolvePetAndBillboard)
