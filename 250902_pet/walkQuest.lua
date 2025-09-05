-- ServerScriptService/WalkQuest.server.lua

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local walkStartTimes = {7, 15, 18, 21}   -- 정각 시작
local WALK_WINDOW_HOURS = 1               -- 창 길이(게임 시계 기준)
local walkDuration = 120                  -- 존 내 누적 필요시간(초)
local walkZones = Workspace:WaitForChild("WalkZones")

local playerWalkTimes: {[Player]: number} = {}
local activePlayers:   {[Player]: boolean} = {}
local completedPlayers:{[Player]: boolean} = {}

local isWalkTime = false
local activeUntilClock: number? = nil

-- 템플릿 (권장: ReplicatedStorage)
local GaugeTemplate = ReplicatedStorage:FindFirstChild("GaugeBar") or game.StarterGui:FindFirstChild("GaugeBar")

-- (선택) 클리어 이펙트
local ClearModule = nil
pcall(function() ClearModule = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ClearModule")) end)

----------------------------------------------------------------
-- 🔁 WalkZones 표시/비표시 및 상호작용 토글
----------------------------------------------------------------
local VISIBLE_TRANSPARENCY = 0.7   -- 보일 때 투명도(원하면 0)
local HIDDEN_TRANSPARENCY  = 1     -- 숨김

local function setZonesActive(active: boolean)
	for _, inst in ipairs(walkZones:GetDescendants()) do
		if inst:IsA("BasePart") then
			-- 충돌은 항상 끔(가림막/벽 역할이 아니면)
			inst.CanCollide = false
			-- 퀘스트 시간에만 상호작용/쿼리/보이기
			inst.CanTouch   = active
			inst.CanQuery   = active
			inst.Transparency = active and VISIBLE_TRANSPARENCY or HIDDEN_TRANSPARENCY
		end
	end
end

----------------------------------------------------------------
-- HUD 보조
----------------------------------------------------------------
local function resetWalkGui(player: Player)
	local pg = player:FindFirstChild("PlayerGui"); if not pg then return end
	local gui = pg:FindFirstChild("GaugeBar"); if gui then gui:Destroy() end
end

local function showWalkGui(player: Player)
	if not GaugeTemplate then return end
	resetWalkGui(player)
	local pg = player:FindFirstChild("PlayerGui"); if not pg then return end
	local clone = GaugeTemplate:Clone()
	clone.Name = "GaugeBar"
	clone.Enabled = true
	clone.Parent = pg
end

local function toast(player: Player, msg: string, seconds: number?)
	local pg = player:FindFirstChild("PlayerGui"); if not pg then return end
	local sg = Instance.new("ScreenGui"); sg.Name = "WalkToast"; sg.ResetOnSpawn = false; sg.Parent = pg
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0, 420, 0, 100)
	lbl.Position = UDim2.new(0.5, -210, 0.4, -50)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.fromRGB(255,255,0)
	lbl.TextStrokeColor3 = Color3.fromRGB(255,0,0)
	lbl.TextStrokeTransparency = 0.2
	lbl.Text = msg
	lbl.Parent = sg
	task.delay(seconds or 2, function() if sg then sg:Destroy() end end)
end

local function showWalkTimeGui(player: Player)
	toast(player, "Walk Time", 2)
end

----------------------------------------------------------------
-- 시작/종료
----------------------------------------------------------------
local function beginWalkWindow(startHour: number)
	isWalkTime = true
	activeUntilClock = (startHour + WALK_WINDOW_HOURS) % 24

	-- 상태 리셋
	playerWalkTimes  = {}
	activePlayers    = {}
	completedPlayers = {}

	-- ✅ 존 활성화/표시
	setZonesActive(true)

	-- 전원 HUD
	for _, plr in ipairs(Players:GetPlayers()) do
		showWalkGui(plr)
		showWalkTimeGui(plr)
	end
end

local function failFor(player: Player)
	resetWalkGui(player)
	activePlayers[player]    = nil
	playerWalkTimes[player]  = nil
	toast(player, "Time's up!", 1.5)
end

local function completeFor(player: Player)
	completedPlayers[player] = true
	if ClearModule and ClearModule.showClearEffect then
		pcall(function() ClearModule.showClearEffect(player) end)
	end
	resetWalkGui(player)
	activePlayers[player]    = nil
	playerWalkTimes[player]  = nil
end

