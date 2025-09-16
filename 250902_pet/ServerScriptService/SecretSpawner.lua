-- ServerScriptService/SecretSpawner.server.lua
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local CoinService = require(script.Parent:WaitForChild("CoinService"))

local CONFIG = {
	TEMPLATE_FOLDER = "Secret",  -- ServerStorage/Secret
	LIVE_FOLDER = "Secret_LIVE", -- Workspace에 생성
	MAX_ACTIVE = 2,              -- 동시에 최대 유지 개수
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

-- 폴더 준비
local templateFolder = ServerStorage:WaitForChild(CONFIG.TEMPLATE_FOLDER)
local liveFolder = workspace:FindFirstChild(CONFIG.LIVE_FOLDER)
if not liveFolder then
	liveFolder = Instance.new("Folder")
	liveFolder.Name = CONFIG.LIVE_FOLDER
	liveFolder.Parent = workspace
end

-- 풀(템플릿) 수집 + Pivot 캐시
local templates = {} -- { {ref=Instance, name=string, pivot=CFrame, isModel=bool}, ... }

local function getSpawnPivot(inst: Instance): CFrame
	local cfv = inst:FindFirstChild("SpawnPivot")
	if cfv and cfv:IsA("CFrameValue") then return cfv.Value end
	local pivot
	if inst:IsA("Model") then
		pivot = inst:GetPivot()
	elseif inst:IsA("BasePart") then
		pivot = inst.CFrame
	else
		return nil
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
	local clone = tmpl.ref:Clone()
	clone.Parent = liveFolder  -- 먼저 부모 설정

	-- 위치/회전 적용
	if tmpl.isModel then
		clone:PivotTo(tmpl.pivot)
	else
		-- BasePart류는 Parent 후 CFrame 적용이 안전
		clone.CFrame = tmpl.pivot
	end

	-- 프롬프트 부착 (기존 로직 그대로)
	local part = findPromptPart(clone)
	if part then
		addPrompt(part, function(player)
			if CoinService:GetBalance(player) >= CoinService.MAX_COINS then return end
			if CoinService:Award(player, nil) then
				local templateRef = tmpl.ref
				task.defer(function()
					if active[templateRef] and active[templateRef].inst == clone then
						clone:Destroy()
						active[templateRef] = nil
						task.delay(CONFIG.RESPAWN_DELAY, function()
							if CoinService:AnyPlayerNeedsCoins() then
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
	end

	active[tmpl.ref] = {inst = clone, spawnAt = os.clock()}
end


local function despawnAll()
	for ref, info in pairs(active) do
		if info.inst then info.inst:Destroy() end
		active[ref] = nil
	end
end

-- 메인 루프
-- SecretSpawner.server.lua (메인 루프만 교체)
task.spawn(function()
	while true do
		-- 모두 상한이면 전부 내림, 아니면 스폰 유지/보충
		if not CoinService:AnyPlayerNeedsCoins() then
			if countActive() > 0 then
				despawnAll()
			end
		else
			-- 보충 스폰
			while countActive() < CONFIG.MAX_ACTIVE do
				local pick = pickRandomAvailable()
				if not pick then break end
				spawnOne(pick)
			end

			-- 로테이트(옵션)
			if CONFIG.ROTATE_SECS > 0 then
				local now = os.clock()
				for ref, info in pairs(active) do
					if now - (info.spawnAt or now) >= CONFIG.ROTATE_SECS then
						if info.inst then info.inst:Destroy() end
						active[ref] = nil
						task.wait(0.05)
						if CoinService:AnyPlayerNeedsCoins() then
							local pick = pickRandomAvailable()
							if pick then spawnOne(pick) end
						end
					end
				end
			end
		end

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