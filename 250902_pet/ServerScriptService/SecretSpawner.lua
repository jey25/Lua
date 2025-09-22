-- ServerScriptService/SecretSpawner.server.lua
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local CoinService = require(script.Parent:WaitForChild("CoinService"))

local CONFIG = {
	TEMPLATE_FOLDER = "Secret",  -- ServerStorage/Secret
	LIVE_FOLDER = "Secret_LIVE", -- Workspace에 생성
	MAX_ACTIVE = 2,     
	MIN_ACTIVE = 2,  -- ★ 추가: 필요 없으면 0-- 동시에 최대 유지 개수
	POLL_SECS = 2,               -- 주기 점검
	RESPAWN_DELAY = 1.0,         -- 터치 후 교체 지연
	ROTATE_SECS = 0,             -- >0 이면 주기적 로테이트(해당 시간 지나면 교체). 0이면 비활성.
	PROMPT = {
		ActionText = "Get Coin",
		ObjectText = "Secret",
		MaxDistance = 12,
		HoldDuration = 0.2,
		KeyboardKeyCode = Enum.KeyCode.E, -- 선택
	},
}

-- 맨 위 CONFIG 아래에 추가
CONFIG.DEBUG = true -- 필요 시 false

local function dbg(...)
	if CONFIG.DEBUG then
		print("[SecretSpawner]", ...)
	end
end

-- 폴더 준비
local templateFolder = ServerStorage:WaitForChild(CONFIG.TEMPLATE_FOLDER)
local liveFolder = workspace:FindFirstChild(CONFIG.LIVE_FOLDER)
if not liveFolder then
	liveFolder = Instance.new("Folder")
	liveFolder.Name = CONFIG.LIVE_FOLDER
	liveFolder.Parent = workspace
end


local function safeAnyPlayerNeedsCoins(): boolean
	-- 1) 메서드가 있으면 그대로 시도
	if type(CoinService.AnyPlayerNeedsCoins) == "function" then
		local ok, res = pcall(CoinService.AnyPlayerNeedsCoins, CoinService)
		if ok then return res end
		warn("[SecretSpawner] AnyPlayerNeedsCoins error:", res)
	end
	-- 2) 폴백: 직접 계산
	local okPlayers, players = pcall(Players.GetPlayers, Players)
	if not okPlayers then return false end
	for _, plr in ipairs(players) do
		local okB, bal = pcall(CoinService.GetBalance, CoinService, plr)
		local okM, max = pcall(CoinService.GetMaxFor, CoinService, plr)
		if okB and okM and tonumber(bal) < tonumber(max) then
			return true
		end
	end
	return false
end


-- 풀(템플릿) 수집 + Pivot 캐시
local templates = {} -- { {ref=Instance, name=string, pivot=CFrame, isModel=bool}, ... }

local function targetActiveCount(): number
	-- 플레이어가 코인이 필요하면 MAX, 아니면 MIN 유지
	if safeAnyPlayerNeedsCoins() then
		return CONFIG.MAX_ACTIVE
	else
		return CONFIG.MIN_ACTIVE or 0
	end
end



local function fallbackPivotCFrame(): CFrame
	-- 맵의 SpawnLocation 있으면 그 위 3스터드
	local sp = workspace:FindFirstChildOfClass("SpawnLocation")
	if sp and sp:IsA("BasePart") then
		return sp.CFrame + Vector3.new(0, 3, 0)
	end
	-- 카메라가 있으면 카메라 위치 앞쪽
	local cam = workspace.CurrentCamera
	if cam then
		return cam.CFrame + cam.CFrame.LookVector * 10 + Vector3.new(0, 3, 0)
	end
	-- 최후 수단
	return CFrame.new(0, 10, 0)
end

local function isBadPivot(cf: CFrame): boolean
	local p = cf.Position
	-- 원점이거나 너무 멀리(스트리밍 반경 밖) 있으면 나쁘다고 판단
	if p:FuzzyEq(Vector3.new(0,0,0), 1e-3) then return true end
	if p.Magnitude > 20000 then return true end
	return false
end



local function getSpawnPivot(inst: Instance): CFrame
	local cfv = inst:FindFirstChild("SpawnPivot")
	if cfv and cfv:IsA("CFrameValue") then
		if isBadPivot(cfv.Value) then
			cfv.Value = fallbackPivotCFrame() -- ★ 중요: 잘못된 Pivot을 교정
		end
		return cfv.Value
	end

	local pivot: CFrame?
	if inst:IsA("Model") then
		pivot = inst:GetPivot()
	elseif inst:IsA("BasePart") then
		pivot = inst.CFrame
	end
	if not pivot or isBadPivot(pivot) then
		pivot = fallbackPivotCFrame()
	end

	local v = Instance.new("CFrameValue")
	v.Name = "SpawnPivot"
	v.Value = pivot
	v.Parent = inst

	return pivot
end




local function isLoosePart(part: BasePart)
	-- Secret 폴더 안에서 Model 조상(템플릿으로 쓸 상위 Model)이 없으면 loose
	local ancModel = part:FindFirstAncestorOfClass("Model")
	return (ancModel == nil) or (ancModel.Parent and not ancModel:IsDescendantOf(templateFolder))
end

templates = {}

