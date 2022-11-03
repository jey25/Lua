--스크립트 기반으로 블럭 요소 찾기

--local blockPart = game.Workspace.Cube
local blockPart = script.Parent


--fire 를 찾아서 컬러 속성 변경
local fire = script.Parent.Fire
--fire.Color = Color3.fromRGB(15, 178, 45)


--컬러 변경하는 2가지 방법
--blockPart.BrickColor = BrickColor.new("Mint")
--blockPart.Color = Color3.fromRGB(0, 156, 187)

--Fire 가 크게 타오르다가 서서히 사라짐
while true do
    fire.Size = 30
    fire.Heat = 25

    wait(1)

    fire.Size = 0
    fire.Heat = 0

    wait(1)
end


-- 반복문을 통한 블록 컬러 반복 변경

local colorBlock = script.Parent

local red = Color3.fromRGB(255, 0, 0)
local green = Color3.fromRGB(0, 255, 0)
local blue = Color3.fromRGB(0, 0, 255)


--[[
for count = 1, 10, 1 do
	print("count = " .. count)
	colorBlock.Color = red
	wait(1)
	colorBlock.Color = green
	wait(1)
	colorBlock.Color = blue
	wait(1)
end
]]

while true do
    colorBlock.Color = red
    wait(1)
    colorBlock.Color = green
    wait(1)
    colorBlock.Color = blue
    wait(1)
end


local timeControl = game.Lighting
local timeVal = 12
local fire = script.Parent.Fire


--시간이 흐름에 따라 낮밤이 바뀌고 Fire 의 크기와 컬러가 변함
while true do
    timeControl.ClockTime = timeVal
    print(timeVal)
    wait(1)

    if timeVal < 12 then
        fire.Size = 30
        fire.Heat = 25
        fire.Color = Color3.fromRGB(0, 0, 255)

    elseif timeVal < 18 then
        fire.Color = Color3.fromRGB(255, 0, 0)

    else
        fire.Size = 0
        fire.Heat = 0
    end

    timeVal = timeVal + 1

    if timeVal == 25 then
        timeVal = 0
    end
end
