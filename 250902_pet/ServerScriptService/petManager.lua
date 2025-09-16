-- ServerScriptService/PetManager.server.lua

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")
local petModels = ReplicatedStorage:WaitForChild("Pets")
local PetQuestEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("PetQuestEvent")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local playerDataStore = DataStoreService:GetDataStore("PlayerPetSelection")
local SFXFolder = ReplicatedStorage:WaitForChild("SFX")
local CoinService = require(game.ServerScriptService:WaitForChild("CoinService"))

-- Constants
local PET_GUI_NAME = "petGui"  -- ReplicatedStorage 내 PetGui 이름
local petGuiTemplate: Instance = ReplicatedStorage:WaitForChild(PET_GUI_NAME)
local petModels = ReplicatedStorage:WaitForChild("Pets")

-- 플레이어별 보유 펫 상태
-- PlayerPets[userId] = { {pet=model, slot=1, attachName="CharAttach_<id>", offset=Vector3}, ... }
local PlayerPets = {}

-- 팔로우 배치 파라미터
local COLS = 2                       -- 2열 (오른쪽/왼쪽)
local X_OFFSET = 2.5                 -- 좌우 거리
local Y_OFFSET = -1.5                -- 살짝 아래
local Z_START  = -2.5                -- 첫 행의 뒤쪽 거리
local Z_STEP   = 1.8                 -- 행이 늘어날 때 추가로 뒤로 떨어지는 간격


-- 클라/서버 동일 테이블(레벨/코인)
local PET_LEVEL_REQ = { golden_dog=100, Skeleton_Dog=150, Robot_Dog=200 }
local PET_COIN_COST = { golden_dog=15,  Skeleton_Dog=20,  Robot_Dog=25  }

-- RemoteEvents
local PetEvents = ReplicatedStorage:FindFirstChild("PetEvents")
if not PetEvents then
	PetEvents = Instance.new("Folder")
	PetEvents.Name = "PetEvents"
	PetEvents.Parent = ReplicatedStorage
end

local TrySelectEpicPet = PetEvents:FindFirstChild("TrySelectEpicPet")
if not TrySelectEpicPet then
	TrySelectEpicPet = Instance.new("RemoteFunction")
	TrySelectEpicPet.Name = "TrySelectEpicPet"
	TrySelectEpicPet.Parent = PetEvents
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


-- 슬롯(1,2,3,...) → 캐릭터 기준 오프셋 계산
local function getFollowOffsetForSlot(slot: number): Vector3
	-- slot 1 → ( +X, Y, Z_START ), slot 2 → ( -X, Y, Z_START )
	-- slot 3 → ( +X, Y, Z_START - Z_STEP ), slot 4 → ( -X, Y, Z_START - Z_STEP ), ...
	local index = math.max(1, math.floor(slot))
	local row = math.floor((index - 1) / COLS)
	local col = (index - 1) % COLS
	local x = (col == 0) and X_OFFSET or -X_OFFSET
	local y = Y_OFFSET
	local z = Z_START - (row * Z_STEP)
	return Vector3.new(x, y, z)
end

local function getOrInitPetList(player: Player)
	local list = PlayerPets[player.UserId]
	if not list then
		list = {}
		PlayerPets[player.UserId] = list
	end
	return list
end

local function nextSlot(player: Player): number
	local list = getOrInitPetList(player)
	return #list + 1
end


-- Helper: PrimaryPart 보장
local function ensurePrimaryPart(m: Model): BasePart?
	if m.PrimaryPart and m.PrimaryPart:IsA("BasePart") then return m.PrimaryPart end
	local cand = m:FindFirstChild("HumanoidRootPart")
		or m:FindFirstChildWhichIsA("MeshPart")
		or m:FindFirstChildWhichIsA("BasePart")
	if cand then m.PrimaryPart = cand end
	return cand
end



-- 캐릭터 HRP에 고유 어태치 생성/복구
local function ensureCharAttach(character: Model, attachName: string, offset: Vector3): Attachment?
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not hrp then return nil end
	local aChar = hrp:FindFirstChild(attachName) :: Attachment
	if not aChar then
		aChar = Instance.new("Attachment")
		aChar.Name = attachName
		aChar.Parent = hrp
	end
	aChar.Position = offset
	return aChar
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