for _, d in ipairs(templateFolder:GetDescendants()) do
	if d:IsA("Model") then
		table.insert(templates, {
			ref = d,
			name = d.Name,
			pivot = getSpawnPivot(d),
			isModel = true,
		})
	elseif d:IsA("BasePart") and isLoosePart(d) then
		table.insert(templates, {
			ref = d,
			name = d.Name,
			pivot = getSpawnPivot(d),
			isModel = false,
		})
	end
end

-- templates 채운 뒤에 바로 추가
dbg("Template count =", #templates)
if #templates == 0 then
	warn("[SecretSpawner] No templates under ServerStorage/" .. CONFIG.TEMPLATE_FOLDER .. ". Nothing to spawn.")
end
for i, t in ipairs(templates) do
	dbg(("Template[%d] name=%s isModel=%s pivot=%s"):format(i, t.name, tostring(t.isModel), tostring(t.pivot)))
end


-- 활성 상태 관리
local active = {}  -- [templateRef] = {inst=Instance, spawnAt=os.clock()}
local function countActive()
	local n=0; for _ in pairs(active) do n+=1 end; return n
end

local function pickRandomAvailable()
	local pool = {}
	for _, t in ipairs(templates) do
		if active[t.ref] == nil then table.insert(pool, t) end
	end
	if #pool == 0 then return nil end
	return pool[math.random(1, #pool)]
end

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
		local specific = root:FindFirstChild("PromptPart", true)
		if specific and specific:IsA("BasePart") then return specific end
		return root:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- (SecretSpawner.server.lua의 spawnOne 함수 내부 핵심만 교체)

local function spawnOne(tmpl)
	if countActive() >= CONFIG.MAX_ACTIVE then
		return
	end
	if not tmpl or not tmpl.ref or not liveFolder or not liveFolder.Parent then
		warn("[SecretSpawner] spawnOne(): invalid state", tmpl and tmpl.name)
		return
	end

	local clone = tmpl.ref:Clone()
	if not clone then
		warn("[SecretSpawner] Clone failed (Archivable=false ?) for", tmpl.name)
		return
	end

	clone.Parent = liveFolder
	-- 위치/회전 적용
	if tmpl.isModel then
		clone:PivotTo(tmpl.pivot)
	else
		local bp = clone :: BasePart
		bp.CFrame = tmpl.pivot
	end

	dbg("Spawned", tmpl.name, "→", clone:GetFullName())

	-- 프롬프트 부착
	local part = findPromptPart(clone)
	if part then
		addPrompt(part, function(player)
			if CoinService:GetBalance(player) >= CoinService:GetMaxFor(player) then
				return
			end
			local prompt = part:FindFirstChildOfClass("ProximityPrompt")
			if prompt then prompt:Destroy() end
			if CoinService:Award(player, nil) then
				local templateRef = tmpl.ref
				task.defer(function()
					if active[templateRef] and active[templateRef].inst == clone then
						clone:Destroy()
						active[templateRef] = nil
						task.delay(CONFIG.RESPAWN_DELAY, function()
							-- 보충은 “목표 개수” 기준으로
							if countActive() < targetActiveCount() then
								local pick = pickRandomAvailable()
								if pick then spawnOne(pick) end
							end
						end)
					else
						clone:Destroy()
					end
				end)
			end
		end)
	else
		warn("[SecretSpawner] No BasePart found for prompt in", tmpl.name)
	end

	active[tmpl.ref] = {inst = clone, spawnAt = os.clock()}
end



local function despawnAll()
	for ref, info in pairs(active) do
		if info.inst then info.inst:Destroy() end
		active[ref] = nil
	end
end



task.spawn(function()
	-- 첫 프레임 보충 (스트리밍/지연에 대비)
	task.wait(0.1)
	local target = targetActiveCount()
	dbg("Initial target", target)
	while countActive() < target do
		local pick = pickRandomAvailable()
		if not pick then break end
		spawnOne(pick)
	end

	while true do
		local t = targetActiveCount()

		-- 보충
		while countActive() < t do
			local pick = pickRandomAvailable()
			if not pick then break end
			spawnOne(pick)
		end

		-- 초과 제거
		while countActive() > t do
			local oldestRef, oldestAge
			local nowT = os.clock()
			for ref, info in pairs(active) do
				local age = nowT - (info.spawnAt or nowT)
				if (not oldestAge) or age > oldestAge then
					oldestRef, oldestAge = ref, age
				end
			end
			if oldestRef and active[oldestRef] then
				local inst = active[oldestRef].inst
				if inst then
					dbg("Despawn", inst:GetFullName())
					inst:Destroy()
				end
				active[oldestRef] = nil
			else
				break
			end
		end

		-- (옵션) 로테이트는 기존 그대로

		task.wait(CONFIG.POLL_SECS)
	end
end)




-- (선택) Secret 폴더에 항목을 나중에 추가/삭제해도 반영하고 싶다면:
templateFolder.DescendantAdded:Connect(function(d)
	if (d:IsA("Model")) or (d:IsA("BasePart") and isLoosePart(d)) then
		local pivot = getSpawnPivot(d)
		if pivot then
			table.insert(templates, {
				ref = d, name = d.Name, pivot = pivot, isModel = d:IsA("Model")
			})
		end
	end
end)