

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

-- ==================== 설정 ====================
local WANG_RADIUS            = 40      -- 근접 판정/프롬프트 반경
local TOUCH_RANGE            = 2.0     -- 닿았다고 판단하는 거리
local LOOP_DT                = 0.15    -- 접근 루프 틱 간격(초)
local EXCLAIM_TEXT           = "!!!"    -- 근접 순간 말풍선
local TOUCH_TEXT             = "Krrrrr..." -- 닿았을 때 말풍선
local HARD_STOP_TIME         = 0.2     -- 하드 고정(앵커) 유지 시간 (초) → 추적 관성 제거

-- 🔽 새로 추가
local LOCK_Y             = true     -- 타겟을 따라갈 때 Y(높이) 고정
local APPROACH_SPEED     = 2      -- studs/sec. 2 미만이면 앵커+CFrame 보간을 씁니다.
local USE_HUMANOID_MOVE  = (APPROACH_SPEED >= 2.0)  -- 느리면 false가 되어 CFrame모드
local GROUND_OFFSET = 0.5       -- 지면에서 약간 띄우기(겹침 방지)
local RAY_LENGTH = 100          -- 바닥 탐사용 레이 길이

-- 닿은 뒤 자동으로 플레이어 추적 복귀할지
local AUTO_RESUME_AFTER_TOUCH = true
local RESUME_DELAY_AFTER_TOUCH = 0.5  -- 초

-- Wang 타겟 쿨타임(초)
local WANG_COOLDOWN_SECS   = 180   --3분 후 타겟 추적 재활성화

-- 타겟을 '닿았을 때(Krrrr)'도 비활성화할지 여부 (원하면 true)
local WANG_COOLDOWN_ON_TOUCH = false



-- ==================== 경로 / RemoteEvents ====================
local World = workspace:WaitForChild("World")
local DogItems = World:WaitForChild("dogItems")
local WangFolder = DogItems:WaitForChild("wang")

local RemoteFolder = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder", ReplicatedStorage)
RemoteFolder.Name = "RemoteEvents"

local WangProxRelay = RemoteFolder:FindFirstChild("WangProxRelay") or Instance.new("RemoteEvent", RemoteFolder)
WangProxRelay.Name = "WangProxRelay"

local WangEvent = RemoteFolder:FindFirstChild("WangEvent") or Instance.new("RemoteEvent", RemoteFolder)
WangEvent.Name = "WangEvent"

-- RemoteEvents 초기화 부 바로 아래에 추가
local WangCancelClick = RemoteFolder:FindFirstChild("WangCancelClick") or Instance.new("RemoteEvent", RemoteFolder)
WangCancelClick.Name = "WangCancelClick"


-- ==================== 유틸 ====================
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

local function getOwnerPlayerFromPet(pet: Model): Player?
	local ownerId = pet:GetAttribute("OwnerUserId")
	if typeof(ownerId) == "number" then
		return Players:GetPlayerByUserId(ownerId)
	end
	return nil
end


local function setModelAnchored(model: Model, anchored: boolean)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			if anchored and p:GetAttribute("WANG_OrigAnch") == nil then
				p:SetAttribute("WANG_OrigAnch", p.Anchored)
			end
			p.Anchored = anchored
		end
	end
end

local function restoreModelAnchored(model: Model)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local orig = p:GetAttribute("WANG_OrigAnch")
			if orig ~= nil then
				p.Anchored = orig
				p:SetAttribute("WANG_OrigAnch", nil)
			end
		end
	end
end


local function getGroundYBelow(origin: Vector3, ignore: Instance?): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {ignore}
	local result = workspace:Raycast(origin + Vector3.new(0, 2, 0), Vector3.new(0, -RAY_LENGTH, 0), params)
	if result then
		return result.Position.Y + GROUND_OFFSET
	end
	return nil
end


