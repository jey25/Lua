-- 게임 내 스코어 보드 생성
local datastore = game:GetService("DataStoreService"):GetDataStore("Playerstats")

game.Players.PlayerAdded:Connect(function(plr)
    local leaderstats = Instance.new("IntValue")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = plr

    local money = Instance.new("IntValue")
    money.Name = "kill"
    money.Value = 0
    money.Parent = leaderstats

    local data = datastore:GetAsync(plr.UserId) --데이터 불러옴
    if data then --데이터 있으면
        money.Value = data -- 있는 데이터를 Money 에 옮김
    end

    --plr.CharacterAdded:Connect(function (char)
    --	char.Humanoid.Died:Connect(function ()
    --		local creator = char.Humanoid:FindFirstChild("creator")

    --		if creator then
    --			local killplr = creator.Value

    --			if killplr then
    --				killplr.leaderstats.kill.Value += 1
    --			end
    --		end
    --	end)
    --end)
end)

game.Players.PlayerRemoving:Connect(function(plr) --플레이어가 나갔을 때
    local s, e = pcall(function() --가끔 데이터 저장에 실패하는 경우 스크립트를 중단하지 않게
        datastore:SetAsync(plr.UserId, plr.leaderstats.Money.Value) -- Money 데이터 저장
    end)
end)
