-- ServerScriptService/PetManager.server.lua

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local petModels = ReplicatedStorage:WaitForChild("Pets")
local PetQuestEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("PetQuestEvent")
local RunService = game:GetService("RunService")

-- DataStore
local playerDataStore = DataStoreService:GetDataStore("PlayerPetSelection")

-- 🔊 SFX 템플릿 폴더
local SFXFolder = ReplicatedStorage:WaitForChild("SFX")


-- RemoteEvents
local PetEvents = ReplicatedStorage:FindFirstChild("PetEvents")
if not PetEvents then
	PetEvents = Instance.new("Folder")
	PetEvents.Name = "PetEvents"
	PetEvents.Parent = ReplicatedStorage
end

local PetSfxEvent = PetEvents:FindFirstChild("PetSfx")
if not PetSfxEvent then
	PetSfxEvent = Instance.new("RemoteEvent")
	PetSfxEvent.Name = "PetSfx"
	PetSfxEvent.Parent = PetEvents
end

local ShowPetGuiEvent = PetEvents:FindFirstChild("ShowPetGui")
if not ShowPetGuiEvent then
	ShowPetGuiEvent = Instance.new("RemoteEvent")
	ShowPetGuiEvent.Name = "ShowPetGui"
	ShowPetGuiEvent.Parent = PetEvents
end

local PetSelectedEvent = PetEvents:FindFirstChild("PetSelected")
if not PetSelectedEvent then
	PetSelectedEvent = Instance.new("RemoteEvent")
	PetSelectedEvent.Name = "PetSelected"
	PetSelectedEvent.Parent = PetEvents
end

local ShowArrowEvent = PetEvents:FindFirstChild("ShowArrow")
if not ShowArrowEvent then
	ShowArrowEvent = Instance.new("RemoteEvent")
	ShowArrowEvent.Name = "ShowArrow"
	ShowArrowEvent.Parent = PetEvents
end

-- Constants
local PET_GUI_NAME = "petGui"  -- ReplicatedStorage 내 PetGui 이름
local petGuiTemplate: Instance = ReplicatedStorage:WaitForChild(PET_GUI_NAME)
local petModels = ReplicatedStorage:WaitForChild("Pets")

-- Helper: PrimaryPart 보장
local function ensurePrimaryPart(m: Model): BasePart?
	if m.PrimaryPart and m.PrimaryPart:IsA("BasePart") then return m.PrimaryPart end
	local cand = m:FindFirstChild("HumanoidRootPart")
		or m:FindFirstChildWhichIsA("MeshPart")
		or m:FindFirstChildWhichIsA("BasePart")
	if cand then m.PrimaryPart = cand end
	return cand
end

-- Helper: 모델의 모든 파츠를 PrimaryPart에 용접
local function weldModelToPrimary(m: Model)
	local pp = ensurePrimaryPart(m)
	if not pp then return end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d ~= pp then
			-- 기존 조인트 정리
			d.Anchored = false
			for _, j in ipairs(d:GetJoints()) do
				if j:IsA("Weld") or j:IsA("WeldConstraint") then j:Destroy() end
			end
			-- 새 용접
			local wc = Instance.new("WeldConstraint")
			wc.Part0 = pp
			wc.Part1 = d
			wc.Parent = pp
			-- 충돌/질량 완화 (끌려다닐 때 걸리지 않게)
			d.CanCollide = false
			d.Massless = true
			d.CustomPhysicalProperties = PhysicalProperties.new(0.1, 0.3, 0.5)
		end
	end
	-- PP도 비앵커 + 충돌/질량 완화
	pp.Anchored = false
	pp.CanCollide = false
	pp.Massless = true
end

-- Helper: 펫 모델에 붙었던 이전 제약/어태치 정리(중복 방지)
local function cleanupPetConstraints(m: Model)
	local pp = ensurePrimaryPart(m)
	if not pp then return end
	for _, obj in ipairs(pp:GetChildren()) do
		if obj:IsA("AlignPosition") or obj:IsA("AlignOrientation")
			or obj:IsA("Attachment") and (obj.Name == "PetAttach") then
			obj:Destroy()
		end
	end
end


-- 서버 권위의 물리 제약으로 캐릭터 따라오기
local function addFollowConstraint(pet: Model, character: Model)
	local petPP = ensurePrimaryPart(pet)
	local charPP = character and character.PrimaryPart
	if not (petPP and charPP) then return end

	-- 중복 제거
	cleanupPetConstraints(pet)

	-- 서버가 네트워크 소유
	petPP:SetNetworkOwner(nil)

	-- 펫/캐릭터 어태치
	local aPet = Instance.new("Attachment"); aPet.Name = "PetAttach"; aPet.Parent = petPP
	local aChar = charPP:FindFirstChild("CharAttach") :: Attachment
	if not aChar then
		aChar = Instance.new("Attachment")
		aChar.Name = "CharAttach"
		aChar.Parent = charPP
	end

	-- 캐릭터 기준 위치(오른쪽·뒤쪽·약간 아래)
	aChar.Position = Vector3.new(2.5, -1.5, -2.5)

	-- ★ 방향 보정 (펫 앞이 뒤를 보고 있으면 180, 옆을 보고 있으면 ±90)
	-- 템플릿/펫 모델에 Attribute로 Yaw 오프셋을 지정할 수 있게 함(없으면 180 기본)
	local yawOffsetDeg = pet:GetAttribute("YawOffsetDeg")
	if typeof(yawOffsetDeg) ~= "number" then
		yawOffsetDeg = 0 -- 펫의 머리 방향 조절, 필요 시 0, 90, -90 등으로 조정
	end
	aPet.Orientation = Vector3.new(0, yawOffsetDeg, 0)

	-- 위치 제약(부드럽게)
	local ap = Instance.new("AlignPosition")
	ap.Attachment0 = aPet
	ap.Attachment1 = aChar
	ap.ApplyAtCenterOfMass = true
	ap.RigidityEnabled = false
	ap.MaxForce = 1e6
	ap.Responsiveness = 80
	ap.Parent = petPP

	-- 방향 제약(캐릭터와 같은 방향을 보게 함 + 위의 yaw 오프셋 반영)
	local ao = Instance.new("AlignOrientation")
	ao.Attachment0 = aPet
	ao.Attachment1 = aChar
	ao.RigidityEnabled = false
	ao.MaxTorque = 1e6
	ao.Responsiveness = 60
	ao.Parent = petPP
