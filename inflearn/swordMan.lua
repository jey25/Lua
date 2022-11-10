--플레이어 인원수가 1명 이하면 대기, 1명 이상이면 10부터 카운트 후 1초가 되면 GameStarted value 값이 1로 변경

GameStarted = game.ReplicatedStorage.GameStarted
GameMessage = game.ReplicatedStorage.GameMessage

-- spawnpoint 를 가져옴
local SpawnPoint = game.Workspace.Fight.Spawnpoints:GetChildren()

local function UpdateLobby()
    while GameStarted.Value == false do
        local players = game.Players:GetChildren()
        local playerCount = #players

        if playerCount < 1 then
            GameMessage.Value = "플레이어 대기중..."
        else
            for i = 10, 1, -1 do
                GameMessage.Value = "게임 시작까지 " .. i .. "초"
                wait(1)
            end

            GameStarted.Value = true
            return

        end

        wait(1)
    end
end

-- GameStarted 가 true 로 변경되면 캐릭터들을 spawnpoint 로 이동시킴
GameStarted.Changed:Connect(function()
    if GameStarted.Value == true then
        for i, player in pairs(game.Players:GetChildren()) do
            local character = player.Character
            local position = SpawnPoint[i].CFrame
            character.HumanoidRootPart.CFrame = position
        end
    end
end)
UpdateLobby()


-- ScreenGui 에서 ReplicatedStorage 의 GameMessage 값을 가져오게 하는 스크립트

local GameMessage = game.ReplicatedStorage.GameMessage
local GameState = script.Parent.GameState


GameMessage.Changed:Connect(function()
    GameState.Text = GameMessage.Value
end)