-- 모델 상단 중앙에 단 1개의 프롬프트만 부착 (중복 방지)
local function ensurePrompt(modelOrPart: Instance)
	-- 항상 모델 단위로 처리
	local model = modelOrPart:IsA("Model") and modelOrPart or modelOrPart:FindFirstAncestorOfClass("Model")
	if not (model and model:IsA("Model")) then return end
	if model:GetAttribute("WangPrompted") then return end

	local base = getAnyBasePart(model)
	if not base then return end

	local anchor = base:FindFirstChild("WangPromptAnchor")
	if not anchor then
		anchor = Instance.new("Attachment")
		anchor.Name = "WangPromptAnchor"
		anchor.Parent = base
	end

	local cf, size = model:GetBoundingBox()
	anchor.WorldCFrame = cf * CFrame.new(0, size.Y/2 + 1.5, 0)

	local p = anchor:FindFirstChild("WangPrompt") :: ProximityPrompt
	if not p then
		p = Instance.new("ProximityPrompt")
		p.Name = "WangPrompt"
		p.ActionText = "Inspect"
		p.ObjectText = model.Name
		p.HoldDuration = 0
		p.Parent = anchor
	end
	-- "가장 가까운 것만" 표시 → 프롬프트 과다 노출 방지
	p.MaxActivationDistance = WANG_RADIUS
	p.RequiresLineOfSight = false
	p.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	-- 필요시 전용키로 분리(StreetFood와 충돌 피하려면 F 등)
	-- p.KeyboardKeyCode = Enum.KeyCode.F

	model:SetAttribute("WangPrompted", true)
	
	-- ensurePrompt(modelOrPart) 마지막 부분에 추가/교체
	if model:GetAttribute("WANG_Active") == nil then
		model:SetAttribute("WANG_Active", true)
	end
	p.Enabled = (model:GetAttribute("WANG_Active") ~= false)

end

-- ====== 팔로우 제약 정리/복원 ======
local function cleanupFollowConstraints(pet: Model)
	local pp = getAnyBasePart(pet); if not pp then return end
	for _, ch in ipairs(pp:GetChildren()) do
		if ch:IsA("AlignPosition") or ch:IsA("AlignOrientation") then ch:Destroy()
		elseif ch:IsA("Attachment") and ch.Name == "PetAttach" then ch:Destroy() end
	end
end

local function reattachFollowToCharacter(pet: Model, character: Model)
	local petPP = getAnyBasePart(pet)
	local charPP = character and character:FindFirstChild("HumanoidRootPart")
	if not (petPP and charPP) then return end

	cleanupFollowConstraints(pet)
	petPP:SetNetworkOwner(nil)

	local aPet = Instance.new("Attachment"); aPet.Name = "PetAttach"; aPet.Parent = petPP
	local aChar = charPP:FindFirstChild("CharAttach") :: Attachment
	if not aChar then aChar = Instance.new("Attachment"); aChar.Name = "CharAttach"; aChar.Parent = charPP end
	aChar.Position = Vector3.new(2.5, -1.5, -2.5)

	local yawOffsetDeg = pet:GetAttribute("YawOffsetDeg")
	if typeof(yawOffsetDeg) ~= "number" then yawOffsetDeg = 0 end
	aPet.Orientation = Vector3.new(0, yawOffsetDeg, 0)

	local ap = Instance.new("AlignPosition")
	ap.Attachment0 = aPet; ap.Attachment1 = aChar
	ap.ApplyAtCenterOfMass = true; ap.RigidityEnabled = false
	ap.MaxForce = 1e6; ap.Responsiveness = 80
	ap.Parent = petPP

	local ao = Instance.new("AlignOrientation")
	ao.Attachment0 = aPet; ao.Attachment1 = aChar
	ao.RigidityEnabled = false; ao.MaxTorque = 1e6; ao.Responsiveness = 60
	ao.Parent = petPP
end

local function takeServerOwnership(pet: Model)
	local root = getAnyBasePart(pet); if root then root:SetNetworkOwner(nil) end
end
local function releaseOwnership(pet: Model)
	local root = getAnyBasePart(pet); if root then root:SetNetworkOwnershipAuto() end
end

local function hardStopPet(pet: Model)
	-- 플레이어 추적 제약 제거
	cleanupFollowConstraints(pet)
	-- 서버 소유
	takeServerOwnership(pet)
	-- 모델 전체 앵커 ON (관성/중력 완전히 차단)
	setModelAnchored(pet, true)
	-- 속도/회전 속도 제거(잔류 속도 방지)
	local pp = getAnyBasePart(pet)
	if pp then
		pp.AssemblyLinearVelocity = Vector3.zero
		pp.AssemblyAngularVelocity = Vector3.zero
	end
end

