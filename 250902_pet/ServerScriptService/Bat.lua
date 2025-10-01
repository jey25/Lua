-- Bat Tool Script
local tool = script.Parent
local canDamage = false
local swingsLeft = 20  -- 총 20번 사용 가능

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ItemRespawnRequest = ReplicatedStorage:WaitForChild("ItemRespawnRequest")

local activatedConnection -- Activated 연결
local touchedConnection   -- Touched 연결
local destroyed = false   -- 중복 파괴 방지

local function cleanupAndDestroy()
	if destroyed then return end
	destroyed = true

	-- 더 이상 사용 못 하도록 차단
	canDamage = false
	if tool:IsDescendantOf(game) then
		tool.Enabled = false -- 추가 입력/발동 방지
	end

	-- 이벤트 해제
	if activatedConnection then activatedConnection:Disconnect(); activatedConnection = nil end
	if touchedConnection   then touchedConnection:Disconnect();   touchedConnection   = nil end

	-- (선택) 리스폰 요청 보내기 (클라이언트에서만 유효)
	local markerPath = tool:GetAttribute("SpawnMarkerPath")
	if markerPath then
		pcall(function()
			ItemRespawnRequest:FireServer(markerPath, tool.Name)
		end)
	end

	-- 장착 중이면 장착 해제 시도
	local char = tool.Parent
	local hum  = char and char:FindFirstChildOfClass("Humanoid")
	if hum and tool.Parent == char then
		pcall(function()
			hum:UnequipTools()
		end)
	end

	-- 혹시라도 손에 그대로 있으면 백팩으로 강제 이동
	if char and tool.Parent == char then
		local plr = Players:GetPlayerFromCharacter(char)
		if plr and plr:FindFirstChild("Backpack") then
			tool.Parent = plr.Backpack
		end
	end

	-- 3초 뒤 파괴
	task.delay(3, function()
		if tool and tool.Parent then
			tool:Destroy()
		end
	end)
end

local function onTouch(otherPart)
	local humanoid = otherPart.Parent:FindFirstChild("Humanoid")
	if not humanoid then return end

	-- 자기 자신(소유자) 제외 + 한 번만 타격
	if humanoid.Parent ~= tool.Parent and canDamage then
		humanoid:TakeDamage(10)
		canDamage = false
	end
end



local function slash()
	-- 사용 횟수 모두 소진 시 즉시 리턴
	if swingsLeft <= 0 then return end

	swingsLeft -= 1
	print("Bat swings left:", swingsLeft)

	-- 애니메이션 트리거
	local str = Instance.new("StringValue")
	str.Name = "toolanim"
	str.Value = "Slash"
	str.Parent = tool

	-- 이번 스윙에서만 유효하게 데미지 ON
	canDamage = true

	-- 소진되면 정리 루틴
	if swingsLeft <= 0 then
		print("Bat expired!")
		cleanupAndDestroy()
	end
end



activatedConnection = tool.Activated:Connect(slash)
touchedConnection   = tool.Handle.Touched:Connect(onTouch)
