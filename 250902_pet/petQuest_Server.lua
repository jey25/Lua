-- ServerScriptService/PetQuestServer.server.lua
-- 서버: 퀘스트 선택/진행/검증. 클라는 UI만.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- RemoteEvent 준비
local remoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local PetQuestEvent = remoteFolder:WaitForChild("PetQuestEvent")

-- 설정
local INTERVAL = 10
local WORLD = Workspace:WaitForChild("World", 10)
local DOG_ITEMS = WORLD and WORLD:FindFirstChild("dogItems")

local Experience = require(game.ServerScriptService:WaitForChild("ExperienceService"))
local PetAffection = require(game.ServerScriptService:WaitForChild("PetAffectionService"))


local SleepArea = Workspace:FindFirstChild("SleepArea")
local FunArea = Workspace:FindFirstChild("FunArea")
-- 펫 선택 여부 & 지연 취소 토큰
local HasSelectedPet : {[Player]: boolean} = {}
local QuestGenToken  : {[Player]: number}  = {}

local OwnerPets : {[number]: Model} = {}


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
	["Feed the Dog"]       = { condition = "clickFoodItem" },
	["Play the Ball"]      = { condition = "useBallItem" },
	["Pet the Dog"]        = { condition = "clickPet" },
	["Put the Dog to Sleep"]= { condition = "goToSleepArea" },
	["Play a Game"]        = { condition = "goToFunArea" },
	["Take the Dog to the Vet"] = { condition = "useVetItem" },
	["Buy the Dog Food"] = { condition = "clickDogFood" },
}

-- 퀘스트 보상 테이블
local QUEST_REWARDS = {
	["Feed the Dog"]        = 150,
	["Play the Ball"]       = 150,
	["Pet the Dog"]         = 100,
	["Put the Dog to Sleep"]= 150,
	["Play a Game"]         = 200,
	["Take the Dog to the Vet"] = 200,
	["Buy the Dog Food"] = 200,
}

-- per-player 상태
local ActiveQuest : {[Player]: string?} = {}
local PendingTimer : {[Player]: boolean} = {}

-- [추가] Play the Ball 전용 아이템 폴더
local PLAY_BALL_ITEMS = DOG_ITEMS and (
	DOG_ITEMS:FindFirstChild("PlayBallItems")
		or DOG_ITEMS:FindFirstChild("playBallItems")
)


-- [추가] 폴더 내 타깃 후보 수집 (Model/BasePart 모두 허용)
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

-- ✅ 펫 클릭용 히트박스 생성/재사용
local function ensurePetClickTarget(pet: Model): BasePart?
	local base = ensurePrimaryOrAnyPart(pet)
	if not base then return nil end

	-- 이미 있으면 재사용
	local hit = pet:FindFirstChild("PetClickHitbox")
	if hit and hit:IsA("BasePart") then return hit end

	-- 모델 외곽 크기 기준으로 투명 히트박스 만들기
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



-- [추가] 중복 연결 방지형 ClickDetector 유틸
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

local function isNearPlayer(player: Player, target: Instance, maxDist: number?): boolean
	maxDist = maxDist or 12
	local char = player.Character
	if not char then return false end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local base: BasePart?
	if target:IsA("Model") then
		base = ensurePrimaryOrAnyPart(target)
	elseif target:IsA("BasePart") then
		base = target
	end
	if not base then return false end
	return (hrp.Position - base.Position).Magnitude <= maxDist
end


-- 기존 findPlayersPet 교체
local function findPlayersPet(player: Player): Model?
	return OwnerPets[player.UserId]
end


-- 서버에서 공용 오브젝트 클릭/터치 세팅
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




-- [추가] 퀘스트별 타깃 인스턴스 찾기 (플레이어별/퀘스트별)
-- [교체] getQuestTargetFor → getQuestTargetsFor : 리스트 반환
local function getQuestTargetsFor(player: Player, questName: string): {Instance}
	if questName == "Feed the Dog" then
		return { DOG_ITEMS and DOG_ITEMS:FindFirstChild("FoodItem") }
	elseif questName == "Play the Ball" then
		local list = collectTargetsInFolder(PLAY_BALL_ITEMS)
		-- 기존 단일 BallItem도 함께 허용(원치 않으면 주석 처리)
		local single = DOG_ITEMS and DOG_ITEMS:FindFirstChild("BallItem")
		if single then table.insert(list, single) end
		return list
	elseif questName == "Take the Dog to the Vet" then
		return { DOG_ITEMS and DOG_ITEMS:FindFirstChild("DogMedicine") }
	elseif questName == "Buy the Dog Food" then
		return { DOG_ITEMS and DOG_ITEMS:FindFirstChild("DogFood") }
	elseif questName == "Put the Dog to Sleep" then
		return { Workspace:FindFirstChild("SleepArea") }
	elseif questName == "Play a Game" then
		return { Workspace:FindFirstChild("FunArea") }
	elseif questName == "Pet the Dog" then
		return { findPlayersPet(player) }
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



