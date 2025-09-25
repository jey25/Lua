--!strict
-- ServerScriptService/LeaderboardService.lua
local DSS     = game:GetService("DataStoreService")
local RS      = game:GetService("ReplicatedStorage")
local MS      = game:GetService("MessagingService")
local Players = game:GetService("Players")

-- ===== Remote =====
local LBEvent = RS:FindFirstChild("BlocksLeaderboard") :: RemoteEvent
if not LBEvent then
	LBEvent = Instance.new("RemoteEvent")
	LBEvent.Name = "BlocksLeaderboard"
	LBEvent.Parent = RS
end

-- ===== Config / Stores =====
local ODS       = DSS:GetOrderedDataStore("BlocksLB_V1")
local LB_TOPIC  = "BlocksLB_DIRTY"
local MAX_TOP           = 25
local REFRESH_COOLDOWN  = 15  -- 최소 15초 간격
local POLL_INTERVAL     = 60  -- 안전 폴링

-- ===== State =====
type TopEntry = { userId: number, name: string, blocks: number }
local currentTop: {TopEntry} = {}
local lastRefreshAt = 0
local nameCache: {[number]: string} = {}

-- ===== Utils =====
local function shallowEqualTop(a: {TopEntry}, b: {TopEntry}): boolean
	if #a ~= #b then return false end
	for i = 1, #a do
		local x, y = a[i], b[i]
		if not x or not y then return false end
		if x.userId ~= y.userId or x.blocks ~= y.blocks or x.name ~= y.name then
			return false
		end
	end
	return true
end

local function getName(uid: number): string
	local cached = nameCache[uid]
	if cached then return cached end
	local ok, nm = pcall(function()
		-- Username 기준. DisplayName이 필요하면 UserService 사용해서 추가 캐시.
		return Players:GetNameFromUserIdAsync(uid)
	end)
	local name = (ok and typeof(nm) == "string") and (nm :: string) or ("User "..tostring(uid))
	nameCache[uid] = name
	return name
end

local function broadcastTop()
	-- 현재 TOP을 모든 클라로
	LBEvent:FireAllClients("top", currentTop)
end

local function refreshTop(maxCount: number)
	-- 쿨다운
	if os.time() - lastRefreshAt < REFRESH_COOLDOWN then return end
	lastRefreshAt = os.time()

	local ok, pages = pcall(function()
		-- 정렬: false = 내림차순(값 큰 것 우선)
		return ODS:GetSortedAsync(false, maxCount)
	end)
	if not ok or not pages then
		warn("[Leaderboard] GetSortedAsync failed")
		return
	end

	local page = pages:GetCurrentPage()
	local nextTop: {TopEntry} = {}

	for _, entry in ipairs(page) do
		local uid = tonumber(entry.key)
		local value = (typeof(entry.value) == "number") and (entry.value :: number) or 0
		if uid then
			table.insert(nextTop, {
				userId = uid,
				name   = getName(uid),
				blocks = value,
			})
		end
	end

	-- 동일하면 방송 생략
	if not shallowEqualTop(currentTop, nextTop) then
		currentTop = nextTop
		broadcastTop()
	end
end

-- ===== Messaging =====
local _subOk, _subConn = pcall(function()
	return MS:SubscribeAsync(LB_TOPIC, function(_msg)
		-- 다른 서버가 값 갱신했다는 신호 → 쿨다운 반영하여 TOP 재조회
		refreshTop(MAX_TOP)
	end)
end)
if not _subOk then
	warn("[Leaderboard] Subscribe failed; fallback to polling only.")
end

-- ===== Safe polling =====
task.spawn(function()
	while true do
		refreshTop(MAX_TOP)
		task.wait(POLL_INTERVAL)
	end
end)

-- 새로 들어온 플레이어에게 현재 TOP 즉시 전송
Players.PlayerAdded:Connect(function(plr)
	if #currentTop > 0 then
		LBEvent:FireClient(plr, "top", currentTop)
	else
		refreshTop(MAX_TOP)
	end
end)
