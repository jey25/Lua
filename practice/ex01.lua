
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