-- [추가/변경] startQuestFor: 퀘스트 시작 알림 + 대상 마커 표시 지시
local function startQuestFor(player: Player)
	if not (player and player.Parent) then return end
	local phrase, questName = pickEligibleQuest(player)
	if not phrase then
		-- 시작 가능한 퀘스트가 현재 없음 → 시작하지 않고 끝 (스케줄은 스케줄러가 담당)
		return
	end

	ActiveQuest[player] = questName
	PetQuestEvent:FireClient(player, "StartQuest", { phrase = phrase, quest = questName })

	local targets = getQuestTargetsFor(player, questName)
	if targets and #targets > 0 then
		PetQuestEvent:FireClient(player, "ShowQuestMarkers", { quest = questName, targets = targets })
	end
end


local function scheduleNextQuest(player: Player)
	if PendingTimer[player] then return end
	PendingTimer[player] = true

	QuestGenToken[player] = (QuestGenToken[player] or 0) + 1
	local myToken = QuestGenToken[player]

	task.delay(INTERVAL, function()
		PendingTimer[player] = false

		-- 유효성/취소 체크
		if not (player and player.Parent) then return end
		if QuestGenToken[player] ~= myToken then return end
		-- 이미 진행 중이면 새로 시작하지 않음
		if ActiveQuest[player] ~= nil then return end

		-- 가능한 게 있으면 곧장 시작, 없으면 다시 예약
		local phrase, _ = pickEligibleQuest(player)
		if phrase then
			startQuestFor(player)
		else
			-- 지금은 조건이 안 맞음 → INTERVAL 후 다시 시도
			scheduleNextQuest(player)
		end
	end)
end



-- [추가/변경] completeQuestFor: 클리어 처리 + 마커 제거 지시
local function completeQuestFor(player, questName)
	if ActiveQuest[player] ~= questName then return end
	ActiveQuest[player] = nil

	local reward = QUEST_REWARDS[questName] or 0
	if reward > 0 then Experience.AddExp(player, reward) end
	
	PetAffection.OnQuestCleared(player, questName)
	PetAffection.Configure({ DefaultMax = 10, DecaySec = 10, MinHoldSec = 10 })

	local targets = getQuestTargetsFor(player, questName)
	if targets and #targets > 0 then
		PetQuestEvent:FireClient(player, "HideQuestMarkers", { quest = questName, targets = targets })
	end

	PetQuestEvent:FireClient(player, "CompleteQuest", { quest = questName })
	scheduleNextQuest(player) -- 다음 퀘스트 예약
end



-- 검증 핸들러(서버 권위)
local function onFoodClicked(player: Player)
	if ActiveQuest[player] == "Feed the Dog" then
		completeQuestFor(player, "Feed the Dog")
	end
end

local function onBallClicked(player: Player)
	if ActiveQuest[player] == "Play the Ball" then
		completeQuestFor(player, "Play the Ball")
	end
end

local function onMedicineClicked(player: Player)
	if ActiveQuest[player] == "Take the Dog to the Vet" then
		completeQuestFor(player, "Take the Dog to the Vet")
	end
end

local function onDogFoodClicked(player: Player)
	if ActiveQuest[player] == "Buy the Dog Food" then
		completeQuestFor(player, "Buy the Dog Food")
	end
end


local function onPetClicked(player: Player, petModel: Model)
	-- ✅ Wang 추적/차단 상태면 'Pet the Dog' 퀘스트 클릭 무시
	if petModel and (petModel:GetAttribute("AIState") == "wang_approach"
		or petModel:GetAttribute("BlockPetQuestClicks") == true) then
		return
	end

	-- 기존 로직
	if ActiveQuest[player] == "Pet the Dog" then
		local owner = petModel and petModel:GetAttribute("OwnerUserId")
		if typeof(owner) == "number" and owner == player.UserId then
			completeQuestFor(player, "Pet the Dog")
		end
	end
