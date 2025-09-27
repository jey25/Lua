-- 스크립트 상위 part 에 플레이어가 닿을 경우 텍스트 말풍선을 띄운다

local part = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local billboardTemplate = ReplicatedStorage:WaitForChild("playerGui")

part.Touched:Connect(function(hit)
	local player = game.Players:GetPlayerFromCharacter(hit.Parent)
	if player and player.Character then
		-- 이미 있으면 중복 생성 방지
		if not player.Character:FindFirstChild("NoEntryMessage") then
			local billboard = billboardTemplate:Clone()
			billboard.Name = "NoEntryMessage"
			billboard.Parent = player.Character:WaitForChild("Head")
			
			-- 텍스트만 세팅
			local label = billboard:FindFirstChildWhichIsA("TextLabel", true)
			if label then
				label.Text = "Can't go in yet"
			end

			-- 3초 후 자동 제거
			task.delay(3, function()
				if billboard and billboard.Parent then
					billboard:Destroy()
				end
			end)
		end
	end
end)
