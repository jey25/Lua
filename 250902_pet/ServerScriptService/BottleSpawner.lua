--!strict
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

-- 데이터스토어 (플레이어 Bottle 보유 여부 저장)
local BottleStore = DataStoreService:GetDataStore("PlayerBottleData")

-- RemoteEvent 준비 (서버→클라이언트 UI 표시)
local QuestRemotes = ReplicatedStorage:FindFirstChild("QuestRemotes") or Instance.new("Folder")
QuestRemotes.Name = "QuestRemotes"
QuestRemotes.Parent = ReplicatedStorage

local BottleChanged = QuestRemotes:FindFirstChild("BottleChanged") :: RemoteEvent
if not BottleChanged then
	BottleChanged = Instance.new("RemoteEvent")
	BottleChanged.Name = "BottleChanged"
	BottleChanged.Parent = QuestRemotes
end

-- 새로 추가: 이미 보유 중일 때 실패 알림
local BottlePromptFailed = QuestRemotes:FindFirstChild("BottlePromptFailed") or Instance.new("RemoteEvent")
BottlePromptFailed.Name = "BottlePromptFailed"
BottlePromptFailed.Parent = QuestRemotes

-- ===== CONFIG =====
local CONFIG = {
	TEMPLATE_FOLDER = "Bottle",     -- ServerStorage/Bottle
	LIVE_FOLDER = "Bottle_LIVE",    -- Workspace 폴더
	MAX_ACTIVE = 1,
	MIN_ACTIVE = 1,
	POLL_SECS = 2,
	RESPAWN_DELAY = 1.0,
	PROMPT = {
		ActionText = "Pick Up",
		ObjectText = "Bottle",
		MaxDistance = 12,
		HoldDuration = 0.2,
		KeyboardKeyCode = Enum.KeyCode.E,
	},
}
local DEBUG = true
local function dbg(...) if DEBUG then print("[BottleSpawner]", ...) end end

-- ===== 폴더 준비 =====
local templateFolder = ServerStorage:WaitForChild(CONFIG.TEMPLATE_FOLDER)
local liveFolder = workspace:FindFirstChild(CONFIG.LIVE_FOLDER)
if not liveFolder then
	liveFolder = Instance.new("Folder")
	liveFolder.Name = CONFIG.LIVE_FOLDER
	liveFolder.Parent = workspace
end

-- ===== 템플릿 수집 =====
local templates = {} :: { {ref: Instance, pivot: CFrame, isModel: boolean, name: string} }

local function getSpawnPivot(inst: Instance): CFrame
	if inst:IsA("Model") then return inst:GetPivot()
	elseif inst:IsA("BasePart") then return inst.CFrame
	else return CFrame.new(0,5,0) end
end

for _, d in ipairs(templateFolder:GetChildren()) do
	if d:IsA("Model") then
		table.insert(templates, {ref = d, name = d.Name, pivot = getSpawnPivot(d), isModel = true})
	elseif d:IsA("BasePart") then
		table.insert(templates, {ref = d, name = d.Name, pivot = d.CFrame, isModel = false})
	end
end
dbg("Template count =", #templates)

-- ===== 활성 상태 =====
local active = {} :: {[Instance]: {inst: Instance, spawnAt: number}}

local function countActive()
	local n=0; for _ in pairs(active) do n+=1 end; return n
end

local function pickRandomAvailable()
	local pool = {}
	for _, t in ipairs(templates) do
		if not active[t.ref] then table.insert(pool, t) end
	end
	if #pool == 0 then return nil end
	return pool[math.random(1, #pool)]
end

-- ===== 프롬프트 부착 =====
local function addPrompt(targetPart: BasePart, onTriggered)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = CONFIG.PROMPT.ActionText
	p.ObjectText = CONFIG.PROMPT.ObjectText
	p.KeyboardKeyCode = CONFIG.PROMPT.KeyboardKeyCode
	p.RequiresLineOfSight = false
	p.MaxActivationDistance = CONFIG.PROMPT.MaxDistance
	p.HoldDuration = CONFIG.PROMPT.HoldDuration
	p.Parent = targetPart
	p.Triggered:Connect(onTriggered)
	return p
end

local function findPromptPart(root: Instance)
	if root:IsA("BasePart") then return root end
	if root:IsA("Model") then
		return root:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- ===== 스폰 함수 =====
local function spawnOne(tmpl)
	if countActive() >= CONFIG.MAX_ACTIVE then return end
	local clone = tmpl.ref:Clone()
	clone.Parent = liveFolder
	if tmpl.isModel then clone:PivotTo(tmpl.pivot)
	else (clone :: BasePart).CFrame = tmpl.pivot end

	dbg("Spawned", tmpl.name)

	local part = findPromptPart(clone)
	if part then
		addPrompt(part, function(player: Player)
			-- 이미 가지고 있으면 실패 이벤트 전송 후 리턴
			if player:GetAttribute("HasBottle") then
				BottlePromptFailed:FireClient(player, "Let's drink a little bit", 2.5)
				return
			end

			local prompt = part:FindFirstChildOfClass("ProximityPrompt")
			if prompt then prompt:Destroy() end

			-- 획득 처리
			player:SetAttribute("HasBottle", true)
			BottleChanged:FireClient(player, true)
			pcall(function()
				BottleStore:SetAsync("Bottle_"..player.UserId, true)
			end)

			-- 모델 제거 및 재스폰
			task.defer(function()
				clone:Destroy()
				active[tmpl.ref] = nil
				task.delay(CONFIG.RESPAWN_DELAY, function()
					if countActive() < CONFIG.MAX_ACTIVE then
						local pick = pickRandomAvailable()
						if pick then spawnOne(pick) end
					end
				end)
			end)
		end)
	end

	active[tmpl.ref] = {inst=clone, spawnAt=os.clock()}
end

-- ===== 루프 =====
task.spawn(function()
	task.wait(0.1)
	while countActive() < CONFIG.MAX_ACTIVE do
		local pick = pickRandomAvailable()
		if not pick then break end
		spawnOne(pick)
	end

	while true do
		while countActive() < CONFIG.MAX_ACTIVE do
			local pick = pickRandomAvailable()
			if not pick then break end
			spawnOne(pick)
		end
		task.wait(CONFIG.POLL_SECS)
	end
end)

-- ===== 플레이어 데이터 관리 =====
Players.PlayerAdded:Connect(function(plr)
	-- DataStore 로드
	local hasBottle = false
	local ok, val = pcall(function()
		return BottleStore:GetAsync("Bottle_"..plr.UserId)
	end)
	if ok and val == true then
		hasBottle = true
	end
	plr:SetAttribute("HasBottle", hasBottle)

	-- 재접속시 UI 띄워주기
	if hasBottle then
		task.defer(function()
			BottleChanged:FireClient(plr, true)  -- true 전달
		end)
	end

end)

Players.PlayerRemoving:Connect(function(plr)
	-- 종료시 저장
	local hasBottle = plr:GetAttribute("HasBottle")
	if hasBottle then
		pcall(function()
			BottleStore:SetAsync("Bottle_"..plr.UserId, true)
		end)
	else
		pcall(function()
			BottleStore:SetAsync("Bottle_"..plr.UserId, false)
		end)
	end
end)
