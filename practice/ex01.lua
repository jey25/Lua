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
   --스크립트 끝

   --애니메이션 스크립트
local f = false
script.Parent.Activated:Connect(function()
 if not f then
  f = true
  local YAnimation = game.Players.LocalPlayer.Character.Humanoid:LoadAnimation(script.Parent.Animation)
  YAnimation:Play()
  wait(0.7)
  f = false
 end
end)
--스크립트끝