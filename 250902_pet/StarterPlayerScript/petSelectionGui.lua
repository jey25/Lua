local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local PetEvents = ReplicatedStorage:WaitForChild("PetEvents")
local ShowPetGuiEvent = PetEvents:WaitForChild("ShowPetGui")
local PetSelectedEvent = PetEvents:WaitForChild("PetSelected")

local petSelectionGuiTemplate = ReplicatedStorage:WaitForChild("PetSelectionGui")


-- 서버에서 "GUI 열어라" 신호 받음
ShowPetGuiEvent.OnClientEvent:Connect(function()
	local gui = petSelectionGuiTemplate:Clone()
	gui.Parent = playerGui

	for _, imageLabel in pairs(gui.Frame:GetChildren()) do
		if imageLabel:IsA("ImageLabel") and imageLabel:FindFirstChild("Select") then
			imageLabel.Select.MouseButton1Click:Connect(function()
				local petName = imageLabel.Name
				-- 서버로 선택 결과 전달
				PetSelectedEvent:FireServer(petName)
				gui:Destroy()
			end)
		end
	end
end)

