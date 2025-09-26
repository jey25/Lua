--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local function forceLandscape()
	local pg = player:WaitForChild("PlayerGui")
	if UserInputService.TouchEnabled then -- 모바일에서만 적용
		pg.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor
	end
end

forceLandscape()

-- (선택) 재스폰/메뉴 복귀 등에서 다시 보장
player.CharacterAdded:Connect(function()
	task.defer(forceLandscape)
end)

