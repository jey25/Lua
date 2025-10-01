-- StreetFood: ProximityPrompt만으로 근접/상호작용 처리 (ClickDetector 제거)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ServerStorage = game:GetService("ServerStorage")

-- 🔹 [추가] 서비스 모듈
local Experience = require(game.ServerScriptService:WaitForChild("ExperienceService"))
local PetAffection = require(game.ServerScriptService:WaitForChild("PetAffectionService"))


-- 맨 위 require들 아래에 추가
local SFXFolder = ReplicatedStorage:WaitForChild("SFX") -- ReplicatedStorage/SFX/StreetFoodEnter (Sound)
local ENTER_SFX_COOLDOWN = 0.6  -- 같은 플레이어에 너무 자주 안 울리도록(초)
local LastEnterSfxAt : {[Player]: number} = {}

-- ===== 설정(원하는 값으로 조정) =====
local PROXIMITY_RADIUS    = 15                      -- 근접 반경(프롬프트 반경)
local PROXIMITY_TEXT      = "Smells good!"     -- 근접 시 펫 말풍선
local CLICK_RESTORE_TEXT  = ""                      -- E키 트리거 후 펫 말풍선(빈문자면 숨김)
local DEACTIVATE_SECS     = 300                      -- 트리거 후 모델 비활성 유지 시간
local ANCHOR_PET          = true                    -- 펫을 Anchored로 고정할지(권장 true)

-- 🔹 [추가] 보상/패널티 기본값 (원하는 수치로!)
local XP_PER_TRIGGER      = 100   -- StreetFood 한 번 완료 시 얻는 경험치
local AFFECTION_PENALTY   = 1     -- StreetFood 한 번 완료 시 감소할 펫 어펙션

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

-- 서버 → 클라: 말풍선 갱신
local StreetFoodEvent = remoteFolder:FindFirstChild("StreetFoodEvent") or Instance.new("RemoteEvent", remoteFolder)
StreetFoodEvent.Name = "StreetFoodEvent"

local WangEvent = remoteFolder:FindFirstChild("WangEvent") or Instance.new("RemoteEvent", remoteFolder)
WangEvent.Name = "WangEvent"


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


-- [추가] 원래 부모 저장 유틸 (ObjectValue로 안전 보관)
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


local function ensurePrompt(target: Instance)
	local base = getAnyBasePart(target)
	if not base then return end
	if base:FindFirstChild("StreetFoodPrompt") then
		-- 반경이 바뀌었을 수 있으니 최신화
		local p = base:FindFirstChild("StreetFoodPrompt") :: ProximityPrompt
		if p and p:IsA("ProximityPrompt") then
			p.MaxActivationDistance = PROXIMITY_RADIUS
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
	p.Style = Enum.ProximityPromptStyle.Custom   -- UI 숨김 처리
	p.Parent = base
end


local function resolveEnterSfxTemplate(): Sound?
	-- 1) 폴더 Attribute로 이름 지정 가능: StreetFoodFolder:SetAttribute("EnterSfxName","StreetFoodEnter")
	local nameAttr = StreetFoodFolder:GetAttribute("EnterSfxName")
	if typeof(nameAttr) == "string" and #nameAttr > 0 then
		local s = SFXFolder:FindFirstChild(nameAttr)
		if s and s:IsA("Sound") then return s end
	end
	-- 2) 기본 후보들
	for _, key in ipairs({ "walwal" }) do
		local s = SFXFolder:FindFirstChild(key)
		if s and s:IsA("Sound") then return s end
	end
	-- 3) 폴더 첫 번째 Sound 폴백
	for _, ch in ipairs(SFXFolder:GetChildren()) do
		if ch:IsA("Sound") then return ch end
	end
	return nil
end



-- [교체] 기존 setActive를 아래 구현으로 완전히 교체
local function setActive(modelOrPart: Instance, active: boolean)
	-- 루트 결정(모델이 있으면 모델 기준으로 토글)
	local root = modelOrPart:IsA("Model") and modelOrPart
		or modelOrPart:FindFirstAncestorOfClass("Model")
		or modelOrPart

	-- 원래 부모 기록(복귀용)
	local ov = ensureOrigParent(root)

	-- 활성화라면 먼저 원래 자리로 되돌린 뒤, 프롬프트/가시성 토글
	if active then
		local desiredParent = ov.Value or StreetFoodFolder
		if root.Parent ~= desiredParent then
			root.Parent = desiredParent
		end
	end

	-- 프롬프트/가시성 토글
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			d.Enabled = active
			-- 반경 최신화(설정 변경에 대응)
			d.MaxActivationDistance = PROXIMITY_RADIUS
		elseif d:IsA("BasePart") then
			-- 원래 투명도 백업
			if not d:GetAttribute("SF_OrigTrans") then
				d:SetAttribute("SF_OrigTrans", d.Transparency)
			end
			if active then
				-- 복귀 시 원래 투명도 회복
				local orig = d:GetAttribute("SF_OrigTrans")
				if typeof(orig) == "number" then d.Transparency = orig end
				d.CanCollide = d.CanCollide -- (그대로 유지; 필요시 정책 반영)
			else
				-- 굳이 페이드할 필요 없지만, 원하면 약간 흐리게 했다가 숨김 처리
				d.Transparency = math.clamp(d.Transparency + 0.3, 0, 1)
			end
		end
	end

	-- 비활성화라면 최종적으로 숨김 컨테이너로 이동(클라 완전 비표시)
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

	pet:SetAttribute("FollowLocked", true) -- 팔로우 스크립트에서 체크 권장
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