-- 서버 권위 팔로우 제약(펫별로 개별 Attachment 사용)
local function addFollowConstraintWithOffset(pet: Model, character: Model, offset: Vector3, attachName: string)
	local petPP = ensurePrimaryPart(pet)
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not (petPP and hrp) then return end

	cleanupPetConstraints(pet)
	petPP:SetNetworkOwner(nil)

	-- 펫쪽 Attach
	local aPet = Instance.new("Attachment")
	aPet.Name = "PetAttach"
	aPet.Parent = petPP
	-- 필요 시 Yaw 보정(모델 Attribute)
	local yawOffsetDeg = pet:GetAttribute("YawOffsetDeg")
	if typeof(yawOffsetDeg) == "number" then
		aPet.Orientation = Vector3.new(0, yawOffsetDeg, 0)
	end

	-- 캐릭터쪽 Attach(고유 이름)
	local aChar = ensureCharAttach(character, attachName, offset)
	if not aChar then return end

	-- AlignPosition
	local ap = Instance.new("AlignPosition")
	ap.Attachment0 = aPet
	ap.Attachment1 = aChar
	ap.ApplyAtCenterOfMass = true
	ap.RigidityEnabled = false
	ap.MaxForce = 1e6
	ap.Responsiveness = 80
	ap.Parent = petPP

	-- AlignOrientation
	local ao = Instance.new("AlignOrientation")
	ao.Attachment0 = aPet
	ao.Attachment1 = aChar
	ao.RigidityEnabled = false
	ao.MaxTorque = 1e6
	ao.Responsiveness = 60
	ao.Parent = petPP
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

	-- 슬롯 계산 + 오프셋
	local slot = nextSlot(player)
	local offset = getFollowOffsetForSlot(slot)

	-- 고유 ID/어태치 이름
	local petId = HttpService:GenerateGUID(false)
	local attachName = "CharAttach_" .. petId

	-- 모델 클론(내장 스크립트/퀘스트 그대로 복제)
	local pet = template:Clone()
	pet.Name = petName
	pet:SetAttribute("OwnerUserId", player.UserId)
	pet:SetAttribute("PetId", petId)
	pet:SetAttribute("Slot", slot)
	pet:SetAttribute("OffsetX", offset.X)
	pet:SetAttribute("OffsetY", offset.Y)
	pet:SetAttribute("OffsetZ", offset.Z)
	pet:SetAttribute("AttachName", attachName)
	pet.Parent = workspace

	-- GUI/물리 준비
	local petGui = petGuiTemplate:Clone()
	petGui.Parent = pet
	weldModelToPrimary(pet)
	local pp = ensurePrimaryPart(pet)
	if not pp then
		warn("No PrimaryPart after weld for pet:", petName)
		pet:Destroy()
		return
	end
	pp.Anchored = false; pp.CanCollide = false; pp.Massless = true

	-- 초기 피벗(오프셋대로 HRP 기준)
	local hrp = character:WaitForChild("HumanoidRootPart")
	pet:PivotTo(hrp.CFrame * CFrame.new(offset))

	-- 팔로우 제약(개별 어태치)
	addFollowConstraintWithOffset(pet, character, offset, attachName)

	-- SFX(선택)
	local tpl = SFXFolder:FindFirstChild("Choice")
	if tpl and tpl:IsA("Sound") then
		PetSfxEvent:FireClient(player, "PlaySfxTemplate", tpl)
	end

	-- 플레이어 보유 목록에 등록
	local list = getOrInitPetList(player)
	table.insert(list, { pet = pet, slot = slot, offset = offset, attachName = attachName })

	-- 캐릭터 리스폰 시 재부착
	player.CharacterAdded:Connect(function(newChar)
		task.defer(function()
			if pet and pet.Parent then
				-- 새 HRP에 어태치 복구
				local off = Vector3.new(
					pet:GetAttribute("OffsetX") or offset.X,
					pet:GetAttribute("OffsetY") or offset.Y,
					pet:GetAttribute("OffsetZ") or offset.Z
				)
				local an = pet:GetAttribute("AttachName") or attachName
				addFollowConstraintWithOffset(pet, newChar, off, an)
			end
		end)
	end)

	-- 각 펫의 퀘스트 시작 신호(독립적으로)
	PetQuestEvent:FireClient(player, "StartQuest", { petName = petName, petId = petId })
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


TrySelectEpicPet.OnServerInvoke = function(player, payload)
	local petName = payload and payload.pet
	if type(petName) ~= "string" then return {ok=false, err="bad_pet"} end

	-- 모델 존재 확인(이름은 GUI와 동일)
	local template = ReplicatedStorage:WaitForChild("Pets"):FindFirstChild(petName)
	if not template then return {ok=false, err="no_model"} end

	-- 레벨 검사
	local needLv = PET_LEVEL_REQ[petName] or math.huge
	local lv = tonumber(player:GetAttribute("Level")) or 1
	if lv < needLv then return {ok=false, err="low_level"} end

	-- 코인 차감
	local cost = PET_COIN_COST[petName] or 0   -- ⚠️ 클라가 보낸 cost는 절대 신뢰 X
	if not CoinService:TrySpend(player, cost) then
		return {ok=false, err="no_coins", coins = CoinService:GetBalance(player)}
	end

	-- 스폰(여러 마리 지원하는 spawnPet 사용)
	spawnPet(player, petName)

	-- 최신 잔액 반환(클라가 즉시 UI 갱신)
	return {ok=true, coins = CoinService:GetBalance(player)}
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


Players.PlayerRemoving:Connect(function(plr)
	local list = PlayerPets[plr.UserId]
	if list then
		for _, info in ipairs(list) do
			if info.pet and info.pet.Parent then
				info.pet:Destroy()
			end
		end
	end
	PlayerPets[plr.UserId] = nil
end)

