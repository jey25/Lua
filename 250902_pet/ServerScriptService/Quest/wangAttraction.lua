

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ExperienceService = require(game.ServerScriptService:WaitForChild("ExperienceService"))
local PetAffectionService = require(game.ServerScriptService:WaitForChild("PetAffectionService"))


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

-- 🔧 기본값 (원하면 바꿔도 됨)
local WANG_ATTRACT_SFX_INTERVAL_DEFAULT = 2   -- 초

-- 🔧 루프 토큰 (플레이어별)
local AttractLoopToken: {[Player]: number} = {}

-- 상태
type TWangState = { approaching: boolean, clicks: number, clickConn: RBXScriptConnection?, lastWalkSpeed: number?, target: Instance? }
local State: {[Player]: TWangState} = {}


-- ==================== 경로 / RemoteEvents ====================
local World = workspace:WaitForChild("World")
local DogItems = World:WaitForChild("dogItems")
local WangFolder = DogItems:WaitForChild("wang")
local SFXFolder = ReplicatedStorage:WaitForChild("SFX") -- 여기에 PetClick Sound 템플릿

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


-- 바닥 레이캐스트 (이미 있던 함수와 동일 취지)
local function getGroundYBelow(origin: Vector3, ignore: Instance?): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {ignore}
	local result = workspace:Raycast(origin + Vector3.new(0, 2, 0), Vector3.new(0, -200, 0), params)
	return result and result.Position.Y or nil
end

-- 피벗(모델 Pivot)과 바운딩박스 하단 사이의 오프셋 계산
local function getPivotBottomOffset(model: Model): number
	local pivotCF = model:GetPivot()
	local cf, size = model:GetBoundingBox()
	local bottomY = cf.Position.Y - size.Y * 0.5
	return (pivotCF.Position.Y - bottomY)
end

-- 현재 XZ 위치에서 “안 가라앉지 않는 Y” 계산
local function computeGroundedY(model: Model, xzPos: Vector3, extraClearance: number?): number
	local pivot = model:GetPivot()
	local groundY = getGroundYBelow(Vector3.new(xzPos.X, pivot.Position.Y, xzPos.Z), model) or pivot.Position.Y
	local pivotBottom = getPivotBottomOffset(model)
	local clearance = tonumber(extraClearance) or (model:GetAttribute("GroundClearance") or 0.5)
	return groundY + pivotBottom + clearance
end


-- 선택: 타겟/폴더 Attribute로 런타임 조정 가능
--  - target(Model/BasePart)에 Number Attribute "WangAttractInterval" 넣으면 그 값(초) 사용
--  - WangFolder(=DogItems.wang)에도 동일 Attribute 가능(타겟에 없을 때 폴백)
--  - 사운드 이름도 "WangAttractSfxName" 로 지정 가능(예: "WangAttractLoop")
local function getAttractIntervalFor(target: Instance?): number
	local t = nil
	if target then t = target:GetAttribute("WangAttractInterval") end
	if typeof(t) ~= "number" then
		t = WangFolder:GetAttribute("WangAttractInterval")
	end
	if typeof(t) ~= "number" then
		t = WANG_ATTRACT_SFX_INTERVAL_DEFAULT
	end
	return math.max(0.1, t)
end

local function resolveAttractTemplate(target: Instance?): Sound?
	-- 1) 이름 Attribute 우선
	local nameAttr = target and target:GetAttribute("WangAttractSfxName")
	if typeof(nameAttr) ~= "string" or #nameAttr == 0 then
		nameAttr = WangFolder:GetAttribute("WangAttractSfxName")
	end
	if typeof(nameAttr) == "string" and #nameAttr > 0 then
		local s = SFXFolder:FindFirstChild(nameAttr)
		if s and s:IsA("Sound") then return s end
	end
	-- 2) 추천 기본 이름들 순회
	for _, key in ipairs({ "Growling" }) do
		local s = SFXFolder:FindFirstChild(key)
		if s and s:IsA("Sound") then return s end
	end
	-- 3) 폴더 첫 번째 Sound 폴백
	for _, ch in ipairs(SFXFolder:GetChildren()) do
		if ch:IsA("Sound") then return ch end
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
		-- 🔹 UI 숨김 처리
		p.Style = Enum.ProximityPromptStyle.Custom
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