-- ▶ 플레이어 추적 상태로 복원 (교체본)
local function restoreFollow(player: Player, pet: Model, prevWalkSpeed: number?)
	-- 논리 플래그 해제
	pet:SetAttribute("FollowLocked", false)
	pet:SetAttribute("AIState", nil)
	pet:SetAttribute("WangApproaching", false)

	-- 0) 앵커 원복 (CFrame/PivotTo 모드에서 전체 앵커를 켰었기 때문)
	if restoreModelAnchored then
		restoreModelAnchored(pet)
	end

	-- 1) 플레이어 캐릭터에 재부착(Align 재생성)
	local character = player.Character or player.CharacterAdded:Wait()
	reattachFollowToCharacter(pet, character)

	-- 2) 이동 파라미터 원복
	local hum = pet:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.AutoRotate = true
		hum.WalkSpeed = prevWalkSpeed or 16
		hum.Sit = false
	end

	-- 3) 네트워크 소유권 자동으로 되돌리기
	releaseOwnership(pet)

	-- 4) 확실히 Unanchor 보장 (일부 파트가 원래 앵커였던 경우는 그대로 두고, PrimaryPart만 확인)
	local pp = getAnyBasePart(pet)
	if pp and not pp:GetAttribute("WANG_KeepAnchored") then
		pp.Anchored = false
	end
	
	pet:SetAttribute("AIState", nil)
	pet:SetAttribute("BlockPetQuestClicks", false) -- ✅ 차단 해제

end



-- 모델/파트 → 모델 해석
local function resolveTargetModel(inst: Instance): Model?
	if not inst then return nil end
	if inst:IsA("Model") then return inst end
	return inst:FindFirstAncestorOfClass("Model")
end

-- Wang 타겟 활성/비활성 (프롬프트/시각 효과 포함)
local function setWangActive(target: Instance, active: boolean)
	local model = resolveTargetModel(target); if not model then return end
	model:SetAttribute("WANG_Active", active)

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Name == "WangPrompt" then
			d.Enabled = active
		elseif d:IsA("BasePart") then
			-- (선택) 비활성화 동안 희미하게 보이게 처리
			if active then
				local orig = d:GetAttribute("WANG_OrigTrans")
				if typeof(orig) == "number" then d.Transparency = orig end
			else
				if d:GetAttribute("WANG_OrigTrans") == nil then
					d:SetAttribute("WANG_OrigTrans", d.Transparency)
				end
				d.Transparency = math.clamp(d.Transparency + 0.25, 0, 1)
			end
		end
	end
end


local function beginApproach(pet: Model, target: Instance)
	local pp = getAnyBasePart(pet); if not pp then return end

	-- target이 Attachment/Prompt 등인 경우에도 BasePart 찾아보기
	local tgt = getAnyBasePart(target)
	if not tgt then
		if target and target:IsA("Attachment") and target.Parent and target.Parent:IsA("BasePart") then
			tgt = target.Parent
		end
		-- fallback: 모델 전체라면 PrimaryPart 얻기
		if not tgt and target and target:IsA("Model") then
			tgt = (target :: Model).PrimaryPart
		end
	end
	if not tgt then return end

	-- 기준 Y 계산
	local planeY = pp.Position.Y
	if LOCK_Y then
		local groundY = getGroundYBelow(pp.Position, pet)
		if groundY then planeY = groundY end
	end

	task.spawn(function()
		while pet.Parent and target and target.Parent do
			-- 접근 취소 플래그 확인(클릭 등에서 끌 수 있음)
			local approachingAttr = pet:GetAttribute("WangApproaching")
			if approachingAttr == false then break end

			pp = getAnyBasePart(pet); tgt = getAnyBasePart(target)
			if not (pp and tgt) then break end

			local petPos = pp.Position
			local tgtPos = tgt.Position
			if LOCK_Y then tgtPos = Vector3.new(tgtPos.X, planeY, tgtPos.Z) end

			local dx, dz = tgtPos.X - petPos.X, tgtPos.Z - petPos.Z
			local distXZ = math.sqrt(dx*dx + dz*dz)

			-- beginApproach 내부: 닿음 분기 교체
			if distXZ <= TOUCH_RANGE then
				local owner = getOwnerPlayerFromPet(pet)
				if owner then
					WangEvent:FireClient(owner, "Bubble", { text = TOUCH_TEXT })
				end

				pet:SetAttribute("WangApproaching", false)

				-- 🔁 닿았을 때도 쿨타임 주고 싶다면 (옵션)
				if WANG_COOLDOWN_ON_TOUCH then
					local targetModel = resolveTargetModel(target)
					if targetModel then
						setWangActive(targetModel, false)
						task.delay(WANG_COOLDOWN_SECS, function()
							if targetModel and targetModel.Parent then
								setWangActive(targetModel, true)
							end
						end)
					end
				end

				if AUTO_RESUME_AFTER_TOUCH and owner then
					local lastWS = pet:GetAttribute("WANG_LastWalkSpeed")
					task.delay(RESUME_DELAY_AFTER_TOUCH, function()
						WangEvent:FireClient(owner, "RestoreBubble")
						restoreFollow(owner, pet, (type(lastWS) == "number") and lastWS or nil)
						pet:SetAttribute("WANG_LastWalkSpeed", nil)
					end)
				end
				break
			end


			-- 한 스텝 이동 (CFrame 보간)
			local step = math.min(distXZ, APPROACH_SPEED * LOOP_DT)
			local dirXZ = (distXZ > 0) and Vector3.new(dx, 0, dz).Unit or Vector3.new()
			local newPos = petPos + dirXZ * step

			local lookAt = Vector3.new(tgtPos.X, newPos.Y, tgtPos.Z)
			local cf = CFrame.new(newPos, lookAt)
			pet:PivotTo(cf)

			task.wait(LOOP_DT)
		end

		-- 루프 종료 후 안전장치: 만약 접근이 멈췄고(플래그 false) 플레이어 복원이 안되어 있다면 네트워크/앵커를 풀어둡니다.
		-- (restoreFollow에서 이미 처리되었다면 중복되어도 괜찮음)
		if not pet:GetAttribute("WangApproaching") then
			-- 복원 시도 (owner가 있으면 restoreFollow 권장)
			local owner3 = getOwnerPlayerFromPet(pet)
			if owner3 then
				-- 만약 FollowLocked가 true라면 restoreFollow를 호출해서 Align/Anchors 복구
				if pet:GetAttribute("FollowLocked") then
					local lastWS2 = pet:GetAttribute("WANG_LastWalkSpeed")
					restoreFollow(owner3, pet, (type(lastWS2) == "number") and lastWS2 or nil)
					pet:SetAttribute("WANG_LastWalkSpeed", nil)
					pet:SetAttribute("FollowLocked", false)
				end
			else
				-- 소유자 없음: 최소 앵커 원복/소유권 자동으로 돌려놓기
				restoreModelAnchored(pet)
				releaseOwnership(pet)
			end
		end
	end)
