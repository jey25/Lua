-- ServerScriptService/PetManager.server.lua
--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Assets / Folders
local petModels = ReplicatedStorage:WaitForChild("Pets")
local SFXFolder = ReplicatedStorage:WaitForChild("SFX")

-- Shared Remotes
local RemoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder", ReplicatedStorage)
RemoteEvents.Name = "RemoteEvents"

local PetEvents = ReplicatedStorage:FindFirstChild("PetEvents")
if not PetEvents then
	PetEvents = Instance.new("Folder")
	PetEvents.Name = "PetEvents"
	PetEvents.Parent = ReplicatedStorage
end

local PetQuestEvent = RemoteEvents:FindFirstChild("PetQuestEvent") or Instance.new("RemoteEvent", RemoteEvents)
PetQuestEvent.Name = "PetQuestEvent"

local TrySelectEpicPet = PetEvents:FindFirstChild("TrySelectEpicPet") or Instance.new("RemoteFunction", PetEvents)
TrySelectEpicPet.Name = "TrySelectEpicPet"

local PetSfxEvent = PetEvents:FindFirstChild("PetSfx") or Instance.new("RemoteEvent", PetEvents)
PetSfxEvent.Name = "PetSfx"

local ShowPetGuiEvent = PetEvents:FindFirstChild("ShowPetGui") or Instance.new("RemoteEvent", PetEvents)
ShowPetGuiEvent.Name = "ShowPetGui"

local PetSelectedEvent = PetEvents:FindFirstChild("PetSelected") or Instance.new("RemoteEvent", PetEvents)
PetSelectedEvent.Name = "PetSelected"

local ShowArrowEvent = PetEvents:FindFirstChild("ShowArrow") or Instance.new("RemoteEvent", PetEvents)
ShowArrowEvent.Name = "ShowArrow"

-- Requires
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CoinService = require(script.Parent:WaitForChild("CoinService"))

-- Constants
local PET_GUI_NAME = "petGui"  -- ReplicatedStorage 내 GUI 이름(펫 머리 위 등)
local petGuiTemplate: Instance = ReplicatedStorage:WaitForChild(PET_GUI_NAME)
-- ▼▼ 추가: 펫이 살짝 더 낮아지도록 전역 기본값(음수면 아래로)
local PET_GROUND_NUDGE_Y = -0.7   -- 추천 범위: -0.3 ~ -1.2 (모델에 따라 조절)

local COLS = 2
local X_OFFSET = 2.5
local Y_OFFSET = -1.5
local Z_START  = -2.5
local Z_STEP   = 1.8

-- 클라/서버 동일 요구 조건(레벨/코인)
local PET_LEVEL_REQ = { golden_dog=100, Skeleton_Dog=150, Robot_Dog=200 }
local PET_COIN_COST = { golden_dog=15,  Skeleton_Dog=20,  Robot_Dog=25  }

-- 런타임 보유 펫(세션용)
-- PlayerPets[userId] = { {pet=model, slot=1, attachName="CharAttach_<id>", offset=Vector3}, ... }
local PlayerPets: { [number]: { { pet: Model, slot: number, attachName: string, offset: Vector3 } } } = {}

-- Helpers -------------------------------------------------------

local function getFollowOffsetForSlot(slot: number): Vector3
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

local function ensurePrimaryPart(m: Model): BasePart?
	if m.PrimaryPart and m.PrimaryPart:IsA("BasePart") then return m.PrimaryPart end
	local cand = m:FindFirstChild("HumanoidRootPart")
		or m:FindFirstChildWhichIsA("MeshPart")
		or m:FindFirstChildWhichIsA("BasePart")
	if cand then m.PrimaryPart = cand end
	return cand
end

local function weldModelToPrimary(m: Model)
	local pp = ensurePrimaryPart(m)
	if not pp then return end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d ~= pp then
			d.Anchored = false
			for _, j in ipairs(d:GetJoints()) do
				if j:IsA("Weld") or j:IsA("WeldConstraint") then j:Destroy() end
			end
			local wc = Instance.new("WeldConstraint")
			wc.Part0 = pp
			wc.Part1 = d
			wc.Parent = pp
			d.CanCollide = false
			d.Massless = true
			d.CustomPhysicalProperties = PhysicalProperties.new(0.1, 0.3, 0.5)
		end
	end
	pp.Anchored = false
	pp.CanCollide = false
	pp.Massless = true