local function endWalkWindow()
	-- 미완료 전원 실패 처리
	for _, plr in ipairs(Players:GetPlayers()) do
		if not completedPlayers[plr] then
			failFor(plr)
		end
	end

	-- ✅ 존 비활성/숨김
	setZonesActive(false)

	isWalkTime = false
	activeUntilClock = nil
end

----------------------------------------------------------------
-- 시간 엣지 감시
----------------------------------------------------------------
local function crossed(prev, curr, targetHour)
	if curr < prev then curr += 24 end
	if targetHour < prev then targetHour += 24 end
	return prev < targetHour and targetHour <= curr
end

local lastClock = Lighting.ClockTime
local function tickTime()
	local curr = Lighting.ClockTime
	for _, h in ipairs(walkStartTimes) do
		if crossed(lastClock, curr, h) then
			beginWalkWindow(h)
			break
		end
	end
	if isWalkTime and activeUntilClock then
		if crossed(lastClock, curr, activeUntilClock) then
			endWalkWindow()
		end
	end
	lastClock = curr
end

----------------------------------------------------------------
-- 존 판정 & 진행 (기존 그대로)
----------------------------------------------------------------
local function pointInsidePart(part: BasePart, worldPos: Vector3): boolean
	local localPos = part.CFrame:PointToObjectSpace(worldPos)
	local half = part.Size * 0.5
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Y) <= half.Y
		and math.abs(localPos.Z) <= half.Z
end

local function isCharacterInAnyZone(character: Model): boolean
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not hrp then return false end
	for _, zone in ipairs(walkZones:GetChildren()) do
		if zone:IsA("BasePart") and pointInsidePart(zone, hrp.Position) then
			return true
		end
	end
	return false
end

local function findFillFrame(gaugeBar: Instance): Frame?
	local ok, fill = pcall(function()
		return gaugeBar:FindFirstChild("Frame"):FindFirstChild("Frame"):FindFirstChild("Frame")
	end)
	if ok and fill and fill:IsA("Frame") then return fill end
	for _, d in ipairs(gaugeBar:GetDescendants()) do
		if d:IsA("Frame") then fill = d end
	end
	return fill
end

local function trackWalkProgress(player: Player)
	if not isWalkTime then return end
	if activePlayers[player] then return end
	activePlayers[player] = true

	local pg = player:FindFirstChild("PlayerGui"); if not pg then activePlayers[player] = nil; return end
	local gaugeBar = pg:FindFirstChild("GaugeBar"); if not gaugeBar then activePlayers[player] = nil; return end
	local fill = findFillFrame(gaugeBar); if not fill then activePlayers[player] = nil; return end

	local t = playerWalkTimes[player] or 0

	while isWalkTime and player.Parent do
		task.wait(0.1)

		local char = player.Character
		if not (char and isCharacterInAnyZone(char)) then
			activePlayers[player] = nil
			return
		end

		t = math.min(t + 0.1, walkDuration)
		playerWalkTimes[player] = t
		fill.Size = UDim2.new(1 - (t / walkDuration), 0, 1, 0)

		if t >= walkDuration then
			completeFor(player)
			return
		end
	end

	activePlayers[player] = nil
end

local function onZoneTouched(hit: BasePart)
	if not isWalkTime then return end
	local char = hit:FindFirstAncestorOfClass("Model")
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
	local plr = Players:GetPlayerFromCharacter(char); if not plr then return end
	if not activePlayers[plr] then task.spawn(trackWalkProgress, plr) end
end

for _, zone in ipairs(walkZones:GetChildren()) do
	if zone:IsA("BasePart") then zone.Touched:Connect(onZoneTouched) end
end

RunService.Heartbeat:Connect(function()
	if not isWalkTime then return end
	for _, plr in ipairs(Players:GetPlayers()) do
		if not activePlayers[plr] and plr.Character and isCharacterInAnyZone(plr.Character) then
			task.spawn(trackWalkProgress, plr)
		end
	end
end)

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function()
		task.defer(function()
			if isWalkTime then
				showWalkGui(plr)
				showWalkTimeGui(plr)
				if plr.Character and isCharacterInAnyZone(plr.Character) then
					task.spawn(trackWalkProgress, plr)
				end
			end
		end)
	end)
end)

task.spawn(function()
	while true do
		tickTime()
		task.wait(0.2)
	end
end)

-- ✅ 서버 시작 시 기본은 감춤
setZonesActive(false)
