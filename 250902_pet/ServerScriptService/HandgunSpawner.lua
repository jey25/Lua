--!strict
local ServerStorage      = game:GetService("ServerStorage")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Players            = game:GetService("Players")
local DataStoreService   = game:GetService("DataStoreService")
local Workspace          = game:GetService("Workspace")
local RunService         = game:GetService("RunService")

-- ◆ 설정
local TOOL_NAME = "Handgun"                             -- ServerStorage 안의 Tool 이름
local MARKER_PATH = {"ItemSpawnMarkers", "HandgunSpawn"} -- Workspace 하위 스폰 마커 경로
local DS_NAME = "WorldDrops_v1"
local DS_KEY  = "drop_" .. TOOL_NAME                    -- 전 서버 공용 키
local RESPAWN_SECS = 24 * 60 * 60                       -- 24시간(실시간)

-- 내부 상태
local dropTool: Tool? = nil
local respawnConn: RBXScriptConnection? = nil
local ds = DataStoreService:GetDataStore(DS_NAME)

-- 스폰 마커 CFrame 찾기
local function getSpawnCFrame(): CFrame?
	local node: Instance = Workspace
	for _, seg in ipairs(MARKER_PATH) do
		local nxt = node:FindFirstChild(seg)
		if not nxt then return nil end
		node = nxt
	end
	local part = node :: Instance
	if part:IsA("BasePart") then
		return (part :: BasePart).CFrame
	end
	return nil
end

-- 현재 픽업 여부 판단: Character/Backpack로 들어가면 픽업으로 간주
local function isPickedUp(tool: Tool, newParent: Instance?): boolean
	if not newParent then return false end
	if newParent:IsA("Backpack") then
		return true
	end
	if newParent:IsA("Model") then
		local plr = Players:GetPlayerFromCharacter(newParent)
		if plr then return true end
	end
	return false
end

-- DataStore: nextAt 읽기
local function getNextAt(): number
	local ok, data = pcall(function()
		return ds:GetAsync(DS_KEY)
	end)
	if ok and typeof(data) == "table" and tonumber(data.nextAt) then
		return tonumber(data.nextAt) :: number
	end
	return 0
end

-- DataStore: nextAt 쓰기
local function setNextAt(nextAt: number)
	pcall(function()
		ds:UpdateAsync(DS_KEY, function(old)
			old = old or {}
			old.nextAt = math.max(0, math.floor(nextAt))
			return old
		end)
	end)
end

-- 드랍(스폰)
local function spawnHandgun()
	if dropTool and dropTool.Parent then return end
	local template = ServerStorage:FindFirstChild(TOOL_NAME)
	if not (template and template:IsA("Tool")) then
		warn(("[HandgunSpawner] ServerStorage.%s Tool이 필요합니다."):format(TOOL_NAME))
		return
	end
	local cf = getSpawnCFrame()
	if not cf then
		warn(("[HandgunSpawner] Workspace/%s/%s 마커가 없습니다."):format(table.concat(MARKER_PATH, "/")))
		return
	end

	local tool = template:Clone()
	tool.Name = TOOL_NAME

	-- Tool 위치 세팅: Handle이 있으면 거기에 CFrame 적용
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		(handle :: BasePart).CFrame = cf
	end

	tool.Parent = Workspace
	dropTool = tool

	-- 픽업 감지
	local function onParentChanged()
		if not dropTool then return end
		local parent = dropTool.Parent
		if isPickedUp(dropTool, parent) then
			-- 픽업 처리: 즉시 쿨다운 시작 & 핸들러 해제
			local untilAt = os.time() + RESPAWN_SECS
			setNextAt(untilAt)
			-- 월드에 남아있을 수 있으니 안전 제거(보통은 자동 이동)
			if dropTool and dropTool.Parent and dropTool.Parent == Workspace then
				dropTool:Destroy()
			end
			dropTool = nil
		elseif parent == nil then
			-- 누군가 지워버린 경우: 같은 쿨다운을 적용하지 않고 그대로 종료(관리자가 수동 삭제한 상황)
			dropTool = nil
		end
	end

	tool.AncestryChanged:Connect(function(_, _)
		onParentChanged()
	end)
	tool:GetPropertyChangedSignal("Parent"):Connect(onParentChanged)

	print("[HandgunSpawner] 스폰 완료")
end

-- 일정 시간 후 재스폰 예약
local function scheduleRespawn(etaSecs: number)
	etaSecs = math.max(0, math.floor(etaSecs))
	task.delay(etaSecs, function()
		-- 예약 도중에 이미 스폰되어 있으면 무시
		if dropTool and dropTool.Parent then return end
		-- DataStore 기준으로 아직 대기 중인지 재검사(서버 다중 실행 대비)
		local now = os.time()
		local nextAt = getNextAt()
		if nextAt > now then
			-- 아직 시간이 안 됨 → 남은 시간만큼 다시 예약
			scheduleRespawn(nextAt - now)
			return
		end
		spawnHandgun()
	end)
end

-- 부팅 시 초기화
local function init()
	-- 마커 유효성
	if not getSpawnCFrame() then
		warn("[HandgunSpawner] 스폰 마커가 없어 초기화를 건너뜁니다.")
		return
	end

	-- DataStore 읽어서 스폰/예약
	local now = os.time()
	local nextAt = getNextAt()
	if nextAt == 0 or nextAt <= now then
		-- 바로 스폰
		spawnHandgun()
		-- 스폰했다고 해서 nextAt을 갱신하진 않습니다(픽업 시점부터 쿨다운)
	else
		-- 남은 시간 예약
		scheduleRespawn(nextAt - now)
		print(("[HandgunSpawner] %d초 후 재스폰 예약"):format(nextAt - now))
	end
end

init()

