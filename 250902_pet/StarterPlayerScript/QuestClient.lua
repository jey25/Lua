--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local QuestRemotes = ReplicatedStorage:WaitForChild("QuestRemotes")
local BottleChanged = QuestRemotes:WaitForChild("BottleChanged") :: RemoteEvent
local BottlePromptFailed = QuestRemotes:WaitForChild("BottlePromptFailed") :: RemoteEvent

-- Bottle UI 제어
local function showBottleIcon()
	local screenGui = PlayerGui:FindFirstChild("BottleGui") or Instance.new("ScreenGui")
	screenGui.Name = "BottleGui"
	screenGui.Parent = PlayerGui

	local icon = screenGui:FindFirstChild("BottleIcon") :: ImageLabel
	if not icon then
		icon = Instance.new("ImageLabel")
		icon.Name = "BottleIcon"
		icon.Size = UDim2.new(0, 50, 0, 50) -- 절반 크기
		icon.AnchorPoint = Vector2.new(1, 1)
		icon.Position = UDim2.new(0.95, 0, 0.95, 0) -- 화면 우하단 근처
		icon.BackgroundTransparency = 1
		icon.Image = ReplicatedStorage.Assets.Icons.Bottle.Image
		icon.Parent = screenGui
	end
end

local function removeBottleIcon()
	local gui = PlayerGui:FindFirstChild("BottleGui")
	if gui then gui:Destroy() end
end

-- 말풍선 표시 함수
local function showBalloonAboveHead(targetPlayer: Player, text: string, duration: number)
	local character = targetPlayer.Character
	if not character then return end
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then return end


	-- 예시: ReplicatedStorage > Assets > UIs > BalloonTemplate (BillboardGui)
	local template = ReplicatedStorage:WaitForChild("playerGui")
	if not template then return end
	
	local balloon = template:Clone()
	balloon.Name = "BottleBalloon"
	balloon.Adornee = head
	balloon.Parent = head  -- Head 밑에 붙여야 바로 보임

	-- 텍스트 설정
	local textLabel = balloon:FindFirstChildWhichIsA("TextLabel", true)
	if textLabel then
		textLabel.Text = text
	end

	-- 일정 시간 후 제거
	task.delay(duration, function()
		if balloon and balloon.Parent then
			balloon:Destroy()
		end
	end)
end


-- RemoteEvent 응답
BottleChanged.OnClientEvent:Connect(function(hasBottle: boolean)
	if hasBottle then
		showBottleIcon()
	else
		removeBottleIcon()
	end
end)

-- Bottle 보유 중 재시도 시 머리 위 말풍선 띄움
BottlePromptFailed.OnClientEvent:Connect(function(msg: string, duration: number)
	-- 항상 자기 자신 머리 위에 표시
	showBalloonAboveHead(Players.LocalPlayer, msg, duration)
end)