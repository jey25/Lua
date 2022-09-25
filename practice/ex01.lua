
-- 체력 감소 스크립트

local Debounce = false

script.Parent.Touched:connect(function(hit)
 if hit.Parent:FindFirstChild("Humanoid")and Debounce == false then
  Debounce = true
  hit.Parent.Humanoid:TakeDamage(10)
  wait(0)
  Debounce = false
 end
end)



-- 시간에 따라 조명 켜기


local timeControl = game.Lighting         --timeControl 변수에 조명(Lighting) 속성 담기
local timeVal = 12                        --timeVal 변수에 12 담기

local brick = game.Workspace.ShiningBrick --brick 변수에 ShiningBrick 파트 담기

while true do                             --while문 조건을 참(true)으로 고정, 무한 반복
    timeControl.ClockTime = timeVal       --현재 시간을 timeVal 값으로 변경
    print(timeVal)                        --imeVal에 저장된 값 출력
    wait(2)                               --2초 쉬기

    if timeVal == 25 then                 --if문 설정 조건 - timeVal이 25와 같으면 참
        timeVal = 0                       --조건이 참이면 timeVal의 값을 0으로 변경
    end

    if timeVal > 18 then        --if문 설정 조건1 - timeVal이 18보다 크면 참
        brick.Material = "Neon" --조건1이 참이면 ShiningPart의 재질(Material)을 네온(Neon)으로 변경
    elseif timeVal < 7 then     --elseif문 설정 조건2 - timeVal이 7보다 작으면 참
        brick.Material = "Neon" --조건2가 참이면 ShiningPart의 재질(Material)을 네온(Neon)으로 변경
    else
        --조건1과 조건2가 모두 거짓이면 ShiningPart의 재질(Material)을 플라스틱(Plastic)으로 변경
        brick.Material = "Plastic"     
    end
    
    timeVal = timeVal + 1   --timeVal 값에 1을 더한 후 timeVal 변수에 저장
end


-- bgm 버튼 넣기 

local button = script.Parent
local on = script.Parent:WaitForChild("on")
local off = script.Parent:WaitForChild("off")

local Sound = Instance.new("Sound", script)

Sound.Volume = 0.5 -- 볼륨

musics = {"rbxassetid://1845385270", -- 음악 목록(아이디)
 "rbxassetid://1840265649",
 "rbxassetid://1846459727"
 
}


