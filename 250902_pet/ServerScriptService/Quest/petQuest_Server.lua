-- ServerScriptService/PetQuestServer.server.lua
-- 서버: 퀘스트 선택/진행/검증. 클라는 UI만.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- RemoteEvent 준비
local remoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local PetQuestEvent = remoteFolder:WaitForChild("PetQuestEvent")

-- 설정
local INTERVAL = 60
local WORLD = Workspace:WaitForChild("World", 10)
local DOG_ITEMS = WORLD and WORLD:FindFirstChild("dogItems")

local Experience = require(game.ServerScriptService:WaitForChild("ExperienceService"))
local PetAffection = require(game.ServerScriptService:WaitForChild("PetAffectionService"))

local SleepArea = Workspace:FindFirstChild("SleepArea")
local FunArea = Workspace:FindFirstChild("FunArea")

-- (참고용) 선택 여부 플래그
local HasSelectedPet : {[Player]: boolean} = {}

-- 🔁 여러 마리 펫/펫별 상태
local OwnerPets : {[number]: {[string]: Model}} = {}   -- userId -> {petId -> Model}
local PetOwner  : {[string]: Player} = {}              -- petId -> Player

local ActiveQuestByPet   : {[string]: string?} = {}    -- petId -> questName
local PendingTimerByPet  : {[string]: boolean} = {}    -- petId -> pending
local QuestGenTokenByPet : {[string]: number}  = {}    -- petId -> token

-- 퀘스트 정의
local phrases = {
	["I'm hungry!"] = "Feed the Dog",
	["Play with me!"] = "Play the Ball",
	["Pet me, please!"] = "Pet the Dog",
	["I'm sleepy!"] = "Put the Dog to Sleep",
	["Let's do some fun!"] = "Play a Game",
	["I'm sick..TT"] = "Take the Dog to the Vet",
	["Something delicious!"] = "Buy the Dog Food",
}

local quests = {
	["Feed the Dog"]        = { condition = "clickFoodItem" },
	["Play the Ball"]       = { condition = "useBallItem" },
	["Pet the Dog"]         = { condition = "clickPet" },
	["Put the Dog to Sleep"]= { condition = "goToSleepArea" },
	["Play a Game"]         = { condition = "goToFunArea" },
	["Take the Dog to the Vet"] = { condition = "useVetItem" },
	["Buy the Dog Food"]    = { condition = "clickDogFood" },
}

-- 퀘스트 보상
local QUEST_REWARDS = {
	["Feed the Dog"]         = 100,
	["Play the Ball"]        = 100,
	["Pet the Dog"]          = 100,
	["Put the Dog to Sleep"] = 100,
	["Play a Game"]          = 100,
	["Take the Dog to the Vet"] = 100,
	["Buy the Dog Food"]     = 100,
}

-- Play the Ball 전용 폴더
local PLAY_BALL_ITEMS = DOG_ITEMS and (
	DOG_ITEMS:FindFirstChild("PlayBallItems")
		or DOG_ITEMS:FindFirstChild("playBallItems")
)

-- ========= 유틸 =========

local function getPetId(m: Model): string?
	return m and m:GetAttribute("PetId")
end

local function getPetsOf(player: Player): {Model}
	local res = {}
	local map = OwnerPets[player.UserId]
	if map then
		for _, m in pairs(map) do
			table.insert(res, m)
		end
	end
	return res
end

local function getAnyBasePart(inst: Instance): BasePart?
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then
		if inst.PrimaryPart then return inst.PrimaryPart end
		local hrp = inst:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then return hrp end
		return inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- (호환) 플레이어의 임의 한 마리 반환
local function findPlayersPet(player: Player): Model?
	local map = OwnerPets[player.UserId]
	if not map then return nil end
	for _, m in pairs(map) do
		return m
	end
	return nil
end

