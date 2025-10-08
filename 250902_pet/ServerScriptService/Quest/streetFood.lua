-- StreetFood: ProximityPrompt만으로 근접/상호작용 처리 (ClickDetector 제거) → 터치/클릭 대응 강화
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- 🔹 [추가] 서비스 모듈
local Experience = require(game.ServerScriptService:WaitForChild("ExperienceService"))
local PetAffection = require(game.ServerScriptService:WaitForChild("PetAffectionService"))

-- 맨 위 require들 아래에 추가
local SFXFolder = ReplicatedStorage:WaitForChild("SFX") -- ReplicatedStorage/SFX/StreetFoodEnter (Sound)
local ENTER_SFX_COOLDOWN = 0.6  -- 같은 플레이어에 너무 자주 안 울리도록(초)
local LastEnterSfxAt : {[Player]: number} = {}

-- ===== 설정(원하는 값으로 조정) =====
local PROXIMITY_RADIUS    = 15                       -- 근접 반경(프롬프트/클릭 감지 반경)
local PROXIMITY_TEXT      = "Smells good!"           -- 근접 시 펫 말풍선
local CLICK_RESTORE_TEXT  = ""                       -- 트리거 후 펫 말풍선(빈문자면 숨김)
local DEACTIVATE_SECS     = 300                      -- 트리거 후 모델 비활성 유지 시간
local ANCHOR_PET          = true                     -- 펫을 Anchored로 고정할지(권장 true)
local CLICK_DISTANCE      = PROXIMITY_RADIUS         -- 클릭 허용 거리(프롬프트 반경과 동일)

-- 🔹 [추가] 보상/패널티 기본값 (원하는 수치로!)
local XP_PER_TRIGGER      = 50   -- StreetFood 한 번 완료 시 얻는 경험치
local AFFECTION_PENALTY   = 1    -- StreetFood 한 번 완료 시 감소할 펫 어펙션

-- ===== 경로 =====
local World = workspace:WaitForChild("World")
local DogItemsFolder = World:WaitForChild("dogItems")
local StreetFoodFolder = DogItemsFolder:WaitForChild("street Food") -- 공백/소문자 주의

-- [추가] 숨김 컨테이너 준비
local HiddenContainer = ServerStorage:FindFirstChild("StreetFoodHidden")
if not HiddenContainer then
	HiddenContainer = Instance.new("Folder")
	HiddenContainer.Name = "StreetFoodHidden"
	HiddenContainer.Parent = ServerStorage
end

-- 🔹 [추가] 폴더 Attribute로 런타임 조정 지원
local function getRuntimeConfig()
	local xp = StreetFoodFolder:GetAttribute("XPPerTrigger")
	local pen = StreetFoodFolder:GetAttribute("AffectionPenalty")
	if typeof(xp) ~= "number" then xp = XP_PER_TRIGGER end
	if typeof(pen) ~= "number" then pen = AFFECTION_PENALTY end
	return xp, pen
end

-- ===== RemoteEvents =====
local remoteFolder = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder", ReplicatedStorage)
remoteFolder.Name = "RemoteEvents"

-- 클라 → 서버: 근접 enter/exit 릴레이
local ProxRelay = remoteFolder:FindFirstChild("StreetFoodProxRelay") or Instance.new("RemoteEvent", remoteFolder)
ProxRelay.Name = "StreetFoodProxRelay"

-- 서버 → 클라: 말풍선/효과 갱신
local StreetFoodEvent = remoteFolder:FindFirstChild("StreetFoodEvent") or Instance.new("RemoteEvent", remoteFolder)
StreetFoodEvent.Name = "StreetFoodEvent"

local WangEvent = remoteFolder:FindFirstChild("WangEvent") or Instance.new("RemoteEvent", remoteFolder)
WangEvent.Name = "WangEvent"

-- 🔹 [추가] 모바일 탭 릴레이(StreetFood 전용)
local StreetFoodTapRelay = remoteFolder:FindFirstChild("StreetFoodTapRelay")
if not StreetFoodTapRelay then
	StreetFoodTapRelay = Instance.new("RemoteEvent")
	StreetFoodTapRelay.Name = "StreetFoodTapRelay"
	StreetFoodTapRelay.Parent = remoteFolder
end

