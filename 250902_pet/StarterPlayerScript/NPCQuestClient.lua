--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local QuestEvents = ReplicatedStorage:WaitForChild("QuestEvents")
local QuestEvent = QuestEvents:WaitForChild("QuestEvent")

-- GUI 템플릿
local QuestGuiTemplate = ReplicatedStorage:WaitForChild("NPCQuestGui")
local ClearEffect = require(ReplicatedStorage:WaitForChild("ClearEffect"))

-- 현재 열려있는 GUI 추적
local currentGui: ScreenGui? = nil
local currentQuestId: string? = nil
local currentNpc: Model? = nil

-- 버튼 스타일 적용 함수
local function styleButton(btn: TextButton, isOk: boolean)
	btn.BorderSizePixel = 3
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.AutoButtonColor = true
	if isOk then
		btn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
	else
		btn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
	end
end

-- GUI 열기
local function openQuestGui(questId: string, npc: Model)
	if currentGui then currentGui:Destroy() end

	local gui = QuestGuiTemplate:Clone()
	gui.Parent = PlayerGui

	local frame = gui:WaitForChild("Frame") :: Frame
	local txt = frame:WaitForChild("Text") :: TextLabel
	local okBtn = frame:WaitForChild("OK") :: TextButton
	local cancelBtn = frame:WaitForChild("Cancel") :: TextButton

	txt.Text = ("%s Do you want to accept?"):format(questId)

	-- 스타일 적용
	styleButton(okBtn, true)
	styleButton(cancelBtn, false)

	-- 기존 okBtn 클릭
	okBtn.MouseButton1Click:Connect(function()
		QuestEvent:FireServer("AcceptQuest", {questId = currentQuestId, npcName = currentNpc.Name})
	end)


	cancelBtn.MouseButton1Click:Connect(function()
		QuestEvent:FireServer("DeclineQuest", {questId = questId, npcName = npc.Name})
		gui:Destroy()
		currentGui = nil
	end)

	currentGui = gui
	currentQuestId = questId
	currentNpc = npc
end

-- 서버 이벤트 수신
QuestEvent.OnClientEvent:Connect(function(action: string, data: any)
	if action == "OpenQuestGui" then
		openQuestGui(data.questId, data.npc)

	elseif action == "QuestClear" then
		ClearEffect.showClearEffect(player)
	end
end)

