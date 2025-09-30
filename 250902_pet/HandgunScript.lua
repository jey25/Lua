--------------------- TEMPLATE WEAPON ---------------------------
--edited by joso555
-- Waits for the child of the specified parent
local function WaitForChild(parent, childName)
	while not parent:FindFirstChild(childName) do parent.ChildAdded:Wait() end
	return parent[childName]
end

-----FPS DATA-----
local FPSHandsEnbled = true --The fps arms visibility when first person is on. true/false to toggle
local AutoFirstPerson = true --Forces the player to firstperson camera. true/false to toggle
-- 탄 완전 소진 스케줄 중복 방지
local OutOfAmmoScheduled = false

----- TOOL DATA -----
-- How much damage a bullet does
local Damage = 18
-- How many times per second the gun can fire
local FireRate = 1 / 5.5
-- The maximum distance the can can shoot, this value should never go above 1000
local Range = 370
-- In radians the minimum accuracy penalty
local MinSpread = 0.005
-- In radian the maximum accuracy penalty
local MaxSpread = 0.07
-- Number of bullets in a clip
local ClipSize = 6
-- DefaultValue for spare ammo
local SpareAmmo = 24
-- The amount the aim will increase or decrease by
-- decreases this number reduces the speed that recoil takes effect
local AimInaccuracyStepAmount = .5
-- Time it takes to reload weapon
local ReloadTime = 2
----------------------------------------

-- Colors
local FriendlyReticleColor = Color3.new(0, 1, 0)
local EnemyReticleColor	= Color3.new(1, 0, 0)
local NeutralReticleColor	= Color3.new(1, 1, 1)

local Spread = MinSpread
local AmmoInClip = ClipSize

local Camera = workspace.CurrentCamera

local Tool = script.Parent
local Handle = WaitForChild(Tool, 'Handle')
local WeaponGui = nil

---------Main Events--------------
local Events = Tool:WaitForChild("Events")
local ShootRE = Events:WaitForChild("ShootRE")
local bulletRE = Events:WaitForChild("CreateBullet")

local LeftButtonDown
local Reloading = false
local IsShooting = false
local Pitch = script.Parent.Handle.FireSound

-- Player specific convenience variables
local MyPlayer = nil
local MyCharacter = nil
local MyHumanoid = nil
local MyTorso = nil
local MyMouse = nil


local RecoilAnim
local RecoilTrack = nil

local ReloadAnim
local ReloadTrack = nil

local IconURL = Tool.TextureId  
local DebrisService = game:GetService('Debris')
local PlayersService = game:GetService('Players')


local FireSound

local OnFireConnection = nil
local OnReloadConnection = nil

local DecreasedAimLastShot = false
local LastSpreadUpdate = time()

local flare = script.Parent:WaitForChild("Flare")

-- this is a dummy object that holds the flash made when the gun is fired
local FlashHolder = nil


local WorldToCellFunction = workspace.Terrain.WorldToCellPreferSolid
local GetCellFunction = workspace.Terrain.GetCell

-- 탄 완전 소진 시: 1초 후 Unequip, 3초 후 삭제를 서버에 요청
local function MaybeScheduleOutOfAmmo()
	if OutOfAmmoScheduled then return end
	if AmmoInClip == 0 and SpareAmmo == 0 then
		OutOfAmmoScheduled = true
		-- 서버에 스케줄 요청 (이벤트/이름 그대로 사용)
		local Events = Tool:WaitForChild("Events")
		local OutOfAmmoRE = Events:WaitForChild("OutOfAmmo")
		OutOfAmmoRE:FireServer("schedule", { unequipIn = 1, destroyIn = 3 })

		-- 체감 개선(선택): 로컬에서도 사격/이펙트 즉시 정지
		LeftButtonDown = false
		IsShooting = false
		if Handle:FindFirstChild("Flash") then Handle.Flash.Enabled = false end
		if flare and flare:FindFirstChild("MuzzleFlash") then flare.MuzzleFlash.Enabled = false end
		-- UI 정리는 Unequipped가 호출되면 기존 OnUnequipped에서 처리됨
	end
end

