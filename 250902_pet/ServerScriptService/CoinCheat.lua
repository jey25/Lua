--!strict
local ServerStorage      = game:GetService("ServerStorage")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

-- CheatBus (라우터가 만들어둔 것)
local CheatBus = ServerStorage:WaitForChild("CheatBus") :: BindableEvent

-- CoinService 모듈 경로에 맞게 require
local CoinService = require(game:GetService("ServerScriptService"):WaitForChild("CoinService"))

-- UI 팝업 (선택: 한번만 띄우기)
local Remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local CoinPopupEvent = Remotes:WaitForChild("CoinPopupEvent") :: RemoteEvent


local function add5CoinsCapped(player: Player)
	if not CoinService._profiles[player.UserId] and CoinService._load then
		CoinService:_load(player)
	end

	local before = CoinService:GetBalance(player)
	-- [CHANGED] 고정 MAX_COINS 대신 동적 상한 사용
	local maxCap = CoinService:GetMaxFor(player)

	if before >= maxCap then return end
	local toAdd = math.max(0, math.min(5, maxCap - before))
	if toAdd <= 0 then return end

	if CoinService._add then
		CoinService:_add(player, toAdd)
	else
		for i = 1, toAdd do CoinService:Award(player) end
	end

	pcall(function() CoinPopupEvent:FireClient(player) end)
end


(CheatBus :: BindableEvent).Event:Connect(function(msg: any)
	if not msg then return end
	if msg.action == "coin.add5" then
		local plr = msg.player :: Player
		if plr then add5CoinsCapped(plr) end
	end
end)

