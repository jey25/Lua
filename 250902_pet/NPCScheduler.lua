<<<<<<< HEAD

=======
>>>>>>> 5e4419183d1704bd855a5b53144707a2681a8e96
-- ServerScriptService/NPCScheduler.server.lua
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local config = require(ServerStorage:WaitForChild("NPCScheduleConfig"))

local templateFolder = ServerStorage:WaitForChild(config.TEMPLATE_FOLDER_NAME)

local liveFolder = workspace:FindFirstChild(config.LIVE_FOLDER_NAME)
if not liveFolder then
<<<<<<< HEAD
	liveFolder = Instance.new("Folder")
	liveFolder.Name = config.LIVE_FOLDER_NAME
	liveFolder.Parent = workspace
=======
    liveFolder = Instance.new("Folder")
    liveFolder.Name = config.LIVE_FOLDER_NAME
    liveFolder.Parent = workspace
>>>>>>> 5e4419183d1704bd855a5b53144707a2681a8e96
end

-- 현재 살아있는 NPC 인스턴스 (템플릿 이름 -> Instance)
local live = {}

-- 시간대 판정 (자정 넘김 지원)
local function inWindow(clock, s, e)
<<<<<<< HEAD
	if s == e then return false end
	if s < e then return (clock >= s) and (clock < e) else return (clock >= s) or (clock < e) end
end

local function inAnyWindow(clock, windows)
	for _, w in ipairs(windows or {}) do
		if inWindow(clock, w.start, w.stop) then return true end
	end
	return false
=======
    if s == e then
        return false
    end
    if s < e then
        return (clock >= s) and (clock < e)
    else
        return (clock >= s) or (clock < e)
    end
end

local function inAnyWindow(clock, windows)
    for _, w in ipairs(windows or {}) do
        if inWindow(clock, w.start, w.stop) then
            return true
        end
    end
    return false
>>>>>>> 5e4419183d1704bd855a5b53144707a2681a8e96
end

-- 템플릿에서 스폰 Pivot 얻기
-- 우선 CFrameValue "SpawnPivot"이 있으면 그것을, 없으면 GetPivot()을 사용하고 즉시 캐시를 만들어 둡니다.
local function getSpawnPivotCF(template)
<<<<<<< HEAD
	local cfv = template:FindFirstChild("SpawnPivot")
	if cfv and cfv:IsA("CFrameValue") then
		return cfv.Value
	end
	local pivot = template:GetPivot() -- PrimaryPart 없이도 동작 (Model Pivot 기반)
	-- 캐시 생성 (템플릿이 혹시 움직여도 스폰 위치 불변)
	local newCFV = Instance.new("CFrameValue")
	newCFV.Name = "SpawnPivot"
	newCFV.Value = pivot
	newCFV.Parent = template
	return pivot
end

local function spawnByTemplatePivot(npcName)
	-- 이미 살아있으면 스킵
	if live[npcName] and live[npcName].Parent then return end

	local template = templateFolder:FindFirstChild(npcName)
	if not template then
		warn(("NPCScheduler: 템플릿 '%s' 를 찾을 수 없습니다."):format(npcName))
		return
	end

	local pivot = getSpawnPivotCF(template)
	local inst

	if config.DESPawn_MODE == "park" or config.DESPAN_MODE == "park" then
		-- 오타 방지용: 잘못된 키를 쓰더라도 destroy가 기본이 되도록 아래 destroy 분기로 빠집니다.
	end

	-- 기본: 새로 클론해서 스폰
	inst = template:Clone()
	inst:PivotTo(pivot)
	inst.Parent = liveFolder
	live[npcName] = inst
end

local function despawn(npcName)
	local inst = live[npcName]
	if not inst then return end

	if config.DESPAN_MODE == "park" or config.DESPawn_MODE == "park" or config.DESPawn_MODE == "PARK" or config.DESPAN_MODE == "PARK" then
		inst.Parent = nil -- 숨기고 재사용
	else
		inst:Destroy() -- 완전 삭제
		live[npcName] = nil
	end