end

local function cleanupPetConstraints(m: Model)
	local pp = ensurePrimaryPart(m)
	if not pp then return end
	for _, obj in ipairs(pp:GetChildren()) do
		if obj:IsA("AlignPosition") or obj:IsA("AlignOrientation")
			or (obj:IsA("Attachment") and (obj.Name == "PetAttach")) then
			obj:Destroy()
		end
	end
end

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

local function addFollowConstraintWithOffset(pet: Model, character: Model, offset: Vector3, attachName: string)
	local petPP = ensurePrimaryPart(pet)
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not (petPP and hrp) then return end

	cleanupPetConstraints(pet)
	petPP:SetNetworkOwner(nil)

	local aPet = Instance.new("Attachment")
	aPet.Name = "PetAttach"
	aPet.Parent = petPP

	local yawOffsetDeg = pet:GetAttribute("YawOffsetDeg")
	if typeof(yawOffsetDeg) == "number" then
		aPet.Orientation = Vector3.new(0, yawOffsetDeg, 0)
	end

	local aChar = ensureCharAttach(character, attachName, offset)
	if not aChar then return end

	local ap = Instance.new("AlignPosition")
	ap.Attachment0 = aPet
	ap.Attachment1 = aChar
	ap.ApplyAtCenterOfMass = true
	ap.RigidityEnabled = false
	ap.MaxForce = 1e6
	ap.Responsiveness = 80
	ap.Parent = petPP

	local ao = Instance.new("AlignOrientation")
	ao.Attachment0 = aPet
	ao.Attachment1 = aChar
	ao.RigidityEnabled = false
	ao.MaxTorque = 1e6
	ao.Responsiveness = 60
	ao.Parent = petPP
end



