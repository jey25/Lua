--!strict
-- ServerScriptService/BlockService.lua

local Players = game:GetService("Players")
local DSS     = game:GetService("DataStoreService")
local RS      = game:GetService("ReplicatedStorage")
local MS      = game:GetService("MessagingService")

local GameOverManager = require(ServerScriptService:WaitForChild("GameOverManager"))


-- ===== Remotes =====
local BlocksEvent = RS:FindFirstChild("Blocks_Update") :: RemoteEvent
if not BlocksEvent then
	BlocksEvent = Instance.new("RemoteEvent")
	BlocksEvent.Name = "Blocks_Update"
	BlocksEvent.Parent = RS
end

-- 리더보드 갱신 신호 (다중 서버 알림용)
local LB_TOPIC   = "BlocksLB_DIRTY"

-- ===== Datastores =====
local STORE      = DSS:GetDataStore("Blocks_V1")
local ODS        = DSS:GetOrderedDataStore("BlocksLB_V1") -- 정렬용
local KEY_PREFIX = "blocks_"

-- ===== In-memory state =====
local blocks: {[number]: number} = {}
local displayNameMap: {[number]: string} = {}

local M = {}

local function clampNonNegInt(n: number): number
	n = math.floor(n)
	return (n < 0) and 0 or n
end

-- ===== Push helpers =====
local function pushFull(toPlr: Player)
	local payload: {[string]: {name: string, blocks: number}} = {}
	for _, p in ipairs(Players:GetPlayers()) do
		payload[tostring(p.UserId)] = {
			name   = displayNameMap[p.UserId] or p.DisplayName,
			blocks = blocks[p.UserId] or 0,
		}
	end
	BlocksEvent:FireClient(toPlr, "full", payload)
end

local function pushDelta(userId: number)
	BlocksEvent:FireAllClients("delta", userId, blocks[userId] or 0, displayNameMap[userId] or "")
end

-- OrderedDataStore & Messaging (비동기)
local function updateOrdered(userId: number)
	local val = blocks[userId] or 0
	task.spawn(function()
		local ok1, err1 = pcall(function()
			ODS:SetAsync(tostring(userId), val)
		end)
		if not ok1 then warn("[BlockService] ODS:SetAsync fail", userId, err1) end

		local ok2, err2 = pcall(function()
			MS:PublishAsync(LB_TOPIC, {uid = userId, v = val, t = os.time()})
		end)
		if not ok2 then warn("[BlockService] MS:PublishAsync fail", userId, err2) end
	end)
end

-- 종료 조건 검사
local function checkAndEndIfAnyZero()
	for _, pl in ipairs(Players:GetPlayers()) do
		if (blocks[pl.UserId] or 0) <= 0 then
			-- 클라에 게임 종료 브로드캐스트(or Round 관리자 호출)
			BlocksEvent:FireAllClients("gameover", pl.UserId)
			GameOverManager.EndGame(loserUserId)
			-- TODO: 서버 측 라운드/게임 종료 처리 호출 (예: RoundService.EndNow())
			return true
		end
	end
	return false
end

-- ===== Public API =====
function M.Get(userId: number): number
	return blocks[userId] or 0
end

-- 0 도달 검사 지점 추가
function M.Set(userId: number, value: number)
	blocks[userId] = clampNonNegInt(value)
	pushDelta(userId)
	updateOrdered(userId)
	checkAndEndIfAnyZero()
end

-- BlockService.lua 하단 “Public API” 근처에 추가
function M.SaveSync(userId: number)
	local ok, err = pcall(saveUser, userId) -- spawn 없이 동기 호출
	if not ok then warn("[BlockService] SaveSync failed:", userId, err) end
end

function M.SaveAllSync()
	for _, pl in ipairs(Players:GetPlayers()) do
		M.SaveSync(pl.UserId)
	end
end

-- 서버 종료/서버이동 대비
game:BindToClose(function()
	M.SaveAllSync()
	-- DS 예산 여유용 짧은 대기(선택)
	task.wait(1)
end)


function M.Add(userId: number, delta: number)
	if delta == 0 then return end
	M.Set(userId, (blocks[userId] or 0) + delta)
end

-- from → to 로 amount 전송 (from 잔액 부족 시 아무 일 없음)
function M.Transfer(fromPlr: Player | number, toPlr: Player | number, amount: number)
	amount = clampNonNegInt(amount)
	if amount <= 0 then return end

	local fromId = (typeof(fromPlr) == "Instance") and (fromPlr :: Player).UserId or (fromPlr :: number)
	local toId   = (typeof(toPlr)   == "Instance") and (toPlr   :: Player).UserId or (toPlr   :: number)

	local fromBal = blocks[fromId] or 0
	if fromBal < amount then
		-- 패자에게 포인트 없으면 승자 증가도 없음(요구사항)
		return
	end

	blocks[fromId] = fromBal - amount
	blocks[toId]   = (blocks[toId] or 0) + amount

	pushDelta(fromId)
	pushDelta(toId)
	updateOrdered(fromId)
	updateOrdered(toId)
	checkAndEndIfAnyZero()
end

function M.ApplyRoundResult(p1: Player, p2: Player, who: "p1"|"p2"|"draw")
	if who == "p1" then
		M.Transfer(p2, p1, 1)
	elseif who == "p2" then
		M.Transfer(p1, p2, 1)
	end
end

-- ===== 영속화 =====
local function saveUser(userId: number)
	local val = blocks[userId] or 0
	local ok, err = pcall(function()
		STORE:SetAsync(KEY_PREFIX .. tostring(userId), val)
	end)
	if not ok then warn("[BlockService] Save failed:", userId, err) end
end

local function loadUser(userId: number): number
	local saved = 0
	local ok, res = pcall(function()
		return STORE:GetAsync(KEY_PREFIX .. tostring(userId))
	end)
	if ok and typeof(res) == "number" then
		saved = math.floor(res)
	else
		saved = 0
	end
	-- 이전 종료 시 0 이하면 다음 접속 때 10 지급
	if saved <= 0 then
		return 10
	else
		return saved
	end
end

function M.ForceSave(userId: number)
	task.spawn(function()
		pcall(saveUser, userId)
	end)
end

function M.ForceSaveAll()
	for _, pl in ipairs(Players:GetPlayers()) do
		M.ForceSave(pl.UserId)
	end
end

-- ===== Player Hooks =====
Players.PlayerAdded:Connect(function(plr: Player)
	displayNameMap[plr.UserId] = plr.DisplayName
	local startVal = loadUser(plr.UserId)
	blocks[plr.UserId] = clampNonNegInt(startVal)

	-- 새로 들어온 유저에게 현재 온라인 전체 스냅샷
	pushFull(plr)
	-- 모두에게 이 유저의 값 브로드캐스트
	pushDelta(plr.UserId)
	-- 오더드에도 반영
	updateOrdered(plr.UserId)
end)

Players.PlayerRemoving:Connect(function(plr: Player)
	saveUser(plr.UserId)
	updateOrdered(plr.UserId)
	BlocksEvent:FireAllClients("leave", plr.UserId)

	-- ★ 메모리 정리
	blocks[plr.UserId] = nil
	displayNameMap[plr.UserId] = nil
end)

return M
