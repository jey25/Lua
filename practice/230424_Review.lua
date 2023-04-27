

local ball1 = game.ServerStorage:FindFirstChild("rollingStone1")
local ball2 = game.ServerStorage:FindFirstChild("rollingStone2")
local ball3 = game.ServerStorage:FindFirstChild("rollingStone3")
local balls = {ball1, ball2, ball3}
local destroyHeight = 20

while true do
	for i=1, 3 do	
		balls[i].Parent = workspace
		balls[i].Position = Vector3.new(-150, 80, 363)
		wait(1)
		balls[i].Parent = workspace
		balls[i].Position = Vector3.new(-170, 80, 363)
		wait(1)
		balls[i].Parent = workspace
		balls[i].Position = Vector3.new(-183, 80, 363)
		if balls[i].Position.Y <= destroyHeight then -- Y값이 파괴 높이 이하라면
			balls[i]:Destroy() -- Part를 파괴합니다.
		end
	end
end

local friction = 0.5 -- 마찰력 값을 조절합니다.
local debounce = false

function onTouched(hit)
    if debounce then return end
    debounce = true
    local humanoid = hit.Parent:FindFirstChild("Humanoid")
    if humanoid then
        local floor = workspace.Terrain:FindPartOnRay(Ray.new(hit.Position, Vector3.new(0, -1, 0)), humanoid.Parent)
        if floor and floor == script.Parent then
            humanoid.PlatformStand = true
            wait()
            humanoid.PlatformStand = false
            humanoid.Sit = true
            wait()
            humanoid.Sit = false
            humanoid.WalkSpeed = humanoid.WalkSpeed * (1 - friction)
        end
    end
    debounce = false
end

script.Parent.Touched:Connect(onTouched)


-- Part 에 닿은 것이 Humanoid 일 때만 블럭이 3초간 사라짐

local part = script.Parent
local isTouched = false

part.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if not isTouched and humanoid then
		isTouched = true
		for i = 0, 10, 1 do
			part.Transparency = i/10
			wait(0.1)
		end
		part.CanCollide = false
		wait(3)
		part.CanCollide = true
		part.Transparency = 0
		isTouched = false
	end
end)


-- 무한이동 킬 파트

function lavaControl()
	local lava = script.Parent
	-- 이동할 위치와 원래 위치를 지정합니다.
	local newPosition = Vector3.new(-105, 90.25, 847.75)
	local originalPosition = lava.Position

	-- part를 서서히 이동시키는 TweenService 인스턴스를 생성합니다.
	-- Duration 은 이동에 걸리는 시간 입력
	local tweenService = game:GetService("TweenService")
	local tweenInfo = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = tweenService:Create(lava, tweenInfo, {Position = newPosition})

	-- part가 이동한 후, 다시 원래 위치로 서서히 돌아오는 TweenService 인스턴스를 생성합니다.
	local returnTweenInfo = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local returnTween = tweenService:Create(lava, returnTweenInfo, {Position = originalPosition})

	-- part를 서서히 이동시키는 Tween을 시작합니다.
	tween:Play()

	wait(3) -- part가 이동하는 동안 대기합니다.
	returnTween:Play()
	
end

while true do
	wait(2.5)
	lavaControl()	
end


local part = script.Parent
local targetScale = Vector3.new(1.5, 1, 30) -- 목표 스케일
local shrinkDuration = 3 -- 줄어들기 애니메이션에 걸리는 시간 (초)
local expandDuration = 2 -- 늘어나기 애니메이션에 걸리는 시간 (초)
local waitTime = 1 -- 줄어들고 난 후 대기 시간 (초)

local originalScale = part.Size

while true do
	-- 첫 번째 Tween: 파트를 일정 길이까지 줄이는 Tween 생성
	local shrinkTween = game:GetService("TweenService"):Create(part, TweenInfo.new(shrinkDuration, Enum.EasingStyle.Linear), {Size = targetScale})
	shrinkTween:Play()
	shrinkTween.Completed:Wait() -- 첫 번째 Tween이 완료될 때까지 대기

	wait(1) -- 일정 시간 대기

	-- 두 번째 Tween: 파트를 원래 크기로 되돌리는 Tween 생성
	local expandTween = game:GetService("TweenService"):Create(part, TweenInfo.new(expandDuration, Enum.EasingStyle.Linear), {Size = originalScale})
	expandTween:Play()
	expandTween.Completed:Wait()
end

print("gogo")
print(2 + 2 *2 <= 7)

-- Property 에서 Reflectance 가 1이면 브릭컬러가 적용이 안됨

if workspace.Baseplate == nil then
	print("Baseplate False")
else
	print("Baseplate True")
end


--로컬 스크립트 SHIFT 달리기

local player = game.player.LocalPlayer
local Player2 = player.Character
local service = game:GetService("UserInputState")

service.InputBegan:Connect(function(SHIFT)
	if SHIFT.KeyCode == Enum.KeyCode.LeftShift then
		Player2.Humanoid.WalkSpeed = 30
	end
end)

service.InputEnded:Connect(function (Shift)
	if Shift.KeyCode == Enum.KeyCode.LeftShift then
		Player2.Humanoid.WalkSpeed = 16
	end
end)


-- 2초 뒤 파트 제거
wait(2)
local part = script.Parent
part:Destroy()

--Serversstorage 안에 있는 파트 10개 클론
for i=1, 10 do
	local part = game.ServerStorage.Part
	local clone = part:clone()
	clone.Parent = workspace
	clone.BrickColor = BrickColor.Black()
	wait()
end

--함수
local function ClonePart(part, location)
	local clone = part:Clone()
	clone.Parent = location
	return clone
end

print("test")
wait(2)

local clone = ClonePart(game.ServerStorage.Part,  workspace)
clone.BrickColor = BrickColor.Random()