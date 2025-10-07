--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local ExperienceService = require(ServerScriptService:WaitForChild("ExperienceService"))
local ClearModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ClearModule"))
local CoinService = require(ServerScriptService:WaitForChild("CoinService"))
-- 파일 상단 require들 근처에 [ADD]
local BuffService = require(ServerScriptService:WaitForChild("BuffService"))


-- 🆕 Jumper 배지 지급용
local BadgeManager = require(ServerScriptService:WaitForChild("BadgeManager"))

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
		BubbleText = "Hey, do you have anything cold to drink?",
		Rewards = {
			Exp = 400,
			--Coin = 20,
			Bubble = "Have you ever been to the building in front of the Black Roof Church?"
		}
	},
	["Crimson"] = {
		Distance = 20,
		BubbleText = "You seem to have something good?",
		Rewards = {
			Exp = 400,
			--Coin = 50,
			Bubble = "Police station's weapons management is lax."
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

-- 🆕 동일 틱/중복 호출 방지용 락
local jumperAwardLock: {[number]: boolean} = {}

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
			bubble.StudsOffset = Vector3.new(0, 4, 0)
			bubble.Parent = npcModel.Head
			bubble.TextLabel.Text = rewards.Bubble
			game:GetService("Debris"):AddItem(bubble, 4)
		end
	end

	-- ✅ 퀘스트 클리어 이펙트(기존)
	ClearModule.showClearEffect(player)
	
	if npcName == "nightwatch_zoechickie" then
		-- 상점과 동일: 50 -> 80 (정확히 1.6배)
		BuffService:ApplyBuff(player, "JumpUp", 30*60, { mult = 80/50 }, "JUMP UP! (30m)")
	end

	-- ✅ Jumper 배지: nightwatch_zoechickie만, "처음 한 번만" 지급
	if npcName == "nightwatch_zoechickie" then
		local uid = player.UserId
		if not jumperAwardLock[uid] then
			jumperAwardLock[uid] = true
			task.spawn(function()
				-- 이미 보유면 스킵(= 토스트/이펙트도 안 보냄)
				local has = false
				local okHas, errHas = pcall(function()
					has = BadgeManager.HasRobloxBadge(player, BadgeManager.Keys.Jumper)
				end)
				if not okHas then warn("[QuestService] HasRobloxBadge error:", errHas) end

				if not has then
					local okAward, errAward = pcall(function()
						-- TryAward 내부에서 서버→클라로 토스트를 쏨
						-- 클라는 BadgeClient가 받아서 Billboard + BadgeEffect를 재생
						BadgeManager.TryAward(player, BadgeManager.Keys.Jumper)
					end)
					if not okAward then
						warn("[QuestService] TryAward(Jumper) failed:", errAward)
					end
				end
				jumperAwardLock[uid] = nil
			end)
		end
	end
end


-- === NPC 세팅 (나중에 스폰되는 NPC도 대응) ===
local NPC_FOLDER = Workspace:WaitForChild("NPC_LIVE")

-- 같은 NPC 인스턴스에 중복 세팅 방지 (약한 참조)
local prepared: {[Instance]: boolean} = setmetatable({}, { __mode = "k" })

local function startWatchFor(player: Player, head: BasePart, cfg)
	local function onChar(char: Model)
		task.spawn(function()
			local bubbleShown = false
			while char.Parent do
				task.wait(0.5)

				-- NPC가 사라지면 정리
				if not (head and head.Parent) then
					break
				end

				local hrp = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
				if not (hrp and hrp:IsA("BasePart")) then
					continue
				end

				local dist = (head.Position - hrp.Position).Magnitude
				if dist <= cfg.Distance and player:GetAttribute("HasBottle") then
					if not bubbleShown then
						bubbleShown = true
						local bubble = BubbleTemplate:Clone()
						bubble.Name = "QuestBubble"
						bubble.Adornee = head
						bubble.StudsOffset = Vector3.new(0, 3, 0)
						bubble.Parent = head
						bubble.TextLabel.Text = cfg.BubbleText
						game:GetService("Debris"):AddItem(bubble, 5)
					end
				else
					bubbleShown = false
				end
			end
		end)
	end

	-- 이미 스폰된 캐릭터에도 즉시 감시 시작
	if player.Character then onChar(player.Character) end
	player.CharacterAdded:Connect(onChar)
end

local function setupNPC(npcName: string, cfg, npcModel: Model)
	if prepared[npcModel] then return end
	prepared[npcModel] = true

	-- Head를 안전하게 기다림
	local head = npcModel:FindFirstChild("Head") or npcModel:WaitForChild("Head", 10)
	if not (head and head:IsA("BasePart")) then
		prepared[npcModel] = nil
		return
	end

	-- ProximityPrompt 생성 (항상 켜두고, 트리거 시 서버에서 HasBottle 검사)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Deliver Bottle"
	prompt.ObjectText = npcName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = cfg.Distance
	prompt.HoldDuration = 0.2
	prompt.Enabled = true
	prompt.Parent = head

	prompt.Triggered:Connect(function(player)
		if not player:GetAttribute("HasBottle") then return end
		RemoveBottle(player)
		giveRewards(player, npcName)
	end)

	-- 모든 플레이어 감시 시작 + 이후 입장자도 커버
	for _, p in ipairs(Players:GetPlayers()) do
		startWatchFor(p, head, cfg)
	end
	Players.PlayerAdded:Connect(function(p)
		startWatchFor(p, head, cfg)
	end)

	-- 이 NPC 인스턴스가 삭제되면 준비 플래그 해제
	npcModel.AncestryChanged:Connect(function(_, parent)
		if not parent then
			prepared[npcModel] = nil
		end
	end)
end

-- 1) 지금 이미 존재하는 NPC들 세팅
for npcName, cfg in pairs(QUEST_CONFIG) do
	local m = NPC_FOLDER:FindFirstChild(npcName)
	if m and m:IsA("Model") then
		setupNPC(npcName, cfg, m)
	end
end

-- 2) 앞으로 새로 생기는 NPC도 세팅
NPC_FOLDER.ChildAdded:Connect(function(child)
	if not child:IsA("Model") then return end
	local cfg = QUEST_CONFIG[child.Name]
	if cfg then
		setupNPC(child.Name, cfg, child)
	end
end)


return {
	GiveBottle = GiveBottle,
	RemoveBottle = RemoveBottle,
}