--this is a function to get player character rig
local function DetectRigAsync(Char)
	local Hum = Char:FindFirstChildOfClass("Humanoid")

	if Hum then
		if Hum.RigType == Enum.HumanoidRigType.R15 then
			return "R15"
		elseif Hum.RigType == Enum.HumanoidRigType.R6 then
			return "R6"
		end
	end
end

function RayCast(startPos, vec, rayLength)
	local Origin = startPos

	local Direction = vec * rayLength

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Blacklist
	Params.IgnoreWater = true
	Params.FilterDescendantsInstances = {Tool.Parent, workspace.BulletsFolder, Tool}

	local raycastResult = workspace:Raycast(Origin, Direction, Params)

	if raycastResult then
		return raycastResult.Instance, raycastResult.Position
	end
end

local function Reload()
	if not Reloading then
		Reloading = true

		if AmmoInClip ~= ClipSize and SpareAmmo > 0 then
			if RecoilTrack then
				RecoilTrack:Stop()
			end
			if WeaponGui and WeaponGui:FindFirstChild('Crosshair') then
				if WeaponGui.Crosshair:FindFirstChild('ReloadingLabel') then
					WeaponGui.Crosshair.ReloadingLabel.Visible = true
				end
			end
			if ReloadTrack then
				ReloadTrack:Play()
			end
			script.Parent.Handle.Reload:Play()
			task.wait(ReloadTime)
			-- Only use as much ammo as you have
			local ammoToUse = math.min(ClipSize - AmmoInClip, SpareAmmo)
			AmmoInClip = AmmoInClip + ammoToUse
			SpareAmmo = SpareAmmo - ammoToUse
			UpdateAmmo(AmmoInClip)
			--WeaponGui.Reload.Visible = false
			if ReloadTrack then
				ReloadTrack:Stop()
			end
		end
		Reloading = false
		MaybeScheduleOutOfAmmo()  -- ★ 추가
	end
end

function OnFire()
	if IsShooting then return end
	if MyHumanoid and MyHumanoid.Health > 0 then
		if RecoilTrack and AmmoInClip > 0 then
			RecoilTrack:Play()
		end
		IsShooting = true
		while LeftButtonDown and AmmoInClip > 0 and not Reloading do
			if Spread and not DecreasedAimLastShot then
				Spread = math.min(MaxSpread, Spread + AimInaccuracyStepAmount)
				UpdateCrosshair(Spread)
			end
			DecreasedAimLastShot = not DecreasedAimLastShot
			if Handle:FindFirstChild('FireSound') then
				Pitch.Pitch = .8 + (math.random() * .5)
				Handle.FireSound:Play()
				Handle.Flash.Enabled = true
				flare.MuzzleFlash.Enabled = true
				--Handle.Smoke.Enabled=true --This is optional
			end
			if MyMouse then
				local targetPoint = MyMouse.Hit.Position
				local shootDirection = (targetPoint - Handle.Position).unit

				shootDirection = CFrame.Angles((0.5 - math.random()) * 2 * Spread,
					(0.5 - math.random()) * 2 * Spread,
					(0.5 - math.random()) * 2 * Spread) * shootDirection
				local hitObject, bulletPos = RayCast(Handle.Position, shootDirection, Range)
				local bullet

				if hitObject then
					bulletRE:FireServer(bulletPos)
					WeaponGui.Crosshair.Hit:Play()
				end
				if hitObject and hitObject.Parent then
					local hitHumanoid = hitObject.Parent:FindFirstChild("Humanoid")
					if hitHumanoid then
						local hitPlayer = game.Players:GetPlayerFromCharacter(hitHumanoid.Parent)
						if MyPlayer.Neutral or (hitPlayer and hitPlayer.TeamColor ~= MyPlayer.TeamColor) then
							ShootRE:FireServer(hitHumanoid, Damage)
							if bullet then
								bullet:Destroy()
								bullet = nil
								--bullet.Transparency = 1
							end
							task.spawn(UpdateTargetHit)
						end
					end
				end
				AmmoInClip = AmmoInClip - 1
				UpdateAmmo(AmmoInClip)
			end
			task.wait(FireRate)
		end
		Handle.Flash.Enabled = false
		IsShooting = false
		flare.MuzzleFlash.Enabled = false
		--Handle.Smoke.Enabled=false --This is optional
		if AmmoInClip == 0 then
			Handle.Tick:Play()
			--WeaponGui.Reload.Visible = true
			Reload()
		end
		MaybeScheduleOutOfAmmo()  -- ★ 추가 (이중 호출 방지는 플래그로 처리됨)
		if RecoilTrack then
			RecoilTrack:Stop()
		end
	end
