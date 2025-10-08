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
local MARKER_KEY = "streetfood"
local DEFAULT_MARKER_PX = Vector2.new(80, 80) -- size 미지정시 기본 픽셀 크기

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

local function getPromptRoot(prompt: ProximityPrompt): Model?
	local root = prompt.Parent
	while root and root.Parent and root.Parent:IsA("Model") do
		root = root.Parent
	end
	return root
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
		-- 근접 이탈 시 해당 루트의 마커도 정리
		local root = getPromptRoot(prompt)
		if root then ActiveMarkers[root] = nil end
	end
end)

-- ====== 서버 PromptTriggered를 강제로 유도 (HoldDuration=0 가정) ======
local function triggerPromptNow()
	if currentPrompt then
		ProximityPromptService:InputHoldBegin(currentPrompt)
		task.defer(function()
			ProximityPromptService:InputHoldEnd(currentPrompt)
		end)
	end
end

-- ====== 활성 Marker 정보를 저장(스크린 판정 용) ======
type MarkerInfo = {
	adornee: BasePart,
	offsetY: number,
	sizePx: Vector2,
}
local ActiveMarkers: {[Model]: MarkerInfo} = {}

-- 스크린 좌표로 Marker 히트 판정
local cam = workspace.CurrentCamera
local function hitTestMarkerAtScreenPos(screenPos: Vector2): boolean
	if not cam then cam = workspace.CurrentCamera end
	if not cam then return false end
	if not currentPrompt then return false end

	local promptRoot = getPromptRoot(currentPrompt)
	if not promptRoot then return false end

	-- 현재 근접 중인 prompt 루트에 한해 판정(다른 마커 탭은 무시)
	local info = ActiveMarkers[promptRoot]
	if not info then return false end
	local base = info.adornee
	if not (base and base.Parent) then return false end

	-- 마커 화면 중심 좌표 계산 (offsetY 적용)
	local wp = base.Position + Vector3.new(0, info.offsetY, 0)
	local vp, onScreen = cam:WorldToViewportPoint(wp)
	if not onScreen then return false end
	local center = Vector2.new(vp.X, vp.Y)

	-- 마커 사이즈 박스(픽셀) 안에 들어오면 히트
	local half = info.sizePx * 0.5
	if math.abs(screenPos.X - center.X) <= half.X and math.abs(screenPos.Y - center.Y) <= half.Y then
		return true
	end
	return false
end

-- ====== 입력 훅: GUI가 입력을 먹어도 InputBegan은 온다! ======
UserInputService.InputBegan:Connect(function(input: InputObject, _gameProcessed: boolean)
	if input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
	then
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if hitTestMarkerAtScreenPos(pos) then
			triggerPromptNow()
		end
	end
end)

-- ====== 서버 → 클라: Marker 표시/숨김 (표시는 MarkerClient, 판정은 ActiveMarkers) ======
WangEvent.OnClientEvent:Connect(function(cmd: string, arg: any)
	if cmd == "ShowMarker" and typeof(arg) == "table" then
		local target = arg.target
		if typeof(target) == "Instance" then
			-- 1) Marker 시각화
			MarkerClient.show(target, {
				key          = arg.key or MARKER_KEY,
				preset       = arg.preset or "TouchIcon",
				image        = arg.image or CLICK_ICON_TEXTURE,
				transparency = arg.transparency or 0.15,
				size         = arg.size,                 -- e.g. UDim2.fromOffset(72,72)
				pulse        = (arg.pulse ~= false),
				pulsePeriod  = arg.pulsePeriod or 0.8,
				offsetY      = arg.offsetY or 2.0,
				alwaysOnTop  = (arg.alwaysOnTop ~= false),
			})

			-- 2) 스크린 판정용 데이터 저장
			local root = getRootModelFrom(target) or (target:IsA("Model") and target) :: Model?
			if root then
				local base = getAnyBasePart(root)
				if base then
					-- size(Udim2) → 픽셀 Vector2 변환
					local sizePx = DEFAULT_MARKER_PX
					local argSize = arg.size
					if typeof(argSize) == "UDim2" then
						-- Scale은 화면 비율이 섞여 복잡해지므로 Offset만 사용
						if argSize.X.Scale == 0 and argSize.Y.Scale == 0 then
							sizePx = Vector2.new(math.max(1, argSize.X.Offset), math.max(1, argSize.Y.Offset))
						end
					end
					ActiveMarkers[root] = {
						adornee = base,
						offsetY = (arg.offsetY or 2.0) :: number,
						sizePx  = sizePx,
					}
				end
			end
		end

	elseif cmd == "HideMarker" and typeof(arg) == "table" then
		local target = arg.target
		if typeof(target) == "Instance" then
			MarkerClient.hide(target, arg.key or MARKER_KEY)
			local root = getRootModelFrom(target) or (target:IsA("Model") and target) :: Model?
			if root then ActiveMarkers[root] = nil end
		end
	end
end)

-- 끝: 모바일/PC 공통으로 Marker “아이콘 영역” 터치/클릭 시만 즉시 완료됨.
