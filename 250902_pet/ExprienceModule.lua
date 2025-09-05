local ExperienceService = {}


local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


-- RemoteEvents
local QuestCleared = ReplicatedStorage:FindFirstChild("QuestCleared") or Instance.new("RemoteEvent", ReplicatedStorage)
QuestCleared.Name = "QuestCleared"

local LevelSync = ReplicatedStorage:FindFirstChild("LevelSync") or Instance.new("RemoteEvent", ReplicatedStorage)
LevelSync.Name = "LevelSync"

-- DataStore
local STORE_NAME = "PlayerProgress_v1"
local ProgressStore = DataStoreService:GetDataStore(STORE_NAME)

-- 경험치 요구량 공식(원하면 테이블로 바꿔도 OK)
local function ExpToNext(level: number): number
	-- Lv1->2는 100, 이후 점증
	-- 곡선은 자유 조정: (100 + 50*(level-1)^2) 예시
	return math.floor(100 + 50 * (level - 1) * (level - 1))
end

-- 안전 저장 유틸
local function trySave(userId: number, payload)
	local success, err
	for i = 1, 3 do
		success, err = pcall(function()
			ProgressStore:SetAsync("u_" .. tostring(userId), payload)
		end)
		if success then return true end
		task.wait(0.5 * i)
	end
	warn(("Save failed for %d: %s"):format(userId, tostring(err)))
	return false
end

local function tryLoad(userId: number)
	local success, data = pcall(function()
		return ProgressStore:GetAsync("u_" .. tostring(userId))
	end)
	if success and typeof(data) == "table" then
		return data
	end
	return {Level = 1, Exp = 0}
end

-- 서버에서 플레이어 상태를 단일 소스로 관리(Attributes + leaderstats)
local function initPlayerState(player: Player)
	-- 데이터 로드
	local data = tryLoad(player.UserId)
	local level = math.max(1, tonumber(data.Level) or 1)
	local exp = math.max(0, tonumber(data.Exp) or 0)

	-- leaderstats(가시성)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local lvValue = Instance.new("IntValue")
	lvValue.Name = "Level"
	lvValue.Value = level
	lvValue.Parent = leaderstats

	-- 표시용(원하면 숨겨도 됨). Exp, ExpToNext를 숫자로 보이고 싶다면 남겨두세요
	--local expValue = Instance.new("IntValue")
	--expValue.Name = "Exp"
	--expValue.Value = exp
	--expValue.Parent = leaderstats

	--local goalValue = Instance.new("IntValue")
	--goalValue.Name = "ExpToNext"
	--goalValue.Value = ExpToNext(level)
	--goalValue.Parent = leaderstats

	 --Attributes (클라가 Changed 시그널로 관찰하기 쉬움)
	--player:SetAttribute("Level", level)
	--player:SetAttribute("Exp", exp)
	--player:SetAttribute("ExpToNext", goalValue.Value)

	-- --첫 동기화
	--LevelSync:FireClient(player, {
	--	Level = level,
	--	Exp = exp,
	--	ExpToNext = goalValue.Value,
	--})
end

-- 경험치 지급(반복적으로 레벨업 처리)
local function addExp(player: Player, amount: number)
	if not player or not player.Parent then return end
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return end -- 음수/0 방어

	local level = player:GetAttribute("Level") or 1
	local exp = player:GetAttribute("Exp") or 0
	local goal = player:GetAttribute("ExpToNext") or ExpToNext(level)

	exp += amount

	-- 여러 레벨 연속 상승 처리
	while exp >= goal do
		exp -= goal
		level += 1
		goal = ExpToNext(level)
	end

	-- 상태 반영
	player:SetAttribute("Level", level)
	player:SetAttribute("Exp", exp)
	player:SetAttribute("ExpToNext", goal)

	-- leaderstats 동기
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local lv = ls:FindFirstChild("Level"); if lv then lv.Value = level end
		local ex = ls:FindFirstChild("Exp"); if ex then ex.Value = exp end
		local gv = ls:FindFirstChild("ExpToNext"); if gv then gv.Value = goal end
	end

	-- 클라 HUD 업데이트
	LevelSync:FireClient(player, {Level = level, Exp = exp, ExpToNext = goal})
end

-- RemoteEvent(클라가 퀘스트 완료 후 호출)
QuestCleared.OnServerEvent:Connect(function(player: Player, payload)
	-- 보안(치트 방어): 서버에서 금액 검증/상한
	local reward = 0
	if typeof(payload) == "table" then
		reward = tonumber(payload.exp) or 0
	else
		reward = tonumber(payload) or 0
	end

	-- 예시: 1회 경험치 상한 10,000, 음수 금지
	if reward <= 0 or reward > 10_000 then
		warn(("Blocked abnormal exp from %s: %s"):format(player.Name, tostring(reward)))
		return
	end

	addExp(player, reward)
end)

Players.PlayerAdded:Connect(function(player)
	initPlayerState(player)
end)

Players.PlayerRemoving:Connect(function(player)
	local payload = {
		Level = player:GetAttribute("Level") or 1,
		Exp = player:GetAttribute("Exp") or 0,
	}
	trySave(player.UserId, payload)
end)

-- 서버 종료 시 안전 저장(가능한 범위)
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local payload = {
			Level = player:GetAttribute("Level") or 1,
			Exp = player:GetAttribute("Exp") or 0,
		}
		trySave(player.UserId, payload)
	end
end)


-- ✅ ExperienceService 테이블에 연결
ExperienceService.AddExp = addExp
ExperienceService.ExpToNext = ExpToNext

-- 필요하다면 initPlayerState, trySave, tryLoad 등도 공개
ExperienceService.InitPlayerState = initPlayerState

return ExperienceService
