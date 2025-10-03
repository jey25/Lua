--!strict
local Players          = game:GetService("Players")
local ServerStorage    = game:GetService("ServerStorage")
local ReplicatedStorage= game:GetService("ReplicatedStorage")

local CheatBus = ServerStorage:WaitForChild("CheatBus") :: BindableEvent
local CoinService = require(game:GetService("ServerScriptService"):WaitForChild("CoinService"))

local Remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local CoinPopupEvent = Remotes:WaitForChild("CoinPopupEvent") :: RemoteEvent

local function add5CoinsCapped(player: Player)
	-- 퍼블릭 API만 사용
	local before = CoinService:GetBalance(player)
	local cap    = CoinService:GetMaxFor(player)
	local after  = math.clamp(before + 5, 0, cap)
	if after == before then return end

	CoinService:SetBalance(player, after)
	-- (선택) 팝업 1회
	pcall(function() CoinPopupEvent:FireClient(player) end)
end

(CheatBus :: BindableEvent).Event:Connect(function(msg: any)
	if not msg then return end
	if msg.action == "coin.add5" then
		local plr = msg.player :: Player
		if plr then add5CoinsCapped(plr) end
	end
end)
