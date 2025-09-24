local CurrentPart = nil
local MaxInc = 10

function onTouched(hit)
	if hit.Parent == nil then
		return
	end

	local humanoid = hit.Parent:findFirstChild("Humanoid")

	if humanoid == nil then
		CurrentPart = hit
	end
end

function waitForChild(parent, childName)
	local child = parent:findFirstChild(childName)

	if child then
		return child
	end

	while true do
		print(childName)

		child = parent.ChildAdded:wait()

		if child.Name==childName then
			return child
		end
	end
end

local Figure = script.Parent
local Humanoid = waitForChild(Figure, "Humanoid")
local Torso = waitForChild(Figure, "Torso")
local Left = waitForChild(Figure, "Left Leg")
local Right = waitForChild(Figure, "Right Leg")

Humanoid.Jump = true
-- 걷는 속도 줄이기 (기본 16 → 6)
Humanoid.WalkSpeed = 6

Left.Touched:connect(onTouched)
Right.Touched:connect(onTouched)

while true do
	wait(math.random(3, 7)) -- 대기 시간도 약간 늘려서 천천히 행동
	if CurrentPart ~= nil then
		if math.random(1, 3) == 1 then
			Humanoid.Jump = true
		end
		-- 가까운 주변만 무작위 배회
		Humanoid:MoveTo(
			Torso.Position + Vector3.new(math.random(-MaxInc, MaxInc), 0, math.random(-MaxInc, MaxInc)),
			CurrentPart
		)
	end
end