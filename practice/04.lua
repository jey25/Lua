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



--touchPart 를 터치하면 숨겨진 Bridge 가 보여지고 5초후 사라짐
local bridge = game.Workspace.BridgePart
local touchPart = script.Parent

function showBridge()
    bridge.CanCollide = true
    bridge.Transparency = 0

    wait(5)

    bridge.CanCollide = false
    bridge.Transparency = 1

end

touchPart.Touched:Connect(showBridge)


-- 캐릭터 몸 크기 조정 기능 가진 함수 만들기
local bodySize = script.Parent

local function changeBody(otherPart)
    local character = otherPart.Parent
    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if humanoid then
        -- 플레이어 외형 조정
        local descriptionClone = humanoid:GetAppliedDescription()
        descriptionClone.HeadScale = 1 --머리크기
        descriptionClone.HeightScale = 3 -- 키 조정
        descriptionClone.DepthScale = 1 --몸통두께
        descriptionClone.WidthScale = 1 -- 몸통너비

        -- 수정한 외모 적용하기
        humanoid:ApplyDescription(descriptionClone)
    end
end

bodySize.Touched:Connect(changeBody)


--파트에 닿으면 캐릭터 파괴
local trap = script.Parent

local function TrapPong(hit)
    hit:Destroy()
end

trap.Touched:Connect(TrapPong)


-- 파트에 닿으면 사망!
local trapPart = script.Parent

local function trap(otherPart)
    local character = otherPart.Parent
    local humanoid = character:FindFirstChildWhichIsA("Humanoid")

    if humanoid then
        humanoid.Health = 0
    end
end

trapPart.Touched:Connect(trap)



-- 2024-05-30

-- A
local event = game.ServerStorage.babo

script.Parent.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid then
		event:Fire()
	end
end)

-- B
local event = game.ServerStorage.babo

event.Event:Connect(function()
	print("Touch")
end)