-- ▶ 교체본: 저장된 OffsetX/Y/Z와 AttachName을 사용 (groundNudgeY 보존)
local function reattachFollowToCharacter(pet: Model, character: Model)
	local petPP = getAnyBasePart(pet)
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not (petPP and hrp) then return end

	cleanupFollowConstraints(pet)
	petPP:SetNetworkOwner(nil)

	local aPet = Instance.new("Attachment")
	aPet.Name = "PetAttach"
	aPet.Parent = petPP

	local attachName = pet:GetAttribute("AttachName")
		or ("CharAttach_"..tostring(pet:GetAttribute("PetId") or "")) -- 펫별 고유
	local aChar = hrp:FindFirstChild(attachName) :: Attachment
	if not aChar then
		aChar = Instance.new("Attachment")
		aChar.Name = attachName
		aChar.Parent = hrp
	end

	local off = Vector3.new(
		tonumber(pet:GetAttribute("OffsetX")) or 2.5,
		tonumber(pet:GetAttribute("OffsetY")) or -1.5, -- ← groundNudgeY가 여기 들어있음
		tonumber(pet:GetAttribute("OffsetZ")) or -2.5
	)
	aChar.Position = off

	local yawOffsetDeg = tonumber(pet:GetAttribute("YawOffsetDeg")) or 0
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

	-- ✅ 한 틱 뒤 ‘착지 보정 킥’(시각적 뜸 방지 + 경사 대응)
	task.defer(function()
		if pet and pet.Parent and hrp.Parent then
			local hrpPos = hrp.Position
			local nextXZ = Vector3.new(hrpPos.X + off.X, 0, hrpPos.Z + off.Z)
			local groundedY = computeGroundedY(pet, nextXZ, GROUND_OFFSET)
			local targetPos = Vector3.new(nextXZ.X, groundedY, nextXZ.Z)
			pet:PivotTo(CFrame.new(targetPos, Vector3.new(hrpPos.X, targetPos.Y, hrpPos.Z)))
		end
	end)
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

	-- ▶ restoreFollow 내 reattachFollowToCharacter 호출 직후(또는 끝부분)에 추가(선택)
	-- (이미 reattach에서 킥을 해주므로 생략해도 OK)
	local off = Vector3.new(
		tonumber(pet:GetAttribute("OffsetX")) or 2.5,
		tonumber(pet:GetAttribute("OffsetY")) or -1.5,
		tonumber(pet:GetAttribute("OffsetZ")) or -2.5
	)
	local hrp = (player.Character or player.CharacterAdded:Wait()):FindFirstChild("HumanoidRootPart")
	if hrp then
		task.defer(function()
			local xz = Vector3.new(hrp.Position.X + off.X, 0, hrp.Position.Z + off.Z)
			local gy = computeGroundedY(pet, xz, GROUND_OFFSET)
			pet:PivotTo(CFrame.new(xz.X, gy, xz.Z, hrp.CFrame.XVector, hrp.CFrame.YVector, hrp.CFrame.ZVector))
		end)
	end


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


local function stopAttractSfxLoop(player: Player)
	AttractLoopToken[player] = (AttractLoopToken[player] or 0) + 1
end


