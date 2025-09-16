-- ServerScriptService/CoinService
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local store = DataStoreService:GetDataStore("GameCoins_v2") -- 버전 업
local Remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
local CoinUpdate = Remotes:FindFirstChild("CoinUpdate") or Instance.new("RemoteEvent", Remotes)
CoinUpdate.Name = "CoinUpdate"

local CoinService = {}

-- 🔧 설정
CoinService.MAX_COINS = 6               -- 상한 (원하면 바꾸기)
CoinService.LEVEL_THRESHOLDS = {5,10,15,20} -- 해당 레벨 "이상" 달성 시 1회 지급

-- 내부 상태
CoinService._profiles = {}   -- [userId] = {coins, awarded(map), dirty, lastSave}
CoinService._anyNeedCache = true -- 누군가 < MAX_COINS 인가(캐시)

local function toMap(tbl)
	local m = {}
	if typeof(tbl) == "table" then
		for k, v in pairs(tbl) do
			if typeof(k) == "string" then m[k] = v and true or false
			elseif typeof(v) == "string" then m[v] = true end
		end
	end
	return m
end

local function fireUpdate(player, coins)
	pcall(function() CoinUpdate:FireClient(player, coins) end)
end

local function recomputeAnyNeed()
	for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
		local p = CoinService._profiles[plr.UserId]
		if p and (p.coins or 0) < CoinService.MAX_COINS then
			CoinService._anyNeedCache = true
			return
		end
	end
	CoinService._anyNeedCache = false
end

function CoinService:_load(player)
	local key = ("p:%d"):format(player.UserId)
	local data
	local ok, err = pcall(function() data = store:GetAsync(key) end)
	if not ok or typeof(data) ~= "table" then data = {coins = 0, awarded = {}} end
	data.coins = math.clamp(tonumber(data.coins) or 0, 0, self.MAX_COINS)
	data.awarded = toMap(data.awarded)
	data.dirty, data.lastSave = false, 0
	self._profiles[player.UserId] = data
	fireUpdate(player, data.coins)
	recomputeAnyNeed()
end

function CoinService:_save(userId)
	local profile = self._profiles[userId]; if not profile then return end
	local now = os.clock()
	if (now - (profile.lastSave or 0)) < 15 and not game:GetService("RunService"):IsStudio() then return end
	local key = ("p:%d"):format(userId)
	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old)
			old = old or {}
			old.coins = math.clamp(profile.coins or 0, 0, CoinService.MAX_COINS)
			local out = {}
			for k, v in pairs(profile.awarded or {}) do if v then out[k] = true end end
			old.awarded = out
			return old
		end)
	end)
	if ok then profile.dirty, profile.lastSave = false, now else warn("Coin save failed:", err) end
end

function CoinService:_remove(player)
	self:_save(player.UserId)
	self._profiles[player.UserId] = nil
	recomputeAnyNeed()
end

function CoinService:GetBalance(player)
	local p = self._profiles[player.UserId]; return p and p.coins or 0
end

function CoinService:AnyPlayerNeedsCoins() -- 스포너가 참조
	return self._anyNeedCache
end

-- 내부 증감(0~MAX_COINS 클램프)
function CoinService:_add(player, delta)
	local p = self._profiles[player.UserId]; if not p then return end
	local before = p.coins or 0
	local after = math.clamp(math.floor(before + delta), 0, self.MAX_COINS)
	if after == before then return end
	p.coins = after; p.dirty = true
	fireUpdate(player, after)
	recomputeAnyNeed()
end

-- 1코인 지급(중복방지 key 있으면 1회성)
function CoinService:Award(player, keyOrNil)
	local p = self._profiles[player.UserId]; if not p then return false end
	if (p.coins or 0) >= self.MAX_COINS then return false end
	if keyOrNil then
		if p.awarded[keyOrNil] then return false end
		p.awarded[keyOrNil] = true
	end
	self:_add(player, 1)
	return true
end

-- 구매(차감)
function CoinService:TrySpend(player, cost:number)
	cost = math.max(0, math.floor(cost or 0))
	local p = self._profiles[player.UserId]; if not p then return false end
	if (p.coins or 0) < cost then return false end
	self:_add(player, -cost)
	return true
end

-- 레벨 변화에 따른 1회성 지급
function CoinService:OnLevelChanged(player, newLevel:number)
	local p = self._profiles[player.UserId]; if not p then return end
	for _, lv in ipairs(self.LEVEL_THRESHOLDS) do
		if newLevel >= lv then
			local k = ("LV:%d"):format(lv)
			if not p.awarded[k] then p.awarded[k] = true; self:_add(player, 1) end
		end
	end
end

-- 주기 저장
task.spawn(function()
	while task.wait(30) do
		for userId in pairs(CoinService._profiles) do CoinService:_save(userId) end
	end
end)

return CoinService
