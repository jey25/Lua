--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BottleFoundEvent = Remotes:WaitForChild("BottleFound")

BottleFoundEvent.OnClientEvent:Connect(function()
	-- BottleGui 생성/재사용
	local screenGui = PlayerGui:FindFirstChild("BottleGui") or Instance.new("ScreenGui")
	screenGui.Name = "BottleGui"
	screenGui.Parent = PlayerGui

	-- 아이콘 생성/재사용
	local icon = screenGui:FindFirstChild("BottleIcon") :: ImageLabel
	if not icon then
		icon = Instance.new("ImageLabel")
		icon.Name = "BottleIcon"

		-- ✅ 크기 절반으로 (100x100 → 50x50)
		icon.Size = UDim2.new(0, 50, 0, 50)

		-- ✅ 화면 중앙 하단 우측 쪽 위치
		-- AnchorPoint (1,1) = 오른쪽 아래 모서리를 기준점으로 설정
		-- Position (0.8, 0.9) = 화면 가로 80%, 세로 90% 지점 → 중앙보다 오른쪽 & 하단
		icon.AnchorPoint = Vector2.new(1, 1)
		icon.Position = UDim2.new(0.8, 0, 0.9, 0)

		icon.BackgroundTransparency = 1
		icon.Image = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Icons"):WaitForChild("Bottle").Image
		icon.Parent = screenGui
	end
end)
