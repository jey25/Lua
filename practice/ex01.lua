-- 체력 감소 스크립트

local Debounce = false

script.Parent.Touched:connect(function(hit)
    if hit.Parent:FindFirstChild("Humanoid") and Debounce == false then
        Debounce = true
        hit.Parent.Humanoid:TakeDamage(10)
        wait(0)
        Debounce = false
    end
end)


-- 시간에 따라 조명 켜기
local timeControl = game.Lighting --timeControl 변수에 조명(Lighting) 속성 담기
local timeVal = 12 --timeVal 변수에 12 담기

local brick = game.Workspace.ShiningBrick --brick 변수에 ShiningBrick 파트 담기

while true do --while문 조건을 참(true)으로 고정, 무한 반복
    timeControl.ClockTime = timeVal --현재 시간을 timeVal 값으로 변경
    print(timeVal) --imeVal에 저장된 값 출력
    wait(2) --2초 쉬기

    if timeVal == 25 then --if문 설정 조건 - timeVal이 25와 같으면 참
        timeVal = 0 --조건이 참이면 timeVal의 값을 0으로 변경
    end

    if timeVal > 18 then --if문 설정 조건1 - timeVal이 18보다 크면 참
        brick.Material = "Neon" --조건1이 참이면 ShiningPart의 재질(Material)을 네온(Neon)으로 변경
    elseif timeVal < 7 then --elseif문 설정 조건2 - timeVal이 7보다 작으면 참
        brick.Material = "Neon" --조건2가 참이면 ShiningPart의 재질(Material)을 네온(Neon)으로 변경
    else
        --조건1과 조건2가 모두 거짓이면 ShiningPart의 재질(Material)을 플라스틱(Plastic)으로 변경
        brick.Material = "Plastic"
    end

    timeVal = timeVal + 1 --timeVal 값에 1을 더한 후 timeVal 변수에 저장
end


-- bgm 버튼 넣기

local button = script.Parent
local on = script.Parent:WaitForChild("on")
local off = script.Parent:WaitForChild("off")

local Sound = Instance.new("Sound", script)

Sound.Volume = 0.5 -- 볼륨


musics = { "rbxassetid://1845385270", -- 음악 목록(아이디)
    "rbxassetid://1840265649",
    "rbxassetid://1846459727"

}