-- 폴더 내 타깃 후보 수집
local function collectTargetsInFolder(folder: Instance?): {Instance}
	local out = {}
	if not folder then return out end
	for _, inst in ipairs(folder:GetDescendants()) do
		if inst:IsA("Model") or inst:IsA("BasePart") then
			table.insert(out, inst)
		end
	end
	return out
end

local function ensurePrimaryOrAnyPart(model: Model): BasePart?
	if model.PrimaryPart then return model.PrimaryPart end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then return hrp end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

-- ✅ 이름으로 전부 수집 (DOG_ITEMS 하위)
local function collectNamedDescendants(root: Instance?, name: string): {Instance}
	local out = {}
	if not root then return out end
	for _, inst in ipairs(root:GetDescendants()) do
		if (inst:IsA("Model") or inst:IsA("BasePart")) and inst.Name == name then
			table.insert(out, inst)
		end
	end
	return out
end

-- ✅ 워크스페이스 전역에서 동일 이름 BasePart 수집 (영역용)
local function collectWorkspaceAreas(name: string): {BasePart}
	local out = {}
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if inst:IsA("BasePart") and inst.Name == name then
			table.insert(out, inst)
		end
	end
	return out
end

-- ✅ 펫 클릭용 히트박스 생성/재사용
local function ensurePetClickTarget(pet: Model): BasePart?
	local base = ensurePrimaryOrAnyPart(pet)
	if not base then return nil end

	-- 이미 있으면 재사용
	local hit = pet:FindFirstChild("PetClickHitbox")
	if hit and hit:IsA("BasePart") then return hit end

	-- 모델 외곽 크기 기준 투명 히트박스
	local size = pet:GetExtentsSize()
	local hitbox = Instance.new("Part")
	hitbox.Name = "PetClickHitbox"
	hitbox.Size = Vector3.new(math.max(size.X, 1.2), math.max(size.Y, 1.2), math.max(size.Z, 1.2))
	hitbox.CFrame = base.CFrame
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = true
	hitbox.Anchored = false
	hitbox.Massless = true
	hitbox.Parent = pet

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hitbox
	weld.Part1 = base
	weld.Parent = hitbox

	return hitbox
end

-- 중복 연결 방지형 ClickDetector (PlayBall 전용으로 계속 사용)
local function ensureClickDetectorOnce(target: Instance, callback: (Player)->())
	if not target then return end
	local base : BasePart? = nil
	if target:IsA("BasePart") then base = target
	elseif target:IsA("Model") then base = ensurePrimaryOrAnyPart(target) end
	if not base then return end

	local cd = base:FindFirstChildOfClass("ClickDetector")
	if not cd then
		cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 10
		cd.Parent = base
	end

	-- 이미 와이어링 됐으면 재연결하지 않음
	if cd:GetAttribute("Wired_PlayBall") then return end
	cd:SetAttribute("Wired_PlayBall", true)

	cd.MouseClick:Connect(function(player)
		if player and player.Parent then
			callback(player)
		end
	end)
end

-- 서버에서 공용 오브젝트 클릭 세팅 (단일 용 - 기존 호환용)
local function ensureClickDetector(target: Instance, callback: (Player)->())
	if not target then return end
	local base : BasePart? = nil
	if target:IsA("BasePart") then base = target
	elseif target:IsA("Model") then base = ensurePrimaryOrAnyPart(target) end
	if not base then return end

	local cd = base:FindFirstChildOfClass("ClickDetector")
	if not cd then
		cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 10
		cd.Parent = base
	end
	cd.MouseClick:Connect(function(player)
		if player and player.Parent then
			callback(player)
		end
	end)
end

