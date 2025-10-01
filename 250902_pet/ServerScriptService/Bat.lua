-- 플레이어가 20회 휘두르면 사라짐, 데미지는 10 

local tool = script.Parent
local canDamage = false
local swingsLeft = 20  -- 총 20번 휘두르면 사라짐

local function onTouch(otherPart)
	local humanoid = otherPart.Parent:FindFirstChild("Humanoid")
	if not humanoid then return end

	if humanoid.Parent ~= tool.Parent and canDamage then
		humanoid:TakeDamage(10)
		canDamage = false
	end
end

local function slash()
	-- 남은 횟수 감소
	swingsLeft -= 1
	print("Bat swings left:", swingsLeft)

	-- 애니메이션 트리거
	local str = Instance.new("StringValue")
	str.Name = "toolanim"
	str.Value = "Slash"
	str.Parent = tool

	canDamage = true

	-- 0이 되면 Bat 제거
	if swingsLeft <= 0 then
		tool:Destroy()
	end
end

tool.Activated:Connect(slash)
tool.Handle.Touched:Connect(onTouch)