-- ===== 초기/동적 와이어링: 모델 로드 시 자동 프롬프트 생성 =====
for _, inst in ipairs(StreetFoodFolder:GetDescendants()) do
	if inst:IsA("Model") or inst:IsA("BasePart") then
		ensurePrompt(inst)
	end
end

StreetFoodFolder.DescendantAdded:Connect(function(inst)
	if inst:IsA("Model") or inst:IsA("BasePart") then
		ensurePrompt(inst)
	end
end)

-- ===== 근접(보임/숨김): 클라 릴레이 수신 → 서버 권위 처리 =====
ProxRelay.OnServerEvent:Connect(function(player, action: "enter"|"exit", prompt: ProximityPrompt)
	if not (player and prompt and prompt:IsDescendantOf(StreetFoodFolder)) then return end
	if prompt.Name ~= "StreetFoodPrompt" then return end

	if action == "enter" then
		StreetFoodEvent:FireClient(player, "Bubble", { text = PROXIMITY_TEXT })
		lockPet(player)

		-- 🔹 [Marker] 이 플레이어에게만 해당 food 모델 위에 Marker 표시
		local rootForMarker = getRootModelFrom(prompt)
		if rootForMarker then
			WangEvent:FireClient(player, "ShowMarker", {
				target      = rootForMarker,
				key         = MARKER_KEY,
				preset      = "Click Icon",   -- 클라 MarkerClient 기본 프리셋
				offsetY     = 2.0,           -- 모델 위로 살짝 띄움
				pulse       = true,          -- 맥동 ON
				-- size / image 등 필요 시 여기서 추가 지정 가능
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
		-- 요구사항상: 근접 이탈 후에도 계속 고정 유지 (언락은 트리거 시점에만)
		-- 필요 시 말풍선 끄려면 아래 주석 해제:
		-- StreetFoodEvent:FireClient(player, "Bubble", { text = "" })
	end
end)


local processing: {[Instance]: boolean} = {}


-- ===== E키 트리거: 프롬프트만으로 상호작용 처리(ClickDetector 제거) =====
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if not (prompt and player) then return end
	if prompt.Name ~= "StreetFoodPrompt" then return end
	if not prompt:IsDescendantOf(StreetFoodFolder) then return end

	-- 최상위 모델(rootModel) 찾기
	local rootModel = prompt.Parent
	while rootModel and rootModel.Parent and rootModel.Parent:IsA("Model") do
		rootModel = rootModel.Parent
	end

	if not rootModel then return end

	-- 이미 처리 중이면 무시
	if processing[rootModel] then return end
	processing[rootModel] = true

	player:SetAttribute("ExpMultiplier", 2)
	task.delay(1800, function()
		if player and player.Parent then
			player:SetAttribute("ExpMultiplier", 1)
		end
	end)
	
	-- 🔹 [Marker] 먼저 숨김 (이후 ServerStorage로 이동되면 클라에서 참조가 사라질 수 있으므로)
	WangEvent:FireClient(player, "HideMarker", {
		target = rootModel,
		key    = MARKER_KEY,
	})

	-- ✅ StreetFood 완료 처리
	setActive(rootModel, false)
	unlockPet(player)
	StreetFoodEvent:FireClient(player, "Bubble", { text = CLICK_RESTORE_TEXT })
	StreetFoodEvent:FireClient(player, "ClearEffect")

	-- ✅ 경험치 & 펫 어펙션 처리
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

	-- 재활성 타이머
	task.delay(DEACTIVATE_SECS, function()
		if rootModel and rootModel.Parent then
			setActive(rootModel, true)
		end
		processing[rootModel] = nil
	end)
end)



-- 정리
Players.PlayerRemoving:Connect(function(plr)
	Locked[plr] = nil
end)