end

local TargetHits = 0
function UpdateTargetHit()
	TargetHits = TargetHits + 1
	if WeaponGui and WeaponGui:FindFirstChild('Crosshair') and WeaponGui.Crosshair:FindFirstChild('TargetHitImage') then
		WeaponGui.Crosshair.TargetHitImage.Visible = true
	end
	task.wait(0.5)
	TargetHits = TargetHits - 1
	if TargetHits == 0 and WeaponGui and WeaponGui:FindFirstChild('Crosshair') and WeaponGui.Crosshair:FindFirstChild('TargetHitImage') then
		WeaponGui.Crosshair.TargetHitImage.Visible = false
	end
end

function UpdateCrosshair(value, mouse)
	if WeaponGui then
		local absoluteY = 650
		WeaponGui.Crosshair:TweenSize(
			UDim2.new(0, value * absoluteY * 2 + 23, 0, value * absoluteY * 2 + 23),
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Linear,
			0.33)
	end
end

function UpdateAmmo(value)
	if WeaponGui and WeaponGui:FindFirstChild('AmmoHud') and WeaponGui.AmmoHud:FindFirstChild('ClipAmmo') then
		WeaponGui.AmmoHud.ClipAmmo.Text = AmmoInClip
		if value > 0 and WeaponGui:FindFirstChild('Crosshair') and WeaponGui.Crosshair:FindFirstChild('ReloadingLabel') then
			WeaponGui.Crosshair.ReloadingLabel.Visible = false
		end
	end
	if WeaponGui and WeaponGui:FindFirstChild('AmmoHud') and WeaponGui.AmmoHud:FindFirstChild('TotalAmmo') then
		WeaponGui.AmmoHud.TotalAmmo.Text = SpareAmmo
	end
end


function OnMouseDown()
	LeftButtonDown = true
	OnFire()
end

function OnMouseUp()
	LeftButtonDown = false
end

function OnKeyDown(key)
	if string.lower(key) == 'r' then
		Reload()
		if RecoilTrack then
			RecoilTrack:Stop()
		end
	end
end

local TransparencyConnections = {}


function OnEquipped(mouse)

	Handle.EquipSound:Play()
	Handle.EquipSound2:Play()
	Handle.UnequipSound:Stop()
	RecoilAnim = WaitForChild(Tool, 'Recoil')
	ReloadAnim = WaitForChild(Tool, 'Reload')
	FireSound  = WaitForChild(Handle, 'FireSound')

	MyCharacter = Tool.Parent

	MyPlayer = game:GetService('Players'):GetPlayerFromCharacter(MyCharacter)
	MyHumanoid = MyCharacter:FindFirstChild('Humanoid')
	MyTorso = MyCharacter:FindFirstChild('Torso')
	MyMouse = mouse
	WeaponGui = WaitForChild(Tool, 'WeaponHud'):Clone()

	if FPSHandsEnbled then
		if AutoFirstPerson then
			MyPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
		end

		local Rig = DetectRigAsync(MyCharacter)

		if Rig == "R15" then
			local WhitelistedBodyParts = {"LeftHand", "LeftLowerArm", "LeftUpperArm", "RightHand", "RightLowerArm", "RightUpperArm"}

			for i, bodypart in pairs(MyCharacter:GetDescendants()) do
				if table.find(WhitelistedBodyParts, bodypart.Name) and bodypart:IsA("BasePart") then
					bodypart.LocalTransparencyModifier = bodypart.Transparency

					TransparencyConnections[bodypart.Name] = bodypart:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
						bodypart.LocalTransparencyModifier = bodypart.Transparency
					end)
				end
			end
		elseif Rig == "R6" then
			local WhitelistedBodyParts = {"Right Arm", "Left Arm"}

			for i, bodypart in pairs(MyCharacter:GetDescendants()) do
				if table.find(WhitelistedBodyParts, bodypart.Name) and bodypart:IsA("BasePart") then
					bodypart.LocalTransparencyModifier = bodypart.Transparency

					TransparencyConnections[bodypart.Name] = bodypart:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
						bodypart.LocalTransparencyModifier = bodypart.Transparency
					end)
				end
			end

		end
	end

	if WeaponGui and MyPlayer then
		WeaponGui.Parent = MyPlayer.PlayerGui
		UpdateAmmo(AmmoInClip)
	end
	if RecoilAnim then
		RecoilTrack = MyHumanoid:LoadAnimation(RecoilAnim)
	end

	if ReloadAnim then
		ReloadTrack = MyHumanoid:LoadAnimation(ReloadAnim)
	end

	if MyMouse then
		-- Disable mouse icon
		MyMouse.Icon = "http://www.roblox.com/asset/?id=18662154"
		MyMouse.Button1Down:connect(OnMouseDown)
		MyMouse.Button1Up:connect(OnMouseUp)
		MyMouse.KeyDown:connect(OnKeyDown)
	end
