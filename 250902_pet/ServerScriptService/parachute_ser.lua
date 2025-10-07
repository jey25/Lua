--!strict
-- Tool/GliderServer.server.lua
local tool = script.Parent
local Debris = game:GetService("Debris")

local hum: Humanoid? = nil
local armed = false      -- 공중(Freefall) 경험 후에만 파괴 루틴 가동
local stConn: RBXScriptConnection? = nil

local function onEquipped()
	local char = tool.Parent
	hum = char and (char:FindFirstChildOfClass("Humanoid")) or nil
	if not hum then return end

	-- 상태 머신으로 비행→착지 감지
	if stConn then stConn:Disconnect() end
	stConn = hum.StateChanged:Connect(function(old, new)
		if new == Enum.HumanoidStateType.Freefall then
			armed = true
		elseif armed and (new == Enum.HumanoidStateType.Landed
			or new == Enum.HumanoidStateType.Running
			or new == Enum.HumanoidStateType.Swimming
			or new == Enum.HumanoidStateType.Seated) then
			-- 땅(또는 수면/좌석) 접촉 → 자동 장착 해제
			pcall(function() hum:UnequipTools() end)
		end
	end)
end

local function onUnequipped()
	-- 비행을 한 번이라도 했을 때만 삭제(지상에서 실수 장착/해제는 보존)
	if not armed then return end

	-- 3초 뒤 삭제
	task.delay(3, function()
		if tool and tool.Parent then
			tool:Destroy()  -- Destroying 시 글라이더 스포너가 24시간 타이머 기록
		end
	end)
end

tool.Equipped:Connect(onEquipped)
tool.Unequipped:Connect(onUnequipped)

tool.Destroying:Connect(function()
	if stConn then stConn:Disconnect() stConn = nil end
end)
