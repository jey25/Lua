--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ExperienceService = require(ServerScriptService:WaitForChild("ExperienceService"))
local ClearModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ClearModule"))
local CoinService = require(script.Parent:WaitForChild("CoinService"))

-- BillboardGui 템플릿
local BubbleTemplate = ReplicatedStorage:WaitForChild("BubbleTemplates"):WaitForChild("Plain")

-- RemoteEvent 준비
local QuestRemotes = ReplicatedStorage:FindFirstChild("QuestRemotes") or Instance.new("Folder")
QuestRemotes.Name = "QuestRemotes"
QuestRemotes.Parent = ReplicatedStorage

local BottleChanged = QuestRemotes:FindFirstChild("BottleChanged") :: RemoteEvent
if not BottleChanged then
	BottleChanged = Instance.new("RemoteEvent")
	BottleChanged.Name = "BottleChanged"
	BottleChanged.Parent = QuestRemotes
end


-- NPC & 보상 설정
local QUEST_CONFIG = {
	["nightwatch_zoechickie"] = {
		Distance = 20,
		BubbleText = "거기 오빠, 시원한 마실 거 좀 가지고 있어?",
		Rewards = {
			Exp = 150,
			--Coin = 20,
			Bubble = "고마워! 혹시 검은 지붕 교회 앞 건물 가 봤어?"
		}
	},
	["QuestNPC2"] = {
		Distance = 20,
		BubbleText = "너, 좋은 걸 가지고 있는 것 같은데?",
		Rewards = {
			Exp = 150,
			--Coin = 50,
			Bubble = "캬~ 꿀맛인데? 비밀인데, 경찰서 무기 관리가 허술하더라고"
		}
	},
}

-- 플레이어 초기화
Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("HasBottle", false)
end)


-- Bottle 제거
local function GiveBottle(player: Player)
	player:SetAttribute("HasBottle", true)
	BottleChanged:FireClient(player, true)

end

-- Bottle 제거
local function RemoveBottle(player: Player)
	player:SetAttribute("HasBottle", false)
	BottleChanged:FireClient(player, false)
end

-- 보상 지급 처리
local function giveRewards(player: Player, npcName: string)
	local cfg = QUEST_CONFIG[npcName]
	if not cfg then return end
	local rewards = cfg.Rewards

	if rewards.Exp then
		ExperienceService.AddExp(player, rewards.Exp)
	end
	if rewards.Coin then
		CoinService:Award(player, rewards.Coin)
	end
	if rewards.Bubble then
		local npcModel = Workspace.NPC_LIVE:FindFirstChild(npcName)
		if npcModel and npcModel:FindFirstChild("Head") then
			local bubble = BubbleTemplate:Clone()
			bubble.Adornee = npcModel.Head
			bubble.StudsOffset = Vector3.new(0, 3, 0) -- 머리 위로 띄우기
			bubble.Parent = npcModel.Head
			bubble.TextLabel.Text = rewards.Bubble
			game:GetService("Debris"):AddItem(bubble, 3)
		end
	end

	ClearModule.showClearEffect(player)
end

-- NPC 세팅
for npcName, cfg in pairs(QUEST_CONFIG) do
	local npc = Workspace:WaitForChild("NPC_LIVE"):FindFirstChild(npcName)
	if npc and npc:FindFirstChild("Head") then
		local head = npc.Head

		-- ProximityPrompt 추가
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Deliver Bottle"
		prompt.ObjectText = npcName
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = cfg.Distance
		prompt.HoldDuration = 0.2
		prompt.Enabled = false
		prompt.Parent = head

		-- Prompt 실행 시
		prompt.Triggered:Connect(function(player)
			if not player:GetAttribute("HasBottle") then return end
			RemoveBottle(player)
			giveRewards(player, npcName)
		end)

		-- 플레이어 근접 감시 (HasBottle 여부)
		Players.PlayerAdded:Connect(function(player)
			player.CharacterAdded:Connect(function(char)
				task.spawn(function()
					local bubbleShown = false -- 한 번만 표시
					while char.Parent do
						task.wait(0.5)
						if not char.PrimaryPart then continue end
						local dist = (head.Position - char.PrimaryPart.Position).Magnitude
						if dist <= cfg.Distance and player:GetAttribute("HasBottle") then
							prompt.Enabled = true
							if not bubbleShown then
								bubbleShown = true
								local bubble = BubbleTemplate:Clone()
								bubble.Name = "QuestBubble"
								bubble.Adornee = head
								bubble.StudsOffset = Vector3.new(0, 3, 0)
								bubble.Parent = head
								bubble.TextLabel.Text = cfg.BubbleText

								-- 일정 시간 후 제거
								task.delay(3, function()
									if bubble and bubble.Parent then
										bubble:Destroy()
									end
								end)
							end
						else
							prompt.Enabled = false
							bubbleShown = false -- 범위 벗어나면 다음 근접 시 다시 표시 가능
						end
					end
				end)
			end)
		end)

	end
end

return {
	GiveBottle = GiveBottle,
	RemoveBottle = RemoveBottle,
}