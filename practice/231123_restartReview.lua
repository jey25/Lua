
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


--50%의 확률
if math.random(1,2) == 1 then
	print("die")
else
	print("save")
end


-- 정수를 10으로 나눠 변수에 저장해서 40% 의 확률 구하기
local n = math.random(10, 20)/10

if n <= 1.4 then
	print("40%")
end




-- 쉬프트 달리가 + 카메라 쉐이크

Bobbing Camera 스크립트 (스타터 GUI에 넣으세요)
-------------------------------------------------------------------------------------
while true do
	wait();
	if game.Players.LocalPlayer.Character then
		break;
	end;
end;
camera = game.Workspace.CurrentCamera;
character = game.Players.LocalPlayer.Character;
Z = 0;
damping = character.Humanoid.WalkSpeed / 2;
PI = 3.1415926;
tick = PI / 2;
running = false;
strafing = false;
character.Humanoid.Strafing:connect(function(p1)
	strafing = p1;
end);
character.Humanoid.Jumping:connect(function()
	running = false;
end);
character.Humanoid.Swimming:connect(function()
	running = false;
end);
character.Humanoid.Running:connect(function(p2)
	if p2 > 0.1 then
		running = true;
		return;
	end;
	running = false;
end);
function mix(p3, p4, p5)
	return p4 + (p3 - p4) * p5;
end;
while true do
	game:GetService("RunService").RenderStepped:wait();
	fps = (camera.CoordinateFrame.p - character.Head.Position).Magnitude;
	if fps < 0.52 then
		Z = 1;
	else
		Z = 0;
	end;
	if running == true and strafing == false then
		tick = tick + character.Humanoid.WalkSpeed / 92;
	else
		if tick > 0 and tick < PI / 2 then
			tick = mix(tick, PI / 2, 0.9);
		end;
		if PI / 2 < tick and tick < PI then
			tick = mix(tick, PI / 2, 0.9);
		end;
		if PI < tick and tick < PI * 1.5 then
			tick = mix(tick, PI * 1.5, 0.9);
		end;
		if PI * 1.5 < tick and tick < PI * 2 then
			tick = mix(tick, PI * 1.5, 0.9);
		end;
	end;
	if PI * 2 <= tick then
		tick = 0;
	end;
	camera.CoordinateFrame = camera.CoordinateFrame * CFrame.new(math.cos(tick) / damping, math.sin(tick * 2) / (damping * 2), Z) * CFrame.Angles(0, 0, math.sin(tick - PI * 1.5) / (damping * 20));
end;
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SprintScript 스크립트 (스타터GUI에 넣으세요)
-----------------------------------------------------------------------------
local Player = game.Players.LocalPlayer
local Character = workspace:WaitForChild(Player.Name)
local Humanoid = Character:WaitForChild('Humanoid')

local RunAnimation = Instance.new('Animation')
RunAnimation.AnimationId = 'rbxassetid://12961464334'
RAnimation = Humanoid:LoadAnimation(RunAnimation)

Running = false

function Handler(BindName, InputState)
	if InputState == Enum.UserInputState.Begin and BindName == 'RunBind' then
		Running = true
		Humanoid.WalkSpeed = 50
	elseif InputState == Enum.UserInputState.End and BindName == 'RunBind' then
		Running = false
		if RAnimation.IsPlaying then
			RAnimation:Stop()
		end
		Humanoid.WalkSpeed = 16
	end
end

Humanoid.Running:connect(function(Speed)
	if Speed >= 10 and Running and not RAnimation.IsPlaying then
		RAnimation:Play()
		Humanoid.WalkSpeed = 30
	elseif Speed >= 10 and not Running and RAnimation.IsPlaying then
		RAnimation:Stop()
		Humanoid.WalkSpeed = 16
	elseif Speed < 10 and RAnimation.IsPlaying then
		RAnimation:Stop()
		Humanoid.WalkSpeed = 16
	end
end)

Humanoid.Changed:connect(function()
	if Humanoid.Jump and RAnimation.IsPlaying then
		RAnimation:Stop()
	end
end)

game:GetService('ContextActionService'):BindAction('RunBind', Handler, true, Enum.KeyCode.LeftShift)
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------
애니메이션 링크
-------------------------------
rbxassetid://1296146433



local array = {123, "string", true}

print(#array)

table.insert(array, 4355)  --마지막에 추가
print(array)

table.remove(array, 2)
print(array)

--print(array[5])

for i = 1,  #array do
	array[i]
end



local model = script.Parent
local parts = {model.Part1, model.Part2, model.Part3 }
local num = math.random(1,3)

print(num)
parts[num].CanCollide = false


local model = script.Parent
local parts = {model.Part1, model.Part2, model.Part3 }
parts[1].CanCollide = false
parts[2].CanCollide = false
parts[3].CanCollide = false

local num = math.random(1,#parts)

print(num)
parts[num].CanCollide = true

local parts = model:GetChildren()
local parts = game.Players:GetPlayers()


local model = script.Parent
local parts = model:GetChildren()

for i=1, #parts do
	if parts[i]:IsA("BasePart") then
		parts[i].CanCollide = false
	end
end

for i, v in ipairs(parts) do
	if v:IsA("BasePart") then
		v.CanCollide = false
	end
end



local players = game.Players

script.Parent.Touched:Connect(function(hit)
	local chr = hit.Parent
	local plr = players:GetPlayerFromCharacter(chr)
	if plr then
		for i, v in ipairs(players:GetPlayers()) do
			if v.Character then
				local humanoid = v.Character:FindFirstChild("Humanoid")
				if humanoid then
					humanoid.Health = 0
				end
			end
		end
	end
end)


-- npc 의 머리가 플레이어를 계속 바라보게

local npcHead = workspace:WaitForChild("Head")
local myHead = script.Parent:WaitForChild("Head")

while wait() do
	npcHead.CFrame = CFrame.lookAt(npcHead.Position, myHead.Position)
end


local RunService = game:GetService("RunService")


-- step 을 이용하면 Frame 에 따른 차이를 없앨 수 있음
function update(step)
	script.Parent.Rotation += 60 * step
end

RunService.RenderStepped:Connect(update)


-- ServerScript 에서는 RenderStepped 대신 Stepped 사용
local runService = game:GetService("RunService")
local part = script.Parent

function update(step)
	part.CFrame = part.CFrame * CFrame.Angles(0, math.rad(180) * step, 0)
end

runService.Stepped:Connect(update)


