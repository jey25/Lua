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

--FightPlate 에서 카운트 30초 시작
local function UpdateFightplate()
    for i = 10, 1, -1 do
        GameMessage.Value = i .. "초가 남았습니다."
        wait(1)
    end

    GameStarted.Value = false
end

-- GameStarted 가 true 로 변경되면 캐릭터들을 spawnpoint 로 이동시킴
GameStarted.Changed:Connect(function()
    if GameStarted.Value == true then
        for i, player in pairs(game.Players:GetChildren()) do
            local character = player.Character
            local position = SpawnPoint[i].CFrame
            position = position + Vector3.new(0, 10, 0)
            character.HumanoidRootPart.CFrame = position

            --검 지급
            local tool = game.ReplicatedStorage.ClassicSword:Clone()
            tool.Parent = player.Backpack
            character.Humanoid:EquipTool(tool)

        end

        UpdateFightplate()
    else
        for i, player in pairs(game.Players:GetChildren()) do
            local character = player.Character
            local position = game.Workspace.Lobby.SpawnLocation.CFrame
            position = position + Vector3.new(0, 10, 0)
            character.HumanoidRootPart.CFrame = position

            --검 회수
            for _, obj in pairs(character:GetChildren()) do
                if obj:IsA("Tool") then
                    obj:Destroy()
                end
            end

            for _, obj in pairs(player.Backpack:GetChildren()) do
                if obj:IsA("Tool") then
                    obj:Destroy()
                end
            end

        end

        UpdateLobby()
    end

end)

UpdateLobby()


-- ScreenGui 에서 ReplicatedStorage 의 GameMessage 값을 가져오는 스크립트

local GameMessage = game.ReplicatedStorage.GameMessage
local GameState = script.Parent.GameState


GameMessage.Changed:Connect(function()
    GameState.Text = GameMessage.Value
end)

--swordScript
local Enemy = nil
local CanAttack = false

local function Attack()
    Enemy = nil

    local anim = Instance.new("StringValue")
    anim.Name = "toolanim"
    anim.Value = "Slash"
    anim.Parent = script.Parent

    CanAttack = true

    wait(2.0)

    CanAttack = false

end

local function OnTouched(touchedPart)
    local humanoid = touchedPart.Parent:FindFirstChild("Humanoid")

    if not humanoid then
        return
    end

    if Enemy == nil and CanAttack then

        Enemy = humanoid
        humanoid:TakeDamage(30)

    end

end

script.Parent.Activated:Connect(Attack)
script.Parent.Handle.Touched:Connect(OnTouched)