end



-- 플레이어의 펫, 펫 클릭 3회 취소
local function findPlayersPet(player: Player): Model?
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("Model") and inst:GetAttribute("OwnerUserId") == player.UserId then
			if getAnyBasePart(inst) then return inst end
		end
	end
	return nil
end

-- 기존 ensurePetClickTarget 그대로 두되, ClickDetector 관련 부분 모두 삭제/주석 처리
local function ensurePetClickTarget(pet: Model): BasePart?
	local base = getAnyBasePart(pet); if not base then return nil end
	local hit = pet:FindFirstChild("PetClickHitbox")
	if hit and hit:IsA("BasePart") then return hit end

	local size = pet:GetExtentsSize()
	local hitbox = Instance.new("Part")
	hitbox.Name = "PetClickHitbox"
	hitbox.Size = size * 1.3      -- 클릭 잘 잡히게 살짝 키움
	hitbox.CFrame = base.CFrame
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = true
	hitbox.Massless = true
	hitbox.Anchored = false
	hitbox.Parent = pet
	hitbox:SetAttribute("WANG_OrigAnch", false)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hitbox
	weld.Part1 = base
	weld.Parent = hitbox
	return hitbox
end



local function normalizeTargetInstance(target)
	if not target then return nil end
	-- Attachment의 경우 그 부모(보통 BasePart)가 실제 이동 타겟
	if target:IsA("Attachment") and target.Parent then
		return target.Parent
	end
	-- ProximityPrompt이 전달된 경우: Prompt.Parent === Attachment; Attachment.Parent === BasePart
	if target:IsA("ProximityPrompt") and target.Parent then
		local anc = target.Parent
		if anc:IsA("Attachment") and anc.Parent then
			return anc.Parent
		end
		-- 혹은 prompt directly parent가 BasePart일 수도 있슴
		if anc:IsA("BasePart") then
			return anc
		end
	end
	-- Model/BasePart 등은 getAnyBasePart로 처리
	return target
end


-- 상태
type TWangState = { approaching: boolean, clicks: number, clickConn: RBXScriptConnection?, lastWalkSpeed: number?, target: Instance? }
local State: {[Player]: TWangState} = {}




-- 현재 활성 상태 조회 (기본값 true)
local function isWangActive(target: Instance): boolean
	local model = resolveTargetModel(target); if not model then return false end
	local v = model:GetAttribute("WANG_Active")
	return (v == nil) and true or (v == true)
