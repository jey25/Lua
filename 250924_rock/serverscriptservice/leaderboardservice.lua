--!strict
-- ServerScriptService/LeaderboardService.lua
local DSS = game:GetService("DataStoreService")
local RS  = game:GetService("ReplicatedStorage")
local MS  = game:GetService("MessagingService")
local Players = game:GetService("Players")

-- Remote for clients
local LBEvent = RS:FindFirstChild("BlocksLeaderboard") :: RemoteEvent
if not LBEvent then
	local ev = Instance.new("RemoteEvent")
	ev.Name = "BlocksLeaderboard"
	ev.Parent = RS
	LBEvent = ev
end

local ODS = DSS:GetOrderedDataStore("BlocksLB_V1")
local LB_TOPIC = "BlocksLB_DIRTY"

local currentTop: { {userId: number, name: string, blocks: number} } = {}
local lastRefreshAt = 0
local REFRESH_COOLDOWN = 15 -- 최소 15초 간격
local POLL_INTERVAL    = 60 -- 안전 폴링

local nameCache: {[number]: string} = {}

local function getName(uid: number): string
	local cached = nameCache[uid]
	if cached then return cached end
	local ok, name = pcall(function()
		-- DisplayName까지 원하면 UserService 사용; 여기선 Username으로 충분
		return Players:GetNameFromUserIdAsync(uid)
	end)
	if not ok or type(name) ~= "string" then
		name = ("User %d"):format(uid)
	end
	nameCache[uid] = name
	return name
end

local function broadcastTop()
	LBEvent:FireAllClients("top", currentTop)
end

local function refreshTop(maxCount: number)
	if os.time() - lastRefreshAt < REFRESH_COOLDOWN then return end
	lastRefreshAt = os.time()

	local ok, pages = pcall(function()
		-- 내림차순(큰 값이 먼저),  maxCount개
		return ODS:GetSortedAsync(false, maxCount)
	end)
	if not ok then
		warn("[Leaderboard] GetSortedAsync failed")
		return
	end
	local page = pages:GetCurrentPage()
	local out: { {userId: number, name: string, blocks: number} } = {}

	for _, entry in ipairs(page) do
		local uid = tonumber(entry.key)
		local value = (typeof(entry.value) == "number") and (entry.value :: number) or 0
		if uid then
			table.insert(out, {
				userId = uid,
				name   = getName(uid),
				blocks = value,
			})
		end
	end

	currentTop = out
	broadcastTop()
end

-- 메시징 수신 → 갱신 시도(쿨다운 적용)
local _subOk, _subConn = pcall(function()
	return MS:SubscribeAsync(LB_TOPIC, function(_msg)
		refreshTop(25)
	end)
end)
if not _subOk then
	warn("[Leaderboard] Subscribe failed; polling only.")
end

-- 안전 폴링
task.spawn(function()
	while true do
		refreshTop(25)
		task.wait(POLL_INTERVAL)
	end
end)

-- 새로 들어온 플레이어에게 현재 TOP 즉시 전송
Players.PlayerAdded:Connect(function(plr)
	if #currentTop > 0 then
		LBEvent:FireClient(plr, "top", currentTop)
	else
		refreshTop(25)
	end
end)