end


-- Unequip logic here
function OnUnequipped()

	if FPSHandsEnbled then

		local Rig = DetectRigAsync(MyCharacter)

		if Rig == "R15" then
			local WhitelistedBodyParts = {"LeftHand", "LeftLowerArm", "LeftUpperArm", "RightHand", "RightLowerArm", "RightUpperArm"}

			for i, v in pairs(WhitelistedBodyParts) do
				TransparencyConnections[v]:Disconnect()
				TransparencyConnections[v] = nil
			end
		elseif Rig == "R6" then
			local WhitelistedBodyParts = {"Right Arm", "Left Arm"}

			for i, v in pairs(WhitelistedBodyParts) do
				TransparencyConnections[v]:Disconnect()
				TransparencyConnections[v] = nil
			end

		end	

		if AutoFirstPerson then
			MyPlayer.CameraMode = Enum.CameraMode.Classic
			MyPlayer.CameraMinZoomDistance = 9.6
			task.wait(0.02)
			MyPlayer.CameraMinZoomDistance = game:GetService("StarterPlayer").CameraMinZoomDistance
		end
	end

	Handle.UnequipSound:Play()
	Handle.EquipSound:Stop()
	Handle.EquipSound2:Stop()
	LeftButtonDown = false
	flare.MuzzleFlash.Enabled = false
	Reloading = false
	MyCharacter = nil
	MyHumanoid = nil
	MyTorso = nil
	MyPlayer = nil
	MyMouse = nil


	if OnFireConnection then
		OnFireConnection:disconnect()
	end
	if OnReloadConnection then
		OnReloadConnection:disconnect()
	end
	if FlashHolder then
		FlashHolder = nil
	end
	if WeaponGui then
		WeaponGui.Parent = nil
		WeaponGui = nil
	end
	if RecoilTrack then
		RecoilTrack:Stop()
	end
	if ReloadTrack then
		ReloadTrack:Stop()
	end
end

local function SetReticleColor(color)
	if WeaponGui and WeaponGui:FindFirstChild('Crosshair') then
		for _, line in pairs(WeaponGui.Crosshair:GetChildren()) do
			if line:IsA('Frame') then
				line.BorderColor3 = color
			end
		end
	end
end


Tool.Equipped:connect(OnEquipped)
Tool.Unequipped:connect(OnUnequipped)

while true do
	task.wait(0.033)
	if WeaponGui and WeaponGui:FindFirstChild('Crosshair') and MyMouse then
		WeaponGui.Crosshair.Position = UDim2.new(0, MyMouse.X, 0, MyMouse.Y)
		SetReticleColor(NeutralReticleColor)

		local target = MyMouse.Target
		if target and target.Parent then
			local player = PlayersService:GetPlayerFromCharacter(target.Parent)
			if player then
				if MyPlayer.Neutral or player.TeamColor ~= MyPlayer.TeamColor then
					SetReticleColor(EnemyReticleColor)
				else
					SetReticleColor(FriendlyReticleColor)
				end
			end
		end
	end
	if Spread and not IsShooting then
		local currTime = time()
		if currTime - LastSpreadUpdate > FireRate * 2 then
			LastSpreadUpdate = currTime
			Spread = math.max(MinSpread, Spread - AimInaccuracyStepAmount)
			UpdateCrosshair(Spread, MyMouse)
		end
	end
end
