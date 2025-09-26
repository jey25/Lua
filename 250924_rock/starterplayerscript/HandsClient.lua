local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipChanged = Remotes:WaitForChild("HandsEquipChanged")
local GetAllEquipped = Remotes:WaitForChild("HandsGetAllEquipped")
local HandsState = require(ReplicatedStorage:WaitForChild("HandsClientState"))

-- ===== RPS 공용 반응형 사이징 =====
local BASE_SHORT_EDGE = 1179    -- iPhone 14 Pro 세로 기준
local BTN_BASE_PX     = 140     -- 기준 버튼 목표 크기(px)
local BTN_MIN_PX      = 130
local BTN_MAX_PX      = 150


local function _vpShort()
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(BASE_SHORT_EDGE, 2556)
	return math.min(vs.X, vs.Y)
end

local function _btnPx()
	local px = math.floor(BTN_BASE_PX * _vpShort() / BASE_SHORT_EDGE)
	return math.clamp(px, BTN_MIN_PX, BTN_MAX_PX)
end

local function _normId(s: any): string
	if typeof(s) ~= "string" then return "" end
	-- rbxassetid://12345, https://.../12345 등 → 숫자만 추출
	local n = string.match(s, "%d+")
	return n or s
end

local function _currentRpsSet(): {[string]: boolean}
	local set = {}
	local pack = HandsState.Get(Players.LocalPlayer.UserId)
	if not (pack and pack.images) then return set end
	for _, k in ipairs({"rock","paper","scissors"}) do
		local v = _normId(pack.images[k])
		if v ~= "" then set[v] = true end
	end
	return set
end

local function _styleOne(img: GuiObject)
	if not (img and (img:IsA("ImageLabel") or img:IsA("ImageButton"))) then return end
	img.ScaleType = Enum.ScaleType.Fit
	local ar = img:FindFirstChildOfClass("UIAspectRatioConstraint") or Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.DominantAxis = Enum.DominantAxis.Width
	ar.Parent = img

	local cap = img:FindFirstChildOfClass("UISizeConstraint") or Instance.new("UISizeConstraint")
	local px = _btnPx()
	cap.MaxSize = Vector2.new(px, px)
	cap.MinSize = Vector2.new(0, 0)
	cap.Parent = img

	-- 이미 너무 크면 한 번 스냅
	if img.Size.X.Offset > px or img.Size.Y.Offset > px then
		img.Size = UDim2.fromOffset(px, px)
	end
end

local function _maybeStyleByAsset(img: GuiObject, rpsSet: {[string]: boolean}?)
	if not (img and (img:IsA("ImageLabel") or img:IsA("ImageButton"))) then return end
	local set = rpsSet or _currentRpsSet()
	local id = _normId(img.Image)
	if id ~= "" and set[id] then
		_styleOne(img)
	end
end

local function styleRpsUnder(root: Instance)
	-- UIGridLayout이 있으면 셀 크기도 맞춰줌
	local grid = root:FindFirstChildOfClass("UIGridLayout")
	if grid then
		local px = _btnPx()
		grid.CellSize = UDim2.fromOffset(px, px)
	end
	local set = _currentRpsSet()
	for _, d in ipairs(root:GetDescendants()) do
		_maybeStyleByAsset(d, set)
	end
end

-- 결과 패널처럼 "이미지가 나중에 세팅"되는 케이스를 위해 프로퍼티 훅
local function hookImageAutoStyle(obj: Instance)
	if not (obj and (obj:IsA("ImageLabel") or obj:IsA("ImageButton"))) then return end
	-- 처음에도 한 번 시도
	_maybeStyleByAsset(obj)
	-- 이미지가 바뀔 때마다 재검
	obj:GetPropertyChangedSignal("Image"):Connect(function()
		_maybeStyleByAsset(obj)
	end)
end