-- ✅ 다중 이름 지원용: 지정 key로 1회만 와이어링, 클릭된 인스턴스까지 콜백 전달
local function ensureClickDetectorOnceWithKey(target: Instance, keyAttr: string, callback: (Player, Instance)->())
	if not target then return end
	local base : BasePart? = target:IsA("BasePart") and target
		or (target:IsA("Model") and ensurePrimaryOrAnyPart(target)) or nil
	if not base then return end

	local cd = base:FindFirstChildOfClass("ClickDetector")
	if not cd then
		cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 10
		cd.Parent = base
	end

	if cd:GetAttribute(keyAttr) then return end
	cd:SetAttribute(keyAttr, true)

	cd.MouseClick:Connect(function(player)
		if player and player.Parent then
			callback(player, target) -- 클릭된 ‘그’ 인스턴스 전달
		end
	end)
end

-- ========= 타깃 탐색/가용성 판단 =========

-- 퀘스트별 타깃 리스트 반환
local function getQuestTargetsFor(player: Player, questName: string): {Instance}
	if questName == "Feed the Dog" then
		return collectNamedDescendants(DOG_ITEMS, "FoodItem")
	elseif questName == "Play the Ball" then
		local list = collectTargetsInFolder(PLAY_BALL_ITEMS)
		local single = DOG_ITEMS and DOG_ITEMS:FindFirstChild("BallItem")
		if single then table.insert(list, single) end
		return list
	elseif questName == "Take the Dog to the Vet" then
		return collectNamedDescendants(DOG_ITEMS, "DogMedicine")
	elseif questName == "Buy the Dog Food" then
		return collectNamedDescendants(DOG_ITEMS, "DogFood")
	elseif questName == "Put the Dog to Sleep" then
		return collectWorkspaceAreas("SleepArea")
	elseif questName == "Play a Game" then
		return collectWorkspaceAreas("FunArea")
	elseif questName == "Pet the Dog" then
		-- 🔧 기존 버그: table(map) 반환하던 것 수정 → 배열(Model들)
		return getPetsOf(player)
	end
	return {}
end

local function hasValidTarget(list: {Instance}): boolean
	for _, t in ipairs(list or {}) do
		if typeof(t) == "Instance" and t:IsDescendantOf(workspace) then
			if t:IsA("BasePart") then return true end
			if t:IsA("Model") and ensurePrimaryOrAnyPart(t) then return true end
		end
	end
	return false
end

local function getEligiblePairs(player: Player): {{phrase: string, quest: string}}
	local out = {}
	for phrase, quest in pairs(phrases) do
		local targets = getQuestTargetsFor(player, quest)
		if hasValidTarget(targets) then
			table.insert(out, { phrase = phrase, quest = quest })
		end
	end
	return out
end

