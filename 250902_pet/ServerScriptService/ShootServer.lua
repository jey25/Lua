--!strict
local DebrisService = game:GetService("Debris")
local Tool = script.Parent
local IconURL = Tool.TextureId

-- Events
local Events = Tool:WaitForChild("Events")
local ShootEvent = Events:WaitForChild("ShootRE")
local CreateBulletEvent = Events:WaitForChild("CreateBullet") -- 클라 호출 무시 예정

-- 초기 청소 + BulletsFolder 보장
do
	local thumb = Tool:FindFirstChild("ThumbnailCamera"); if thumb then thumb:Destroy() end
	local readme = Tool:FindFirstChild("READ ME"); if readme then readme:Destroy() end
	if not workspace:FindFirstChild("BulletsFolder") then
		local f = Instance.new("Folder"); f.Name = "BulletsFolder"; f.Parent = workspace
	end
end

-- 무기 서버 파라미터(원하는 값으로 조절)
local WEAPON = {
	RPM = 400,                             -- 분당 발사수 (쿨다운 = 60/RPM 초)
	BASE_DAMAGE = 25,                      -- 기본 데미지(몸통)
	HEAD_MULT = 2.0,                       -- 헤드샷 배수
	LIMB_MULT = 0.8,                       -- 팔다리 배수
	RANGE_FULL = 60,                       -- 이 거리까지는 풀 데미지
	RANGE_MAX = 200,                       -- 최대 사거리
	RANGE_MIN_MULT = 0.5,                  -- 최대 사거리에서의 최소 배율
	MAX_AIM_ANGLE_DEG = 35,                -- (선택) 클라 조준방향 허용 각도
}

local FIRE_INTERVAL = 60 / WEAPON.RPM
local lastShotByUser: {[number]: number} = {} -- userId -> os.clock()

-- 상단 Events 근처
local OutOfAmmoEvent = Events:FindFirstChild("OutOfAmmo")
if not OutOfAmmoEvent then
	OutOfAmmoEvent = Instance.new("RemoteEvent")
	OutOfAmmoEvent.Name = "OutOfAmmo"
	OutOfAmmoEvent.Parent = Events
end

-- 중복 스케줄 방지 플래그 (툴 개체 단위)
local oomScheduled = false

OutOfAmmoEvent.OnServerEvent:Connect(function(plr, action, payload)
	-- 이 툴이 해당 플레이어 소유인지 검증
	local Tool = script.Parent
	local char = plr.Character
	if not char then return end
	local backpack = plr:FindFirstChild("Backpack")
	local owned = (Tool.Parent == char) or (backpack and Tool.Parent == backpack)
	if not owned then return end

	-- 오직 최초 1회만 스케줄
	if oomScheduled then return end
	oomScheduled = true

	-- 기본값(요청 없을 때의 하위호환)
	local unequipIn = 2
	local destroyIn = 3

	if action == "schedule" and typeof(payload) == "table" then
		unequipIn = tonumber(payload.unequipIn) or unequipIn
		destroyIn = tonumber(payload.destroyIn) or destroyIn
	end
	-- 안전 클램프
	unequipIn = math.clamp(unequipIn, 0, 5)
	destroyIn = math.clamp(destroyIn, 0, 10)

	-- 1) 일정 시간 후 Unequip
	if unequipIn > 0 then
		task.delay(unequipIn, function()
			-- 여전히 그 플레이어 소유일 때만
			if not Tool or not Tool.Parent then return end
			local stillOwned = (Tool.Parent == char) or (backpack and Tool.Parent == backpack)
			if not stillOwned then return end

			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum and Tool.Parent == char then
				pcall(function() hum:UnequipTools() end)
			end
		end)
	else
		-- 즉시 Unequip
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and Tool.Parent == char then
			pcall(function() hum:UnequipTools() end)
		end
	end

	-- 2) 일정 시간 후 삭제(이벤트 시점 기준)
	task.delay(destroyIn, function()
		if not Tool or not Tool.Parent then return end
		local stillOwned = (Tool.Parent == char) or (backpack and Tool.Parent == backpack)
		if stillOwned then
			Tool:Destroy()
		end
	end)