-- 🔹 [Marker] 루트 모델 찾기 & 키 상수
local function getRootModelFrom(inst: Instance): Model?
	local m = inst:FindFirstAncestorOfClass("Model")
	while m and m.Parent and m.Parent:IsA("Model") do
		m = m.Parent
	end
	return m
end
local MARKER_KEY = "streetfood"  -- Hide 시에도 동일 키 사용

-- ===== 유틸 =====
local function getAnyBasePart(inst: Instance): BasePart?
	if inst:IsA("BasePart") then return inst end
	if inst:IsA("Model") then
		if inst.PrimaryPart then return inst.PrimaryPart end
		local hrp = inst:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then return hrp end
		return inst:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

-- 원래 부모 저장 유틸
local function ensureOrigParent(root: Instance): ObjectValue
	local ov = root:FindFirstChild("SF_OrigParent")
	if not ov then
		ov = Instance.new("ObjectValue")
		ov.Name = "SF_OrigParent"
		ov.Value = root.Parent -- 최초 부모 기억
		ov.Parent = root
	elseif ov.Value == nil then
		ov.Value = StreetFoodFolder -- 폴백
	end
	return ov :: ObjectValue
end

-- ✨ [추가] StreetFood 모델/파츠용 표준 클릭 히트박스 생성(모바일 탭 안정화)
local function ensureStreetFoodHitbox(target: Instance): BasePart?
	local base: BasePart? = nil
	local root: Model? = nil
	if target:IsA("Model") then
		root = getRootModelFrom(target) or target
		base = getAnyBasePart(root)
	elseif target:IsA("BasePart") then
		base = target
		root = getRootModelFrom(target)
	else
		return nil
	end
	if not base then return nil end

	-- 루트 모델 기준 단일 생성
	if root then
		local exist = root:FindFirstChild("StreetFoodHitbox")
		if exist and exist:IsA("BasePart") then return exist end
	end

	-- 크기 산정(최소 보장)
	local sizeVec = root and root:GetExtentsSize() or base.Size
	local sx = math.max(sizeVec.X * 1.1, 2.0)
	local sy = math.max(sizeVec.Y * 1.1, 2.0)
	local sz = math.max(sizeVec.Z * 1.1, 2.0)

	local hit = Instance.new("Part")
	hit.Name = "StreetFoodHitbox"
	hit.Size = Vector3.new(sx, sy, sz)
	hit.CFrame = base.CFrame
	hit.Transparency = 1
	hit.CanCollide = false
	hit.CanTouch = false
	hit.CanQuery = true
	hit.Anchored = false
	hit.Massless = true
	hit.Parent = root or base.Parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hit
	weld.Part1 = base
	weld.Parent = hit

	return hit
end

-- ✨ [추가] ClickDetector 1회 연결(거리/모바일 친화)
local function wireClickOnce(target: Instance)
	if not target then return end
	local hit = ensureStreetFoodHitbox(target) or getAnyBasePart(target)
	if not hit then return end

	local cd = hit:FindFirstChildOfClass("ClickDetector")
	if not cd then
		cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = CLICK_DISTANCE
		cd.Parent = hit
	else
		if (cd.MaxActivationDistance or 10) < CLICK_DISTANCE then
			cd.MaxActivationDistance = CLICK_DISTANCE
		end
	end

	if cd:GetAttribute("Wired_StreetFood") then return end
	cd:SetAttribute("Wired_StreetFood", true)

	cd.MouseClick:Connect(function(player)
		if not (player and player.Parent) then return end
		-- 거리 가드
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hrp and hit then
			if (hrp.Position - hit.Position).Magnitude > CLICK_DISTANCE + 0.5 then
				return
			end
		end
		-- 실제 트리거
		local rootModel = getRootModelFrom(target) or getRootModelFrom(hit) or getRootModelFrom(target.Parent or hit.Parent)
		if rootModel then
			_G.__streetfood_trigger(player, rootModel)
		end
	end)
end

local function ensurePrompt(target: Instance)
	local base = getAnyBasePart(target)
	if not base then return end
	if base:FindFirstChild("StreetFoodPrompt") then
		local p = base:FindFirstChild("StreetFoodPrompt") :: ProximityPrompt
		if p and p:IsA("ProximityPrompt") then
			p.MaxActivationDistance = PROXIMITY_RADIUS
			p.Style = Enum.ProximityPromptStyle.Custom -- 👈 UI 숨김
		end
		return
	end

	local p = Instance.new("ProximityPrompt")
	p.Name = "StreetFoodPrompt"
	p.ActionText = "Interact"
	p.ObjectText = target.Name
	p.HoldDuration = 0
	p.RequiresLineOfSight = false
	p.MaxActivationDistance = PROXIMITY_RADIUS
	p.Style = Enum.ProximityPromptStyle.Custom   -- 👈 UI 숨김 (E키 표시 안 함)
	p.Parent = base
