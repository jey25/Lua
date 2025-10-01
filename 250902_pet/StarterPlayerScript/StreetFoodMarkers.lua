--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- MarkerClient
local MarkerClient = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MarkerClient"))

-- Remotes
local RemoteFolder  = ReplicatedStorage:WaitForChild("RemoteEvents")
local WangEvent     = RemoteFolder:WaitForChild("WangEvent") :: RemoteEvent
local ProxRelay     = RemoteFolder:WaitForChild("StreetFoodProxRelay") :: RemoteEvent

-- ====== 설정 ======
local TAPS_TO_TRIGGER = 1          -- wangattraction과 동일 동작(3회 탭) / 1로 바꾸면 한 번에 발동
local TAP_WINDOW_SECS = 1.2        -- 연속 탭 허용 시간 창
local RAY_DISTANCE    = 500        -- 화면 → 월드 레이캐스트 거리
local MARKER_KEY      = "streetfood"

-- ====== UI/Markers/Click Icon (Decal)에서 Texture 가져오기 ======
local CLICK_ICON_TEXTURE: string? = nil
do
	local UI = ReplicatedStorage:FindFirstChild("UI")
	if UI then
		local Markers = UI:FindFirstChild("Markers")
		if Markers then
			local decal = Markers:FindFirstChild("Click Icon")
			if decal and decal:IsA("Decal") and type((decal :: Decal).Texture) == "string" then
				CLICK_ICON_TEXTURE = (decal :: Decal).Texture
			end
		end
	end
end

-- ====== 유틸 ======
local function getRootModelFrom(inst: Instance?): Model?
	if not inst then return nil end
	local m = inst:FindFirstAncestorOfClass("Model")
	while m and m.Parent and m.Parent:IsA("Model") do
		m = m.Parent
	end
	return m
end

local function getPromptRoot(prompt: ProximityPrompt): Model?
	local root = prompt.Parent
	while root and root.Parent and root.Parent:IsA("Model") do
		root = root.Parent
	end
	return root
end

local function sameRoot(a: Instance?, b: Instance?): boolean
	if not a or not b then return false end
	return getRootModelFrom(a) == getRootModelFrom(b)
end

local cam = workspace.CurrentCamera
local function worldRaycastFromScreen(pos: Vector2): RaycastResult?
	if not cam then cam = workspace.CurrentCamera end
	if not cam then return nil end
	local unitRay = cam:ViewportPointToRay(pos.X, pos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local char = Players.LocalPlayer.Character
	if char then
		params.FilterDescendantsInstances = {char}
	end
	return workspace:Raycast(unitRay.Origin, unitRay.Direction * RAY_DISTANCE, params)
end

-- ====== 현재 표시 중인 StreetFood 프롬프트 추적 ======
local currentPrompt: ProximityPrompt? = nil
ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	if prompt.Name == "StreetFoodPrompt" then
		currentPrompt = prompt
		ProxRelay:FireServer("enter", prompt)
	end
end)

ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
	if prompt.Name == "StreetFoodPrompt" then
		if currentPrompt == prompt then currentPrompt = nil end
		ProxRelay:FireServer("exit", prompt)
	end
end)

-- ====== 서버 → 클라: Marker 표시/숨김 (Click Icon 적용) ======
WangEvent.OnClientEvent:Connect(function(cmd: string, arg: any)
	if cmd == "ShowMarker" and typeof(arg) == "table" then
		local target = arg.target
		if typeof(target) == "Instance" then
			MarkerClient.show(target, {
				key          = arg.key or MARKER_KEY,
				preset       = arg.preset or "TouchIcon",  -- ReplicatedStorage/UI/Markers/TouchIcon
				image        = arg.image or CLICK_ICON_TEXTURE,
				transparency = arg.transparency or 0.15,
				size         = arg.size,                   -- e.g. UDim2.fromOffset(72,72)
				pulse        = (arg.pulse ~= false),
				pulsePeriod  = arg.pulsePeriod or 0.8,
				offsetY      = arg.offsetY or 2.0,
				alwaysOnTop  = (arg.alwaysOnTop ~= false),
			})
		end
	elseif cmd == "HideMarker" and typeof(arg) == "table" then
		local target = arg.target
		if typeof(target) == "Instance" then
			MarkerClient.hide(target, arg.key or MARKER_KEY)
		end
	end
end)

local tapState = {
	root = nil,
	count = 0,
	lastTime = 0.0,
}

local function resetTap()
	tapState.root = nil
	tapState.count = 0
	tapState.lastTime = 0.0
end


local function triggerPromptNow()
	if currentPrompt then
		-- HoldDuration=0 → Begin/End 연속 호출로 즉시 서버 PromptTriggered 발생
		ProximityPromptService:InputHoldBegin(currentPrompt)
		task.defer(function()
			ProximityPromptService:InputHoldEnd(currentPrompt)
		end)
	end
end

local function registerTapOn(hitInst: Instance)
	if not currentPrompt then return end
	-- 현재 보이는 StreetFoodPrompt의 루트 모델
	local curRoot = getPromptRoot(currentPrompt)
	if not curRoot then return end

	-- 사용자가 탭한 곳(모델/마커 위)을 루트 모델로 정규화
	local hitRoot = getRootModelFrom(hitInst)
	if not hitRoot then return end

	-- 같은 루트가 아니면 새 시퀀스로 교체
	local now = os.clock()
	if tapState.root ~= hitRoot or (now - tapState.lastTime) > TAP_WINDOW_SECS then
		tapState.root = hitRoot
		tapState.count = 1
		tapState.lastTime = now
		return
	end

	-- 같은 루트 안에서 시간창 내 추가 탭
	tapState.count += 1
	tapState.lastTime = now

	if tapState.count >= TAPS_TO_TRIGGER then
		resetTap()
		-- 최종적으로 currentPrompt가 같은 루트에 붙어있는지 확인(안전장치)
		local promptRoot = getPromptRoot(currentPrompt)
		if promptRoot == hitRoot then
			-- 근접 조건 충족 상태(프롬프트 표시 중)이므로 트리거
			triggerPromptNow()
		end
	end
end

-- 터치가 UI에서 소비되었더라도 좌표로 월드 레이캐스트해서 뒤의 모델을 판정
local function onTouchPositions(touchPositions: {Vector2}?, _processedByUI: boolean)
	if not touchPositions or #touchPositions == 0 then return end
	for _, pos in ipairs(touchPositions) do
		local result = worldRaycastFromScreen(pos)
		if result and result.Instance then
			registerTapOn(result.Instance)
		end
	end
end

-- 모바일: 월드 탭(3D) 이벤트
if UserInputService.TouchEnabled then
	-- 3D 월드 탭 전용
	if UserInputService.TouchTapInWorld then
		UserInputService.TouchTapInWorld:Connect(onTouchPositions)
	end
	-- 일부 기기/버전 대비 일반 Tap 이벤트도 후킹
	if UserInputService.TouchTap then
		UserInputService.TouchTap:Connect(onTouchPositions)
	end
end
