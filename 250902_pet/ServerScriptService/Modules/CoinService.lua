-- ServerScriptService/CoinService.lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder", ReplicatedStorage)
Remotes.Name = "RemoteEvents"

local CoinUpdate = Remotes:FindFirstChild("CoinUpdate") or Instance.new("RemoteEvent", Remotes)
CoinUpdate.Name = "CoinUpdate"

local CoinPopupEvent = Remotes:FindFirstChild("CoinPopupEvent") or Instance.new("RemoteEvent", Remotes)
CoinPopupEvent.Name = "CoinPopupEvent"

-- ✅ 추가: 클라이언트 최초 동기화를 위한 RemoteFunction
local GetCoinState = Remotes:FindFirstChild("GetCoinState") or Instance.new("RemoteFunction", Remotes)
GetCoinState.Name = "GetCoinState"

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local CoinService = {}

-- 동적 상한: BASE + (Level // 10)
CoinService.BASE_MAX_COINS = 5

local function getPlayerLevel(plr: Player): number
	return math.max(1, tonumber(plr:GetAttribute("Level")) or 1)
end

function CoinService:GetMaxFor(player: Player): number
	return (self.BASE_MAX_COINS or 0) + math.floor(getPlayerLevel(player) / 10)
end

local function fireUpdate(player: Player, coins: number)
	local max = CoinService:GetMaxFor(player)
	pcall(function() CoinUpdate:FireClient(player, coins, max) end)
end

function CoinService:_ensureLoaded(player: Player)
	PlayerDataService:Load(player) -- 필요시 로드
	fireUpdate(player, PlayerDataService:GetCoins(player))
end

function CoinService:GetBalance(player: Player): number
	return PlayerDataService:GetCoins(player)
end

function CoinService:SetBalance(player: Player, amount: number)
	amount = math.max(0, math.floor(amount or 0))
	local cap = CoinService:GetMaxFor(player)
	amount = math.clamp(amount, 0, cap)
	PlayerDataService:SetCoins(player, amount)
	fireUpdate(player, amount)
end

function CoinService:AnyPlayerNeedsCoins()
	for _, plr in ipairs(Players:GetPlayers()) do
		local okB, bal = pcall(function() return self:GetBalance(plr) end)
		local okM, max = pcall(function() return self:GetMaxFor(plr) end)
		if okB and okM and tonumber(bal) < tonumber(max) then
			return true
		end
	end
	return false
end


-- 내부 증감(동적 상한 클램프)
function CoinService:_add(player: Player, delta: number)
	self:_ensureLoaded(player)
	local before = PlayerDataService:GetCoins(player)
	local cap = self:GetMaxFor(player)
	local after = math.clamp(math.floor(before + (delta or 0)), 0, cap)
	if after == before then return end
	PlayerDataService:SetCoins(player, after)
	fireUpdate(player, after)
end

-- 1코인 지급(중복 방지 key가 있으면 1회성)
function CoinService:Award(player: Player, uniqueKeyOrNil: string?): boolean
	self:_ensureLoaded(player)
	local cap = self:GetMaxFor(player)
	if PlayerDataService:GetCoins(player) >= cap then return false end

	-- 간단한 1회성 키 관리(플레이어 Attributes로 관리: "Awarded_<key>" = true)
	if uniqueKeyOrNil then
		local attrName = "Awarded_" .. uniqueKeyOrNil
		if player:GetAttribute(attrName) then return false end
		player:SetAttribute(attrName, true)
	end

	self:_add(player, 1)
	pcall(function() CoinPopupEvent:FireClient(player) end)
	return true
end

function CoinService:TrySpend(player: Player, cost: number): boolean
	local price = math.max(0, math.floor(cost or 0))
	self:_ensureLoaded(player)
	if PlayerDataService:GetCoins(player) < price then return false end
	self:_add(player, -price)
	return true
end

function CoinService:OnLevelChanged(player: Player, a: number, b: number?)
	-- 구버전 호환: 인자가 하나면 oldLevel 추정
	local oldLevel: number, newLevel: number
	if b ~= nil then
		oldLevel, newLevel = math.max(1, math.floor(a or 1)), math.max(1, math.floor(b or 1))
	else
		newLevel = math.max(1, math.floor(a or 1))
		oldLevel = (math.max(1, tonumber(player:GetAttribute("Level")) or 1)) - 1
	end
	if newLevel <= oldLevel then return end

	-- oldLevel+1 ~ newLevel 사이에서 10의 배수마다 1회성 지급
	for lv = oldLevel + 1, newLevel do
		if lv % 10 == 0 then
			-- 고유키: "LV:<레벨>" → 중복 지급 방지
			self:Award(player, ("LV:%d"):format(lv))
			-- Award 내부에서 CoinPopupEvent를 쏘므로 머리 위 아이콘 표시됨
		end
	end

	local balance = PlayerDataService:GetCoins(player)
	fireUpdate(player, balance)
end

-- ✅ 추가: 최초 동기화용 RemoteFunction 응답 (balance, maxBalance)
GetCoinState.OnServerInvoke = function(player: Player)
	CoinService:_ensureLoaded(player)
	local balance = PlayerDataService:GetCoins(player)
	local maxBalance = CoinService:GetMaxFor(player)
	return balance, maxBalance
end

-- PlayerAdded에서 초기 코인 동기화
Players.PlayerAdded:Connect(function(plr)
	task.defer(function()
		CoinService:_ensureLoaded(plr)
	end)
end)

return CoinService
