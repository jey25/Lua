local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local part = script.Parent
local billboardTemplate = ReplicatedStorage:WaitForChild("playerGui")

-- 플레이어별 상태 추적: 안에 있는지 여부
local insidePlayers = {}

-- 말풍선 표시 함수
local function showBillboard(player)
	if player and player.Character then
		if not player.Character:FindFirstChild("NoEntryMessage") then
			local billboard = billboardTemplate:Clone()
			billboard.Name = "NoEntryMessage"
			billboard.Parent = player.Character:WaitForChild("Head")

			local label = billboard:FindFirstChildWhichIsA("TextLabel", true)
			if label then
				label.Text = "This is my regular grocery store"
			end

			-- 3초 후 자동 제거
			task.delay(3, function()
				if billboard and billboard.Parent then
					billboard:Destroy()
				end
			end)
		end
	end
end

-- 매 프레임 체크
RunService.Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char and char.PrimaryPart then
			local inside = (char.PrimaryPart.Position - part.Position).Magnitude <= (part.Size.Magnitude / 2)

			if inside and not insidePlayers[player] then
				-- 파트 안으로 들어온 순간
				insidePlayers[player] = true
				showBillboard(player)
			elseif not inside and insidePlayers[player] then
				-- 파트 밖으로 나간 순간
				insidePlayers[player] = nil
			end
		end
	end
end)
