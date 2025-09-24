--!strict
-- ServerScriptService/BlockService.lua
local Players = game:GetService("Players")
local DSS = game:GetService("DataStoreService")
local RS  = game:GetService("ReplicatedStorage")
local MS  = game:GetService("MessagingService")

local BlocksEvent = RS:FindFirstChild("Blocks_Update") :: RemoteEvent
if not BlocksEvent then
	BlocksEvent = Instance.new("RemoteEvent")
	BlocksEvent.Name = "Blocks_Update"
	BlocksEvent.Parent = RS
end

-- ▷ 리더보드 업데이트 신호
local LB_TOPIC = "BlocksLB_DIRTY"

local STORE     = DSS:GetDataStore("Blocks_V1")
local ODS       = DSS:GetOrderedDataStore("BlocksLB_V1") -- ← 정렬용
local KEY_PREFIX = "blocks_"

local blocks: {[number]: number} = {}
local displayNameMap: {[number]: string} = {}

local M = {}

local function clampNonNeg(n: number): number
	return (n < 0) and 0 or n
end

-- 모든 온라인 유저 스냅샷을 한 클라에 보냄(키는 문자열로!)
local function pushFull(toPlr: Player)
	local payload: {[string]: {name: string, blocks: number}} = {}
	for _, p in ipairs(Players:GetPlayers()) do
		payload[tostring(p.UserId)] = {
			name   = displayNameMap[p.UserId] or p.DisplayName,
			blocks = blocks[p.UserId] or 0
		}
	end
	BlocksEvent:FireClient(toPlr, "full", payload)
end

local function pushDelta(userId: number)
	BlocksEvent:FireAllClients("delta", userId, blocks[userId] or 0, displayNameMap[userId] or "")
end

-- ===== OrderedDataStore & 메시징 =====
local function updateOrdered(userId: number)
	local val = blocks[userId] or 0
	pcall(function()
		ODS:SetAsync(tostring(userId), val) -- 숫자 값만!
	end)
	-- 다른 서버에 "리더보드 갱신 필요" 통지 (부하 줄이려면 디바운스는 LeaderboardService에서)
	pcall(function()
		MS:PublishAsync(LB_TOPIC, {uid = userId, v = val, t = os.time()})
	end)
end

-- ===== Public API =====
function M.Get(userId: number): number
	return blocks[userId] or 0
end

function M.Set(userId: number, value: number)
	blocks[userId] = clampNonNeg(math.floor(value))
	pushDelta(userId)
	updateOrdered(userId)
end

-- from → to 로 amount 전송 (from 잔액 부족 시 아무 일 없음)
function M.Transfer(fromPlr: Player | number, toPlr: Player | number, amount: number)
	if amount <= 0 then return end
	local fromId = (typeof(fromPlr) == "Instance") and (fromPlr :: Player).UserId or (fromPlr :: number)
	local toId   = (typeof(toPlr)   == "Instance") and (toPlr   :: Player).UserId or (toPlr   :: number)

	local fromBal = blocks[fromId] or 0
	if fromBal < amount then
		return -- 패자에게 포인트 없으면 승자 증가도 없음(요구사항)
	end
	blocks[fromId] = fromBal - amount
	blocks[toId]   = (blocks[toId] or 0) + amount

	pushDelta(fromId)
	pushDelta(toId)

	updateOrdered(fromId)
	updateOrdered(toId)
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
	if saved <= 0 then
		return 10 -- 이전 종료 시 0 이하면 다음 접속 때 10 지급
	else
		return saved
	end
end

-- ===== Player Hooks =====
Players.PlayerAdded:Connect(function(plr: Player)
	displayNameMap[plr.UserId] = plr.DisplayName
	local startVal = loadUser(plr.UserId)
	blocks[plr.UserId] = clampNonNeg(startVal)

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
end)

return M