=======
    local cfv = template:FindFirstChild("SpawnPivot")
    if cfv and cfv:IsA("CFrameValue") then
        return cfv.Value
    end
    local pivot = template:GetPivot() -- PrimaryPart 없이도 동작 (Model Pivot 기반)
    -- 캐시 생성 (템플릿이 혹시 움직여도 스폰 위치 불변)
    local newCFV = Instance.new("CFrameValue")
    newCFV.Name = "SpawnPivot"
    newCFV.Value = pivot
    newCFV.Parent = template
    return pivot
end

local function spawnByTemplatePivot(npcName)
    -- 이미 살아있으면 스킵
    if live[npcName] and live[npcName].Parent then
        return
    end

    local template = templateFolder:FindFirstChild(npcName)
    if not template then
        warn(("NPCScheduler: 템플릿 '%s' 를 찾을 수 없습니다."):format(npcName))
        return
    end

    local pivot = getSpawnPivotCF(template)
    local inst

    if config.DESPawn_MODE == "park" or config.DESPAN_MODE == "park" then
        -- 오타 방지용: 잘못된 키를 쓰더라도 destroy가 기본이 되도록 아래 destroy 분기로 빠집니다.
    end

    -- 기본: 새로 클론해서 스폰
    inst = template:Clone()
    inst:PivotTo(pivot)
    inst.Parent = liveFolder
    live[npcName] = inst
end

local function despawn(npcName)
    local inst = live[npcName]
    if not inst then
        return
    end

    if config.DESPAN_MODE == "park" or config.DESPawn_MODE == "park" or config.DESPawn_MODE == "PARK" or
        config.DESPAN_MODE == "PARK" then
        inst.Parent = nil -- 숨기고 재사용
    else
        inst:Destroy() -- 완전 삭제
        live[npcName] = nil
    end
>>>>>>> 5e4419183d1704bd855a5b53144707a2681a8e96
end

-- 메인 루프
-- 메인 루프 (합집합 방식)
task.spawn(function()
<<<<<<< HEAD
	while true do
		local now = Lighting.ClockTime -- 0~24 float

		-- 1) 이번 틱에 "보여야 하는 NPC" 집합 계산 (그룹들의 OR)
		local desired = {}  -- npcName -> true/false
		for groupName, group in pairs(config.GROUPS) do
			local active = inAnyWindow(now, group.windows)
			for _, npcName in ipairs(group.npcs or {}) do
				if active then
					desired[npcName] = true
				elseif desired[npcName] == nil then
					desired[npcName] = false
				end
			end
		end

		-- 2) 스폰: 보여야 하는데 아직 안 떠 있으면 스폰
		for npcName, want in pairs(desired) do
			if want then
				spawnByTemplatePivot(npcName)
			end
		end

		-- 3) 디스폰: 현재 떠 있는데 이번 틱에 필요 없으면 내리기
		for npcName, inst in pairs(live) do
			if desired[npcName] ~= true then
				despawn(npcName)
			end
		end

		task.wait(config.POLL_SECS)
	end
=======
    while true do
        local now = Lighting.ClockTime -- 0~24 float

        -- 1) 이번 틱에 "보여야 하는 NPC" 집합 계산 (그룹들의 OR)
        local desired = {} -- npcName -> true/false
        for groupName, group in pairs(config.GROUPS) do
            local active = inAnyWindow(now, group.windows)
            for _, npcName in ipairs(group.npcs or {}) do
                if active then
                    desired[npcName] = true
                elseif desired[npcName] == nil then
                    desired[npcName] = false
                end
            end
        end

        -- 2) 스폰: 보여야 하는데 아직 안 떠 있으면 스폰
        for npcName, want in pairs(desired) do
            if want then
                spawnByTemplatePivot(npcName)
            end
        end

        -- 3) 디스폰: 현재 떠 있는데 이번 틱에 필요 없으면 내리기
        for npcName, inst in pairs(live) do
            if desired[npcName] ~= true then
                despawn(npcName)
            end
        end

        task.wait(config.POLL_SECS)
    end
>>>>>>> 5e4419183d1704bd855a5b53144707a2681a8e96
end)

