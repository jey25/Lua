-- ServerScriptService/PetManager.server.lua
--!strict

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local petModels = ReplicatedStorage:WaitForChild("Pets")
local SFXFolder = ReplicatedStorage:WaitForChild("SFX")

-- PetManager.server.lua 맨 위 유틸/상수 근처에 추가
local _lastPetSelectAt: {[number]: number} = {}

-- Requires
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local CoinService = require(script.Parent:WaitForChild("CoinService"))
local BadgeManager = require(script.Parent:WaitForChild("BadgeManager"))  -- ✅ 배지 체크용

-- 플레이어/펫 충돌 방지
local PhysicsService = game:GetService("PhysicsService")

local function ensureCollisionGroups()
	local function safeCreate(name: string)
		pcall(function() PhysicsService:CreateCollisionGroup(name) end)
	end
	safeCreate("Players")
	safeCreate("Pets")

	PhysicsService:CollisionGroupSetCollidable("Players", "Pets", false)
	PhysicsService:CollisionGroupSetCollidable("Pets",   "Pets", false)
end
ensureCollisionGroups()

local function setCollisionGroupRecursive(inst: Instance, groupName: string)
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			PhysicsService:SetPartCollisionGroup(d, groupName)
		end
	end
end

-- Shared Remotes
local RemoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder", ReplicatedStorage)
RemoteEvents.Name = "RemoteEvents"

local PetEvents = ReplicatedStorage:FindFirstChild("PetEvents")
if not PetEvents then
	PetEvents = Instance.new("Folder")
	PetEvents.Name = "PetEvents"
	PetEvents.Parent = ReplicatedStorage
end

local PetQuestEvent  = RemoteEvents:FindFirstChild("PetQuestEvent") or Instance.new("RemoteEvent", RemoteEvents)
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

-- Constants
local PET_GUI_NAME = "petGui"
local petGuiTemplate: Instance = ReplicatedStorage:WaitForChild(PET_GUI_NAME)

-- ❗ 바닥 보정 제거: 단순히 전역(또는 모델 속성) nudge만 적용해서 약간 떠 있게 유지
--   모델 개별 미세 조정이 필요하면 각 펫 모델에 Attribute "GroundNudgeY" 로 덮어써라.
local PET_GROUND_NUDGE_Y = -0.4  -- 음수면 캐릭터 기준 아래쪽(약간 더 낮춘 느낌)

local SIDE_DIST   = 3.2
local BACK_DIST   = 3.6
local FRONT_DIST  = 3.6
local SLIGHT_X    = 1.2
local Y_OFFSET    = -1.5

-- ✅ Demon_Dog 상수(이름/요구조건)
local DEMON_NAME       = "Demon_Dog"
local DEMON_LEVEL_REQ  = 250
local DEMON_COIN_COST  = 30

local PET_LEVEL_REQ = { golden_dog=100, Skeleton_Dog=150, Robot_Dog=200, [DEMON_NAME]=DEMON_LEVEL_REQ }  -- ✅
local PET_COIN_COST = { golden_dog=15,  Skeleton_Dog=20,  Robot_Dog=25,  [DEMON_NAME]=DEMON_COIN_COST }  -- ✅

local ACTIVE_MAX = 5

-- 런타임 보유 목록
type PetInfo = { pet: Model, slot: number, attachName: string, offset: Vector3 }
local PlayerPets: { [number]: { PetInfo } } = {}

-- Helpers -------------------------------------------------------

