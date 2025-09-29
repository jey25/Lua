--!strict
-- ItemSpawnMarkers 폴더에 HandgunSpawn(BasePart) 여러 개를 배치하면
-- 각 위치에 Handgun이 스폰되고, 플레이어가 습득 시 그 자리만 RESPAWN_SECS 후 재스폰됩니다.

local ServerStorage      = game:GetService("ServerStorage")
local Players            = game:GetService("Players")
local Workspace          = game:GetService("Workspace")

-- ◆ 설정 (기존 이름 유지)
local TOOL_NAME = "Handgun"                             -- ServerStorage 안의 Tool 이름
local MARKER_PATH = {"ItemSpawnMarkers", "HandgunSpawn"} -- [마커폴더, 마커이름]
local RESPAWN_SECS = 24 * 60 * 60                       -- 24시간(실시간)

-- 내부 상태: 마커별로 상태를 관리
type MarkerState = {
	tool: Tool?,
	version: number, -- 예약/스폰 충돌 방지용 세대 번호
}
local stateByMarker: {[BasePart]: MarkerState} = {}

-- 현재 픽업 여부 판단: Character/Backpack로 들어가면 픽업으로 간주 (기존 함수명 유지)
local function isPickedUp(tool: Tool, newParent: Instance?): boolean
	if not newParent then return false end
	if newParent:IsA("Backpack") then return true end
	if newParent:IsA("Model") then
		local plr = Players:GetPlayerFromCharacter(newParent)
		if plr then return true end
	end
	return false
end

-- 마커 폴더 찾기 (MARKER_PATH[1]) → 그 아래의 모든 HandgunSpawn(BasePart) 수집
local function findAllMarkerParts(): {BasePart}
	local markersName = MARKER_PATH[#MARKER_PATH] -- "HandgunSpawn"
	-- 폴더(또는 컨테이너)까지 이동: MARKER_PATH의 마지막 요소 전까지 따라감
	local node: Instance = Workspace
	for i, seg in ipairs(MARKER_PATH) do
		if i == #MARKER_PATH then break end -- 마지막은 이름 매칭용
		local nxt = node:FindFirstChild(seg)
		if not nxt then
			warn(("[HandgunSpawner] Workspace/%s 폴더가 없습니다."):format(table.concat(MARKER_PATH, "/")))
			return {}
		end
		node = nxt
	end

	local results = {} :: {BasePart}
	for _, inst in ipairs(node:GetDescendants()) do
		if inst.Name == markersName and inst:IsA("BasePart") then
			table.insert(results, inst)
		end
	end
	return results
end

-- 일정 시간 후 재스폰 예약 (기존 함수명 유지, 시그니처 확장: 마커별 예약)
local function scheduleRespawn(marker: BasePart, etaSecs: number)
	if etaSecs < 0 then etaSecs = 0 end
	local st = stateByMarker[marker]
	if not st then return end
	local myVersion = st.version

	task.delay(etaSecs, function()
		-- 마커가 삭제되었거나, 다른 스폰이 먼저 일어났다면 무시
		local cur = stateByMarker[marker]
		if not cur then return end
		if cur.version ~= myVersion then return end
		if cur.tool and cur.tool.Parent then return end

		-- 재스폰
		-- (spawnHandgun 호출은 아래 정의. 동일 이름 유지하되 마커 인자로 받도록 확장)
		local ok, err = pcall(function()
			-- spawnHandgun이 내부에서 cur.version을 증가시킴
			-- version 체크 덕분에 지연 예약 중복이 있어도 한 번만 스폰됨
			spawnHandgun(marker)
		end)
		if not ok then
			warn(("[HandgunSpawner] 재스폰 실패: %s"):format(err))
		end
	end)
end

-- 드랍(스폰) (기존 함수명 유지, 시그니처 확장: 특정 마커로 스폰)
function spawnHandgun(marker: BasePart)
	-- 상태 초기화/획득
	local st = stateByMarker[marker]
	if not st then
		st = { tool = nil, version = 0 }
		stateByMarker[marker] = st
	end

	-- 이미 월드에 살아있는 경우 스킵
	if st.tool and st.tool.Parent then return end

	-- 템플릿 검증
	local template = ServerStorage:FindFirstChild(TOOL_NAME)
	if not (template and template:IsA("Tool")) then
		warn(("[HandgunSpawner] ServerStorage.%s Tool이 필요합니다."):format(TOOL_NAME))
		return
	end

	-- 세대 갱신(예약 충돌 방지 토큰)
	st.version += 1

	-- 스폰
	local tool = template:Clone()
	tool.Name = TOOL_NAME

	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		(handle :: BasePart).CFrame = marker.CFrame
	else
		warn(("[HandgunSpawner] %s: Tool에 Handle이 없어 위치를 정확히 지정할 수 없습니다."):format(TOOL_NAME))
	end

	-- 마커 식별 정보(디버깅/트래킹용, 선택)
	tool:SetAttribute("SpawnMarkerPath", marker:GetFullName())

	tool.Parent = Workspace
	st.tool = tool

	-- 픽업/삭제 감지
	local pickedProcessed = false
	local function onParentChanged()
		if not st or not tool then return end
		if pickedProcessed then return end

		local parent = tool.Parent
		if isPickedUp(tool, parent) then
			-- 픽업됨 → 해당 마커만 리스폰 카운트 시작
			pickedProcessed = true
			st.tool = nil
			-- 혹시 월드에 잔존 시 안전 제거 (보통은 Backpack/Character로 이동)
			if parent == Workspace then
				tool:Destroy()
			end
			-- 이 마커만 타이머 시작
			scheduleRespawn(marker, RESPAWN_SECS)
		elseif parent == nil then
			-- 관리자 등이 강제 삭제 → 쿨다운 없이 종료(요구사항: "플레이어가 습득해서 사라질 경우"에만 리스폰)
			pickedProcessed = true
			st.tool = nil
		end
	end

	tool.AncestryChanged:Connect(function(_, _)
		onParentChanged()
	end)
	tool:GetPropertyChangedSignal("Parent"):Connect(onParentChanged)

	print(("[HandgunSpawner] 스폰 완료 @ %s"):format(marker:GetFullName()))
end

-- 부팅 시 초기화 (기존 함수명 유지)
local function init()
	-- 모든 마커 수집
	local markers = findAllMarkerParts()
	if #markers == 0 then
		warn("[HandgunSpawner] 스폰 마커(HandgunSpawn)가 없어 초기화를 건너뜁니다.")
		return
	end

	-- 각 마커마다 즉시 스폰 (서버별로 독립적으로 돌아감)
	for _, marker in ipairs(markers) do
		-- 마커별 상태 준비
		if not stateByMarker[marker] then
			stateByMarker[marker] = { tool = nil, version = 0 }
		end
		spawnHandgun(marker)
	end
end

init()
