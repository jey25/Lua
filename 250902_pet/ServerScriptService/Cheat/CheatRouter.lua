--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local DevGate           = require(game:GetService("ServerScriptService"):WaitForChild("DevGate"))

-- 공용 RemoteEvent (클라 → 서버)
local remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")


local DevCheatRE = remotes:FindFirstChild("DevCheat") :: RemoteEvent?
if not DevCheatRE then
	DevCheatRE = Instance.new("RemoteEvent")
	DevCheatRE.Name = "DevCheat"
	DevCheatRE.Parent = remotes
end

-- 서버 내부 브로드캐스트 버스 (서버 ↔ 서버)
local CheatBus = ServerStorage:FindFirstChild("CheatBus") :: BindableEvent?
if not CheatBus then
	CheatBus = Instance.new("BindableEvent")
	CheatBus.Name = "CheatBus"
	CheatBus.Parent = ServerStorage
end

-- 간단 스로틀: 플레이어별 0.3s
local lastAt: {[number]: number} = {}
local function throttled(uid: number): boolean
	local t = os.clock()
	local last = lastAt[uid] or 0
	if t - last < 0.3 then return true end
	lastAt[uid] = t
	return false
end

-- 단일 엔드포인트: action(string), payload(any)
DevCheatRE.OnServerEvent:Connect(function(plr: Player, action: any, payload: any)
	if not DevGate.isDev(plr) then return end
	if throttled(plr.UserId) then return end
	if typeof(action) ~= "string" then return end

	-- 서버 내부로 브로드캐스트 → 각 시스템(시간/스폰/템 등)이 구독
	(CheatBus :: BindableEvent):Fire({
		player = plr,
		action = action,     -- 예) "time.night", "time.set_hours"
		payload = payload,   -- 예) 숫자/테이블 등
		at = os.time(),
	})

	print(("[Cheat] %s -> %s"):format(plr.Name, action))
end)
