-- ServerScriptService/QuestManager.lua
--!strict
local QuestManager = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- 외부에서 세팅 가능한 값들
QuestManager.NPCFolder = nil -- set from server init
QuestManager.QuestEvent = nil -- RemoteEvent, set from server init
local ExperienceService = nil -- set from server init

-- 템플릿 예시 (원하면 로드/JSON으로 관리해도 됨)
QuestManager.Templates = {
	["Q1"] = {
		Id = "Q1",
		Title = "Goblin 3마리 처치",
		Description = "마을 주변 Goblin을 3마리 처치하세요.",
		Type = "Kill",
		TargetName = "Goblin",
		Amount = 3,
		Rewards = {Exp = 50, Gold = 10},
		Duration = 180, -- seconds
		MaxAssignees = 3, -- 동시에 3명까지 받을 수 있음
		SpawnableOnAnyNPC = true,
		Weight = 1,
		SpawnCooldown = 10
	},
	["Q2"] = {
		Id = "Q2",
		Title = "강아지 쓰다듬기",
		Description = "강아지에게 다가가서 쓰다듬어주세요.",
		Type = "Interact",
		TargetName = "DogModel",
		Amount = 1,
		Rewards = {Exp = 30},
		Duration = 120,
		MaxAssignees = 1,
		SpawnableOnAnyNPC = true,
		Weight = 1
	}
}

-- 런타임 스토리지
local Instances : {[string]: any} = {}
local ActiveQuestsByNPC : {[Instance]: any} = {}
local PlayerQuests : {[Player]: string} = {} -- player -> instanceId
local LastSpawnTimes : {[string]: number} = {} -- templateId -> last spawn time

-- 유틸
local function genInstanceId(templateId)
	return templateId.."_"..tostring(os.time()).."_"..tostring(math.random(1,9999))
end

local function findTemplate(templateId)
	return QuestManager.Templates[templateId]
end

-- 인스턴스 생성 (NPC Model과 템플릿 ID 필요)
function QuestManager.SpawnInstanceOnNPC(npc: Model, templateId: string)
	local template = findTemplate(templateId)
	if not template or not npc then return nil end
	-- 중복 방지: 이미 NPC에 퀘스트가 걸려있으면 리턴
	if ActiveQuestsByNPC[npc] then return nil end

	local instId = genInstanceId(templateId)
	local instance = {
		id = instId,
		templateId = templateId,
		npc = npc,
		assignees = {}, -- list of userIds
		progress = {}, -- map userId -> number
		expireTime = os.time() + (template.Duration or 60),
		status = "Active"
	}
	Instances[instId] = instance
	ActiveQuestsByNPC[npc] = instance

	-- 클라에게 마커 표시
	if QuestManager.QuestEvent then
		QuestManager.QuestEvent:FireAllClients("ShowQuestMarker", {
			target = npc,
			questId = templateId,
			title = template.Title,
			description = template.Description
		})
	end

	LastSpawnTimes[templateId] = os.time()
	return instance
end