local function getFollowOffsetForSlot(slot: number): Vector3
	local s = math.max(1, math.floor(slot))
	local y = Y_OFFSET

	if s == 1 then
		return Vector3.new( SIDE_DIST, y,  0)
	elseif s == 2 then
		return Vector3.new(-SIDE_DIST, y,  0)
	elseif s == 3 then
		return Vector3.new( SLIGHT_X, y,  BACK_DIST)
	elseif s == 4 then
		return Vector3.new(-SLIGHT_X, y,  BACK_DIST)
	elseif s == 5 then
		return Vector3.new(0, y, -FRONT_DIST)
	end

	local ringIndex = s - 5
	local ring = 1 + math.floor((ringIndex-1)/3)
	local posInTriad = ((ringIndex-1) % 3) + 1

	local radiusZBack  = BACK_DIST  + (ring-1) * 1.0
	local radiusXSide  = SLIGHT_X   + (ring-1) * 0.6
	local radiusZFront = FRONT_DIST + (ring-1) * 1.0

	if posInTriad == 1 then
		return Vector3.new( radiusXSide, y,  radiusZBack)
	elseif posInTriad == 2 then
		return Vector3.new(-radiusXSide, y,  radiusZBack)
	else
		return Vector3.new(0, y, -radiusZFront)
	end
end

local function getOrInitPetList(player: Player)
	local list = PlayerPets[player.UserId]
	if not list then
		list = {}
		PlayerPets[player.UserId] = list
	end
	return list
end

local function alreadySpawned(player: Player, petName: string): boolean
	for _, info in ipairs(getOrInitPetList(player)) do
		if info.pet and info.pet.Parent and info.pet.Name == petName then
			return true
		end
	end
	return false
end

local function nextSlot(player: Player): number
	return #getOrInitPetList(player) + 1
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

-- ▼ 모델의 PrimaryPart 기준 '가장 낮은 지점'을 찾아
--   발바닥이 지면 위로 desiredClearance 만큼 떠 있게 만드는 보정값(양수)을 계산
local function computeLiftFromPrimary(m: Model, desiredClearance: number?): number
	local pp = ensurePrimaryPart(m)
	if not pp then return 0 end
	local clearance = (typeof(desiredClearance) == "number") and desiredClearance or 0.2

	-- PrimaryPart 좌표계에서 각 파트의 최저 Y를 구함
	local lowestLocalY = 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			local localPos = pp.CFrame:PointToObjectSpace(d.Position)
			local partLowest = localPos.Y - (d.Size.Y * 0.5)
			if partLowest < lowestLocalY then
				lowestLocalY = partLowest
			end
		end
	end

	-- lowestLocalY 가 음수면 PrimaryPart 아래로 그만큼 파츠가 내려와 있다는 뜻
	-- 그 값을 뒤집어(+clearance)만큼 올려주면 발이 바닥 위로 올라옴
	return (-lowestLocalY) + clearance
end

local function uniqAppend(list: {string}, name: string)
	for _, v in ipairs(list) do if v == name then return end end
	table.insert(list, name)
end

local function trimToCap(list: {string}, cap: number)
	while #list > cap do table.remove(list, 1) end
end

local function getActivePetsFromData(player: Player, data): {string}
	if data and typeof(data.activePets) == "table" then
		return table.clone(data.activePets)
	end

	if PlayerDataService.GetActivePets then
		local ok, ap = pcall(function() return PlayerDataService:GetActivePets(player) end)
		if ok and typeof(ap) == "table" then
			return table.clone(ap)
		end
	end

	local res = {}
	if data and data.selectedPetName then
		uniqAppend(res, data.selectedPetName)
	end

	local ownedNames = {}
	if data and type(data.ownedPets) == "table" then
		for name, _ in pairs(data.ownedPets) do
			table.insert(ownedNames, name)
		end
	elseif PlayerDataService.GetOwnedPetNames then
		local ok, arr = pcall(function() return PlayerDataService:GetOwnedPetNames(player) end)
		if ok and type(arr) == "table" then
			ownedNames = arr
		end
	end

	for _, name in ipairs(ownedNames) do
		if #res >= ACTIVE_MAX then break end
		if not (data and name == data.selectedPetName) then
			uniqAppend(res, name)
		end
	end

	trimToCap(res, ACTIVE_MAX)
	return res
end

