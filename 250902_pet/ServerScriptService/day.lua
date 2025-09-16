-- ServerScriptService/ClockDayServer.server.lua
--!strict
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")
local RunService        = game:GetService("RunService")
local Lighting          = game:GetService("Lighting")

-- ▣ 하루 길이(현실 초) — 여기만 바꾸면 게임의 '체감 속도'가 바뀐다.
local WORLD_SECONDS_PER_GAME_DAY = 2400  -- 40분/하루 (원하는 값으로 조절)
-- UI 전송 주기(초): 1초마다 업데이트
local SEND_INTERVAL_SEC = 1.0

-- RemoteEvent
local event = ReplicatedStorage:FindFirstChild("ClockUpdateEvent")
if not event then
	event = Instance.new("RemoteEvent")
	event.Name = "ClockUpdateEvent"
	event.Parent = ReplicatedStorage
end

-- Day 저장소
local DAY_STORE = DataStoreService:GetDataStore("PlayerDayStore")

-- 접속자별 Day
local playerDays: {[number]: number} = {}

-- 안전 ClockTime 읽기/쓰기
local function safeGetClock(): number
	local v = tonumber(Lighting.ClockTime)
	if not v or v ~= v then return 0 end
	return v % 24
end
local function safeSetClock(v: number)
	local ok, err = pcall(function()
		Lighting.ClockTime = (tonumber(v) or 0) % 24
	end)
	if not ok then warn("[Clock] set failed:", err) end
end

-- Day I/O
local function loadDay(userId: number): number
	local ok, data = pcall(function() return DAY_STORE:GetAsync("u_"..userId) end)
	if ok and tonumber(data) then
		return math.max(1, math.floor(data))
	end
	return 1
end
local function saveDay(userId: number, day: number)
	pcall(function() DAY_STORE:SetAsync("u_"..userId, math.max(1, math.floor(day))) end)
end

-- 입장/퇴장
Players.PlayerAdded:Connect(function(plr)
	local d = loadDay(plr.UserId)
	playerDays[plr.UserId] = d
	plr:SetAttribute("GameDay", d)
	-- 현재 스냅샷 즉시 전송
	event:FireClient(plr, safeGetClock(), d)
end)
Players.PlayerRemoving:Connect(function(plr)
	local d = playerDays[plr.UserId]
	if d then saveDay(plr.UserId, d) end
	playerDays[plr.UserId] = nil
end)
game:BindToClose(function()
	for _, plr in ipairs(Players:GetPlayers()) do
		local d = playerDays[plr.UserId]
		if d then saveDay(plr.UserId, d) end
	end
end)

-- 전역 시계 루프
local worldHours = safeGetClock()             -- 0~24
local hoursPerRealSecond = 24 / WORLD_SECONDS_PER_GAME_DAY
local prevHours = worldHours
local sendAcc = 0

RunService.Heartbeat:Connect(function(dt: number)
	dt = (typeof(dt) == "number") and dt or 0

	-- 시계 진행
	worldHours += dt * hoursPerRealSecond

	-- 24h 래핑 처리(한 프레임에 여러 번 넘어가도 정확)
	if worldHours >= 24 then
		local wraps = math.floor(worldHours / 24)
		worldHours -= wraps * 24
		-- 접속자 Day += wraps
		if wraps > 0 then
			for _, plr in ipairs(Players:GetPlayers()) do
				local uid = plr.UserId
				local nd = (playerDays[uid] or 1) + wraps
				playerDays[uid] = nd
				plr:SetAttribute("GameDay", nd)
				task.spawn(saveDay, uid, nd)  -- 즉시 저장(안전)
			end
		end
	end

	-- 서버 권위 Time 반영
	safeSetClock(worldHours)
	prevHours = worldHours

	-- 1초마다 현재 Time/개인 Day 브로드캐스트
	sendAcc += dt
	if sendAcc >= SEND_INTERVAL_SEC then
		sendAcc = 0
		for _, plr in ipairs(Players:GetPlayers()) do
			event:FireClient(plr, worldHours, playerDays[plr.UserId] or 1)
		end
	end
end)