end

local function resolveEnterSfxTemplate(): Sound?
	local nameAttr = StreetFoodFolder:GetAttribute("EnterSfxName")
	if typeof(nameAttr) == "string" and #nameAttr > 0 then
		local s = SFXFolder:FindFirstChild(nameAttr)
		if s and s:IsA("Sound") then return s end
	end
	for _, key in ipairs({ "walwal" }) do
		local s = SFXFolder:FindFirstChild(key)
		if s and s:IsA("Sound") then return s end
	end
	for _, ch in ipairs(SFXFolder:GetChildren()) do
		if ch:IsA("Sound") then return ch end
	end
	return nil
end

-- [교체] 기존 setActive를 아래 구현으로 완전히 교체
local function setActive(modelOrPart: Instance, active: boolean)
	local root = modelOrPart:IsA("Model") and modelOrPart
		or modelOrPart:FindFirstAncestorOfClass("Model")
		or modelOrPart

	local ov = ensureOrigParent(root)

	if active then
		local desiredParent = ov.Value or StreetFoodFolder
		if root.Parent ~= desiredParent then
			root.Parent = desiredParent
		end
	end

	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			d.Enabled = active
			d.MaxActivationDistance = PROXIMITY_RADIUS
			d.Style = Enum.ProximityPromptStyle.Custom
		elseif d:IsA("BasePart") then
			if not d:GetAttribute("SF_OrigTrans") then
				d:SetAttribute("SF_OrigTrans", d.Transparency)
			end
			if active then
				local orig = d:GetAttribute("SF_OrigTrans")
				if typeof(orig) == "number" then d.Transparency = orig end
			else
				d.Transparency = math.clamp(d.Transparency + 0.3, 0, 1)
			end
		end
	end

	if not active then
		if root.Parent ~= HiddenContainer then
			root.Parent = HiddenContainer
		end
	end

	root:SetAttribute("SF_Active", active)
end

-- 펫 찾기(OwnerUserId == player.UserId)
local function findPlayersPet(player: Player): Model?
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("Model") and inst:GetAttribute("OwnerUserId") == player.UserId then
			if getAnyBasePart(inst) then return inst end
		end
	end
	return nil
end

-- 펫 고정/해제
local Locked: {[Player]: boolean} = {}

local function lockPet(player: Player)
	if Locked[player] then return end
	local pet = findPlayersPet(player)
	if not pet then return end

	pet:SetAttribute("FollowLocked", true)
	local base = getAnyBasePart(pet)

	local hum = pet:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:Move(Vector3.zero, false)
		hum.AutoRotate = false
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.Sit = true
	end
	if ANCHOR_PET and base then
		base.Anchored = true
	end

	Locked[player] = true
end

local function unlockPet(player: Player)
	if not Locked[player] then return end
	local pet = findPlayersPet(player)
	if not pet then
		Locked[player] = nil
		return
	end

	pet:SetAttribute("FollowLocked", false)
	local base = getAnyBasePart(pet)
	local hum = pet:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = true
		hum.WalkSpeed = 16
		hum.JumpPower = 50
		hum.Sit = false
	end
	if ANCHOR_PET and base then
		base.Anchored = false
	end

	Locked[player] = nil
end

-- ===== 트리거 공통 처리 (프롬프트/클릭/탭 공용) =====
local processing: {[Instance]: boolean} = {}