end


local function startSequence(player: Player, target: Instance)
	
	
	local pet = findPlayersPet(player); if not pet then return end
	if pet:GetAttribute("WangApproaching") then return end
	
	pet:SetAttribute("AIState", "wang_approach")
	pet:SetAttribute("BlockPetQuestClicks", true)  -- ✅ 펫클릭 퀘스트 일시차단


	local resolvedTarget = normalizeTargetInstance(target)
	if not resolvedTarget then return end

	-- 🔒 타겟 비활성 중이면 시작 안 함
	if not isWangActive(resolvedTarget) then return end

	local resolvedTarget = normalizeTargetInstance(target)
	if not resolvedTarget then return end

	local st = State[player]
	if st then
		st.approaching = false
		if st.clickConn then st.clickConn:Disconnect(); st.clickConn = nil end
	end

	st = { approaching = true, clicks = 0, clickConn = nil, lastWalkSpeed = nil, target = resolvedTarget }
	State[player] = st

	pet:SetAttribute("WangApproaching", true)
	pet:SetAttribute("FollowLocked", true)
	pet:SetAttribute("AIState", "wang_approach")

	WangEvent:FireClient(player, "Bubble", { text = EXCLAIM_TEXT, stash = true })

	hardStopPet(pet)

	local hum = pet:FindFirstChildOfClass("Humanoid")
	if hum then
		st.lastWalkSpeed = hum.WalkSpeed
		pet:SetAttribute("WANG_LastWalkSpeed", st.lastWalkSpeed)
	end

	-- ✅ ClickDetector 와이어링 없음 (Hitbox만 보장)
	ensurePetClickTarget(pet)

	beginApproach(pet, resolvedTarget)
end





WangCancelClick.OnServerEvent:Connect(function(player, clickedPart: Instance)
	local pet = findPlayersPet(player)
	if not pet or not clickedPart or not clickedPart:IsDescendantOf(pet) then return end
	if clickedPart.Name ~= "PetClickHitbox" then return end

	local st = State[player]
	
	if not st or not st.approaching then return end
	if pet:GetAttribute("WangApproaching") ~= true then return end

	st.clicks += 1
	WangEvent:FireClient(player, "Bubble", { text = ("Cancel "..st.clicks.."/3") })

	if st.clicks >= 3 then
		st.approaching = false
		pet:SetAttribute("WangApproaching", false)

		WangEvent:FireClient(player, "RestoreBubble")
		restoreFollow(player, pet, st.lastWalkSpeed)

		-- ✅ Wang은 '클리어' 시점에만 이펙트
		WangEvent:FireClient(player, "ClearEffect")

		-- ✅ 이번에 사용한 타겟 쿨타임 진입
		local targetModel = resolveTargetModel(st.target or clickedPart)
		if targetModel then
			setWangActive(targetModel, false)
			task.delay(WANG_COOLDOWN_SECS, function()
				if targetModel and targetModel.Parent then
					setWangActive(targetModel, true)
				end
			end)
		end

		st.clicks = 0
	end
end)

WangProxRelay.OnServerEvent:Connect(function(player, action: "enter"|"exit", prompt: ProximityPrompt)
	if not (player and prompt and prompt:IsDescendantOf(WangFolder)) then return end
	if prompt.Name ~= "WangPrompt" then return end

	if action == "enter" then
		-- 🔒 비활성 타겟이면 무시
		if not isWangActive(prompt) then return end
		-- … 기존 Bubble/접근 시작 로직 …
		local target = prompt.Parent
		startSequence(player, target)
	end
end)


-- ==================== 프롬프트 자동 설치(모델당 1개) ====================
for _, inst in ipairs(WangFolder:GetChildren()) do
	if inst:IsA("Model") then ensurePrompt(inst) end
end
WangFolder.ChildAdded:Connect(function(inst)
	if inst:IsA("Model") then ensurePrompt(inst) end
end)


-- ==================== 정리 ====================
Players.PlayerRemoving:Connect(function(plr)
	local st = State[plr]
	if st then
		if st.clickConn then st.clickConn:Disconnect() end
		State[plr] = nil
	end
	-- 소유 펫 찾아 가드 해제 시도
	local pet = findPlayersPet(plr)
	if pet then
		pet:SetAttribute("BlockPetQuestClicks", false)
		pet:SetAttribute("WangApproaching", false)
	end
end)
