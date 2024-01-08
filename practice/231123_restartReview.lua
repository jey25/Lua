
script.Parent.Transparency = 0
script.Parent.Name = "창문"
script.Parent.Anchored = true
script.Parent.Material = Enum.Material.Brick

for i=1, 50 do
    local part = game.ServerStorage.test01
    local clone = part:Clone()
    clone.Parent = workspace
    wait()	
    end

    
local function ClonePart(part, location)
    local clone = part:Clone()
    clone.Parent = location
    end

for i=1, 50 do
    ClonePart(game.ServerStorage.test01, workspace)
    wait()
end

-- true 를 넣어서 이중삼중 폴더 밑에 있는 개체까지 찾게 한다
local part = workspace:FindFirstChild("Part", true)



local part = script.Parent
local function kill(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid then
		--humanoid.Health = 0   --kill part
		humanoid.Health -= 5     --damage Part
	end	
end

part.Touched:Connect(kill)


-- 이벤트 쿨타임
local part = script.Parent
local Enabled = true

part.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid and Enabled then
		Enabled = false
		--humanoid.Health = 0   --kill part
		humanoid.Health -= 5     --damage Part
		wait(1)
		Enabled = true
	end
end)


game.Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(chr)
		
	end)
end)



--로컬 스크립트에서 로컬 플레이어 구하기
local localplayer = game.Players.LocalPlayer

--접속한 플레이어 구하기
game.Players.PlayerAdded:Connect(function(plr)
	
end)

--클릭한 플레이어 구하기
local part = workspace.Baseplate
part.ClickDetector.MouseClick:Connect(function(plr)
	
end)

--사물에 닿은 플레이어 구하기 
local part = workspace.Baseplate
part.Touched:Connect(function(hit)
	local plr = game.Players:GetPlayerFromCharacter(hit.Parent)
end)


-- Part 에 하위의 A 스크립트에서 캐릭터가 밟았을 때 이벤트를 보내고 B 스크립트가 받아서 출력 
local event = game.ServerStorage.babo

local part = script.Parent
part.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid then
		event:Fire()
	end
end)

local event = game.ServerStorage.babo

event.Event:Connect(function()
	print("1111")
end)


--if 사용하지 않는 and or 조건문
local nuna = "cola"
local na = "water"

local masil

if nuna then
	masil = nuna
else
	masil = na
end

print(masil)

--간이 조건문
local masil = nuna == "cola" and nuna or na
local 변수 = 조건 and a or b

--파트가 있으면 파트를, 없으면 새로 생성해서 part 에 넣어줌
local part = workspace:FindFirstChild("Part") or Instance.new("Part", workspace)
part.BrickColor = BrickColor.new("Really black")


-- 텔레포트 파트 만들기

local part = script.Parent

part.Touched:Connect(function(hit)
	if hit.Parent:FindFirstChild("Humanoid") then
		hit.Parent:PivotTo(hit.Parent:GetPivot() * CFrame.new(0, 0, 20))  -- 뒤로 20칸
	end
end)


--Angles 를 써서 회전시킬 때는 math.rad 함수를 사용한다
workspace.Part.CFrame = CFrame.new(5,5,5) * CFrame.Angles(math.rad(30),1,1)

-- 파트 30도씩 회전
workspace.Part.CFrame = workspace.Part.CFrame * CFrame.Angles(math.rad(30),0,0)