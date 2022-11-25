-- 게임 내 스코어 보드 생성

game.Players.PlayerAdded:Connect(function(plr)
    local leaderstats = Instance.new("IntValue")
    leaderstats.Name = "leaderstats"
    leaderstats.Parent = plr

    local money = Instance.new("IntValue")
    money.Name = "kill"
    money.Value = 0
    money.Parent = leaderstats
    

    plr.CharacterAdded:Connect(function (char)
        char.Humanoid.Died:Connect(function ()
            local creator = char.Humanoid:FindFirstChild("creator")

            if creator then
                local killplr = creator.Value

                if killplr then
                    killplr.leaderstats.kill.Value += 1
                end
            end
        end)
    end)
end)
