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


--블록 무한 회전

while true do
    wait()
    script.Parent.CFrame = script.Parent.CFrame * CFrame.fromEulerAnglesXYZ(0.1, 0, 0)
end



--캐릭터 네임 태그 설정
------------------------ 기초 설정 (지우지 마세요)

local clone = game.ReplicatedStorage:WaitForChild("NameTag"):Clone()

clone.Parent = script.Parent.Head
script.Parent = clone

local plr = game.Players:GetPlayerFromCharacter(script.Parent.Parent.Parent)
script.Parent.Parent.Parent:WaitForChild("Humanoid").DisplayDistanceType = "None"

------------------------ 체력바

local hpbar = script.Parent.Frame

script.Parent.Parent.Parent:WaitForChild("Humanoid"):GetPropertyChangedSignal

("Health"):Connect(function()

    local Maxhp = script.Parent.Parent.Parent.Humanoid.MaxHealth

    local hp = script.Parent.Parent.Parent.Humanoid.Health

    local v = hp / Maxhp

    hpbar.Frame:TweenSize((UDim2.new(v, 0, 1, 0)), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15)
end)

------------------------ 이름 태그 표시

script.Parent.name.Text = plr.Name

------------------------ 제작자, 부제작자, 플레이어 태그 표시

local creator = "meka5146"
local creator2 = "..."

if plr.Name == creator then
    script.Parent.player.Text = "[제작자]"
    script.UIGradient.Parent = script.Parent.player
elseif plr.Name == creator2 then
    script.Parent.player.Text = "[부제작자]"
    script.UIGradient.Parent = script.Parent.player
elseif plr.Name ~= creator and plr.Name ~= creator2 then
    script.Parent.player.Text = "[플레이어]"
end

------------------------ 팀 컬러, 이름 표시

script.Parent.team.Text = plr.Team.Name
script.Parent.team.TextColor = plr.TeamColor

------------------------
