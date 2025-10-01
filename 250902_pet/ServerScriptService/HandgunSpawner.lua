--!strict
-- ItemSpawnMarkers 폴더에 HandgunSpawn(BasePart), BatSpawn(BasePart) 등 여러 개를 배치하면
-- 각 위치에 대응되는 아이템이 스폰되고,
-- 플레이어가 습득 시 그 자리만 respawnSecs 후 재스폰됩니다.

local ServerStorage = game:GetService("ServerStorage")
local Players       = game:GetService("Players")
local Workspace     = game:GetService("Workspace")

-- ◆ 여러 아이템 스폰 설정
local ITEM_CONFIGS = {
	{
		toolName    = "Handgun",                             -- ServerStorage 안 Tool 이름
		markerPath  = {"ItemSpawnMarkers", "HandgunSpawn"},  -- 마커 이름
		respawnSecs = 24 * 60 * 60,                          -- 24시간
	},
	{
		toolName    = "Bat",
		markerPath  = {"ItemSpawnMarkers", "BatSpawn"},
		respawnSecs = 24 * 60 * 60,                                    
	},
	-- 필요하면 추가 가능
}

-- 내부 상태: 마커별로 상태를 관리
type MarkerState = {
	tool: Tool?,
	version: number, -- 예약/스폰 충돌 방지용 세대 번호
	cfg: any,        -- 어떤 아이템 설정에 속하는지
}
local stateByMarker: {[BasePart]: MarkerState} = {}

-- 현재 픽업 여부 판단
local function isPickedUp(tool: Tool, newParent: Instance?): boolean
	if not newParent then return false end
	if newParent:IsA("Backpack") then return true end
	if newParent:IsA("Model") then
		local plr = Players:GetPlayerFromCharacter(newParent)
		if plr then return true end
	end
	return false
end

-- 마커 폴더 찾기
local function findAllMarkerParts(markerPath: {string}): {BasePart}
	local markersName = markerPath[#markerPath]
	local node: Instance = Workspace
	for i = 1, #markerPath - 1 do
		local seg = markerPath[i]
		local nxt = node:FindFirstChild(seg)
		if not nxt then return {} end
		node = nxt
	end
	local results = {}
	for _, inst in ipairs(node:GetDescendants()) do
		if inst.Name == markersName and inst:IsA("BasePart") then
			table.insert(results, inst)
		end
	end
	return results
end

-- 일정 시간 후 재스폰 예약
local function scheduleRespawn(marker: BasePart, etaSecs: number)
	if etaSecs < 0 then etaSecs = 0 end
	local st = stateByMarker[marker]
	if not st then return end
	local myVersion = st.version

	task.delay(etaSecs, function()
		local cur = stateByMarker[marker]
		if not cur then return end
		if cur.version ~= myVersion then return end
		if cur.tool and cur.tool.Parent then return end

		local ok, err = pcall(function()
			spawnItem(cur.cfg, marker)
		end)
		if not ok then
			warn(("[%sSpawner] 재스폰 실패: %s"):format(cur.cfg.toolName, err))
		end
	end)
end

-- 아이템 스폰
function spawnItem(itemCfg, marker: BasePart)
	-- 상태 초기화/획득
	local st = stateByMarker[marker]
	if not st then
		st = { tool = nil, version = 0, cfg = itemCfg }
		stateByMarker[marker] = st
	end

	-- 이미 월드에 살아있는 경우 스킵
	if st.tool and st.tool.Parent then return end

	-- 템플릿 확인
	local toolName = itemCfg.toolName
	local template = ServerStorage:FindFirstChild(toolName)
	if not (template and template:IsA("Tool")) then
		warn(("[%sSpawner] ServerStorage.%s Tool 없음"):format(toolName, toolName))
		return
	end

	-- 세대 갱신
	st.version += 1

	-- 스폰
	-- spawnItem() 안 스폰 직후 부분을 이렇게 바꿔보세요.

	-- 스폰
	local tool = template:Clone()
	tool.Name = toolName

	-- 1) 먼저 Parent 지정
	tool.Parent = Workspace

	-- 2) 모든 파트를 Unanchor (그리고 필요하면 충돌 정리)
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			if d ~= tool:FindFirstChild("Handle") then
				d.CanCollide = false
			end
		end
	end

	-- 3) 조립체 루트(AssemblyRootPart) 기준으로 이동
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		local root = handle.AssemblyRootPart or handle
		root.CFrame = marker.CFrame
	end

	-- 리스폰에 쓸 마커 경로
	tool:SetAttribute("SpawnMarkerPath", marker:GetFullName())

	st.tool = tool
	st.cfg = itemCfg

	-- 픽업/삭제 감지
	local pickedProcessed = false
	local function onParentChanged()
		if not st or not tool then return end
		if pickedProcessed then return end

		local parent = tool.Parent
		if isPickedUp(tool, parent) then
			pickedProcessed = true
			st.tool = nil
			if parent == Workspace then
				tool:Destroy()
			end
			scheduleRespawn(marker, itemCfg.respawnSecs)
		elseif parent == nil then
			pickedProcessed = true
			st.tool = nil
		end
	end

	tool.AncestryChanged:Connect(function(_, _)
		onParentChanged()
	end)
	tool:GetPropertyChangedSignal("Parent"):Connect(onParentChanged)

	print(("[%sSpawner] 스폰 완료 @ %s"):format(toolName, marker:GetFullName()))
end

-- 초기화
local function init()
	for _, cfg in ipairs(ITEM_CONFIGS) do
		local markers = findAllMarkerParts(cfg.markerPath)
		if #markers == 0 then
			warn(("[%sSpawner] 마커가 없습니다."):format(cfg.toolName))
		end
		for _, marker in ipairs(markers) do
			if not stateByMarker[marker] then
				stateByMarker[marker] = { tool = nil, version = 0, cfg = cfg }
			end
			spawnItem(cfg, marker)
		end
	end
end

init()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemRespawnRequest = ReplicatedStorage:WaitForChild("ItemRespawnRequest")

ItemRespawnRequest.OnServerEvent:Connect(function(player, markerPath, toolName)
	for marker, st in pairs(stateByMarker) do
		if marker:GetFullName() == markerPath and st.cfg.toolName == toolName then
			st.tool = nil
			scheduleRespawn(marker, st.cfg.respawnSecs)
			print(("[%sSpawner] %s 요청으로 재스폰 예약"):format(toolName, player.Name))
		end
	end
end)