-- 랜덤 NPC에 템플릿 스폰 (템플릿 룰 고려)
function QuestManager.SpawnRandom(templateId: string)
	if not QuestManager.NPCFolder then return end
	local template = findTemplate(templateId)
	if not template then return end
	-- 쿨다운 체크
	local last = LastSpawnTimes[templateId] or 0
	if os.time() - last < (template.SpawnCooldown or 0) then return end

	local all = QuestManager.NPCFolder:GetChildren()
	local candidates = {}
	for _, npc in ipairs(all) do
		-- whitelist/blacklist 룰이 있으면 추가 검증
		if template.SpawnableOnAnyNPC or (template.NPCWhitelist and table.find(template.NPCWhitelist, npc.Name)) then
			if not ActiveQuestsByNPC[npc] then
				table.insert(candidates, npc)
			end
		end
	end
	if #candidates == 0 then return end
	local npc = candidates[math.random(1, #candidates)]
	return QuestManager.SpawnInstanceOnNPC(npc, templateId)
end

-- 플레이어에게 인스턴스 할당
function QuestManager.Assign(player: Player, npcName: string)
	if PlayerQuests[player] then
		return false, "PlayerAlreadyOnQuest"
	end
	local npc = QuestManager.NPCFolder:FindFirstChild(npcName)
	if not npc then return false, "NoSuchNPC" end
	local instance = ActiveQuestsByNPC[npc]
	if not instance then return false, "NoActiveQuestOnNPC" end
	local template = findTemplate(instance.templateId)
	if not template then return false, "TemplateMissing" end

	-- 수용 인원 체크
	if template.MaxAssignees and #instance.assignees >= template.MaxAssignees then
		return false, "Full"
	end

	table.insert(instance.assignees, player.UserId)
	instance.progress[player.UserId] = 0
	PlayerQuests[player] = instance.id

	-- 만일 MaxAssignees == 1 이거나 꽉찼다면 마커 숨김
	if template.MaxAssignees == 1 or #instance.assignees >= template.MaxAssignees then
		if QuestManager.QuestEvent then
			QuestManager.QuestEvent:FireAllClients("HideQuestMarker", {target = npc})
		end
	end

	-- 클라에 퀘스트 상세 열어주기
	if QuestManager.QuestEvent then
		QuestManager.QuestEvent:FireClient(player, "OpenQuestGui", {
			questId = template.Id,
			title = template.Title,
			description = template.Description,
			npcName = npc.Name
		})
	end

	return true
end

-- 진행 보고 (서버에서 호출 권장: ex. 몬스터 사망 핸들러에서)
function QuestManager.AddProgress(player: Player, amount: number, actionType: string?, targetName: string?)
	local instId = PlayerQuests[player]
	if not instId then return end
	local instance = Instances[instId]
	if not instance then return end
	local template = findTemplate(instance.templateId)
	if not template then return end

	-- 타입 매칭 검증
	if template.Type ~= actionType then return end
	if template.TargetName and template.TargetName ~= targetName then return end

	local uid = player.UserId
	instance.progress[uid] = (instance.progress[uid] or 0) + (amount or 1)

	-- 클라에 진행 알림
	if QuestManager.QuestEvent then
		QuestManager.QuestEvent:FireClient(player, "QuestProgress", {
			questId = template.Id,
			progress = instance.progress[uid],
			required = template.Amount
		})
	end

	-- 완료 체크
	if instance.progress[uid] >= (template.Amount or 1) then
		-- 플레이어는 NPC로 돌아가서 턴인해야 함 (Ready 상태 알림)
		if QuestManager.QuestEvent then
			QuestManager.QuestEvent:FireClient(player, "QuestReady", {
				questId = template.Id
			})
		end
	end
end

-- 플레이어가 NPC에게 턴인 시도
function QuestManager.TryTurnIn(player: Player, npcName: string)
	local instId = PlayerQuests[player]
	if not instId then return false, "NoPlayerQuest" end
	local instance = Instances[instId]
	if not instance then return false, "InstanceMissing" end
	local npc = QuestManager.NPCFolder:FindFirstChild(npcName)
	if not npc then return false, "NoSuchNPC" end
	-- 반드시 '수령받았던 NPC'에서 턴인하도록 요구
	if instance.npc ~= npc then return false, "WrongNPC" end

	local template = findTemplate(instance.templateId)
	local uid = player.UserId
	local prog = instance.progress[uid] or 0
	if prog < (template.Amount or 1) then
		return false, "NotComplete"
	end

	-- 보상 지급 (ExperienceService 등 외부 서비스 사용)
	if ExperienceService and template.Rewards and template.Rewards.Exp then
		ExperienceService.AddExp(player, template.Rewards.Exp)
	end
	-- 금화/아이템 등 추가 지급 로직 삽입 가능

	-- 클라 알림
	if QuestManager.QuestEvent then
		QuestManager.QuestEvent:FireClient(player, "QuestClear", {questId = template.Id})
	end

	-- 플레이어 상태 정리
	PlayerQuests[player] = nil
	-- instance에서 해당 플레이어 제거
	for i, id in ipairs(instance.assignees) do
		if id == uid then
			table.remove(instance.assignees, i)
			break
		end
	end
	instance.progress[uid] = nil

	-- 인스턴스가 더 이상 할당자 없다면 인스턴스 종료 및 재스폰 로직
	if #instance.assignees == 0 then
		ActiveQuestsByNPC[instance.npc] = nil
		Instances[instance.id] = nil
		-- 같은 템플릿을 다른 NPC에 스폰 (원하면 시간 지연/쿨다운 적용)
		delay(2, function()
			QuestManager.SpawnRandom(template.Id)
		end)
	end

	return true
end

-- 주기적으로 만료/정리
function QuestManager.TickCleanup()
	for id, inst in pairs(Instances) do
		if os.time() > inst.expireTime then
			-- 마커 숨김 및 정리
			if QuestManager.QuestEvent then
				QuestManager.QuestEvent:FireAllClients("HideQuestMarker", {target = inst.npc})
			end
			Instances[id] = nil
			ActiveQuestsByNPC[inst.npc] = nil
		end
	end
end

-- 초기화(서버 스크립트에서 호출)
function QuestManager.Init(args)
	QuestManager.NPCFolder = args.NPCFolder
	QuestManager.QuestEvent = args.QuestEvent
	ExperienceService = args.ExperienceService

	-- 간단한 주기 루프 (테스트용 15초)
	spawn(function()
		while true do
			wait(15)
			QuestManager.TickCleanup()
			-- 간단: 템플릿 풀에서 랜덤으로 스폰 시도
			for tid, tpl in pairs(QuestManager.Templates) do
				-- 가중치/정책 고려해서 확률적으로 스폰 (간단 구현)
				if math.random() < 0.2 * (tpl.Weight or 1) then
					QuestManager.SpawnRandom(tid)
				end
			end
		end
	end)
end

return QuestManager

