-- Server Script (NPC Model 바로 아래에 넣기)
-- ex) workspace.World.NPCs.Doctor.Script

--!strict
local npc = script.Parent :: Model
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ===== 설정 =====
local cfg = {
	Distance = 20,                    -- 말풍선 표시 거리
	BubbleText = "What a puppy! I only see strange letters, today is a bad day",
	TemplateFolder = "BubbleTemplates", -- ReplicatedStorage 안의 폴더명
	TemplateName   = "Plain",           -- 사용할 BillboardGui 이름
	ShowSecs = 5,                     -- 말풍선 표시 시간
	OffsetY  = 3,                     -- 머리 위 오프셋
	TextSizeDelta = 4,                -- 글자 크기 증가량(+4 = '조금 더 큼')
	RequireAttributeName = nil,       -- 예: "HasBottle" / nil이면 조건 미사용
	RequireAttributeValue = true,
	CooldownSecs = 1,                 -- 재생성 최소 간격(스팸 방지)
	HideAfterShow = true,             -- 말풍선 한 번 뜬 후 NPC 숨김
	RespawnAfterSecs = 24 * 60 * 60,  -- 24시간 후 재등장 (서버 런타임 기준)
}

-- ===== 유틸 =====
local function getAdorneePart(npcModel: Model): BasePart?
	local head = npcModel:FindFirstChild("Head")
	if head and head:IsA("BasePart") then return head end
	if npcModel.PrimaryPart and npcModel.PrimaryPart:IsA("BasePart") then return npcModel.PrimaryPart end
	for _, d in ipairs(npcModel:GetDescendants()) do
		if d:IsA("BasePart") then return d end
	end
	return nil
end

local head = getAdorneePart(npc)
if not head then
	warn(("[NPC Bubble] %s: 부착할 BasePart(Head/PrimaryPart)가 없습니다."):format(npc:GetFullName()))
	return
end

-- 원래 자리 기억
local originalParent = npc.Parent
local originalPivot = npc:GetPivot()

-- 숨김/복귀 제어
local npcHidden = false
local bubbleCycleConsumed = false -- 이번 사이클에서 한 번 뜸/숨김 처리했는지

local function hideNPC()
	if npcHidden then return end
	npcHidden = true
	-- 혹시 표시 중인 버블 제거
	local existing = head:FindFirstChild("QuestBubble")
	if existing then existing:Destroy() end
	-- 충돌 끄고 언페어런트(씬에서 안 보이게)
	for _, d in ipairs(npc:GetDescendants()) do
		if d:IsA("BasePart") then d.CanCollide = false end
	end
	npc.Parent = nil

	-- 24시간 후 복귀
	task.delay(cfg.RespawnAfterSecs, function()
		-- 복귀 시 투명도/충돌 되돌리고 원래 위치로
		npc.Parent = originalParent
		for _, d in ipairs(npc:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = true
				if d ~= head then d.Transparency = d.Transparency end -- (그대로 유지)
			end
		end
		pcall(function() npc:PivotTo(originalPivot) end)
		npcHidden = false
		bubbleCycleConsumed = false
	end)
end

local function findTemplate(): BillboardGui?
	local folder = ReplicatedStorage:FindFirstChild(cfg.TemplateFolder)
	if not folder then
		warn(("[NPC Bubble] ReplicatedStorage.%s 폴더가 없습니다."):format(cfg.TemplateFolder))
		return nil
	end
	local tpl = folder:FindFirstChild(cfg.TemplateName)
	if not (tpl and tpl:IsA("BillboardGui")) then
		warn(("[NPC Bubble] %s/%s 가 BillboardGui가 아닙니다."):format(cfg.TemplateFolder, cfg.TemplateName))
		return nil
	end
	return tpl
end

local lastShownAt = 0.0
local function showBubbleOnce()
	if npcHidden or bubbleCycleConsumed then return end
	if os.clock() - lastShownAt < cfg.CooldownSecs then return end
	lastShownAt = os.clock()

	-- 이미 떠 있으면 패스
	local existing = head:FindFirstChild("QuestBubble")
	if existing and existing:IsA("BillboardGui") then return end

	local tpl = findTemplate()
	if not tpl then return end

	local bubble = tpl:Clone()
	bubble.Name = "QuestBubble"
	bubble.Adornee = head
	bubble.StudsOffset = Vector3.new(0, cfg.OffsetY, 0)
	bubble.AlwaysOnTop = true
	bubble.Parent = head

	-- 글씨 키우기 + 텍스트 적용
	local label = bubble:FindFirstChild("TextLabel")
	if label and label:IsA("TextLabel") then
		label.Text = cfg.BubbleText
		-- '조금' 키움: 텍스트 스케일링 없이 사이즈만 +delta
		local current = tonumber(label.TextSize) or 14
		label.TextScaled = false
		label.TextSize = math.clamp(current + cfg.TextSizeDelta, 8, 100)
	end

	-- 표시 시간 끝나면 제거 + (옵션) 숨김 타이밍
	task.delay(cfg.ShowSecs, function()
		if bubble and bubble.Parent then bubble:Destroy() end
		if cfg.HideAfterShow and not npcHidden then
			bubbleCycleConsumed = true
			hideNPC()
		end
	end)
end

local function passesAttr(plr: Player): boolean
	if not cfg.RequireAttributeName then return true end
	return plr:GetAttribute(cfg.RequireAttributeName) == cfg.RequireAttributeValue
end

-- ===== 근접 감시 (NPC가 숨겨져 있어도 루프는 계속 돌아가게 설계) =====
local function startWatcher(plr: Player, char: Model)
	task.spawn(function()
		while char.Parent do
			task.wait(0.3)
			if npcHidden then continue end
			if not npc.Parent then continue end

			local root = char.PrimaryPart
			if not root then continue end

			local dist = (head.Position - root.Position).Magnitude
			if dist <= cfg.Distance and passesAttr(plr) then
				showBubbleOnce()
			end
		end
	end)
end

Players.PlayerAdded:Connect(function(plr: Player)
	plr.CharacterAdded:Connect(function(char: Model)
		startWatcher(plr, char)
	end)
end)

-- 이미 접속 중인 플레이어(서버 재시작 직후 등)도 커버
for _, plr in ipairs(Players:GetPlayers()) do
	if plr.Character then
		startWatcher(plr, plr.Character)
	end
end
