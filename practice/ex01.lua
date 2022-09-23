
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