end


local function touchedArea(questName: string, player: Player)
	if ActiveQuest[player] == questName then
		completeQuestFor(player, questName)
	end
end

-- [추가] 전용 폴더에 들어있는 모든 아이템을 'Play the Ball' 클리어 대상으로 연결
if PLAY_BALL_ITEMS then
	-- 최초 일괄 와이어링
	for _, inst in ipairs(PLAY_BALL_ITEMS:GetDescendants()) do
		if inst:IsA("Model") or inst:IsA("BasePart") then
			ensureClickDetectorOnce(inst, onBallClicked)
		end
	end
	-- 런타임 추가 아이템도 자동 와이어링
	PLAY_BALL_ITEMS.DescendantAdded:Connect(function(inst)
		if inst:IsA("Model") or inst:IsA("BasePart") then
			ensureClickDetectorOnce(inst, onBallClicked)
		end
	end)
end


-- 기존 단일 아이템들(다른 퀘스트 포함)은 유지
if DOG_ITEMS then
	ensureClickDetector(DOG_ITEMS:FindFirstChild("FoodItem"), onFoodClicked)
	ensureClickDetector(DOG_ITEMS:FindFirstChild("BallItem"), onBallClicked)  -- 기존 단일 BallItem도 유효
	ensureClickDetector(DOG_ITEMS:FindFirstChild("DogMedicine"), onMedicineClicked)
	ensureClickDetector(DOG_ITEMS:FindFirstChild("DogFood"), onDogFoodClicked)
end



-- 영역들

if SleepArea and SleepArea:IsA("BasePart") then
	SleepArea.Touched:Connect(function(hit)
		local char = hit and hit:FindFirstAncestorOfClass("Model")
		if not char then return end
		local player = Players:GetPlayerFromCharacter(char)
		if player then
			touchedArea("Put the Dog to Sleep", player)
		end
	end)
end


if FunArea and FunArea:IsA("BasePart") then
	FunArea.Touched:Connect(function(hit)
		local char = hit and hit:FindFirstAncestorOfClass("Model")
		if not char then return end
		local player = Players:GetPlayerFromCharacter(char)
		if player then
			touchedArea("Play a Game", player)
		end
	end)
end

-- ✅ 펫 클릭 와이어링(교체)
local function tryWirePetClick(inst: Instance)
	if not (inst and inst:IsA("Model")) then return end
	local owner = inst:GetAttribute("OwnerUserId")
	if typeof(owner) ~= "number" then return end
	
	-- tryWirePetClick 내부, owner 확인 직후 추가
	OwnerPets[owner] = inst
	inst.Destroying:Once(function()
		if OwnerPets[owner] == inst then
			OwnerPets[owner] = nil
		end
	end)

	-- 모델 루트에 잘못 붙어 있는 ClickDetector는 제거(무효)
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

	-- 중복 연결을 피하려면 once-guard를 둘 수도 있음 (간단히 그대로 연결)
	cd.MouseClick:Connect(function(clickedBy)
		if clickedBy and clickedBy.UserId == owner then
			onPetClicked(clickedBy, inst) -- 기존 완료 로직 호출
		end
	end)
end


-- 기존에 이미 Workspace 내에 존재하는 펫들 처리(서버 리스타트/테스트 대비)
for _, inst in ipairs(Workspace:GetDescendants()) do
	tryWirePetClick(inst)
end


-- 이후 새로 들어오는 것들 처리
Workspace.DescendantAdded:Connect(function(inst)
	tryWirePetClick(inst)
end)

Players.PlayerAdded:Connect(function(player)
	scheduleNextQuest(player)
end)

for _, p in ipairs(Players:GetPlayers()) do
	scheduleNextQuest(p)
end


local PetSelectedEvent = remoteFolder:FindFirstChild("PetSelected")
if PetSelectedEvent then
	PetSelectedEvent.OnServerEvent:Connect(function(player, petName)
		HasSelectedPet[player] = true -- (옵션) 참고용 플래그만 유지
	end)
end




Players.PlayerRemoving:Connect(function(player)
	ActiveQuest[player] = nil
	PendingTimer[player] = nil
	HasSelectedPet[player] = nil
	QuestGenToken[player] = nil
end)