end)


OutOfAmmoEvent.OnServerEvent:Connect(function(plr)

	local char = plr.Character
	local backpack = plr:FindFirstChild("Backpack")

	local owned =
		(char and Tool.Parent == char) or
		(backpack and Tool.Parent == backpack)

	if not owned then
		return -- 남의 무기/바닥/위조 호출 방지
	end

	-- 장착 중이면 먼저 해제
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and Tool.Parent == char then
		pcall(function() hum:UnequipTools() end)
		task.wait(0.1)  -- 1~2틱 권장
		Tool:Destroy()
	end

	-- 안전 제거
	Tool:Destroy()
end)


-- 유틸: 휴머노이드 태그 (킬크레딧)
local function TagHumanoid(humanoid: Humanoid, player: Player)
	if humanoid.Health <= 0 then return end
	while humanoid:FindFirstChild("creator") do
		humanoid.creator:Destroy()
	end
	local creatorTag = Instance.new("ObjectValue")
	creatorTag.Name = "creator"
	creatorTag.Value = player
	creatorTag.Parent = humanoid
	DebrisService:AddItem(creatorTag, 1.5)

	local iconTag = Instance.new("StringValue")
	iconTag.Name = "icon"
	iconTag.Value = IconURL
	iconTag.Parent = creatorTag
end

-- 유틸: BulletsFolder에 시각용 총알 & 탄피
local function CreateBullet(bulletPos: Vector3)
	local bulletsFolder = workspace:FindFirstChild("BulletsFolder") :: Folder?
	if not bulletsFolder then
		bulletsFolder = Instance.new("Folder"); bulletsFolder.Name = "BulletsFolder"; bulletsFolder.Parent = workspace
	end

	local bullet = Instance.new("Part")
	bullet.Size = Vector3.new(0.1, 0.1, 0.1)
	bullet.Name = "Bullet"
	bullet.Anchored = true
	bullet.CanCollide = false
	bullet.TopSurface = Enum.SurfaceType.Smooth
	bullet.BottomSurface = Enum.SurfaceType.Smooth
	bullet.BrickColor = BrickColor.new("Black")
	bullet.CFrame = CFrame.new(bulletPos)
	bullet.Parent = bulletsFolder
	DebrisService:AddItem(bullet, 2.5)

	if Tool:FindFirstChild("Handle") then
		local shell = Instance.new("Part")
		shell.Name = "Shell"
		shell.Size = Vector3.new(1,1,1)
		shell.CanCollide = false
		shell.TopSurface = Enum.SurfaceType.Smooth
		shell.BottomSurface = Enum.SurfaceType.Smooth
		shell.BrickColor = BrickColor.new(226)
		shell.CFrame = Tool.Handle.CFrame
		shell.AssemblyLinearVelocity = Tool.Handle.CFrame.LookVector * 35 + Vector3.new(math.random(-10,10),20,math.random(-10,20))
		shell.RotVelocity = Vector3.new(0,200,0)
		shell.Parent = bulletsFolder
		DebrisService:AddItem(shell, 1)

		local mesh = Instance.new("SpecialMesh")
		mesh.Scale = Vector3.new(.15,.4,.15)
		mesh.Parent = shell
	end
end

-- 드롭오프 계산(선형)
local function rangeMultiplier(dist: number): number
	if dist <= WEAPON.RANGE_FULL then return 1 end
	if dist >= WEAPON.RANGE_MAX then return WEAPON.RANGE_MIN_MULT end
	local t = (dist - WEAPON.RANGE_FULL) / (WEAPON.RANGE_MAX - WEAPON.RANGE_FULL)
	return 1 - t * (1 - WEAPON.RANGE_MIN_MULT)
end

