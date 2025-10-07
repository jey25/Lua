-- ServerScriptService/CivicNPCChaseService.server.lua
--!strict

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local PathfindingService = game:GetService("PathfindingService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

local PlayerDataService = require(SSS:WaitForChild("PlayerDataService"))

local DEBUG = false
local function log(...) if DEBUG then print("[CivicNPC]", ...) end end

local BubbleTemplate = RS:WaitForChild("BubbleTemplates"):WaitForChild("Plain") :: BillboardGui

local NPC_FOLDER = workspace:WaitForChild("NPC_LIVE") :: Folder
local SAFE_FOLDER = (function()
	local f = workspace:FindFirstChild("PoliceSafeZones")
	if not f then
		f = Instance.new("Folder"); f.Name = "PoliceSafeZones"; f.Parent = workspace
	end
	return f :: Folder
end)()

-- === 이름 기반 (필요 시 수정) ===
local GOOD_NPC_NAMES = {
	"night_cowman","night_cowman2","night_boxman","night_ninja_bae",
	"nightwatch_zombie","nightwatch_pumpkin","nightwatch_zombie2",
	"nightwatch_crazy","nightwatch_savage","nightwatch_nudeman",
	"nightwatch_flower","nightwatch_eagle","nightwatch_DeathDollieOriginal",
	"nightwatch_Goblin","nightwatch_Skeleton",
}
local SUSPICIOUS_NPC_NAMES = {
	"gentleman","gentlecow","eagle","police_a","police_b","afternoon_gentlecolor",
	"king","illidan","afternoon_gentlecow","afternoon_ninja","electroman",
	"biking","snakeman","catman","TheOdd",
}

local BUBBLE_TEXT_GOOD = "You reported me, didn't you? Stand there! Right now!"
local BUBBLE_TEXT_SUSPICIOUS = "Wait, you look suspicious. What is your identity?"

local DEFAULT_CFG = {
	ChaseDistance = 45,
	LoseDistance  = 75,
	AttackRange   = 4,
	AttackDamage  = 10,
	AttackCD      = 1.2,
	MoveSpeed     = 24,   -- ▲ 살짝 상향
	PathRefresh   = 1.0,
	BubbleEvery   = 4.0,
	BubbleLife    = 2.5,
	TargetRefresh = 0.3,
	ReturnTolerance = 3.5,
}

-- === 유틸 ===
local function findPrimary(m: Model): BasePart?
	if m.PrimaryPart then return m.PrimaryPart end
	local hrp = m:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then m.PrimaryPart = hrp; return hrp end
	local head = m:FindFirstChild("Head")
	if head and head:IsA("BasePart") then return head end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then return p end
	end
	return nil
end

local function getHeadLike(m: Model): BasePart?
	local head = m:FindFirstChild("Head")
	if head and head:IsA("BasePart") then return head end
	return findPrimary(m)
end

local function getHRP(char: Model?): BasePart?
	return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function pointInsidePart(part: BasePart, worldPoint: Vector3): boolean
	local lp = part.CFrame:PointToObjectSpace(worldPoint)
	local half = part.Size * 0.5
	return math.abs(lp.X) <= half.X and math.abs(lp.Y) <= half.Y and math.abs(lp.Z) <= half.Z
end

local function isInAnySafeZone(hrp: BasePart): boolean
	for _, inst in ipairs(SAFE_FOLDER:GetChildren()) do
		if inst:IsA("BasePart") and pointInsidePart(inst, hrp.Position) then
			return true
		end
	end
	return false
end

-- ▲ NPC 키(높이)에 비례해서 말풍선 오프셋을 계산 (겹침 방지)
local function getBubbleOffsetY(npc: Model): number
	local size = npc:GetExtentsSize()
	local y = size.Y > 0 and size.Y * 0.7 or 4
	return math.clamp(y, 4, 10)
end

-- ▲ 월드 기준 Y오프셋으로 말풍선 표시 (겹침 최소화)
local function showBubble(npc: Model, text: string, life: number)
	local anchor = getHeadLike(npc)
	if not anchor then return end
	local g = BubbleTemplate:Clone()
	g.Adornee = anchor
	g.StudsOffsetWorldSpace = Vector3.new(0, getBubbleOffsetY(npc), 0)
	g.Parent = anchor
	local tl = g:FindFirstChildOfClass("TextLabel"); if tl then tl.Text = text end
	Debris:AddItem(g, life)
end

local function civicOk(plr: Player, want: "good" | "suspicious"): boolean
	local cs = plr:GetAttribute("CivicStatus")
	return (want == "good" and cs == "good") or (want == "suspicious" and cs == "suspicious")
end

-- === NPC 준비: Humanoid 있으면 경로추적, 없으면 피봇 이동 폴백 ===
type Prep = { mode: "humanoid" | "pivot", humanoid: Humanoid?, root: BasePart? }

local function ensureNPCReady(npc: Model): Prep
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = findPrimary(npc)
	if not root then return {mode="pivot", humanoid=nil, root=nil} end

	-- 공통 보정
	local hrp = npc:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		hrp.Anchored = false
		pcall(function() hrp:SetNetworkOwner(nil) end)
	end
	root.Anchored = false

	if humanoid then
		humanoid.AutoRotate = true
		if humanoid.WalkSpeed <= 0 then humanoid.WalkSpeed = DEFAULT_CFG.MoveSpeed end
		return {mode="humanoid", humanoid=humanoid, root=root}
	else
		-- ▲ Humanoid가 없는 모델: 피봇 이동으로 최소한 쫓아가게
		return {mode="pivot", humanoid=nil, root=root}
	end
end

-- === 러너 ===
type ChaseCfg = {
	npcName: string,
	targetCivic: "good" | "suspicious",
	bubbleText: string,
	ChaseDistance: number?, LoseDistance: number?,
	AttackRange: number?, AttackDamage: number?, AttackCD: number?,
	MoveSpeed: number?, PathRefresh: number?,
	BubbleEvery: number?, BubbleLife: number?,
	TargetRefresh: number?, ReturnTolerance: number?,
}

local function runNPC(npc: Model, cfg: ChaseCfg)
	local prep = ensureNPCReady(npc)
	if not prep.root then
		warn("[CivicNPC] Missing root:", npc:GetFullName()); return
	end

	local humanoid, root = prep.humanoid, prep.root
	if cfg.MoveSpeed and humanoid then humanoid.WalkSpeed = cfg.MoveSpeed end
	local homeCF = root.CFrame

	local lastBubbleAt, lastAttackAt, lastPathAt = 0.0, 0.0, 0.0
	local targetPlr: Player? = nil
	local currentWaypointIndex = 0
	local currentPath: Path? = nil

	local function refreshPath(toPos: Vector3)
		if prep.mode ~= "humanoid" then return end
		local now = os.clock()
		if now - lastPathAt < (cfg.PathRefresh or DEFAULT_CFG.PathRefresh) then return end
		lastPathAt = now
		local path = PathfindingService:CreatePath()
		local ok = pcall(function() path:ComputeAsync(root.Position, toPos) end)
		if ok and path.Status == Enum.PathStatus.Success then
			currentPath = path; currentWaypointIndex = 1
		else
			currentPath = nil
			humanoid:MoveTo(toPos)
		end
	end

	local function stepFollow(toPos: Vector3, dt: number)
		if prep.mode == "humanoid" then
			if currentPath then
				local wps = currentPath:GetWaypoints()
				if currentWaypointIndex <= #wps then
					local wp = wps[currentWaypointIndex]
					humanoid:MoveTo(wp.Position)
					if (root.Position - wp.Position).Magnitude <= 2.5 then
						currentWaypointIndex += 1
					end
				else
					currentPath = nil
				end
			else
				humanoid:MoveTo(toPos)
			end
		else
			-- ▲ 피봇 이동 폴백(장애물 무시·미끄러지듯 이동)
			local here = root.Position
			local flatTo = Vector3.new(toPos.X, here.Y, toPos.Z)
			local dir = flatTo - here
			local dist = dir.Magnitude
			if dist > 0.05 then
				local speed = cfg.MoveSpeed or DEFAULT_CFG.MoveSpeed
				local step = math.min(dist, speed * dt)
				local newPos = here + dir.Unit * step
				local look = CFrame.lookAt(newPos, newPos + Vector3.new(dir.X, 0, dir.Z))
				npc:PivotTo(look)
			end
		end
	end

	task.spawn(function()
		while npc.Parent do
			local dt = (cfg.TargetRefresh or DEFAULT_CFG.TargetRefresh)
			task.wait(dt)

			-- 타깃 탐색
			local tgt: Player? = nil
			local nearest = math.huge
			for _, plr in ipairs(Players:GetPlayers()) do
				if civicOk(plr, cfg.targetCivic) then
					local char = plr.Character
					local phrp = getHRP(char)
					local phum = char and char:FindFirstChildOfClass("Humanoid")
					if phrp and phum and phum.Health > 0 and not isInAnySafeZone(phrp) then
						local d = (phrp.Position - root.Position).Magnitude
						if d <= (cfg.ChaseDistance or DEFAULT_CFG.ChaseDistance) and d < nearest then
							nearest = d; tgt = plr
						end
					end
				end
			end

			targetPlr = tgt or targetPlr

			-- 타깃 상실
			if targetPlr then
				local char = targetPlr.Character
				local phrp = getHRP(char)
				local phum = char and char:FindFirstChildOfClass("Humanoid")
				local loseDist = cfg.LoseDistance or DEFAULT_CFG.LoseDistance
				local invalid = (not targetPlr.Parent)
					or (not phrp) or (not phum) or (phum.Health <= 0)
					or isInAnySafeZone(phrp)
					or ((phrp.Position - root.Position).Magnitude > loseDist)
					or (not civicOk(targetPlr, cfg.targetCivic))

				if invalid then
					targetPlr = nil; currentPath = nil
				end
			end

			-- 동작
			if targetPlr then
				local now = os.clock()
				if now - lastBubbleAt >= (cfg.BubbleEvery or DEFAULT_CFG.BubbleEvery) then
					lastBubbleAt = now
					showBubble(npc, cfg.bubbleText, cfg.BubbleLife or DEFAULT_CFG.BubbleLife)
				end

				local phrp = getHRP(targetPlr.Character)
				if phrp then
					refreshPath(phrp.Position)
					stepFollow(phrp.Position, dt)

					local dist = (phrp.Position - root.Position).Magnitude
					if dist <= (cfg.AttackRange or DEFAULT_CFG.AttackRange) then
						if os.clock() - lastAttackAt >= (cfg.AttackCD or DEFAULT_CFG.AttackCD) then
							lastAttackAt = os.clock()
							local hum = targetPlr.Character and targetPlr.Character:FindFirstChildOfClass("Humanoid")
							if hum and hum.Health > 0 then hum:TakeDamage(cfg.AttackDamage or DEFAULT_CFG.AttackDamage) end
						end
					end
				end
			else
				-- 복귀
				local toPos = homeCF.Position
				local here = root.Position
				local distHome = (here - toPos).Magnitude
				if distHome > (cfg.ReturnTolerance or DEFAULT_CFG.ReturnTolerance) then
					if prep.mode == "humanoid" then
						refreshPath(toPos)
						stepFollow(toPos, dt)
					else
						-- 피봇 복귀
						local dir = (Vector3.new(toPos.X, here.Y, toPos.Z) - here)
						local step = math.min(dir.Magnitude, (cfg.MoveSpeed or DEFAULT_CFG.MoveSpeed) * dt)
						local newPos = here + (dir.Magnitude > 0 and dir.Unit or Vector3.new()) * step
						local look = CFrame.lookAt(newPos, newPos + Vector3.new(dir.X, 0, dir.Z))
						npc:PivotTo(look)
					end
				end
			end
		end
	end)
end

-- === 바인딩 ===
local function nameMatchesAny(name: string, list: {string}): boolean
	for _, k in ipairs(list) do
		if name == k or string.find(string.lower(name), string.lower(k), 1, true) == 1 then
			return true
		end
	end
	return false
end

local function resolveCivicTarget(model: Model): ("good" | "suspicious" | nil)
	local attr = model:GetAttribute("CivicTarget")
	if attr == "good" or attr == "suspicious" then return attr end
	if CollectionService:HasTag(model, "CivicGoodChaser") then return "good" end
	if CollectionService:HasTag(model, "CivicSuspiciousChaser") then return "suspicious" end
	if nameMatchesAny(model.Name, GOOD_NPC_NAMES) then return "good" end
	if nameMatchesAny(model.Name, SUSPICIOUS_NPC_NAMES) then return "suspicious" end
	return nil
end

local function tryBind(inst: Instance)
	local model = inst:IsA("Model") and inst or nil
	if not model then return end
	local civic = resolveCivicTarget(model); if not civic then return end
	if model:GetAttribute("CivicBound") then return end

	local prep = ensureNPCReady(model)
	if not prep.root then
		warn("[CivicNPC] Bind skipped; no root:", model:GetFullName()); return
	end

	model:SetAttribute("CivicBound", true)
	local bubble = (civic == "good") and BUBBLE_TEXT_GOOD or BUBBLE_TEXT_SUSPICIOUS
	local cfg: ChaseCfg = { npcName = model.Name, targetCivic = civic, bubbleText = bubble }
	log("Bound", model.Name, "->", civic, "mode:", prep.mode)
	runNPC(model, cfg)
end

for _, inst in ipairs(NPC_FOLDER:GetChildren()) do tryBind(inst) end
NPC_FOLDER.ChildAdded:Connect(tryBind)

Players.PlayerAdded:Connect(function(plr)
	pcall(function() PlayerDataService:Load(plr) end) -- CivicStatus Attribute 보장
end)