local function beginApproach(pet: Model, target: Instance)
	local tgt = getAnyBasePart(target)
	if not tgt then
		if target and target:IsA("Attachment") and target.Parent and target.Parent:IsA("BasePart") then
			tgt = target.Parent
		elseif target and target:IsA("Model") then
			tgt = (target :: Model).PrimaryPart
		end
	end
	if not tgt then return end

	-- 기준 Y(LOCK_Y면 한 번만 샘플)
	local pivotCF = pet:GetPivot()
	local planeY = pivotCF.Position.Y
	if LOCK_Y then
		local groundY = getGroundYBelow(pivotCF.Position, pet)
		if groundY then planeY = groundY end
	end

	task.spawn(function()
		while pet.Parent and target and target.Parent do
			if pet:GetAttribute("WangApproaching") == false then break end

			pivotCF = pet:GetPivot()
			local petPos = pivotCF.Position

			local tgtPos = tgt.Position
			if LOCK_Y then
				tgtPos = Vector3.new(tgtPos.X, planeY, tgtPos.Z)
			end

			local dx, dz = tgtPos.X - petPos.X, tgtPos.Z - petPos.Z
			local distXZ = math.sqrt(dx*dx + dz*dz)

			-- 도착 체크
			if distXZ <= TOUCH_RANGE then
				local owner = getOwnerPlayerFromPet(pet)
				if owner then
					WangEvent:FireClient(owner, "Bubble", { text = TOUCH_TEXT })
					stopAttractSfxLoop(owner)

					-- ⬇⬇ 추가: 도착 즉시 마커/이펙트 제거
					WangEvent:FireClient(owner, "HideMarker", { target = pet, key = "wang_touch" })
					WangEvent:FireClient(owner, "ClearEffect")
					
					--실패하면 애정도 감소
					pcall(function()
						PetAffectionService.Adjust(owner, -1, "wang_touch_fail")
					end)
				end
				pet:SetAttribute("WangApproaching", false)

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

				if AUTO_RESUME_AFTER_TOUCH then
					local owner = getOwnerPlayerFromPet(pet)
					if owner then
						local lastWS = pet:GetAttribute("WANG_LastWalkSpeed")
						task.delay(RESUME_DELAY_AFTER_TOUCH, function()
							WangEvent:FireClient(owner, "RestoreBubble")
							restoreFollow(owner, pet, (type(lastWS) == "number") and lastWS or nil)
							pet:SetAttribute("WANG_LastWalkSpeed", nil)
						end)
					end
				end
				break
			end

			-- ▶ Pivot 기준으로 전진
			local step = math.min(distXZ, APPROACH_SPEED * LOOP_DT)
			local dirXZ = (distXZ > 0) and Vector3.new(dx, 0, dz).Unit or Vector3.new()
			local nextXZ = petPos + dirXZ * step

			-- Y 보정
			local groundedY = computeGroundedY(pet, nextXZ, GROUND_OFFSET)
			local newPos = Vector3.new(nextXZ.X, groundedY, nextXZ.Z)

			local lookAt = Vector3.new(tgtPos.X, newPos.Y, tgtPos.Z)
			pet:PivotTo(CFrame.new(newPos, lookAt))

			task.wait(LOOP_DT)
		end

		-- 종료 후 안전 복구(기존 그대로)
		-- ⬇⬇ 추가: 어떤 종료 경로에서도 마커/이펙트가 남지 않도록 보장
		do
			local owner4 = getOwnerPlayerFromPet(pet)
			if owner4 then
				WangEvent:FireClient(owner4, "HideMarker", { target = pet, key = "wang_touch" })
				WangEvent:FireClient(owner4, "ClearEffect")
			end
		end

		-- 종료 후 안전 복구(기존 그대로)
		if not pet:GetAttribute("WangApproaching") then
			local owner3 = getOwnerPlayerFromPet(pet)
			if owner3 then
				if pet:GetAttribute("FollowLocked") then
					local lastWS2 = pet:GetAttribute("WANG_LastWalkSpeed")
					restoreFollow(owner3, pet, (type(lastWS2) == "number") and lastWS2 or nil)
					pet:SetAttribute("WANG_LastWalkSpeed", nil)
					pet:SetAttribute("FollowLocked", false)
				end
			else
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



local function startAttractSfxLoop(player: Player, target: Instance)
	local tpl = resolveAttractTemplate(target)
	if not tpl then return end

	AttractLoopToken[player] = (AttractLoopToken[player] or 0) + 1
	local my = AttractLoopToken[player]

	task.spawn(function()
		while player and player.Parent do
			-- 토큰/상태 체크
			if AttractLoopToken[player] ~= my then break end
			local st = State[player]
			if not (st and st.approaching) then break end

			local pet = findPlayersPet(player)
			if not pet or pet:GetAttribute("WangApproaching") ~= true then break end

			-- 발견 루프(see): 주기 재생
			WangEvent:FireClient(player, "PlaySfxTemplate", tpl, "see")

			task.wait(getAttractIntervalFor(target))
		end
	end)
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

	-- Wang 추적 시작 시
	WangEvent:FireClient(player, "ShowMarker", {
		target = pet,
		preset = "Click Icon",     -- ← 또는 미지정 시 기본값으로 "Click Icon" 사용
		key = "wang_touch",
		transparency = 0.2,
		size = UDim2.fromOffset(72,72),
		pulse = true,
	})

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

	-- ✅ 루프 시작: 처음 발견 시점부터 주기적으로 SFX
	startAttractSfxLoop(player, resolvedTarget)
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

	-- ✅ 유효 클릭일 때 그 플레이어에게만 SFX 재생 지시
	local tpl = SFXFolder:FindFirstChild("PetClick")
	if tpl and tpl:IsA("Sound") then
		-- 펫 클릭(click): 클릭 시 재생
		WangEvent:FireClient(player, "PlaySfxTemplate", tpl, "click")
	end


	WangEvent:FireClient(player, "Bubble", { text = ("Cancel "..st.clicks.."/3") })

	if st.clicks >= 3 then
		st.approaching = false
		pet:SetAttribute("WangApproaching", false)

		WangEvent:FireClient(player, "RestoreBubble")
		restoreFollow(player, pet, st.lastWalkSpeed)

		WangEvent:FireClient(player, "HideMarker", { target = pet, key = "wang_touch" })

		-- ✅ Wang은 '클리어' 시점에만 이펙트
		WangEvent:FireClient(player, "ClearEffect")
		ExperienceService.AddExp(player, 200)

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

		-- (기존 완료 처리들)
		-- ✅ 사운드 루프 정지
		stopAttractSfxLoop(player)
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
		stopAttractSfxLoop(plr)
	end
	-- 소유 펫 찾아 가드 해제 시도
	local pet = findPlayersPet(plr)
	if pet then
		pet:SetAttribute("BlockPetQuestClicks", false)
		pet:SetAttribute("WangApproaching", false)
	end
end)