-- ===== 유틸 =====
local function findBoardsForUser(userId: number)
	local targets = {}
	for _, inst in ipairs(playerGui:GetDescendants()) do
		if inst:IsA("Frame") or inst:IsA("Folder") or inst:IsA("ScreenGui") then
			local tag = inst:FindFirstChild("OwnerUserId")
			if tag and tag:IsA("IntValue") and tag.Value == userId then
				table.insert(targets, inst)
			end
		end
	end
	if #targets == 0 and userId == player.UserId then
		for _, inst in ipairs(playerGui:GetDescendants()) do
			if (inst:IsA("Frame") or inst:IsA("ScreenGui") or inst:IsA("Folder")) and inst.Name:lower() == "board" then
				table.insert(targets, inst)
			end
		end
	end
	return targets
end

local function applyImagesToContainer(container, images)
	if not images then return end
	for _, choice in ipairs({"paper", "rock", "scissors"}) do
		for _, obj in ipairs(container:GetDescendants()) do
			if (obj:IsA("ImageButton") or obj:IsA("ImageLabel")) and obj.Name:lower() == choice then
				obj.Image = images[choice] or ""
			end
		end
	end
	styleRpsUnder(container)  -- 컨테이너 하위 전부 캡/정사각/핏 적용
end

local function applyForUser(userId)
	local data = HandsState.Get(userId)
	if not data or not data.images then return end
	local targets = findBoardsForUser(userId)
	for _, t in ipairs(targets) do
		applyImagesToContainer(t, data.images)
	end
end

-- ===== 초기 동기화 =====
local all = GetAllEquipped:InvokeServer()
for uid, info in pairs(all) do
	local id = tonumber(uid) or uid
	HandsState.Set(id, { theme = info.theme, images = info.images })
	applyForUser(id)
end

-- 새로 생기는 모든 이미지에 자동 훅(결과 패널/팝업 포함)
playerGui.DescendantAdded:Connect(function(obj)
	if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
		hookImageAutoStyle(obj)
	elseif obj:IsA("UIGridLayout") and obj.Parent then
		task.defer(function() styleRpsUnder(obj.Parent) end)
	end
end)

-- 화면 회전/리사이즈 시, 전체를 한 번 재적용
local cam = workspace.CurrentCamera
if cam then
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		styleRpsUnder(playerGui)
	end)
end

-- 테마가 바뀌어 에셋 ID가 바뀌면, 전체 스캔해서 새 세트로 재적용
EquipChanged.OnClientEvent:Connect(function(userId, themeName, images)
	if userId == player.UserId then
		task.defer(function() styleRpsUnder(playerGui) end)
	end
end)

-- 내 보드 fallback 적용 (board_runtime)
task.defer(function()
	local me = HandsState.Get(player.UserId)
	if me and me.images then
		local board = playerGui:FindFirstChild("board_runtime")
		if board then
			applyImagesToContainer(board, me.images)
		end
	end
end)

-- ===== 서버 이벤트 =====
EquipChanged.OnClientEvent:Connect(function(userId, themeName, images)
	HandsState.Set(userId, { theme = themeName, images = images })
	applyForUser(userId)
end)

-- ===== 결과 화면 헬퍼 =====
local function setResultIcon(imageLabel: ImageLabel, userId: number, choiceName: "paper"|"rock"|"scissors")
	local pack = HandsState.Get(userId)
	if pack and pack.images then
		imageLabel.Image = pack.images[choiceName] or ""
	end
	hookImageAutoStyle(imageLabel)  -- 결과 화면 아이콘도 강제 스타일
end

-- ===== 보드 동적 생성 대응 =====
playerGui.DescendantAdded:Connect(function(obj)
	if not (obj:IsA("ScreenGui") or obj:IsA("Frame") or obj:IsA("Folder")) then return end
	local tag = obj:FindFirstChild("OwnerUserId")
	if tag and tag.Value == player.UserId or obj.Name:lower() == "board_runtime" then
		task.defer(function()
			applyForUser(player.UserId)
		end)
	end
end)