function playNewMusic()
 Sound:Stop()
 Sound.SoundId = musics[math.random(1, #musics)]
 Sound.Loaded:Wait() -- 바꾼 음악 아이디 로딩 대기
 Sound:Play()
end

button.MouseButton1Click:Connect(function(plr)
 if Sound.IsPlaying then -- 음악 켜져있었음(정석 방법으로 바꿈)
  off.Visible = true
  on.Visible = false
  Sound:Pause() -- 일시정지
 else -- 음악 꺼져있었음
  off.Visible = false
  on.Visible = true
  Sound:Resume() -- 다시 재생
 end
end)

Sound.Ended:Connect(function()
 if on.Visible then -- 여긴 그대로(음악은 끝까지 플레이 후 꺼진 상태라서)
  playNewMusic()
 end
end)

playNewMusic()


-- 시간 GUI

local minute = ('분')
local second = ('초')

while true do 
 if minute == 0 then
  script.Parent.Text = second .. "초"
 else
  script.Parent.Text = minute .. "분" .. second .. "초"
 end
 
 if  second == 0 then
  minute = minute - 1
  second = 60
 end
 
 second = second - 1
 
 wait(1)
end


-- 체력바 스크립트

wait(0.2)
while true do
 local hp = game.Players.LocalPlayer.Character.Humanoid.Health/100
 script.Parent:TweenSize((UDim2.new(hp,0,1,0)),Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.15)
 wait(0.2)
end


-----닿으면 죽는 스크립트-----
local function onTouch(part)
    local humanoid = part.Parent:FindFirstChild("Humanoid")
    if (humanoid) then
       humanoid.Health = 0
    end
 end
 
 script.Parent.Touched:connect(onTouch)
 

 -----피 조금 닳는 스크립트-----
 local Debounce = false
 
 script.Parent.Touched:connect(function(hit)
  if hit.Parent:FindFirstChild("Humanoid")and Debounce == false then
   Debounce = true
   hit.Parent.Humanoid:TakeDamage(10)
   wait(0)
   Debounce = false
  end
 end)

 
 -------- 피 회복 스크립트 ---------
local function onTouch(part)
    local humanoid = part.Parent:FindFirstChild("Humanoid")
    if (humanoid) then
     humanoid.Health = 100
    end
   end
   
   script.Parent.Touched:connect(onTouch)



-- 밟으면 시작되는 타이머, 다른 파트를 밟으면 끝나는 타이머
local start = game.Workspace.ggl
local stop = game.Workspace.asd
local time_label = script.Parent
local LPlayer = game.Players.LocalPlayer
local jero = 0
local timer_started = false
local completed = false

time_label.Visible = false

local function start_timer(otherPart)

	local player = game.Players:FindFirstChild(otherPart.Parent.Name)

	if player.Name == LPlayer.Name and not timer_started then
		timer_started = true
		time_label.Text = jero
		player.PlayerGui.Scree.TextLabel.Visible = true

		local time_num = tonumber(player.PlayerGui.Scree.TextLabel.Text)

		while time_num < 1000000 do
			wait(0.1)
			time_num = time_num + 0.1
			player.PlayerGui.Scree.TextLabel.Text = tostring(time_num)
		end

		timer_started = false
		completed = false
		player.PlayerGui.Scree.TextLabel.Text = jero
	end
end

local function finish_timer(otherPart)
	local player = game.Players:FindFirstChild(otherPart.Parent.Name)
	if player.Name == LPlayer.Name then
		player.PlayerGui.Scree.TextLabel.Visible = false
		completed = true
	end
end

start.Touched:Connect(start_timer)
stop.Touched:Connect(finish_timer)


------------------------------------------------------
-- 파트를 밟으면 서버 메시지가 뜬다

--스크립트1
local TouchEvent = game.ReplicatedStorage.Touched

script.Parent.Touched:Connect(function(hit)
 local Human  = hit.Parent:FindFirstChild("Humanoid")
 if Human then
  TouchEvent:FireAllClients(hit)
 end
end)
--스크립트끝

--스크립트2
local Message = " 님이 정상에 도착하였습니다!"

game.ReplicatedStorage.Touched.OnClientEvent:Connect(function(hit)
 local Name = hit.Parent.Name

 if script.Value.Value ~= Name then
  for _, plr in pairs(game.Players:GetChildren()) do
   if plr.PlayerGui.TouchedGui.TextLabel.Visible == false then
    plr.PlayerGui.TouchedGui.TextLabel.Visible = true
    plr.PlayerGui.TouchedGui.TextLabel.Text = Name .. Message
    plr.PlayerGui.TouchedGui.TextLabel:TweenPosition(UDim2.new(0.047, 0,0.063, 0))
    wait(3)
    plr.PlayerGui.TouchedGui.TextLabel:TweenPosition(UDim2.new(-0.9, 0,0.029, 0))
    script.Value.Value = Name
    wait(2)
    plr.PlayerGui.TouchedGui.TextLabel.Visible = false
   end
  end
 end
end)

------------------------------------------------------------------------

-- 게임에 배경음악 버튼 넣기

버튼 스크립트(수정)
local button = script.Parent
local on = script.Parent:WaitForChild("on")
local off = script.Parent:WaitForChild("off")

local Sound = Instance.new("Sound", script)

Sound.Volume = 0.5 -- 볼륨

musics = {"rbxassetid://1845385270", -- 음악 목록(아이디)
 "rbxassetid://1840265649",
 "rbxassetid://1846459727"
 
}


function playNewMusic()
 Sound:Stop()
 Sound.SoundId = musics[math.random(1, #musics)]
 Sound.Loaded:Wait() -- 바꾼 음악 아이디 로딩 대기
 Sound:Play()
end

button.MouseButton1Click:Connect(function(plr)
 if Sound.IsPlaying then -- 음악 켜져있었음(정석 방법으로 바꿈)
  off.Visible = true
  on.Visible = false
  Sound:Pause() -- 일시정지
 else -- 음악 꺼져있었음
  off.Visible = false
  on.Visible = true
  Sound:Resume() -- 다시 재생
 end
end)

Sound.Ended:Connect(function()
 if on.Visible then -- 여긴 그대로(음악은 끝까지 플레이 후 꺼진 상태라서)
  playNewMusic()
 end
end)

playNewMusic()



-- 시스템 메시지 띄우기

local System = "[System] "

local Message = "안녕하세요"

local Waiter = 5

local TextSizes = 18


while wait(Waiter) do
 game.StarterGui:SetCore("ChatMakeSystemMessage", 
  {
   Text = System .. Message,
   Color = Color3.fromRGB(0, 0, 255),
   TextSize = TextSizes,
  })
end

-- 랜덤 시스템 메시지 띄우기

local System = "[System] "
local Message = 
 {
  "안녕하세요",
  "플레이 해주셔서 감사합니다.",
  "즐거운 시간 보내세요",
 }

local Waiter = 5
local TextSizes = 18



while wait(Waiter) do
 game.StarterGui:SetCore("ChatMakeSystemMessage", 
  {
   Text = System .. Message[math.random(1, #Message)],
   Color = Color3.fromRGB(0, 0, 255),
   TextSize = TextSizes,
  })
end