-- 부위 배수
local function hitzoneMultiplier(part: BasePart): number
	local n = part.Name
	if n == "Head" then return WEAPON.HEAD_MULT end
	local function has(s) return string.find(n, s, 1, true) ~= nil end
	if has("Arm") or has("Leg") or has("Hand") or has("Foot") then return WEAPON.LIMB_MULT end
	if has("Lower") or has("Upper") then
		if has("Torso") then return 1 end
		return WEAPON.LIMB_MULT
	end
	return 1
end


-- 파츠에서 휴머노이드 찾기
local function findHumanoidFromPart(part: Instance?): Humanoid?
	if not part then return nil end
	local m = part:FindFirstAncestorOfClass("Model")
	if not m then return nil end
	return m:FindFirstChildOfClass("Humanoid")
end

-- OnServerEvent: 서버가 자체 레이캐스트로 판정 & 데미지 산출
ShootEvent.OnServerEvent:Connect(function(plr: Player, arg1, arg2)
	-- 1) 발사 간격 제한
	local now = os.clock()
	local last = lastShotByUser[plr.UserId] or 0
	if now - last < FIRE_INTERVAL then
		return -- 과발사(매크로) 무시
	end

	-- 2) 무기 소지/장착 검증
	local char = plr.Character
	if not char then return end
	if Tool.Parent ~= char then return end
	local handle = Tool:FindFirstChild("Handle")
	if not (handle and handle:IsA("BasePart")) then return end

	-- 3) (선택) 클라 전송 조준 데이터 수용 + 각도 제한
	--   - 기존 클라가 hum, damage를 보내던 방식과 호환: 테이블이 없으면 서버가 Handle 방향 그대로 사용
	local payload = (typeof(arg1) == "table" and arg1) or (typeof(arg2) == "table" and arg2) or nil
	local origin: Vector3 = handle.Position
	local dir: Vector3 = handle.CFrame.LookVector

	if payload then
		local pdir = (typeof(payload.dir) == "Vector3") and payload.dir.Unit or nil
		local porg = (typeof(payload.origin) == "Vector3") and payload.origin or nil
		if pdir then
			-- 각도 제한(에임 스푸핑 방지)
			local baseDir = handle.CFrame.LookVector
			local cosMax = math.cos(math.rad(WEAPON.MAX_AIM_ANGLE_DEG))
			if baseDir:Dot(pdir) >= cosMax then
				dir = pdir
			end
		end
		if porg then
			-- 원점은 플레이어 근처일 때만 허용(텔레포트·벽 관통 방지)
			if (porg - handle.Position).Magnitude <= 10 then
				origin = porg
			end
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char, workspace:FindFirstChild("BulletsFolder") }

	local result = workspace:Raycast(origin, dir * WEAPON.RANGE_MAX, params)
	if not result then
		return -- 빗나감
	end

	local hitPart = result.Instance
	local hitHum = findHumanoidFromPart(hitPart)
	if not (hitHum and hitHum.Health > 0) then
		-- 사람 아닌 오브젝트를 맞춘 경우: 이펙트만 생성하고 종료
		CreateBullet(result.Position)
		lastShotByUser[plr.UserId] = now
		return
	end

	-- 5) 데미지 산출(서버권위)
	local dist = (result.Position - origin).Magnitude
	local dmg = WEAPON.BASE_DAMAGE * hitzoneMultiplier(hitPart) * rangeMultiplier(dist)
	dmg = math.floor(dmg + 0.5)
	if dmg <= 0 then
		CreateBullet(result.Position)
		lastShotByUser[plr.UserId] = now
		return
	end

	-- 6) 적용 & 태깅
	hitHum:TakeDamage(dmg)
	TagHumanoid(hitHum, plr)

	-- 7) 시각 효과
	CreateBullet(result.Position)

	-- 8) 마지막 발사 시간 기록
	lastShotByUser[plr.UserId] = now
end)

-- 클라가 임의로 총알을 생성 못 하도록: 무시 처리(서버만 CreateBullet 호출)
CreateBulletEvent.OnServerEvent:Connect(function() end)