end


local function spawnPet(player: Player, petName: string)
	local character = player.Character or player.CharacterAdded:Wait()
	local template = petModels:FindFirstChild(petName)
	if not template then
		warn("Pet model not found: " .. tostring(petName))
		return
	end

	local pet = template:Clone()
	pet.Name = petName
	pet:SetAttribute("OwnerUserId", player.UserId)
	pet.Parent = workspace
	
	-- GUI 생성
	local petGui = petGuiTemplate:Clone()
	petGui.Parent = pet

	-- PrimaryPart/Weld/Unanchor/충돌 완화
	weldModelToPrimary(pet)
	local pp = ensurePrimaryPart(pet)
	if not pp then
		warn("No PrimaryPart after weld for pet:", petName)
		return
	end

	-- 초기 위치(캐릭 오른쪽/뒤쪽)
	local root = character:WaitForChild("HumanoidRootPart")
	local startCFrame = root.CFrame * CFrame.new(2.5, -1.5, -2.5)
	pet:PivotTo(startCFrame)

	-- 따라오기 제약
	addFollowConstraint(pet, character)
	
	-- 🔊 스폰 사운드 (그 플레이어에게만)
	local tpl = SFXFolder:FindFirstChild("Choice")
	if tpl and tpl:IsA("Sound") then
		PetSfxEvent:FireClient(player, "PlaySfxTemplate", tpl)
	end

	-- 캐릭터 리스폰 시에도 재부착 (HRP 교체되므로)
	local conn
	conn = player.CharacterAdded:Connect(function(newChar)
		task.defer(function()
			if pet and pet.Parent then
				addFollowConstraint(pet, newChar)
			end
		end)
	end)

	-- 첫 퀘스트 시작 신호(필요 시)
	PetQuestEvent:FireClient(player, "StartQuest", { petName = petName })
end



-- 서버 util: workspace 기준 경로 문자열 생성
local function PathFromWorkspace(inst: Instance): string
	local parts = {}
	local cur = inst
	while cur and cur ~= workspace do
		table.insert(parts, 1, cur.Name)
		cur = cur.Parent
	end
	return table.concat(parts, "/") -- 예: "World/Building/Pet Hospital/Doctor/Head"
end

-- 첫 퀘스트 GUI 실행
local function FirstQuestGui(player)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ShowArrowEvent = ReplicatedStorage.PetEvents.ShowArrow

	local FirstQuestTemplate = ReplicatedStorage:WaitForChild("FirstQuest")
	if not FirstQuestTemplate then return end

	local nextGui = FirstQuestTemplate:Clone()
	nextGui.Parent = player:WaitForChild("PlayerGui")

	task.delay(5, function()
		if nextGui then
			nextGui:Destroy()

			local doctor = workspace.World.Building:FindFirstChild("Pet Hospital"):FindFirstChild("Doctor")
			if not doctor then warn("Doctor NPC를 찾을 수 없습니다."); return end

			local targetPart = doctor.PrimaryPart
				or doctor:FindFirstChild("HumanoidRootPart")
				or doctor:FindFirstChild("Head")
				or doctor:FindFirstChildWhichIsA("BasePart", true)

			if not targetPart then
				warn("Doctor NPC에 사용할 파트를 찾지 못했습니다."); return
			end

			ShowArrowEvent:FireClient(player, {
				Target = targetPart,                         -- 인스턴스 (스트리밍 되면 즉시 사용)
				TargetPath = PathFromWorkspace(targetPart),  -- 경로 스트링 (스트리밍 미완 시 복구용)
				HideDistance = 10
			})
		end
	end)
end



-- Pet 선택 완료 이벤트
PetSelectedEvent.OnServerEvent:Connect(function(player, petName)
	-- 데이터 저장
	local success, err = pcall(function()
		playerDataStore:SetAsync(player.UserId, true)
	end)
	if not success then warn("DataStore save error:", err) end

	-- 펫 스폰
	spawnPet(player, petName)

	-- 첫 퀘스트 GUI 실행
	FirstQuestGui(player)
end)

-- Player 처음 접속 시
Players.PlayerAdded:Connect(function(player)
	local success, hasPet = pcall(function()
		return playerDataStore:GetAsync(player.UserId)
	end)

	if not success or not hasPet then
		-- 클라에게 GUI 열라는 신호 전송
		ShowPetGuiEvent:FireClient(player)
	end
end)