local function pickEligibleQuest(player: Player): (string?, string?)
	local eligible = getEligiblePairs(player)
	if #eligible == 0 then return nil, nil end
	local pick = eligible[math.random(1, #eligible)]
	return pick.phrase, pick.quest
end

-- ========= 펫별 스케줄/시작/완료 =========
-- ✅ 교체본
local function startQuestForPet(player: Player, petId: string, phrase: string?, questName: string?)
	if not (player and player.Parent) then return end

	-- phrase/questName 둘 다 없으면 새로 뽑기
	if not phrase then
		local pickedPhrase, pickedQuest = pickEligibleQuest(player)
		if not pickedPhrase or not pickedQuest then return end
		phrase, questName = pickedPhrase, pickedQuest
		-- phrase만 있고 questName이 없으면 매핑으로 보완
	elseif not questName then
		questName = phrases[phrase]
		if not questName then return end
	end

	ActiveQuestByPet[petId] = questName

	-- 클라 통지
	PetQuestEvent:FireClient(player, "StartQuestForPet", {
		petId = petId, phrase = phrase, quest = questName
	})

	-- 마커 표시 (Pet the Dog는 해당 펫 자체)
	local targets = getQuestTargetsFor(player, questName)
	if questName == "Pet the Dog" then
		local m = OwnerPets[player.UserId] and OwnerPets[player.UserId][petId]
		targets = m and { m } or {}
	end
	if targets and #targets > 0 then
		PetQuestEvent:FireClient(player, "ShowQuestMarkers", {
			quest = questName, targets = targets, petId = petId
		})
	end
end


local function scheduleNextQuestForPet(player: Player, petId: string)
	if PendingTimerByPet[petId] then return end
	PendingTimerByPet[petId] = true
	QuestGenTokenByPet[petId] = (QuestGenTokenByPet[petId] or 0) + 1
	local myToken = QuestGenTokenByPet[petId]

	task.delay(INTERVAL, function()
		PendingTimerByPet[petId] = false
		if not (player and player.Parent) then return end
		if QuestGenTokenByPet[petId] ~= myToken then return end
		if ActiveQuestByPet[petId] ~= nil then return end

		local phrase, quest = pickEligibleQuest(player)
		if phrase then
			startQuestForPet(player, petId, phrase, quest)
		else
			-- 지금은 조건이 안 맞음 → INTERVAL 후 재시도
			scheduleNextQuestForPet(player, petId)
		end
	end)
end

local function completeQuestForPet(player: Player, petId: string, questName: string)
	if ActiveQuestByPet[petId] ~= questName then return end
	ActiveQuestByPet[petId] = nil

	-- 방어적: 소유자 확인(선택적 강화)
	if PetOwner[petId] and PetOwner[petId] ~= player then
		return
	end

	local reward = QUEST_REWARDS[questName] or 0
	if reward > 0 then Experience.AddExp(player, reward) end

	PetAffection.OnQuestCleared(player, questName)
	PetAffection.Configure({ DefaultMax = 10, DecaySec = 10, MinHoldSec = 10 })

	-- 마커 숨김
	local targets = getQuestTargetsFor(player, questName)
	if questName == "Pet the Dog" then
		local m = OwnerPets[player.UserId] and OwnerPets[player.UserId][petId]
		targets = m and { m } or {}
	end
	PetQuestEvent:FireClient(player, "HideQuestMarkers", {
		quest = questName, targets = targets, petId = petId
	})

	-- 해당 펫만 완료
	PetQuestEvent:FireClient(player, "CompleteQuestForPet", {
		quest = questName, petId = petId
	})

	-- 다음 퀘 예약
	scheduleNextQuestForPet(player, petId)
end

-- 활성 퀘스트 가진 "가장 가까운 펫" 고르기
local function pickActivePetFor(player: Player, questName: string, nearInst: Instance?): string? -- returns petId
	local pets = getPetsOf(player)
	if #pets == 0 then return nil end

	local refPart = nearInst and getAnyBasePart(nearInst)
	if not refPart then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		refPart = hrp
	end

	local bestPetId, bestDist = nil, math.huge
	for _, m in ipairs(pets) do
		local pid = getPetId(m)
		if pid and ActiveQuestByPet[pid] == questName then
			if not refPart then
				return pid
			end
			local base = getAnyBasePart(m)
			if base then
				local d = (base.Position - refPart.Position).Magnitude
				if d < bestDist then
					bestDist, bestPetId = d, pid
				end
			end
		end
	end
	return bestPetId
end

-- ========= 완료 핸들러 =========

-- 'Pet the Dog': 클릭된 펫만 완료
local function onPetClicked(player: Player, petModel: Model)
	if petModel and (petModel:GetAttribute("AIState") == "wang_approach"
		or petModel:GetAttribute("BlockPetQuestClicks") == true) then
		return
	end
	local pid = getPetId(petModel)
	if not pid then return end
	if ActiveQuestByPet[pid] == "Pet the Dog" then
		completeQuestForPet(player, pid, "Pet the Dog")
	end
end

-- 아래 콜백들은 다중 동일 이름 오브젝트 지원을 위해 클릭된 인스턴스를 함께 받음
local function onFoodClicked(player: Player, inst: Instance)
	local pid = pickActivePetFor(player, "Feed the Dog", inst)
	if pid then completeQuestForPet(player, pid, "Feed the Dog") end
end

local function onBallClicked(player: Player, inst: Instance)
	-- PlayBall은 기존 ensureClickDetectorOnce로 player만 넘길 수도 있음 → inst 없으면 nil 허용
	local pid = pickActivePetFor(player, "Play the Ball", inst)
	if pid then completeQuestForPet(player, pid, "Play the Ball") end
end

local function onMedicineClicked(player: Player, inst: Instance)
	local pid = pickActivePetFor(player, "Take the Dog to the Vet", inst)
	if pid then completeQuestForPet(player, pid, "Take the Dog to the Vet") end
end

local function onDogFoodClicked(player: Player, inst: Instance)
	local pid = pickActivePetFor(player, "Buy the Dog Food", inst)
	if pid then completeQuestForPet(player, pid, "Buy the Dog Food") end
end

local function touchedArea(questName: string, player: Player, area: BasePart?)
	local pid = pickActivePetFor(player, questName, area)
	if pid then completeQuestForPet(player, pid, questName) end
end

-- ========= 와이어링 =========

-- PlayBall 전용 폴더 와이어링 (기존 동작 유지: 모든 하위에 1회 와이어링)
if PLAY_BALL_ITEMS then
	-- 최초 일괄
	for _, inst in ipairs(PLAY_BALL_ITEMS:GetDescendants()) do
		if inst:IsA("Model") or inst:IsA("BasePart") then
			ensureClickDetectorOnce(inst, function(player)
				onBallClicked(player, inst)
			end)
		end
	end
	-- 런타임 추가
	PLAY_BALL_ITEMS.DescendantAdded:Connect(function(inst)
		if inst:IsA("Model") or inst:IsA("BasePart") then
			ensureClickDetectorOnce(inst, function(player)
				onBallClicked(player, inst)
			end)
		end
	end)
end

-- 단일 아이템들 → 동일 이름 여러 개 전부 와이어링으로 확장
if DOG_ITEMS then
	-- 초기 일괄: FoodItem / DogMedicine / DogFood 모두
	for _, inst in ipairs(collectNamedDescendants(DOG_ITEMS, "FoodItem")) do
		ensureClickDetectorOnceWithKey(inst, "Wired_FoodItem", onFoodClicked)
	end
	for _, inst in ipairs(collectNamedDescendants(DOG_ITEMS, "DogMedicine")) do
		ensureClickDetectorOnceWithKey(inst, "Wired_DogMedicine", onMedicineClicked)
	end
	for _, inst in ipairs(collectNamedDescendants(DOG_ITEMS, "DogFood")) do
		ensureClickDetectorOnceWithKey(inst, "Wired_DogFood", onDogFoodClicked)
	end

	-- 런타임 추가
	DOG_ITEMS.DescendantAdded:Connect(function(inst)
		if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
		if inst.Name == "FoodItem" then
			ensureClickDetectorOnceWithKey(inst, "Wired_FoodItem", onFoodClicked)
		elseif inst.Name == "DogMedicine" then
			ensureClickDetectorOnceWithKey(inst, "Wired_DogMedicine", onMedicineClicked)
		elseif inst.Name == "DogFood" then
			ensureClickDetectorOnceWithKey(inst, "Wired_DogFood", onDogFoodClicked)
		end
	end)
end

-- 영역들: SleepArea / FunArea 전부 와이어링
for _, area in ipairs(collectWorkspaceAreas("SleepArea")) do
	if not area:GetAttribute("Wired_SleepArea") then
		area:SetAttribute("Wired_SleepArea", true)
		area.Touched:Connect(function(hit)
			local char = hit and hit:FindFirstAncestorOfClass("Model")
			if not char then return end
			local player = Players:GetPlayerFromCharacter(char)
			if player then
				touchedArea("Put the Dog to Sleep", player, area)
			end
		end)
	end
end

for _, area in ipairs(collectWorkspaceAreas("FunArea")) do
	if not area:GetAttribute("Wired_FunArea") then
		area:SetAttribute("Wired_FunArea", true)
		area.Touched:Connect(function(hit)
			local char = hit and hit:FindFirstAncestorOfClass("Model")
			if not char then return end
			local player = Players:GetPlayerFromCharacter(char)
			if player then
				touchedArea("Play a Game", player, area)
			end
		end)
	end
end

-- ✅ 펫 클릭 와이어링
local function tryWirePetClick(inst: Instance)
	if not (inst and inst:IsA("Model")) then return end
	local owner = inst:GetAttribute("OwnerUserId")
	if typeof(owner) ~= "number" then return end

	local petId = getPetId(inst)
	if not petId then return end

	-- 여러 마리 등록
	OwnerPets[owner] = OwnerPets[owner] or {}
	OwnerPets[owner][petId] = inst
	local player = Players:GetPlayerByUserId(owner)
	PetOwner[petId] = player

	-- 파괴 시 정리
	inst.Destroying:Once(function()
		if OwnerPets[owner] then OwnerPets[owner][petId] = nil end
		PetOwner[petId] = nil
		ActiveQuestByPet[petId] = nil
		PendingTimerByPet[petId] = nil
		QuestGenTokenByPet[petId] = nil
	end)

	-- 루트에 잘못 붙은 ClickDetector 제거
	for _, child in ipairs(inst:GetChildren()) do
		if child:IsA("ClickDetector") then child:Destroy() end
	end

	local clickTarget = ensurePetClickTarget(inst)  -- 히트박스 확보
	if not clickTarget then return end

	local cd = clickTarget:FindFirstChildOfClass("ClickDetector")
	if not cd then
		cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 60
		cd.Parent = clickTarget
	end

	cd.MouseClick:Connect(function(clickedBy)
		if clickedBy and clickedBy.UserId == owner then
			onPetClicked(clickedBy, inst)
		end
	end)

	-- 이 펫 전용 퀘스트 스케줄 시작
	if player then
		scheduleNextQuestForPet(player, petId)
	end
end

-- 기존 존재 펫들
for _, inst in ipairs(Workspace:GetDescendants()) do
	tryWirePetClick(inst)
end

-- 이후 새로 들어오는 것들 (펫 + 영역)
Workspace.DescendantAdded:Connect(function(inst)
	-- 펫
	tryWirePetClick(inst)

	-- 영역: SleepArea / FunArea
	if inst:IsA("BasePart") and inst.Name == "SleepArea" and not inst:GetAttribute("Wired_SleepArea") then
		inst:SetAttribute("Wired_SleepArea", true)
		inst.Touched:Connect(function(hit)
			local char = hit and hit:FindFirstAncestorOfClass("Model"); if not char then return end
			local player = Players:GetPlayerFromCharacter(char)
			if player then touchedArea("Put the Dog to Sleep", player, inst) end
		end)
	elseif inst:IsA("BasePart") and inst.Name == "FunArea" and not inst:GetAttribute("Wired_FunArea") then
		inst:SetAttribute("Wired_FunArea", true)
		inst.Touched:Connect(function(hit)
			local char = hit and hit:FindFirstAncestorOfClass("Model"); if not char then return end
			local player = Players:GetPlayerFromCharacter(char)
			if player then touchedArea("Play a Game", player, inst) end
		end)
	end
end)

-- 선택 이벤트 (참고 플래그)
local PetSelectedEvent = remoteFolder:FindFirstChild("PetSelected")
if PetSelectedEvent then
	PetSelectedEvent.OnServerEvent:Connect(function(player, _petName)
		HasSelectedPet[player] = true
	end)
end

-- 플레이어 퇴장 정리
Players.PlayerRemoving:Connect(function(player)
	HasSelectedPet[player] = nil
	local map = OwnerPets[player.UserId]
	if map then
		for pid, _m in pairs(map) do
			PetOwner[pid] = nil
			ActiveQuestByPet[pid] = nil
			PendingTimerByPet[pid] = nil
			QuestGenTokenByPet[pid] = nil
		end
		OwnerPets[player.UserId] = nil
	end
end)