local function setActivePets(player: Player, names: {string})
	trimToCap(names, ACTIVE_MAX)
	if PlayerDataService.SetActivePets then
		pcall(function() PlayerDataService:SetActivePets(player, names) end)
	end
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
	ap.Enabled = false
	ap.Parent = petPP

	local ao = Instance.new("AlignOrientation")
	ao.Attachment0 = aPet
	ao.Attachment1 = aChar
	ao.RigidityEnabled = false
	ao.MaxTorque = 1e6
	ao.Responsiveness = 60
	ao.Enabled = false
	ao.Parent = petPP

	pet:PivotTo(hrp.CFrame * CFrame.new(offset))

	ap.Enabled = true
	ao.Enabled = true
end

-- 🔙 바닥 보정 제거: 간단한 nudge만
local function spawnPet(player: Player, petName: string)
	if alreadySpawned(player, petName) then return end

	local character = player.Character or player.CharacterAdded:Wait()
	local template = petModels:FindFirstChild(petName)
	if not template then
		warn("Pet model not found: " .. tostring(petName))
		return
	end

	local slot   = nextSlot(player)
	local offset = getFollowOffsetForSlot(slot)

	local attrNudge = template:GetAttribute("GroundNudgeY")
	local nudgeY = (typeof(attrNudge) == "number" and attrNudge)
		or (typeof(PET_GROUND_NUDGE_Y) == "number" and PET_GROUND_NUDGE_Y)
		or -0.4

	local pet = template:Clone()
	pet.Name = petName

	local petId = HttpService:GenerateGUID(false)
	local attachName = "CharAttach_" .. petId

	pet:SetAttribute("OwnerUserId", player.UserId)
	pet:SetAttribute("PetId", petId)
	pet:SetAttribute("Slot", slot)
	pet:SetAttribute("OffsetX", offset.X)
	pet:SetAttribute("OffsetY", offset.Y)
	pet:SetAttribute("OffsetZ", offset.Z)
	pet:SetAttribute("AttachName", attachName)
	pet:SetAttribute("GroundNudgeY", nudgeY)

	-- ✅ 모델 기하를 보고 자동 상승치 계산 (발이 박히지 않도록)
	local autoLift = computeLiftFromPrimary(pet, 0.2)
	offset = offset + Vector3.new(0, nudgeY + autoLift, 0)

	pet.Parent = workspace

	setCollisionGroupRecursive(pet, "Pets")

	local petGui = petGuiTemplate:Clone()
	petGui.Parent = pet

	weldModelToPrimary(pet)
	local pp = ensurePrimaryPart(pet)
	if not pp then
		warn("No PrimaryPart for pet: " .. petName)
		pet:Destroy()
		return
	end
	pp.Anchored = false
	pp.CanCollide = false
	pp.Massless = true

	local hrp = character:WaitForChild("HumanoidRootPart")
	pet:PivotTo(hrp.CFrame * CFrame.new(offset))

	addFollowConstraintWithOffset(pet, character, offset, attachName)

	local list = getOrInitPetList(player)
	table.insert(list, { pet = pet, slot = slot, offset = offset, attachName = attachName })

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

	-- ✅ 서버 가드: 이미 보유한 펫은 재구매 불가
	if PlayerDataService.HasOwnedPet and PlayerDataService:HasOwnedPet(player, petName) then
		return {ok=false, err="already_owned", coins = CoinService:GetBalance(player)}
	end

	local template = petModels:FindFirstChild(petName)
	if not template then return {ok=false, err="no_model"} end

	-- ✅ Demon_Dog 전용 배지 게이트
	if petName == DEMON_NAME then
		local hasGT = false
		local okCheck, _ = pcall(function()
			hasGT = BadgeManager.HasRobloxBadge(player, BadgeManager.Keys.GreatTeam)
		end)
		if not okCheck then hasGT = false end
		if not hasGT then
			return {ok=false, err="no_badge", coins = CoinService:GetBalance(player)}
		end
	end

	-- 레벨/코인 검증
	local needLv = PET_LEVEL_REQ[petName] or math.huge
	local lv = tonumber(player:GetAttribute("Level")) or 1
	if lv < needLv then return {ok=false, err="low_level"} end

	local cost = PET_COIN_COST[petName] or 0
	if cost > 0 then
		if not CoinService:TrySpend(player, cost) then
			return {ok=false, err="no_coins", coins = CoinService:GetBalance(player)}
		end
	end

	-- 소유/선택/스폰
	PlayerDataService:AddOwnedPet(player, petName)
	PlayerDataService:SetSelectedPet(player, petName)
	spawnPet(player, petName)

	local dataNow = PlayerDataService:Load(player)
	local active = getActivePetsFromData(player, dataNow)
	uniqAppend(active, petName)
	trimToCap(active, ACTIVE_MAX)
	setActivePets(player, active)

	local tpl = SFXFolder:FindFirstChild("Choice")
	if tpl and tpl:IsA("Sound") then
		PetSfxEvent:FireClient(player, "PlaySfxTemplate", tpl)
	end

	return {ok=true, coins = CoinService:GetBalance(player)}
