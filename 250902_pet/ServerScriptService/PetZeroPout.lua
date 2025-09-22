
--!strict
-- ServerScriptService/PetZeroPout.server.lua
-- 애정도 0 + Suck 아이콘 상태에서 주기적으로 "펫 삐짐" 연출:
-- 1~3회: 제자리 멈춤 + 터치 아이콘 + 3회 클릭 해제
-- 4회: HomeLocation으로 천천히 귀가(클릭 불가), 도착 시 카운트 0 리셋
-- 애정도 ≥1 이 되면 즉시 비활성화/초기화

local Players            = game:GetService("Players")
local DataStoreService   = game:GetService("DataStoreService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

-- ▸ WangEvent(마커/버블/SFX) 재사용
local RemoteFolder = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder", ReplicatedStorage)
RemoteFolder.Name = "RemoteEvents"
local WangEvent = RemoteFolder:FindFirstChild("WangEvent") or Instance.new("RemoteEvent", RemoteFolder)
WangEvent.Name = "WangEvent"

local StreetFoodEvent = RemoteFolder:FindFirstChild("StreetFoodEvent") or Instance.new("RemoteEvent", RemoteFolder)
StreetFoodEvent.Name = "StreetFoodEvent"

local SFXFolder = ReplicatedStorage:WaitForChild("SFX")
local function resolveWhimper(): Sound?
	local s = SFXFolder:FindFirstChild("Whimper")
	return (s and s:IsA("Sound")) and s or nil
end

-- ===== 설정 =====
local DS_NAME                = "PetPout_v1"
local POUT_MIN_GAP_SEC       = 60      -- 1회차~3회차: 최소 대기
local POUT_MAX_GAP_SEC       = 90     -- 1회차~3회차: 최대 대기 (평균 ~2분)
local HOME_SPEED             = 2.0     -- wangattraction의 APPROACH_SPEED와 동일
local LOOP_DT                = 0.15
local TOUCH_NEEDED           = 3       -- 클릭 필요 횟수
local TOUCH_RANGE            = 2.5     -- 목표 도달 판정
local MARKER_KEY             = "pout_touch"
local MARKER_PRESET          = "Click Icon" -- MarkerClient 프리셋 이름
local ZERO_HOLD_ATTR         = "PetAffectionZeroHoldSec"
local ZERO_REACHED_ATTR      = "PetAffectionMinReachedUnix"

-- ▸ 저장소
local Store = DataStoreService:GetDataStore(DS_NAME)

-- ===== 내부 상태 =====
type PState = {
	count: number,         -- 현재까지 발동 누계(0~3). 4회째에 홈으로 귀가
	schedTok: number,      -- 스케줄 토큰
	actionTok: number,     -- 진행 중 액션 토큰(멈춤/귀가)
	clicking: boolean,     -- 클릭 해제 모드 중 여부
	clickCount: number,    -- 이번 회차 클릭 누계
	savedWS: number?,      -- 복원용 WalkSpeed
}
local ST: {[Player]: PState} = {}

local function now(): number return os.time() end

-- ===== 유틸 =====
local function getAnyBasePart(inst: Instance): BasePart?
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then
		local m = inst :: Model
		if m.PrimaryPart then return m.PrimaryPart end
		local hrp = m:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then return hrp end
		return m:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function findPlayersPet(player: Player): Model?
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("Model") and inst:GetAttribute("OwnerUserId") == player.UserId then
			if getAnyBasePart(inst) then return inst end
		end
	end
	return nil
end

-- Align/Follow 제약 정리
local function cleanupFollowConstraints(pet: Model)
	local pp = getAnyBasePart(pet); if not pp then return end
	for _, ch in ipairs(pp:GetChildren()) do
		if ch:IsA("AlignPosition") or ch:IsA("AlignOrientation") then ch:Destroy()
		elseif ch:IsA("Attachment") and ch.Name == "PetAttach" then ch:Destroy() end
	end
end

local function setModelAnchored(model: Model, anchored: boolean)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = anchored
			if anchored then
				p.AssemblyLinearVelocity = Vector3.zero
				p.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end
end

-- 플레이어 캐릭터에 재부착(기존 wang 코어 로직을 경량화)
local function reattachFollowToCharacter(pet: Model, player: Player)
	local pp = getAnyBasePart(pet)
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not (pp and hrp) then return end

	cleanupFollowConstraints(pet)

	local aPet = Instance.new("Attachment"); aPet.Name = "PetAttach"; aPet.Parent = pp
	local aChar = hrp:FindFirstChild("PetAttach_"..tostring(pet:GetAttribute("PetId") or "")) :: Attachment
	if not aChar then
		aChar = Instance.new("Attachment"); aChar.Name = "PetAttach_"..tostring(pet:GetAttribute("PetId") or "")
		aChar.Parent = hrp
	end

	-- 기존 속성에 저장된 오프셋 사용(없으면 기본값)
	local off = Vector3.new(
		tonumber(pet:GetAttribute("OffsetX")) or 2.5,
		tonumber(pet:GetAttribute("OffsetY")) or -1.5,
		tonumber(pet:GetAttribute("OffsetZ")) or -2.5
	)
	aChar.Position = off

	local ap = Instance.new("AlignPosition")
	ap.Attachment0 = aPet; ap.Attachment1 = aChar
	ap.ApplyAtCenterOfMass = true; ap.RigidityEnabled = false
	ap.MaxForce = 1e6; ap.Responsiveness = 80
	ap.Parent = pp

	local ao = Instance.new("AlignOrientation")
	ao.Attachment0 = aPet; ao.Attachment1 = aChar
	ao.RigidityEnabled = false; ao.MaxTorque = 1e6; ao.Responsiveness = 60
	ao.Parent = pp
end

-- 마커 on/off
local function showTouchMarker(player: Player, target: Instance)
	WangEvent:FireClient(player, "ShowMarker", {
		target = target, key = MARKER_KEY, preset = MARKER_PRESET,
		transparency = 0.15, size = UDim2.fromOffset(72,72),
		pulse = true, offsetY = 2.2, alwaysOnTop = true
	})
end


local function hideTouchMarker(player: Player, target: Instance)
	WangEvent:FireClient(player, "HideMarker", { target = target, key = MARKER_KEY })
end

-- 펫 클릭 3회 해제용 ClickDetector 간단 부착
local function ensurePoutHitbox(pet: Model): BasePart?
	local base = getAnyBasePart(pet); if not base then return nil end
	local hit = pet:FindFirstChild("PoutClickHitbox")
	if hit and hit:IsA("BasePart") then return hit end

	local size = pet:GetExtentsSize()
	local hitbox = Instance.new("Part")
	hitbox.Name = "PoutClickHitbox"
	hitbox.Size = size * 1.4               -- 클릭 편의 위해 크게
	hitbox.CFrame = base.CFrame
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = true
	hitbox.Massless = true
	hitbox.Anchored = false
	hitbox.Parent = pet

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hitbox
	weld.Part1 = base
	weld.Parent = hitbox

	-- 여기에 ClickDetector 부착
	local cd = Instance.new("ClickDetector")
	cd.Name = "PoutClick"
	cd.MaxActivationDistance = 40
	cd.Parent = hitbox

	return hitbox
end

local WHIMPER_PERIOD = 2.0

local function startWhimperLoop(player: Player)
	local st = ST[player]; if not st then return end
	st.whTok = (st.whTok or 0) + 1
	local my = st.whTok
	local tpl = resolveWhimper(); if not tpl then return end

	task.spawn(function()
		while ST[player] == st and st.whTok == my and st.clicking do
			-- 클라의 WangEvent SFX 핸들러가 이미 있으므로 그대로 사용
			WangEvent:FireClient(player, "PlaySfxTemplate", tpl, "whimper")
			task.wait(WHIMPER_PERIOD)
		end
	end)
end

local function stopWhimperLoop(player: Player)
	local st = ST[player]; if not st then return end
	st.whTok = (st.whTok or 0) + 1
end


local function removePoutClick(pet: Model)
	for _, d in ipairs(pet:GetDescendants()) do
		if d:IsA("ClickDetector") and d.Name == "PoutClick" then d:Destroy() end
	end
	local hb = pet:FindFirstChild("PoutClickHitbox")
	if hb and hb:IsA("BasePart") then hb:Destroy() end
end


-- ===== 저장/로드 =====
local function save(player: Player)
	local st = ST[player]; if not st then return end
	pcall(function()
		Store:SetAsync("u_"..player.UserId, { Count = st.count })
	end)
end
local function load(player: Player): number
	local ok, data = pcall(function()
		return Store:GetAsync("u_"..player.UserId)
	end)
	if ok and typeof(data) == "table" and typeof(data.Count) == "number" then
		return math.clamp(math.floor(data.Count), 0, 3)
	end
	return 0
end

-- ===== 조건 검사: Suck Icon(Zero) 실제 노출 상태인지 =====
local function isZeroIconOn(player: Player): boolean
	local aff = player:GetAttribute("PetAffection") or 0
	if aff ~= 0 then return false end
	local last0 = tonumber(player:GetAttribute(ZERO_REACHED_ATTR)) or 0
	local hold  = tonumber(player:GetAttribute(ZERO_HOLD_ATTR)) or 30
	return (last0 > 0) and ((now() - last0) >= hold)
end

-- ===== 진행 취소/초기화 =====
local function stopAll(player: Player, doRestoreFollow: boolean)
	local st = ST[player]; if not st then return end
	st.schedTok += 1; st.actionTok += 1
	st.clicking = false; st.clickCount = 0
	stopWhimperLoop(player)

	local pet = findPlayersPet(player)
	if pet then
		hideTouchMarker(player, pet)
		removePoutClick(pet)
		StreetFoodEvent:FireClient(player, "Bubble", { text = "" }) -- 버블 제거
		setModelAnchored(pet, false)
		if doRestoreFollow then
			reattachFollowToCharacter(pet, player)
			local hum = pet:FindFirstChildOfClass("Humanoid")
			if hum and st.savedWS then hum.WalkSpeed = st.savedWS end
		end
		pet:SetAttribute("BlockPetQuestClicks", false)
	end
end


-- ===== 1~3회차: 멈춤 + 3회 클릭 =====
local function startFreezeAndClick(player: Player)
	local st = ST[player]; if not st then return end
	st.actionTok += 1
	local my = st.actionTok

	local pet = findPlayersPet(player); if not pet then return end
	local base = getAnyBasePart(pet); if not base then return end
	pet:SetAttribute("BlockPetQuestClicks", true)

	-- 멈춤
	cleanupFollowConstraints(pet)
	setModelAnchored(pet, true)
	local hum = pet:FindFirstChildOfClass("Humanoid")
	if hum then st.savedWS = hum.WalkSpeed end

	-- 마커/버블/SFX/클릭 준비
	showTouchMarker(player, pet)
	StreetFoodEvent:FireClient(player, "Bubble", { text = ("Tap 0/"..TOUCH_NEEDED), stash = true })

	local hit = ensurePoutHitbox(pet); if not hit then return end
	local cd = hit:FindFirstChild("PoutClick") :: ClickDetector
	if not (cd and cd:IsA("ClickDetector")) then return end

	st.clicking = true
	st.clickCount = 0
	startWhimperLoop(player)

	-- 클릭 핸들러
	local function onClick(p: Player)
		if p ~= player then return end
		if ST[player] ~= st or st.actionTok ~= my or not st.clicking then return end

		st.clickCount += 1
		StreetFoodEvent:FireClient(player, "Bubble", { text = ("Tap "..st.clickCount.."/"..TOUCH_NEEDED) })

		if st.clickCount >= TOUCH_NEEDED then
			-- 해제
			st.clicking = false
			stopWhimperLoop(player)
			hideTouchMarker(player, pet)
			removePoutClick(pet)
			StreetFoodEvent:FireClient(player, "Bubble", { text = "" })

			setModelAnchored(pet, false)
			reattachFollowToCharacter(pet, player)
			if hum and st.savedWS then hum.WalkSpeed = st.savedWS end
			pet:SetAttribute("BlockPetQuestClicks", false)

			-- 누계 +1 저장
			st.count = math.clamp(st.count + 1, 0, 3)
			save(player)
		end
	end

	local c1 = cd.MouseClick:Connect(onClick)
	local c2 = cd.TouchTap:Connect(onClick)

	-- 루프 종료/해제 시 연결 해제
	task.spawn(function()
		while ST[player] == st and st.actionTok == my and st.clicking do task.wait(0.2) end
		if c1 then c1:Disconnect() end
		if c2 then c2:Disconnect() end
	end)
end



-- ===== 4회차: HomeLocation으로 이동 =====
local function startGoHome(player: Player)
	local st = ST[player]; if not st then return end
	st.actionTok += 1
	local my = st.actionTok

	local pet = findPlayersPet(player); if not pet then return end
	local home = workspace:FindFirstChild("HomeLocation")
	local homePart = home and getAnyBasePart(home)
	if not homePart then return end

	-- 클릭/마커 비활성
	hideTouchMarker(player, pet)
	removePoutClick(pet)
	pet:SetAttribute("BlockPetQuestClicks", true)

	-- 추종 제약 제거(멈춘 상태일 수도 있으니 앵커 해제)
	cleanupFollowConstraints(pet)
	setModelAnchored(pet, false)

	-- 이동 루프
	task.spawn(function()
		local pp = getAnyBasePart(pet); if not pp then return end
		local hum = pet:FindFirstChildOfClass("Humanoid"); if hum then st.savedWS = hum.WalkSpeed end

		while ST[player] == st and st.actionTok == my and pet.Parent and homePart.Parent do
			local p0 = pp.Position
			local p1 = homePart.Position
			local d  = (p1 - p0); d = Vector3.new(d.X, 0, d.Z)
			local dist = d.Magnitude
			if dist <= TOUCH_RANGE then break end
			if dist > 0 then
				local step = math.min(dist, HOME_SPEED * LOOP_DT)
				local dir = d.Unit
				local nextPos = p0 + dir * step
				pet:PivotTo(CFrame.new(nextPos, Vector3.new(p1.X, nextPos.Y, p1.Z)))
			end
			task.wait(LOOP_DT)
		end

		-- 도착: 카운트 리셋, 추종 복원
		if ST[player] == st and st.actionTok == my then
			st.count = 0
			save(player)
			reattachFollowToCharacter(pet, player)
			local hum2 = pet:FindFirstChildOfClass("Humanoid")
			if hum2 and st.savedWS then hum2.WalkSpeed = st.savedWS end
			pet:SetAttribute("BlockPetQuestClicks", false)
		end
		
		-- 도착 처리 직후
		StreetFoodEvent:FireClient(player, "Bubble", { text = "" })
		stopWhimperLoop(player)
		hideTouchMarker(player, pet)
		removePoutClick(pet)
	end)
end

-- ===== 스케줄링 =====
local function scheduleNext(player: Player)
	local st = ST[player]; if not st then return end
	st.schedTok += 1
	local my = st.schedTok

	-- 0 유지 + Suck 표시 상태에서만 작동
	if not isZeroIconOn(player) then return end

	-- 무작위 간격
	local delaySec = math.random(POUT_MIN_GAP_SEC, POUT_MAX_GAP_SEC)
	task.delay(delaySec, function()
		if ST[player] ~= st or st.schedTok ~= my then return end
		if not isZeroIconOn(player) then return end

		if st.count >= 3 then
			-- 4회째: 귀가
			startGoHome(player)
		else
			-- 1~3회: 멈춤 + 클릭
			startFreezeAndClick(player)
		end

		-- 다음 스케줄은 액션이 끝났을 때 다시 암 → 간단히 조금 뒤 조건 재확인
		task.delay(5, function()
			if ST[player] == st and isZeroIconOn(player) then
				scheduleNext(player)
			end
		end)
	end)
end

-- ===== 활성/비활성 제어 =====
local function tryArm(player: Player)
	local st = ST[player]
	if not st then return end
	-- 애정도 0 + Suck 아이콘 on 일 때만
	if isZeroIconOn(player) then
		scheduleNext(player)
	end
end

local function disarmAndResetIfPositive(player: Player)
	local aff = player:GetAttribute("PetAffection") or 0
	if aff >= 1 then
		-- 전부 중단 + 복원
		stopAll(player, true)
	end
end

-- ===== 플레이어 훅 =====
local function onPlayerAdded(player: Player)
	ST[player] = {
		count = load(player), schedTok = 0, actionTok = 0,
		clicking = false, clickCount = 0, savedWS = nil
	}

	-- 애정도 변화 감시
	player:GetAttributeChangedSignal("PetAffection"):Connect(function()
		disarmAndResetIfPositive(player)
		if isZeroIconOn(player) then tryArm(player) end
	end)

	-- "0 도달 시각"이나 "대기시간"이 바뀌면 재암
	player:GetAttributeChangedSignal(ZERO_REACHED_ATTR):Connect(function()
		if isZeroIconOn(player) then tryArm(player) end
	end)
	player:GetAttributeChangedSignal(ZERO_HOLD_ATTR):Connect(function()
		if isZeroIconOn(player) then tryArm(player) end
	end)

	-- 접속 직후 상태 검사
	task.defer(function()
		disarmAndResetIfPositive(player)
		if isZeroIconOn(player) then tryArm(player) end
	end)
end

local function onPlayerRemoving(player: Player)
	save(player)
	stopAll(player, false)
	ST[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- 서버 종료 시 저장
game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayerRemoving(p)
	end
end)
