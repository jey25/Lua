--ProfileService 사용 방법

--일반적인 DataService 이용 방법
local DataStoreService = game:GetService("DataStoreService")

--DataStore2 버그도 많고 복잡해서 사용하지 않음


-- Data 증가, 초기화 Part 버튼
local DataManagerModule = require(game.ServerScriptService.DataManager) 

script.Parent.Triggered:Connect(function(player)
	local MoneyValue = player.leaderstats.Money
	MoneyValue.Value += 1
	
	DataManagerModule:UpdateData(player, "Money", MoneyValue.Value)
end)


local DataManagerModule = require(game.ServerScriptService.DataManager) 

script.Parent.Triggered:Connect(function(player)
	local MoneyValue = player.leaderstats.Money
	MoneyValue.Value = 0
	
	DataManagerModule:UpdateData(player, "Money", MoneyValue.Value)
end)



-- leaderboard Script

local BUILD_GROUP_ID = 42

local function playerJoin(player) 

	if player:IsInGroup(BUILD_GROUP_ID) then
		player.Team = game.Teams["Blue"]
	else
		player.Team = game.Teams["Red"]
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local score = Instance.new("IntValue")
	score.Name = "Score"
	score.Value = 0
	score.Parent = leaderstats

	local rank = Instance.new("StringValue")
	rank.Name = "Rank"
	rank.Value = player:GetRankInGroup(BUILD_GROUP_ID)
	rank.Parent = leaderstats

	local role = Instance.new("StringValue")
	role.Name = "Role"
	role.Value = player:GetRoleInGroup(BUILD_GROUP_ID)
	role.Parent = leaderstats

end

game.Players.PlayerAdded:Connect(playerJoin)