end

PetSelectedEvent.OnServerEvent:Connect(function(player: Player, petName: string)
	-- [서버 가드] ① 파라미터 검사
	if typeof(petName) ~= "string" or petName == "" then
		return
	end

	-- [서버 가드] ② 존재하는 펫 모델인지 확인
	local template = petModels:FindFirstChild(petName)
	if not (template and template:IsA("Model")) then
		return
	end

	-- [서버 가드] ③ 안티스팸(더블클릭/매크로 방지) - 2초 쿨다운
	local now = os.clock()
	local last = _lastPetSelectAt[player.UserId] or 0
	if (now - last) < 2.0 then
		return
	end
	_lastPetSelectAt[player.UserId] = now

	-- ====== 기존 흐름 유지
	PlayerDataService:AddOwnedPet(player, petName)
	PlayerDataService:SetSelectedPet(player, petName)
	spawnPet(player, petName)

	local dataNow = PlayerDataService:Load(player)
	local active = getActivePetsFromData(player, dataNow)
	uniqAppend(active, petName)
	trimToCap(active, ACTIVE_MAX)
	setActivePets(player, active)

	local tpl = SFXFolder:FindFirstChild("Choice")
	if tpl and tpl:IsA("Sound") then
		PetSfxEvent:FireClient(player, "PlaySfxTemplate", tpl)
	end
	FirstQuestGui(player)
end)

-- 접속/퇴장 -------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	-- ✅ 접속 시 배지 보유 스냅샷을 속성으로 노출(클라 초기 표시 안정성)
	local hasGT = false
	pcall(function()
		hasGT = BadgeManager.HasRobloxBadge(player, BadgeManager.Keys.GreatTeam)
	end)
	player:SetAttribute("HasGreatTeamBadge", hasGT)

	local data = PlayerDataService:Load(player)
	local active = getActivePetsFromData(player, data)
	local spawned = 0
	for _, petName in ipairs(active) do
		if petModels:FindFirstChild(petName) then
			spawnPet(player, petName)
			spawned += 1
		end
	end

	if PlayerDataService.SetActivePets then
		pcall(function() PlayerDataService:SetActivePets(player, active) end)
	end

	if spawned == 0 then
		if data.selectedPetName and petModels:FindFirstChild(data.selectedPetName) then
			spawnPet(player, data.selectedPetName)
			if PlayerDataService.SetActivePets then
				pcall(function() PlayerDataService:SetActivePets(player, { data.selectedPetName }) end)
			end
		else
			ShowPetGuiEvent:FireClient(player)
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		setCollisionGroupRecursive(char, "Players")
	end)
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
	_lastPetSelectAt[plr.UserId] = nil -- (선택) 스팸 타임스탬프 정리
end)
