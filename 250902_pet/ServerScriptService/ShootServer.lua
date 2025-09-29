local DebrisService = game:GetService("Debris")
local IconURL = script.Parent.TextureId
local Tool = script.Parent

--------Main Events----------
local Events = Tool:WaitForChild("Events")
local ShootEvent = Events:WaitForChild("ShootRE")
local CreateBulletEvent = Events:WaitForChild("CreateBullet")

-- ⬇️ 무한대기 제거 + 일관된 폴더 생성
do
	local thumb = script.Parent:FindFirstChild("ThumbnailCamera")
	if thumb then thumb:Destroy() end

	-- WaitForChild 대신 FindFirstChild (없으면 그냥 넘어감)
	local readme = script.Parent:FindFirstChild("READ ME")
	if readme then readme:Destroy() end

	-- BulletsFolder 보장 (이름/부모 일관)
	if not workspace:FindFirstChild("BulletsFolder") then
		local f = Instance.new("Folder")
		f.Name = "BulletsFolder"
		f.Parent = workspace
	end
end

function TagHumanoid(humanoid, player)
	if humanoid.Health > 0 then
		while humanoid:FindFirstChild('creator') do
			humanoid:FindFirstChild('creator'):Destroy()
		end
		local creatorTag = Instance.new("ObjectValue")
		creatorTag.Value = player
		creatorTag.Name = "creator"
		creatorTag.Parent = humanoid
		DebrisService:AddItem(creatorTag, 1.5)

		local weaponIconTag = Instance.new("StringValue")
		weaponIconTag.Value = IconURL
		weaponIconTag.Name = "icon"
		weaponIconTag.Parent = creatorTag
	end
end

function CreateBullet(bulletPos)
	-- BulletsFolder 보장 (런타임에서도 혹시 몰라 재확인)
	local bulletsFolder = workspace:FindFirstChild("BulletsFolder")
	if not bulletsFolder then
		bulletsFolder = Instance.new("Folder")
		bulletsFolder.Name = "BulletsFolder"
		bulletsFolder.Parent = workspace
	end

	local bullet = Instance.new('Part')
	bullet.Size = Vector3.new(0.1, 0.1, 0.1)
	bullet.BrickColor = BrickColor.new("Black")
	bullet.Shape = Enum.PartType.Block
	bullet.CanCollide = false
	bullet.CFrame = CFrame.new(bulletPos)
	bullet.Anchored = true -- 레이캐스트 방식 시 시각용이면 그대로 OK
	bullet.TopSurface = Enum.SurfaceType.Smooth
	bullet.BottomSurface = Enum.SurfaceType.Smooth
	bullet.Name = 'Bullet'
	bullet.Parent = bulletsFolder
	DebrisService:AddItem(bullet, 2.5)

	local shell = Instance.new("Part")
	shell.Size = Vector3.new(1,1,1)
	shell.BrickColor = BrickColor.new(226)
	shell.CanCollide = false
	shell.Transparency = 0
	shell.BottomSurface = Enum.SurfaceType.Smooth
	shell.TopSurface = Enum.SurfaceType.Smooth
	shell.Name = "Shell"
	shell.CFrame = Tool.Handle.CFrame
	shell.Velocity = Tool.Handle.CFrame.LookVector * 35 + Vector3.new(math.random(-10,10),20,math.random(-10,20))
	shell.RotVelocity = Vector3.new(0,200,0)
	shell.Parent = bulletsFolder
	DebrisService:AddItem(shell, 1)

	local shellmesh = Instance.new("SpecialMesh")
	shellmesh.Scale = Vector3.new(.15,.4,.15)
	shellmesh.Parent = shell
end

ShootEvent.OnServerEvent:Connect(function(plr, hum, damage)
	if typeof(hum) == "Instance" and hum:IsA("Humanoid") and hum.Health > 0 then
		hum:TakeDamage(tonumber(damage) or 0)
		TagHumanoid(hum, plr)
	end
end)

CreateBulletEvent.OnServerEvent:Connect(function(plr, pos)
	if typeof(pos) == "Vector3" then
		CreateBullet(pos)
	end
end)