function playNewMusic()
    Sound:Stop()
    Sound.SoundId = musics[math.random(1, #musics)]
    Sound.Loaded:Wait() -- 바꾼 음악 아이디 로딩 대기
    Sound:Play()
end

button.MouseButton1Click:Connect(function(plr)
    if Sound.IsPlaying then -- 음악 켜져있었음(정석 방법으로 바꿈)
        off.Visible = true
        on.Visible = false
        Sound:Pause() -- 일시정지
    else -- 음악 꺼져있었음
        off.Visible = false
        on.Visible = true
        Sound:Resume() -- 다시 재생
    end
end)

Sound.Ended:Connect(function()
    if on.Visible then -- 여긴 그대로(음악은 끝까지 플레이 후 꺼진 상태라서)
        playNewMusic()
    end
end)

playNewMusic()


-- 시간 GUI

local minute = ('분')
local second = ('초')

while true do
    if minute == 0 then
        script.Parent.Text = second .. "초"
    else
        script.Parent.Text = minute .. "분" .. second .. "초"
    end

    if second == 0 then
        minute = minute - 1
        second = 60
    end

    second = second - 1

    wait(1)
end


-- 체력바 스크립트

wait(0.2)
while true do
    local hp = game.Players.LocalPlayer.Character.Humanoid.Health / 100
    script.Parent:TweenSize((UDim2.new(hp, 0, 1, 0)), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15)
    wait(0.2)
end


-----닿으면 죽는 스크립트-----
local function onTouch(part)
    local humanoid = part.Parent:FindFirstChild("Humanoid")
    if (humanoid) then
        humanoid.Health = 0
    end
end

script.Parent.Touched:connect(onTouch)


-----피 조금 닳는 스크립트-----
local Debounce = false

script.Parent.Touched:connect(function(hit)
    if hit.Parent:FindFirstChild("Humanoid") and Debounce == false then
        Debounce = true
        hit.Parent.Humanoid:TakeDamage(10)
        wait(0)
        Debounce = false
    end
end)


-------- 피 회복 스크립트 ---------
local function onTouch(part)
    local humanoid = part.Parent:FindFirstChild("Humanoid")
    if (humanoid) then
        humanoid.Health = 100
    end
end

script.Parent.Touched:connect(onTouch)



-- 밟으면 시작되는 타이머, 다른 파트를 밟으면 끝나는 타이머
local start = game.Workspace.ggl
local stop = game.Workspace.asd
local time_label = script.Parent
local LPlayer = game.Players.LocalPlayer
local jero = 0
local timer_started = false
local completed = false

time_label.Visible = false

local function start_timer(otherPart)

    local player = game.Players:FindFirstChild(otherPart.Parent.Name)

    if player.Name == LPlayer.Name and not timer_started then
        timer_started = true
        time_label.Text = jero
        player.PlayerGui.Scree.TextLabel.Visible = true

        local time_num = tonumber(player.PlayerGui.Scree.TextLabel.Text)

        while time_num < 1000000 do
            wait(0.1)
            time_num = time_num + 0.1
            player.PlayerGui.Scree.TextLabel.Text = tostring(time_num)
        end

        timer_started = false
        completed = false
        player.PlayerGui.Scree.TextLabel.Text = jero
    end
end

local function finish_timer(otherPart)
    local player = game.Players:FindFirstChild(otherPart.Parent.Name)
    if player.Name == LPlayer.Name then
        player.PlayerGui.Scree.TextLabel.Visible = false
        completed = true
    end
end

start.Touched:Connect(start_timer)
stop.Touched:Connect(finish_timer)


------------------------------------------------------
-- 파트를 밟으면 서버 메시지가 뜬다

--스크립트1
local TouchEvent = game.ReplicatedStorage.Touched

script.Parent.Touched:Connect(function(hit)
    local Human = hit.Parent:FindFirstChild("Humanoid")
    if Human then
        TouchEvent:FireAllClients(hit)
    end
end)
--스크립트끝

--스크립트2
local Message = " 님이 정상에 도착하였습니다!"

game.ReplicatedStorage.Touched.OnClientEvent:Connect(function(hit)
    local Name = hit.Parent.Name

    if script.Value.Value ~= Name then
        for _, plr in pairs(game.Players:GetChildren()) do
            if plr.PlayerGui.TouchedGui.TextLabel.Visible == false then
                plr.PlayerGui.TouchedGui.TextLabel.Visible = true
                plr.PlayerGui.TouchedGui.TextLabel.Text = Name .. Message
                plr.PlayerGui.TouchedGui.TextLabel:TweenPosition(UDim2.new(0.047, 0, 0.063, 0))
                wait(3)
                plr.PlayerGui.TouchedGui.TextLabel:TweenPosition(UDim2.new(-0.9, 0, 0.029, 0))
                script.Value.Value = Name
                wait(2)
                plr.PlayerGui.TouchedGui.TextLabel.Visible = false
            end
        end
    end
end)

------------------------------------------------------------------------

-- 게임에 배경음악 버튼 넣기

버튼
스크립트(수정)
local button = script.Parent
local on = script.Parent:WaitForChild("on")
local off = script.Parent:WaitForChild("off")

local Sound = Instance.new("Sound", script)

Sound.Volume = 0.5 -- 볼륨

musics = { "rbxassetid://1845385270", -- 음악 목록(아이디)
    "rbxassetid://1840265649",
    "rbxassetid://1846459727"

}


function playNewMusic()
    Sound:Stop()
    Sound.SoundId = musics[math.random(1, #musics)]
    Sound.Loaded:Wait() -- 바꾼 음악 아이디 로딩 대기
    Sound:Play()
end

button.MouseButton1Click:Connect(function(plr)
    if Sound.IsPlaying then -- 음악 켜져있었음(정석 방법으로 바꿈)
        off.Visible = true
        on.Visible = false
        Sound:Pause() -- 일시정지
    else -- 음악 꺼져있었음
        off.Visible = false
        on.Visible = true
        Sound:Resume() -- 다시 재생
    end
end)

Sound.Ended:Connect(function()
    if on.Visible then -- 여긴 그대로(음악은 끝까지 플레이 후 꺼진 상태라서)
        playNewMusic()
    end
end)

playNewMusic()



-- 시스템 메시지 띄우기

local System = "[System] "

local Message = "안녕하세요"

local Waiter = 5

local TextSizes = 18


while wait(Waiter) do
    game.StarterGui:SetCore("ChatMakeSystemMessage",
        {
            Text = System .. Message,
            Color = Color3.fromRGB(0, 0, 255),
            TextSize = TextSizes,
        })
end

-- 랜덤 시스템 메시지 띄우기

local System = "[System] "
local Message =
{
    "안녕하세요",
    "플레이 해주셔서 감사합니다.",
    "즐거운 시간 보내세요",
}

local Waiter = 5
local TextSizes = 18



while wait(Waiter) do
    game.StarterGui:SetCore("ChatMakeSystemMessage",
        {
            Text = System .. Message[math.random(1, #Message)],
            Color = Color3.fromRGB(0, 0, 255),
            TextSize = TextSizes,
        })
end


-- 닿으면 체력이 떨어지는 블록


local box = script.Parent

local function onTouched(hit)
    print("Touched")

    local humanoid = hit.Parent:FindFirstChild('Humanoid')
    if humanoid then
        print(humanoid.health)
        humanoid:TakeDamage(10)
    end
end

box.Touched:Connect(onTouched)


--서비스 목록 확인 스크립트

local services = {}

for _, service in ipairs(game:GetChildren()) do
    local success, result = pcall(function()
        table.insert(services, service.Name)
    end)
end

table.sort(services)

for _, service in ipairs(services) do
    print(service)
end



-- 플레이어 충돌 없애주는 스크립트

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local playerCollisionGroupName = "Players"
PhysicsService:CreateCollisionGroup(playerCollisionGroupName)
PhysicsService:CollisionGroupSetCollidable(playerCollisionGroupName, playerCollisionGroupName, false)

local previousCollisionGroups = {}

local function setCollisionGroup(object)
    if object:IsA("BasePart") then
        previousCollisionGroups[object] = object.CollisionGroupId
        PhysicsService:SetPartCollisionGroup(object, playerCollisionGroupName)
    end
end

local function setCollisionGroupRecursive(object)
    setCollisionGroup(object)

    for _, child in ipairs(object:GetChildren()) do
        setCollisionGroupRecursive(child)
    end
end

local function resetCollisionGroup(object)
    local previousCollisionGroupId = previousCollisionGroups[object]
    if not previousCollisionGroupId then return end

    local previousCollisionGroupName = PhysicsService:GetCollisionGroupName(previousCollisionGroupId)
    if not previousCollisionGroupName then return end

    PhysicsService:SetPartCollisionGroup(object, previousCollisionGroupName)
    previousCollisionGroups[object] = nil
end

local function onCharacterAdded(character)
    setCollisionGroupRecursive(character)


    character.DescendantAdded:Connect(setCollisionGroup)
    character.DescendantRemoving:Connect(resetCollisionGroup)
end

local function onPlayerAdded(player)
    player.CharacterAdded:Connect(onCharacterAdded)
end

Players.PlayerAdded:Connect(onPlayerAdded)


-- Mouselockcontroller

--!nonstrict
--[[
	MouseLockController - Replacement for ShiftLockController, manages use of mouse-locked mode
	2018 Camera Update - AllYourBlox
--]]

--[[ Constants ]]--
local DEFAULT_MOUSE_LOCK_CURSOR = "rbxasset://textures/MouseLockedCursor.png"

local CONTEXT_ACTION_NAME = "MouseLockSwitchAction"
local MOUSELOCK_ACTION_PRIORITY = Enum.ContextActionPriority.Default.Value

--[[ Services ]]--
local PlayersService = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local Settings = UserSettings()	-- ignore warning
local GameSettings = Settings.GameSettings

--[[ Imports ]]
local CameraUtils = require(script.Parent:WaitForChild("CameraUtils"))

--[[ The Module ]]--
local MouseLockController = {}
MouseLockController.__index = MouseLockController

function MouseLockController.new()
	local self = setmetatable({}, MouseLockController)

	self.isMouseLocked = false
	self.savedMouseCursor = nil
	self.boundKeys = {Enum.KeyCode.LeftControl, Enum.KeyCode.RightShift} -- defaults

	self.mouseLockToggledEvent = Instance.new("BindableEvent")

	local boundKeysObj = script:FindFirstChild("BoundKeys")
	if (not boundKeysObj) or (not boundKeysObj:IsA("StringValue")) then
		-- If object with correct name was found, but it's not a StringValue, destroy and replace
		if boundKeysObj then
			boundKeysObj:Destroy()
		end

		boundKeysObj = Instance.new("StringValue")
		-- Luau FIXME: should be able to infer from assignment above that boundKeysObj is not nil
		assert(boundKeysObj, "")
		boundKeysObj.Name = "BoundKeys"
		boundKeysObj.Value = "LeftControl,RightShift"
		boundKeysObj.Parent = script
	end

	if boundKeysObj then
		boundKeysObj.Changed:Connect(function(value)
			self:OnBoundKeysObjectChanged(value)
		end)
		self:OnBoundKeysObjectChanged(boundKeysObj.Value) -- Initial setup call
	end

	-- Watch for changes to user's ControlMode and ComputerMovementMode settings and update the feature availability accordingly
	GameSettings.Changed:Connect(function(property)
		if property == "ControlMode" or property == "ComputerMovementMode" then
			self:UpdateMouseLockAvailability()
		end
	end)

	-- Watch for changes to DevEnableMouseLock and update the feature availability accordingly
	PlayersService.LocalPlayer:GetPropertyChangedSignal("DevEnableMouseLock"):Connect(function()
		self:UpdateMouseLockAvailability()
	end)

	-- Watch for changes to DevEnableMouseLock and update the feature availability accordingly
	PlayersService.LocalPlayer:GetPropertyChangedSignal("DevComputerMovementMode"):Connect(function()
		self:UpdateMouseLockAvailability()
	end)

	self:UpdateMouseLockAvailability()

	return self
end

function MouseLockController:GetIsMouseLocked()
	return self.isMouseLocked
end

function MouseLockController:GetBindableToggleEvent()
	return self.mouseLockToggledEvent.Event
end

function MouseLockController:GetMouseLockOffset()
	local offsetValueObj: Vector3Value = script:FindFirstChild("CameraOffset") :: Vector3Value
	if offsetValueObj and offsetValueObj:IsA("Vector3Value") then
		return offsetValueObj.Value
	else
		-- If CameraOffset object was found but not correct type, destroy
		if offsetValueObj then
			offsetValueObj:Destroy()
		end
		offsetValueObj = Instance.new("Vector3Value")
		assert(offsetValueObj, "")
		offsetValueObj.Name = "CameraOffset"
		offsetValueObj.Value = Vector3.new(1.75,0,0) -- Legacy Default Value
		offsetValueObj.Parent = script
	end

	if offsetValueObj and offsetValueObj.Value then
		return offsetValueObj.Value
	end

	return Vector3.new(1.75,0,0)
end

function MouseLockController:UpdateMouseLockAvailability()
	local devAllowsMouseLock = PlayersService.LocalPlayer.DevEnableMouseLock
	local devMovementModeIsScriptable = PlayersService.LocalPlayer.DevComputerMovementMode == Enum.DevComputerMovementMode.Scriptable
	local userHasMouseLockModeEnabled = GameSettings.ControlMode == Enum.ControlMode.MouseLockSwitch
	local userHasClickToMoveEnabled =  GameSettings.ComputerMovementMode == Enum.ComputerMovementMode.ClickToMove
	local MouseLockAvailable = devAllowsMouseLock and userHasMouseLockModeEnabled and not userHasClickToMoveEnabled and not devMovementModeIsScriptable

	if MouseLockAvailable~=self.enabled then
		self:EnableMouseLock(MouseLockAvailable)
	end
end

function MouseLockController:OnBoundKeysObjectChanged(newValue: string)
	self.boundKeys = {} -- Overriding defaults, note: possibly with nothing at all if boundKeysObj.Value is "" or contains invalid values
	for token in string.gmatch(newValue,"[^%s,]+") do
		for _, keyEnum in pairs(Enum.KeyCode:GetEnumItems()) do
			if token == keyEnum.Name then
				self.boundKeys[#self.boundKeys+1] = keyEnum :: Enum.KeyCode
				break
			end
		end
	end
	self:UnbindContextActions()
	self:BindContextActions()
end

--[[ Local Functions ]]--
function MouseLockController:OnMouseLockToggled()
	self.isMouseLocked = not self.isMouseLocked

	if self.isMouseLocked then
		local cursorImageValueObj: StringValue? = script:FindFirstChild("CursorImage") :: StringValue?
		if cursorImageValueObj and cursorImageValueObj:IsA("StringValue") and cursorImageValueObj.Value then
			CameraUtils.setMouseIconOverride(cursorImageValueObj.Value)
		else
			if cursorImageValueObj then
				cursorImageValueObj:Destroy()
			end
			cursorImageValueObj = Instance.new("StringValue")
			assert(cursorImageValueObj, "")
			cursorImageValueObj.Name = "CursorImage"
			cursorImageValueObj.Value = DEFAULT_MOUSE_LOCK_CURSOR
			cursorImageValueObj.Parent = script
			CameraUtils.setMouseIconOverride(DEFAULT_MOUSE_LOCK_CURSOR)
		end
	else
		CameraUtils.restoreMouseIcon()
	end

	self.mouseLockToggledEvent:Fire()
end

function MouseLockController:DoMouseLockSwitch(name, state, input)
	if state == Enum.UserInputState.Begin then
		self:OnMouseLockToggled()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

function MouseLockController:BindContextActions()
	ContextActionService:BindActionAtPriority(CONTEXT_ACTION_NAME, function(name, state, input)
		return self:DoMouseLockSwitch(name, state, input)
	end, false, MOUSELOCK_ACTION_PRIORITY, unpack(self.boundKeys))
end

function MouseLockController:UnbindContextActions()
	ContextActionService:UnbindAction(CONTEXT_ACTION_NAME)
end

function MouseLockController:IsMouseLocked(): boolean
	return self.enabled and self.isMouseLocked
end

function MouseLockController:EnableMouseLock(enable: boolean)
	if enable ~= self.enabled then

		self.enabled = enable

		if self.enabled then
			-- Enabling the mode
			self:BindContextActions()
		else
			-- Disabling
			-- Restore mouse cursor
			CameraUtils.restoreMouseIcon()

			self:UnbindContextActions()

			-- If the mode is disabled while being used, fire the event to toggle it off
			if self.isMouseLocked then
				self.mouseLockToggledEvent:Fire()
			end

			self.isMouseLocked = false
		end

	end
end

return MouseLockController


--ban Chat 설정
local plr = game.Players.LocalPlayer --플레이어 구하기
local event = game.ReplicatedStorage:WaitForChild("BanEvent") --리모트 이벤트 구하기
local banChat = {}

plr.Chatted:Connect(function(chat) --플레이어 채팅 감지
 for i = 1, #banChat do --단어 감지를 위한 반복문
  local findChat = chat:find(banChat[i]) --banchat에 적혀있는 단어가 들어가 있는지 감지

  if findChat then --금지어가 감지되면
   event:FireServer(banChat[i]) --리모트 이벤트로 메세지를 보낸다
  end
 end
end) --끝




-- 서버스크립트:
local datastore = game:GetService("DataStoreService") --데이터 저장 서비스
local data = datastore:GetDataStore("banplayer") --데이터 저장소 생성

game.Players.PlayerAdded:Connect(function(plr) --플레이어가 접속했을 때
 local ban

 local s, e = pcall(function() --데이터 불러오기 실패할때를 대비해 오류방지
  ban = data:GetAsync(plr.UserId.."Player") --밴 데이터 확인
 end)

 if ban == true then --데이터가 있으면 밴 (없으면 넘김)
  plr:Kick("당신은 밴입니다.")
 end
end) --끝


game.ReplicatedStorage.BanEvent.OnServerEvent:Connect(function(plr, chat) --리모트 이벤트에서 메세지가 왔을 때
	local s, e = pcall(function() --데이터 저장을 실패할 때 대비해 오류방지
		data:SetAsync(plr.UserId.."Player", true) --밴 데이터 저장
	end)

	plr:Kick("금지어[ "..chat.." ]을(를) 사용하여 밴 당했습니다.") --밴(정확히는 킥(데이터가 저장되어 밴이랑 같음))
end)

-- 컨베이어 파트
while wait() do
	script.Parent.Velocity = Vector3.new(-20, 0, 0)
end

-- 상점의 X 버튼 Script
script.Parent.MouseButton1Click:Connect(function()
	script.Parent.Parent:TweenPosition(
		UDim2.new(0.205, 0,1.1, 0),
		"Out",
		"Quad",
		0.5	
	)
end)

-- 상점의 리더보드 텍스트
while wait(0.1) do -- 0.1초에 한번씩 반복
	script.Parent.Text = "Coin : "..game.Players.LocalPlayer.leaderstats.Points.Value -- "Coin" 에 자신의 리더보드 이름적기
end -- 끝(다시반복)

-- 상점의 Buy 버튼에 넣어주는 Local Script
local Price = 500
local Item = script.Parent.Parent.Parent.ItemName.Text

local Event = game.ReplicatedStorage:WaitForChild("ItemBuy")

script.Parent.MouseButton1Click:Connect(function()
	Event:FireServer(Item, Price)
	script.Parent.Parent.Visible = false
end)



--피 회복 스크립트
local yellot = script.Parent 
local function Health(part)
 local parent = part.Parent
 if game.Players:GetPlayerFromCharacter(parent) then
  parent.Humanoid.Health = parent.Humanoid.Health + 100
  wait(1)
 end
end

yellot.Touched:connect(Health)
--스크립트 끝



-- mouselockcontroller

--[[
	MouseLockController - Replacement for ShiftLockController, manages use of mouse-locked mode
	2018 Camera Update - AllYourBlox
--]]

--[[ Constants ]]--
local DEFAULT_MOUSE_LOCK_CURSOR = "rbxasset://textures/MouseLockedCursor.png"

local CONTEXT_ACTION_NAME = "MouseLockSwitchAction"
local MOUSELOCK_ACTION_PRIORITY = Enum.ContextActionPriority.Default.Value

--[[ Services ]]--
local PlayersService = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local Settings = UserSettings()	-- ignore warning
local GameSettings = Settings.GameSettings

--[[ Imports ]]
local CameraUtils = require(script.Parent:WaitForChild("CameraUtils"))

--[[ The Module ]]--
local MouseLockController = {}
MouseLockController.__index = MouseLockController

function MouseLockController.new()
	local self = setmetatable({}, MouseLockController)

	self.isMouseLocked = false
	self.savedMouseCursor = nil
	self.boundKeys = {Enum.KeyCode.LeftControl, Enum.KeyCode.RightShift} -- defaults

	self.mouseLockToggledEvent = Instance.new("BindableEvent")

	local boundKeysObj = script:FindFirstChild("BoundKeys")
	if (not boundKeysObj) or (not boundKeysObj:IsA("StringValue")) then
		-- If object with correct name was found, but it's not a StringValue, destroy and replace
		if boundKeysObj then
			boundKeysObj:Destroy()
		end

		boundKeysObj = Instance.new("StringValue")
		-- Luau FIXME: should be able to infer from assignment above that boundKeysObj is not nil
		assert(boundKeysObj, "")
		boundKeysObj.Name = "BoundKeys"
		boundKeysObj.Value = "LeftControl,RightShift"
		boundKeysObj.Parent = script
	end

	if boundKeysObj then
		boundKeysObj.Changed:Connect(function(value)
			self:OnBoundKeysObjectChanged(value)
		end)
		self:OnBoundKeysObjectChanged(boundKeysObj.Value) -- Initial setup call
	end

	-- Watch for changes to user's ControlMode and ComputerMovementMode settings and update the feature availability accordingly
	GameSettings.Changed:Connect(function(property)
		if property == "ControlMode" or property == "ComputerMovementMode" then
			self:UpdateMouseLockAvailability()
		end
	end)

	-- Watch for changes to DevEnableMouseLock and update the feature availability accordingly
	PlayersService.LocalPlayer:GetPropertyChangedSignal("DevEnableMouseLock"):Connect(function()
		self:UpdateMouseLockAvailability()
	end)

	-- Watch for changes to DevEnableMouseLock and update the feature availability accordingly
	PlayersService.LocalPlayer:GetPropertyChangedSignal("DevComputerMovementMode"):Connect(function()
		self:UpdateMouseLockAvailability()
	end)

	self:UpdateMouseLockAvailability()

	return self
end

function MouseLockController:GetIsMouseLocked()
	return self.isMouseLocked
end

function MouseLockController:GetBindableToggleEvent()
	return self.mouseLockToggledEvent.Event
end

function MouseLockController:GetMouseLockOffset()
	local offsetValueObj: Vector3Value = script:FindFirstChild("CameraOffset") :: Vector3Value
	if offsetValueObj and offsetValueObj:IsA("Vector3Value") then
		return offsetValueObj.Value
	else
		-- If CameraOffset object was found but not correct type, destroy
		if offsetValueObj then
			offsetValueObj:Destroy()
		end
		offsetValueObj = Instance.new("Vector3Value")
		assert(offsetValueObj, "")
		offsetValueObj.Name = "CameraOffset"
		offsetValueObj.Value = Vector3.new(1.75,0,0) -- Legacy Default Value
		offsetValueObj.Parent = script
	end

	if offsetValueObj and offsetValueObj.Value then
		return offsetValueObj.Value
	end

	return Vector3.new(1.75,0,0)
end

function MouseLockController:UpdateMouseLockAvailability()
	local devAllowsMouseLock = PlayersService.LocalPlayer.DevEnableMouseLock

	local devMovementModeIsScriptable = PlayersService.LocalPlayer.DevComputerMovementMode == Enum.DevComputerMovementMode.Scriptable

	local userHasMouseLockModeEnabled = GameSettings.ControlMode == Enum.ControlMode.MouseLockSwitch

	local userHasClickToMoveEnabled =  GameSettings.ComputerMovementMode == Enum.ComputerMovementMode.ClickToMove

	local MouseLockAvailable = devAllowsMouseLock and userHasMouseLockModeEnabled and not userHasClickToMoveEnabled and not devMovementModeIsScriptable

	if MouseLockAvailable~=self.enabled then
		self:EnableMouseLock(MouseLockAvailable)
	end
end

function MouseLockController:OnBoundKeysObjectChanged(newValue: string)
	self.boundKeys = {} -- Overriding defaults, note: possibly with nothing at all if boundKeysObj.Value is "" or contains invalid values
	for token in string.gmatch(newValue,"[^%s,]+") do
		for _, keyEnum in pairs(Enum.KeyCode:GetEnumItems()) do
			if token == keyEnum.Name then
				self.boundKeys[#self.boundKeys+1] = keyEnum :: Enum.KeyCode
				break
			end
		end
	end
	self:UnbindContextActions()
	self:BindContextActions()
end


--[[ Local Functions ]]--

function MouseLockController:OnMouseLockToggled()
	self.isMouseLocked = not self.isMouseLocked

	if self.isMouseLocked then
		local cursorImageValueObj: StringValue? = script:FindFirstChild("CursorImage") :: StringValue?
		if cursorImageValueObj and cursorImageValueObj:IsA("StringValue") and cursorImageValueObj.Value then
			CameraUtils.setMouseIconOverride(cursorImageValueObj.Value)
		else
			if cursorImageValueObj then
				cursorImageValueObj:Destroy()
			end
			cursorImageValueObj = Instance.new("StringValue")
			assert(cursorImageValueObj, "")
			cursorImageValueObj.Name = "CursorImage"
			cursorImageValueObj.Value = DEFAULT_MOUSE_LOCK_CURSOR
			cursorImageValueObj.Parent = script
			CameraUtils.setMouseIconOverride(DEFAULT_MOUSE_LOCK_CURSOR)
		end
	else
		CameraUtils.restoreMouseIcon()
	end

	self.mouseLockToggledEvent:Fire()
end


function MouseLockController:DoMouseLockSwitch(name, state, input)
	if state == Enum.UserInputState.Begin then
		self:OnMouseLockToggled()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

function MouseLockController:BindContextActions()
	ContextActionService:BindActionAtPriority(CONTEXT_ACTION_NAME, function(name, state, input)
		return self:DoMouseLockSwitch(name, state, input)
	end, false, MOUSELOCK_ACTION_PRIORITY, unpack(self.boundKeys))
end


function MouseLockController:UnbindContextActions()
	ContextActionService:UnbindAction(CONTEXT_ACTION_NAME)
end


function MouseLockController:IsMouseLocked(): boolean
	return self.enabled and self.isMouseLocked
end


function MouseLockController:EnableMouseLock(enable: boolean)
	if enable ~= self.enabled then

		self.enabled = enable

		if self.enabled then
			-- Enabling the mode
			self:BindContextActions()
		else
			-- Disabling
			-- Restore mouse cursor
			CameraUtils.restoreMouseIcon()

			self:UnbindContextActions()

			-- If the mode is disabled while being used, fire the event to toggle it off
			if self.isMouseLocked then
				self.mouseLockToggledEvent:Fire()
			end

			self.isMouseLocked = false
		end

	end
end

return MouseLockController

--데미지 스크립트
script.Parent.Handle.Sword.Touched:Connect(function(hit)
    
    local h = hit.Parent:FindFirstChild("Humanoid")
    if h then
     h:TakeDamage(50)
    end
   end)

   --애니메이션 스크립트
local f = false

script.Parent.Activated:Connect (function()

 if not f then
  f = true
  local YAnimation = game.Players.LocalPlayer.Character.Humanoid:LoadAnimation(script.Parent.Animation)
  YAnimation:Play()
  wait(0.7)
  f = false

 end
end)
--스크립트끝

-- 동상 춤추기 스크립트
local id = 000000000
game.InsertService:LoadAsset(id).Parent = game.Lighting

local Humanoid = script.Parent:WaitForChild("Humanoid")
Humanoid:LoadAnimation(script.Parent.Animation):Play()
-- 스크립트 끝

--탈수 없는 회전 블럭 스크립트
while true do 
    wait()
    script.Parent.CFrame = script.Parent.CFrame * CFrame.fromEulerAnglesXYZ(0.1,0,0)
    end 
--스크립트끝

-- Jump Coil
local Players                     = game:GetService("Players")
local Tool                        = script.Parent

local GravityAccelerationConstant = 9.81 * 20 -- For every 20 studs is one meter on ROBLOX. 9.81 is the common accepted acceleration of gravity per a kg on earth, and is used on ROBLOX
local PercentGravity              = 0.25      -- Percentage of countered acceleration due to gravity by the coil. 

-- @author Quenty
-- A rewritten gravity coil script designed for understanding and reliability

local function WaitForChild(Parent, Name, TimeLimit)
	-- Waits for a child to appear. Not efficient, but it shoudln't have to be. It helps with debugging. 
	-- Useful when ROBLOX lags out, and doesn't replicate quickly.
	-- @param TimeLimit If TimeLimit is given, then it will return after the timelimit, even if it hasn't found the child.

	assert(Parent ~= nil, "Parent is nil")
	assert(type(Name) == "string", "Name is not a string.")

	local Child     = Parent:FindFirstChild(Name)
	local StartTime = tick()
	local Warned    = false

	while not Child and Parent do
		wait(0)
		Child = Parent:FindFirstChild(Name)
		if not Warned and StartTime + (TimeLimit or 5) <= tick() then
			Warned = true
			warn("Infinite yield possible for WaitForChild(" .. Parent:GetFullName() .. ", " .. Name .. ")")
			if TimeLimit then
				return Parent:FindFirstChild(Name)
			end
		end
	end

	if not Parent then
		warn("Parent became nil.")
	end

	return Child
end


local function CallOnChildren(Instance, FunctionToCall)
	-- Calls a function on each of the children of a certain object, using recursion.  

	FunctionToCall(Instance)

	for _, Child in next, Instance:GetChildren() do
		CallOnChildren(Child, FunctionToCall)
	end
end

local function GetBricks(StartInstance)
	-- Returns a list of bricks (will include StartInstance)

	local List = {}

	CallOnChildren(StartInstance, function(Item)
		if Item:IsA("BasePart") then
			List[#List+1] = Item;
		end
	end)

	return List
end

--[[Maid
Manages the cleaning of events and other things.
 
API:
	HireMaid()                        Returns a new Maid object.
 
	Maid[key] = (function)            Adds a task to perform when cleaning up.
	Maid[key] = (event connection)    Manages an event connection. Anything that isn't a function is assumed to be this.
	Maid[key] = nil                   Removes a named task. If the task is an event, it is disconnected.
 
	Maid:GiveTask(task)               Same as above, but uses an incremented number as a key.
	Maid:DoCleaning()                 Disconnects all managed events and performs all clean-up tasks.
]]
local MakeMaid do
	local index = {
		GiveTask = function(self, task)
			local n = #self.Tasks+1
			self.Tasks[n] = task
			return n
		end;
		DoCleaning = function(self)
			local tasks = self.Tasks
			for name,task in pairs(tasks) do
				if type(task) == 'function' then
					task()
				else
					task:disconnect()
				end
				tasks[name] = nil
			end
			-- self.Tasks = {}
		end;
	};

	local mt = {
		__index = function(self, k)
			if index[k] then
				return index[k]
			else
				return self.Tasks[k]
			end
		end;
		__newindex = function(self, k, v)
			local tasks = self.Tasks
			if v == nil then
				-- disconnect if the task is an event
				if type(tasks[k]) ~= 'function' and tasks[k] then
					tasks[k]:disconnect()
				end
			elseif tasks[k] then
				-- clear previous task
				self[k] = nil
			end
			tasks[k] = v
		end;
	}

	function MakeMaid()
		return setmetatable({Tasks={},Instances={}},mt)
	end
end

local function GetCharacter(Descendant)
	-- Returns the Player and Charater that a descendent is part of, if it is part of one.
	-- @param Descendant A child of the potential character. 

	local Charater = Descendant
	local Player   = Players:GetPlayerFromCharacter(Charater)

	while not Player do
		if Charater.Parent then
			Charater = Charater.Parent
			Player   = Players:GetPlayerFromCharacter(Charater)
		else
			return nil
		end
	end

	-- Found the player, character must be true.
	return Charater, Player
end

--- Load and create constants
local AntiGravityForce      = Instance.new("BodyForce")
AntiGravityForce.Name       = "GravityCoilEffect"
AntiGravityForce.Archivable = false

local Handle           = WaitForChild(Tool, "Handle")
local CoilSound        = WaitForChild(Handle, "CoilSound")
local GravityMaid      = MakeMaid() -- Will contain and maintain events

local function UpdateGravityEffect(Character)
	-- Updates the AntiGravityForce to match the force of gravity on the character

	local Bricks
	if Character:IsDescendantOf(game) and Character:FindFirstChild("HumanoidRootPart") and Character.HumanoidRootPart:IsA("BasePart") then
		local BasePart = Character.HumanoidRootPart
		Bricks         = BasePart:GetConnectedParts(true) -- Recursive
	else
		warn("[UpdateGravityEffect] - Character failed to have a HumanoidRootPart or something")
		Bricks = GetBricks(Character)
	end

	local TotalMass = 0

	-- Calculate total mass of player
	for _, Part in pairs(Bricks) do
		TotalMass = TotalMass + Part:GetMass()
	end

	-- Force = Mass * Acceleration
	local ForceOnCharacter         = GravityAccelerationConstant * TotalMass
	local CounteringForceMagnitude = (1 - 0.25) * ForceOnCharacter

	-- Set the actual value...
	AntiGravityForce.force = Vector3.new(0, CounteringForceMagnitude, 0)
end


-- Connect events for player interaction
Tool.Equipped:connect(function()
	local Character, Player = GetCharacter(Tool)

	if Character then
		-- Connect events to recalculate gravity when hats are added or removed. Of course, this is not a perfect solution,
		-- as connected parts are not necessarily part of the character, but ROBLOX has no API to handle the changing of joints, and
		-- scanning the whole game for potential joints is really not worth the efficiency cost. 
		GravityMaid.DescendantAddedConnection = Character.DescendantAdded:connect(function()
			UpdateGravityEffect(Character)
		end)

		GravityMaid.DecendantRemovingConnection = Character.DescendantRemoving:connect(function()
			UpdateGravityEffect(Character)
		end)

		UpdateGravityEffect(Character)
		-- Add in the force
		AntiGravityForce.Parent = Handle
	else
		warn("[GravityCoil] - Somehow inexplicity failed to retrieve character")
	end
end)

Tool.Unequipped:connect(function()
	-- Remove force and clean up events
	AntiGravityForce.Parent = nil
	GravityMaid:DoCleaning()
end)


--캐릭터 서로 통과하게 만드는 스크립트

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local playerCollisionGroupName = "Players"
PhysicsService:CreateCollisionGroup(playerCollisionGroupName)
PhysicsService:CollisionGroupSetCollidable(playerCollisionGroupName, playerCollisionGroupName, false)

local previousCollisionGroups = {}

local function setCollisionGroup(object)
 if object:IsA("BasePart") then
  previousCollisionGroups[object] = object.CollisionGroupId
  PhysicsService:SetPartCollisionGroup(object, playerCollisionGroupName)
 end
end

local function setCollisionGroupRecursive(object)
 setCollisionGroup(object)

 for _, child in ipairs(object:GetChildren()) do
  setCollisionGroupRecursive(child)
 end
end

local function resetCollisionGroup(object)
 local previousCollisionGroupId = previousCollisionGroups[object]
 if not previousCollisionGroupId then return end 

 local previousCollisionGroupName = PhysicsService:GetCollisionGroupName(previousCollisionGroupId)
 if not previousCollisionGroupName then return end

 PhysicsService:SetPartCollisionGroup(object, previousCollisionGroupName)
 previousCollisionGroups[object] = nil
end

local function onCharacterAdded(character)
 setCollisionGroupRecursive(character)

 character.DescendantAdded:Connect(setCollisionGroup)
 character.DescendantRemoving:Connect(resetCollisionGroup)
end

local function onPlayerAdded(player)
 player.CharacterAdded:Connect(onCharacterAdded)
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- 스크립트 끝


-- 게임에 적용되어 있는 Service 들을 볼수 있는 Script
local services = {
	
}

for _, service in ipairs(game:GetChildren()) do
	local success, result = pcall(function()
		table.insert(services, service.Name)
	end)
end

table.sort(services)

for _, service in ipairs(services) do
	print(service)
end

-- 로블록스 서비스 목록

--AdService - AdService는 게임 수익 창출을 위한 모바일 비디오 광고를 게임에 넣을수 있었던 서비스. 현재는 사용할수 없는 기능
--AnalyticsService - 게임내 각종 통계를 확인 가능 PlayFab 프로그램에 등록된 개발자만 사용가능/ 게임 통계를 간단하게 확인 하는 방법은 로블록스 게임 설정에서 개발통계에서 확인
--AssetService - 로블록스에 저장되어 있는 여러가지 정보들을 가져오는 기능 
--★BadgeService -  배지와 관련된 정보 및 기능을 제공. 플랫폼 전체에서 플레이어의 업적과 활동을 인식하는데 사용. 플레이어에게 배지를 수여하면 인벤토리에 추가되고 프로필 페이지에 표시
--ChangeHistoryService- 플러그인이 변경 사항을 실행 취소 및 다시 실행하고 장소가 변경될 때 웨이포인트를 생성하는 방법을 제공
--★Chat - LocalScript이며 기본 챗 및 버블챗 기능
--ClusterPacketCache - 클러스터 패킷을 캐시하기 위한 내부 서비스입니다. 이 서비스가 있는 경우에만 제공
--★CollectionService - 태그가 있는 인스턴스 의 CollectionService그룹(컬렉션)을 관리합니다. 
--ConfigureServerService - 구성 서버 서비스
--ContentProvider - 
--[[서비스의 주요 용도 게임에 미리 로드하는 것. Decal또는 같은 새 자산 Sound이 게임에서 사용되면 Roblox는 
Roblox 서버에서 이와 관련된 콘텐츠를 로드합니다. 어떤 경우에는 콘텐츠가 게임에 로드되기 전에 지연이 발생할 수 있으므로 개발자에게 바람직하지 않을 수 있습니다.]]
--ContextActionService - 게임이 사용자 입력을 상황별 작업 또는 특정 조건이나 기간 동안에만 활성화되는 작업에 바인딩할 수 있도록 하는 게임 서비스
--CookiesService - Roblox에서 분석 목적으로 HTTP 쿠키를 제어하는 ​​데 사용합니다.Roblox의 백엔드 서버에서만 사용할 수 있으므로 어떤 형태나 형태의 개발자도 사용할 수 없습니다
--★DataStoreService - 
--[[플레이어의 인벤토리 또는 스킬 포인트에 있는 항목과 같이 세션 간에 유지되어야 하는 데이터를 저장할 수 있습니다 . 
    저장소는 경험별로 공유 되므로 다른 서버의 장소를 포함하여 경험의 모든 장소에서 동일한 데이터에 액세스하고 변경데이터 저장소는
   게임 서버에서만 액세스할 수 있으므로 에서 사용하는 또는 내에서만 사용]]
--★Debris - 이 서비스를 사용하면 개발자가 메서드를 사용하여 코드를 생성하지 않고 개체 제거를 예약
--FilteredSelection - 
--★FriendService - 게임 내에서 친구 요청을 전송, 취소, 수락 및 거부하는 데 사용되는 서비스. PlayerListScript에서 리더보드와 함께 친구 요청을 보내는 데 사용
--★GamePassService - 게임 패스
--Geometry - 개발자 사용 불가능한 내부 서비스
--★GuiService - 개발자가 GuiObject게임패드 내비게이터에서 현재 선택하고 있는 것을 제어할 수 있게 해주는 서비스
--HttpRbxApiService - 관리자 가 사용하는 버전입니다 .일반 서비스와 달리 이 서비스는 roblox.com에 GET/POST 요청을 보낼 수 있습니다.
--HttpService - 이 서비스를 사용하면 분석, 데이터 저장, 원격 서버 구성, 오류 보고, 고급 계산 또는 실시간 통신과 같은 Roblox 외부 웹 서비스와 게임을 통합할 수 있습니다.
--InsertService - 
--[[자산을 로드하려면 자산을 로드하는 게임 작성자(사용자 또는 그룹일 수 있음)가 자산에 액세스할 수 있어야 합니다. 이러한 제한으로 인해
   InsertService는 민감한 데이터, 일반적으로 에 사용할 API 또는 비밀 키를 로드하는 데 유용]]
--Instance - 
--[[클래스 계층 구조의 모든 클래스에 대한 기본 클래스입니다. Roblox 엔진이 정의하는 다른 모든 클래스는 Instance의 모든 멤버를 상속합니다. 
   Instance 개체를 직접 생성할 수 없습니다.]]
--JointsService - 표면 연결에 의해 생성된 관절을 저장하는 서비스입니다. 또한 표면 대 표면 접촉을 시각화하고 표면을 함께 결합하는 데 사용할 수 있는 API가 있습니다.
--LanguageService - 나라별 언어 선택 기능
--★Lighting - 게임의 환경 조명을 제어
--LocalizationService - 자동 번역 서비스
--LogService - 출력된 텍스트를 읽을 수 있는 서비스
--★MarketplaceService - 게임 내 거래를 담당하는 게임 서비스- 수익을 내기 위한 첫번째 단계
--NetworkServer - 
--[[NetworkServer는 NetworkReplicator게임의 모든 것을 저장하고 모든 연결을 처리합니다. 
   Start ServerNetworkPeer:SetOutgoingKBPSLimit 를 사용하는 동안 대기 시간을 모방하는 데 사용]]
--NotificationService - 알림을 예약할 수 있는 미완성 서비스입니다. 현재 구현되지 않으며 활성화할 수 없습니다.
--PermissionsService - 권한 서비스
--PhysicsService - 
--[[PhysicsService는 다른 충돌 그룹에 할당된 부분과 충돌할 수도 있고 충돌하지 않을 수도 있는 
   부분 집합을 정의하는 충돌 그룹 작업을 위한 기능이 있는 게임 서비스입니다. 를 사용하여 부품을 충돌 그룹에 할당]]
--★Players - 
--[[Roblox 게임 서버에 연결된 클라이언트에 대한 개체만 포함되어 있습니다. 
   또한 장소의 구성(예: 말풍선 채팅 또는 기본 채팅)에 대한 정보도 포함합니다. 캐릭터 외모, 친구 및 아바타 썸네일과 같이 서버에 연결되지 않은 플레이어에 대한 정보]]
--PointsService - 현재 사용할수 없음
--PolicyService - 여러 국가의 다양한 국가 규정을 준수할 수 있는 게임플레이 구성 요소를 구축하는 데 도움
--ProcessInstancePhysicsService - 
--★ProximityPromptService -  ProximityPrompt전역 방식으로 개체와 상호 작용할 수 있습니다. 개별 ProximityPrompt 개체보다 이 서비스의 이벤트를 수신하는 것이 더 편리할 수 있습니다.
--★ReplicatedFirst - 로딩  GUI를 사용하는데 좋고 한번 뜨면 다시 뜨지 않음 속도가 빠름
--★ReplicatedStorage - 서버와 연결된 게임 클라이언트 모두에서 사용할 수 있는 개체에 대한 일반 컨테이너 서비스
--★Run Service - 
--[[게임이나 스크립트가 실행되는 컨텍스트를 관리할 뿐만 아니라 시간 관리를 위한 메서드와 이벤트가 포함되어 있습니다. IsClient, IsServer, , 같은 메서드 IsStudio는 어떤
   컨텍스트 코드가 실행되고 있는지 확인하는 데 도움이 될 수 있습니다. 이러한 메서드는 클라이언트 및 서버 스크립트 모두에 필요할 수 있는 ModuleScript에 유용합니다.
   또한 IsStudio스튜디오 내 테스트를 위한 특수 동작을 추가하는 데 사용할 수  있습니다.
   Stepped또한 RunService에는 코드가 , Heartbeat및 와 같은 Roblox의 프레임별 루프를 준수할 수 있도록 하는 이벤트가 있습니다 RenderStepped.
   작업 스케줄러모든 경우에 사용할 적절한 이벤트를 선택하는 것이 중요하므로 정보에 입각한 결정을 내리기 위해 읽어야 합니다.]]
--ScriptContext - 모든 기본 스크립트를 통제 가능 속성을 사용하여 일반 보안 액세스가 있는 스레드에서 모든 스크립트를 비활성화할 수 있음
--Selection - 선택 항목을 엑세스및 제어 스튜디오 내에서 사용가능
--★ServerScriptService - 서버 전용 및 기타 스크립팅 관련 자산에 Script대한 서비스
--★ServerStorage - 서버에서만 콘텐츠에 액세스할 수 있음
--SocialService - 친구 초대기능, 쪽지 기능 외 
--★SoundService - 여러가지 사운드 설정 기능
--SpawnerService - 개발자 사용 불가능한 서비스 (플레이어 스폰포인트의 여러가지 기본설정)
--★StarterGui - 플레이어가 게임에 접속 후 다양한 GUI를 화면에 띄울수 있게 해주는 서비스
--★StarterPack - 시작시에 플레이어에게 아이템을 지급
--★StarterPlayer - 개체의 속성 기본값을 설정할 수 있는 서비스
--★Stats - 게임내 여러가지 정보 제공
--★Teams - 팀을 구성하는 기능
--★Teleport Service - 플레이어가 원하는 게임으로 이동 시켜주는 기능	
--TestService - 내부적으로 엔진에서 분석 테스트를 실행하는 데 사용하는 서비스입니다.게임 내에서 바로 정교한 테스트를 작성할 수 있습니다.
--TextService - 게임에서 텍스트 표시를 내부적으로 처리하는 서비스
--TouchInputService - 모바일 장치의 터치 입력을 담당하는 내부 서비스
--★TweenService - 다양한 Roblox 개체에 대한 애니메이션을 만드는 데 사용할 수 있습니다. 거의 모든 숫자 속성은 TweenService를 사용하여 트위닝
--VRService - 가상 현실(VR) 간의 상호 작용을 처리하는 서비스
--VirtualInputManager - 개발자 사용 불가능한 내부 서비스
--VoiceChatService - 음성 챗 서비스
--★Workspace - 3D 모델이 랜더링 될 모든 객체가 존재


-- 데이터가 저장되는 머니, 킬 리더보드 만들기
local datastore = game:GetService("DataStoreService"):GetDataStore("Playerstats")

game.Players.PlayerAdded:Connect(function(plr)
	local leaderstats = Instance.new("IntValue")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = plr

	local money = Instance.new("IntValue")

	money.Name = "Money"
	money.Value = 0

	local data = datastore:GetAsync(plr.UserId)
	if data then
		money.Value = data
	end
end)

game.Players.PlayerRemoving:Connect(function (plr) -- 플레이어가 나갔을 때
	local s, e = pcall(function() --가끔 데이터 저장에 실패하는 경우 스크립트를 중단하지 않게
		datastore:SetAsync(plr.UserId, plr.leaderstats.Money.Value) -- Money 데이터 저장
	end)
end)