-- 완전 교체용: ServerScriptService/PetManager.server.lua 내 spawnPet
local function spawnPet(player: Player, petName: string)
	local character = player.Character or player.CharacterAdded:Wait()
	local template = petModels:FindFirstChild(petName)
	if not template then
		warn("Pet model not found: " .. tostring(petName))
		return
	end

	-- 슬롯/기본 오프셋 계산 (기존 유지)
	local slot = nextSlot(player)
	local offset = getFollowOffsetForSlot(slot)

	-- ▼ 지면 밀착: 모델 Attribute > 전역 상수 > 기본값(-0.7) 우선순위
	local attrNudge = template:GetAttribute("GroundNudgeY")
	local globalNudge = (typeof(PET_GROUND_NUDGE_Y) == "number") and PET_GROUND_NUDGE_Y or nil
	local nudgeY = (typeof(attrNudge) == "number" and attrNudge)
		or (globalNudge)
		or -0.7
	offset = offset + Vector3.new(0, nudgeY, 0)

	local petId = HttpService:GenerateGUID(false)
	local attachName = "CharAttach_" .. petId

	local pet = template:Clone()
	pet.Name = petName
	pet:SetAttribute("OwnerUserId", player.UserId)
	pet:SetAttribute("PetId", petId)
	pet:SetAttribute("Slot", slot)

	-- 오프셋/부가정보 Attribute 저장 (재부착시 동일 높이 유지)
	pet:SetAttribute("OffsetX", offset.X)
	pet:SetAttribute("OffsetY", offset.Y)
	pet:SetAttribute("OffsetZ", offset.Z)
	pet:SetAttribute("AttachName", attachName)
	pet:SetAttribute("GroundNudgeY", nudgeY)

	pet.Parent = workspace

	-- 머리말풍선/HP바 등 GUI 템플릿 부착
	local petGui = petGuiTemplate:Clone()
	petGui.Parent = pet

	-- 모델을 PrimaryPart 기준으로 단단히 묶고 물리 설정
	weldModelToPrimary(pet)
	local pp = ensurePrimaryPart(pet)
	if not pp then
		warn("No PrimaryPart after weld for pet:", petName)
		pet:Destroy()
		return
	end
	pp.Anchored = false
	pp.CanCollide = false
	pp.Massless = true

	-- 최초 위치: 캐릭터 뒤/좌우 offset 위치
	local hrp = character:WaitForChild("HumanoidRootPart")
	pet:PivotTo(hrp.CFrame * CFrame.new(offset))

	-- 따라가기 제약(AlignPosition/Orientation) 생성 + 오프셋 반영
	addFollowConstraintWithOffset(pet, character, offset, attachName)

	-- 선택 SFX (있을 때만)
	local tpl = SFXFolder:FindFirstChild("Choice")
	if tpl and tpl:IsA("Sound") then
		PetSfxEvent:FireClient(player, "PlaySfxTemplate", tpl)
	end

	-- 세션 보유 리스트에 등록
	local list = getOrInitPetList(player)
	table.insert(list, { pet = pet, slot = slot, offset = offset, attachName = attachName })

	-- 캐릭터 리스폰 시 재부착(저장된 오프셋 그대로 사용)
	player.CharacterAdded:Connect(function(newChar)
		task.defer(function()
			if pet and pet.Parent then
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

	-- 펫별 퀘스트 시작 신호
	PetQuestEvent:FireClient(player, "StartQuest", { petName = petName, petId = petId })
end




-- UI 화살표(첫 퀘스트) -------------------------------------------------------

local function PathFromWorkspace(inst: Instance): string
	local parts = {}
	local cur = inst
	while cur and cur ~= workspace do
		table.insert(parts, 1, cur.Name)
		cur = cur.Parent
	end
	return table.concat(parts, "/")
end

local function FirstQuestGui(player: Player)
	local FirstQuestTemplate = ReplicatedStorage:FindFirstChild("FirstQuest")
	if not FirstQuestTemplate then return end

	local nextGui = FirstQuestTemplate:Clone()
	nextGui.Parent = player:WaitForChild("PlayerGui")

	task.delay(5, function()
		if nextGui then
			nextGui:Destroy()

			local doctorFolder = workspace:FindFirstChild("World")
			if doctorFolder then
				doctorFolder = doctorFolder:FindFirstChild("Building")
			end
			local petHospital = doctorFolder and doctorFolder:FindFirstChild("Pet Hospital")
			local doctor = petHospital and petHospital:FindFirstChild("Doctor")
			if not doctor then warn("Doctor NPC를 찾을 수 없습니다."); return end

			local targetPart = (doctor :: any).PrimaryPart
				or doctor:FindFirstChild("HumanoidRootPart")
				or doctor:FindFirstChild("Head")
				or doctor:FindFirstChildWhichIsA("BasePart", true)

			if not targetPart then
				warn("Doctor NPC에 사용할 파트를 찾지 못했습니다."); return
			end

			ShowArrowEvent:FireClient(player, {
				Target = targetPart,
				TargetPath = PathFromWorkspace(targetPart),
				HideDistance = 10
			})
		end
	end)
end

-- 구매/선택 흐름 -------------------------------------------------------

TrySelectEpicPet.OnServerInvoke = function(player: Player, payload)
	local petName = payload and payload.pet
	if type(petName) ~= "string" then return {ok=false, err="bad_pet"} end

	local template = petModels:FindFirstChild(petName)
	if not template then return {ok=false, err="no_model"} end

	local needLv = PET_LEVEL_REQ[petName] or math.huge
	local lv = tonumber(player:GetAttribute("Level")) or 1
	if lv < needLv then return {ok=false, err="low_level"} end

	local cost = PET_COIN_COST[petName] or 0
	if not CoinService:TrySpend(player, cost) then
		return {ok=false, err="no_coins", coins = CoinService:GetBalance(player)}
	end

	PlayerDataService:AddOwnedPet(player, petName)
	PlayerDataService:SetSelectedPet(player, petName)

	spawnPet(player, petName)

	return {ok=true, coins = CoinService:GetBalance(player)}
end

PetSelectedEvent.OnServerEvent:Connect(function(player: Player, petName: string)
	-- 최초 선택 시 저장
	PlayerDataService:AddOwnedPet(player, petName)
	PlayerDataService:SetSelectedPet(player, petName)

	spawnPet(player, petName)
	FirstQuestGui(player)
end)

-- 접속/퇴장 -------------------------------------------------------

Players.PlayerAdded:Connect(function(player)
	local data = PlayerDataService:Load(player)

	-- 코인/레벨/EXP는 각 서비스에서 별도 동기화
	-- 선택 펫이 있으면 팝업 미표시 + 바로 소환
	if data.selectedPetName and petModels:FindFirstChild(data.selectedPetName) then
		spawnPet(player, data.selectedPetName)
	else
		-- 최초 접속(선택 없음): 클라에 선택 GUI 띄우기
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
