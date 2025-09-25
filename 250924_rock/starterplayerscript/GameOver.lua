-- StarterPlayerScripts/GameOverClient.client.lua
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local event = RS:WaitForChild("GameOver") :: RemoteEvent

event.OnClientEvent:Connect(function()
	-- 1) "게임 종료" 글씨 표시
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameOverGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1,0,1,0)
	label.BackgroundTransparency = 1
	label.Text = "게임 종료"
	label.TextScaled = true
	label.TextColor3 = Color3.new(1,0,0)
	label.Parent = screenGui

	task.wait(2) -- 2초 후

	-- 2) "나가기" 안내창 띄우기
	label.Visible = false
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0.4,0,0.25,0)
	frame.Position = UDim2.new(0.3,0,0.35,0)
	frame.BackgroundColor3 = Color3.new(0,0,0)
	frame.BackgroundTransparency = 0.3
	frame.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1,0,0.6,0)
	title.BackgroundTransparency = 1
	title.Text = "게임이 종료되었습니다.\nRoblox 홈 화면으로 나가주세요."
	title.TextScaled = true
	title.TextColor3 = Color3.new(1,1,1)
	title.Parent = frame

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.6,0,0.3,0)
	btn.Position = UDim2.new(0.2,0,0.65,0)
	btn.Text = "확인"
	btn.TextScaled = true
	btn.BackgroundColor3 = Color3.fromRGB(200,0,0)
	btn.TextColor3 = Color3.new(1,1,1)
	btn.Parent = frame

	btn.MouseButton1Click:Connect(function()
		-- 확인 누르면 단순히 안내창만 닫음
		screenGui:Destroy()
		-- 유저는 직접 Roblox 메뉴에서 "Leave Game" 눌러야 함
	end)
end)

