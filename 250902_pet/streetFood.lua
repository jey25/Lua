-- StreetFood: ProximityPrompt만으로 근접/상호작용 처리 (ClickDetector 제거)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

-- ===== 설정(원하는 값으로 조정) =====
local PROXIMITY_RADIUS    = 15                      -- 근접 반경(프롬프트 반경)
local PROXIMITY_TEXT      = "Smells good!"     -- 근접 시 펫 말풍선
local CLICK_RESTORE_TEXT  = ""                      -- E키 트리거 후 펫 말풍선(빈문자면 숨김)
local DEACTIVATE_SECS     = 300                      -- 트리거 후 모델 비활성 유지 시간
local ANCHOR_PET          = true                    -- 펫을 Anchored로 고정할지(권장 true)

-- ===== 경로 =====
local World = workspace:WaitForChild("World")
local DogItemsFolder = World:WaitForChild("dogItems")
local StreetFoodFolder = DogItemsFolder:WaitForChild("street Food") -- 공백/소문자 주의

-- ===== RemoteEvents =====
local remoteFolder = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder", ReplicatedStorage)
remoteFolder.Name = "RemoteEvents"

-- 클라 → 서버: 근접 enter/exit 릴레이
local ProxRelay = remoteFolder:FindFirstChild("StreetFoodProxRelay") or Instance.new("RemoteEvent", remoteFolder)
ProxRelay.Name = "StreetFoodProxRelay"

-- 서버 → 클라: 말풍선 갱신
local StreetFoodEvent = remoteFolder:FindFirstChild("StreetFoodEvent") or Instance.new("RemoteEvent", remoteFolder)
StreetFoodEvent.Name = "StreetFoodEvent"

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
	p.Parent = base
end

-- 프롬프트/상호작용 비활성/활성
local function setActive(modelOrPart: Instance, active: boolean)
	local root = modelOrPart:IsA("Model") and modelOrPart or modelOrPart:FindFirstAncestorOfClass("Model") or modelOrPart
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			d.Enabled = active
		elseif d:IsA("BasePart") then
			-- 선택: 시각적으로 희미화 (원치 않으면 주석 처리)
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
	(root :: Instance):SetAttribute("SF_Active", active)
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
		lockPet(player)           -- 근접 시 펫 고정
	elseif action == "exit" then
		-- 요구사항상: 근접 이탈 후에도 계속 고정 유지 (언락은 트리거 시점에만)
		-- 필요 시 말풍선 끄려면 아래 주석 해제:
		-- StreetFoodEvent:FireClient(player, "Bubble", { text = "" })
	end
end)

-- ===== E키 트리거: 프롬프트만으로 상호작용 처리(ClickDetector 제거) =====
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
	if not (prompt and player) then return end
	if prompt.Name ~= "StreetFoodPrompt" then return end
	if not prompt:IsDescendantOf(StreetFoodFolder) then return end

	local targetPart = prompt.Parent
	setActive(targetPart, false)                    -- 비활성화(쿨타임)
	unlockPet(player)                               -- 원래대로 펫 추적 재개
	
	StreetFoodEvent:FireClient(player, "Bubble", {  -- 말풍선 문구 갱신(비우기 권장)
		text = CLICK_RESTORE_TEXT
	})
	
	-- ✅ 프롬프트 실행 시 로컬 이펙트 실행 지시
	StreetFoodEvent:FireClient(player, "ClearEffect")

	task.delay(DEACTIVATE_SECS, function()
		if targetPart and targetPart.Parent then
			setActive(targetPart, true)             -- 쿨 종료 후 재활성
		end
	end)
end)

-- 정리
Players.PlayerRemoving:Connect(function(plr)
	Locked[plr] = nil
end)
