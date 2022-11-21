-- 게임 내 스코어 보드 생성

game.Players.PlayerAdded:Connect(function(plr)
    local leaderstats = Instance.new("IntValue")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = plr

    local money = Instance.new("IntValue")
    money.Name = "money"
    money.Value = 0
    money.Parent = leaderstats
end)