_G.__streetfood_trigger = function(player: Player, rootModel: Instance)
	-- 루트 모델 보정
	local root = getRootModelFrom(rootModel) or rootModel
	if not root or not root:IsDescendantOf(StreetFoodFolder) then return end

	if processing[root] then return end
	processing[root] = true

	-- 🔹 [Marker] 숨김
	WangEvent:FireClient(player, "HideMarker", {
		target = root,
		key    = MARKER_KEY,
	})

	-- 완료 처리
	setActive(root, false)
	unlockPet(player)
	StreetFoodEvent:FireClient(player, "Bubble", { text = CLICK_RESTORE_TEXT })
	StreetFoodEvent:FireClient(player, "ClearEffect")

	-- 보상
	local xpGain, affectionDown = getRuntimeConfig()
	pcall(function() Experience.AddExp(player, xpGain) end)
	pcall(function()
		local delta = -math.abs(affectionDown)
		if PetAffection.Adjust then
			PetAffection.Adjust(player, delta, "streetfood")
		elseif PetAffection.Add then
			PetAffection.Add(player, delta, "streetfood")
		elseif PetAffection.Delta then
			PetAffection.Delta(player, delta, "streetfood")
		end
	end)

	-- 재활성
	task.delay(DEACTIVATE_SECS, function()
		if root and root.Parent then
			setActive(root, true)
		end
		processing[root] = nil
	end)
end

-- ===== 초기/동적 와이어링: 프롬프트 + 클릭(히트박스) 생성 =====
for _, inst in ipairs(StreetFoodFolder:GetDescendants()) do
	if inst:IsA("Model") or inst:IsA("BasePart") then
		ensurePrompt(inst)
		wireClickOnce(inst)
	end
end

StreetFoodFolder.DescendantAdded:Connect(function(inst)
	if inst:IsA("Model") or inst:IsA("BasePart") then
		ensurePrompt(inst)
		wireClickOnce(inst)
	end
end)

-- ===== 근접(보임/숨김): 클라 릴레이 수신 → 서버 권위 처리 =====
ProxRelay.OnServerEvent:Connect(function(player, action: "enter"|"exit", prompt: ProximityPrompt)
	if not (player and prompt and prompt:IsDescendantOf(StreetFoodFolder)) then return end
	if prompt.Name ~= "StreetFoodPrompt" then return end

	if action == "enter" then
		StreetFoodEvent:FireClient(player, "Bubble", { text = PROXIMITY_TEXT })
		lockPet(player)

		local rootForMarker = getRootModelFrom(prompt)
		if rootForMarker then
			WangEvent:FireClient(player, "ShowMarker", {
				target  = rootForMarker,
				key     = MARKER_KEY,
				preset  = "Click Icon",
				offsetY = 2.0,
				pulse   = true,
			})
		end

		-- 🔊 SFX (쿨다운 유지)
		local now = os.clock()
		if (LastEnterSfxAt[player] or -1e9) + ENTER_SFX_COOLDOWN <= now then
			local tpl = resolveEnterSfxTemplate()
			if tpl then
				StreetFoodEvent:FireClient(player, "PlaySfxTemplate", tpl)
				LastEnterSfxAt[player] = now
			end
		end

	elseif action == "exit" then
		-- 요구사항상: 언락은 트리거 시점에만
	end
end)

-- ===== E키 백업 경로(Style=Custom이라 UI는 안 보임, 그래도 남겨둠)
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if not (prompt and player) then return end
	if prompt.Name ~= "StreetFoodPrompt" then return end
	if not prompt:IsDescendantOf(StreetFoodFolder) then return end

	local rootModel = getRootModelFrom(prompt) or prompt.Parent
	if rootModel then
		_G.__streetfood_trigger(player, rootModel)
	end
end)

-- ===== 모바일 탭 릴레이(클라에서 월드 탭 좌표로 넘어옴)
local function isNear(player: Player, part: BasePart, maxDist: number): boolean
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end
	return (hrp.Position - part.Position).Magnitude <= maxDist + 0.5
end

StreetFoodTapRelay.OnServerEvent:Connect(function(player, tappedInst: Instance)
	if not (player and player.Parent) then return end
	if typeof(tappedInst) ~= "Instance" then return end
	if not tappedInst:IsDescendantOf(StreetFoodFolder) then return end

	-- 히트박스 확보 및 거리 가드
	local hit = ensureStreetFoodHitbox(tappedInst) or getAnyBasePart(tappedInst)
	if not (hit and hit:IsA("BasePart")) then return end
	if not isNear(player, hit, CLICK_DISTANCE) then return end

	local rootModel = getRootModelFrom(tappedInst) or getRootModelFrom(hit)
	if rootModel then
		_G.__streetfood_trigger(player, rootModel)
	end
end)

-- 정리
Players.PlayerRemoving:Connect(function(plr)
	Locked[plr] = nil
end)
