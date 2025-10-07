-- LocalScript: 경찰 NPC 근접/대화/GUI 흐름 (robust bind ver)
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ===== 설정 =====
local BUBBLE_DISTANCE = 20          -- 말풍선 표시 거리
local INTERACT_DISTANCE = 6         -- NPCClick 버튼 표시/활성 거리

-- 대상 NPC 이름 후보 (대소문자/접미어 상관없이 탐색)
local NPC_MODEL_NAMES = { "police_c" }

-- 리소스
local NPCClickTemplate = ReplicatedStorage:WaitForChild("NPCClick")      :: ScreenGui
local PoliceGuiTemplate = ReplicatedStorage:WaitForChild("police_c")     :: ScreenGui

local PoliceRemotes = ReplicatedStorage:WaitForChild("PoliceRemotes")
local PoliceChoice  = PoliceRemotes:WaitForChild("PoliceChoice") :: RemoteEvent

-- ===== NPC 폴더 & 동적 바인딩 =====
local NPC_FOLDER = Workspace:WaitForChild("NPC_LIVE") :: Folder
local npc: Model? = nil

local function nameMatches(name: string): boolean
	local lname = string.lower(name)
	for _, key in ipairs(NPC_MODEL_NAMES) do
		local lk = string.lower(key)
		-- 정확일치 또는 접두/부분 일치 허용 (스폰러가 접미어 붙이는 케이스 대비)
		if lname == lk or string.find(lname, lk, 1, true) == 1 then
			return true
		end
	end
	return false
end

local function pickNPC(): Model?
	-- 정확/부분 일치로 검색
	for _, m in ipairs(NPC_FOLDER:GetChildren()) do
		if m:IsA("Model") and nameMatches(m.Name) then
			return m
		end
	end
	return nil
end

local function rebindNPC()
	local candidate = pickNPC()
	if candidate ~= npc then
		npc = candidate
		-- 앵커/말풍선 초기화
		if npc == nil then
			-- NPC가 없으면 말풍선/버튼을 끈다
			local bb = PlayerGui:FindFirstChild("NPC_TalkBubble", true)
			if bb and bb:IsA("BillboardGui") then bb.Enabled = false end
		end
	end
end

-- 폴더 감시: NPC 스폰/교체 대응
NPC_FOLDER.ChildAdded:Connect(function()
	rebindNPC()
end)
NPC_FOLDER.ChildRemoved:Connect(function(inst)
	if inst == npc then
		npc = nil
	end
	rebindNPC()
end)

-- 최초 바인딩 시도
rebindNPC()

-- ===== NPC 좌표 헬퍼 =====
local function getModelPart(m: Model?): BasePart?
	if not m then return nil end
	if m.PrimaryPart then return m.PrimaryPart end
	local hrp = m:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then return hrp end
	local head = m:FindFirstChild("Head")
	if head and head:IsA("BasePart") then return head end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then return p end
	end
	return nil
end

local function getModelPos(m: Model?): Vector3?
	local p = getModelPart(m)
	return p and p.Position or nil
end

-- ===== 말풍선 관리 =====
local bubbleGui: BillboardGui? = nil
local function ensureBubble()
	local anchor = getModelPart(npc)
	if not anchor then return nil end

	-- 기존 것 있으면 같은 앵커에 붙어있는지 확인
	if bubbleGui and bubbleGui.Parent == anchor then
		return bubbleGui
	end
	-- 새로 생성(또는 앵커 갈아끼움)
	if bubbleGui then bubbleGui:Destroy() end
	local bb = Instance.new("BillboardGui")
	bb.Name = "NPC_TalkBubble"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.new(0, 180, 0, 60)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	bb.Enabled = false
	bb.Parent = anchor

	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 0.15
	tl.Text = "Hey there, come here"
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.TextColor3 = Color3.fromRGB(255, 255, 255)
	tl.TextStrokeTransparency = 0.4
	tl.TextStrokeColor3 = Color3.new(0, 0, 0)
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 10); corner.Parent = tl
	tl.Parent = bb

	bubbleGui = bb
	return bubbleGui
end

local function setBubble(on: boolean)
	local bb = ensureBubble()
	if bb then bb.Enabled = on end
end

-- ===== NPCClick 버튼 관리 =====
local interactGui: ScreenGui? = nil
local guiOpen = false

local function destroyInteractGui()
	if interactGui then
		interactGui:Destroy()
		interactGui = nil
	end
end

local function showInteractButton()
	if guiOpen then return end
	destroyInteractGui()

	local g = NPCClickTemplate:Clone()
	g.Name = "NPCClick_runtime"
	g.ResetOnSpawn = false
	g.Parent = PlayerGui
	interactGui = g

	local btn = g:WaitForChild("NPCClick") :: TextButton
	btn.MouseButton1Click:Connect(function()
		-- 버튼 눌렀으면 버튼 닫고 본 GUI 띄우기
		destroyInteractGui()
		setBubble(false)
		-- 본 대화 GUI
		local pg = PoliceGuiTemplate:Clone()
		pg.Name = "police_c_runtime"
		pg.ResetOnSpawn = false
		pg.Enabled = true
		pg.Parent = PlayerGui
		guiOpen = true

		-- 내부 프레임들
		local Inoculation = pg:WaitForChild("Inoculation") :: Frame
		local CloseFrame  = pg:WaitForChild("close") :: Frame
		local Ok1Frame    = pg:WaitForChild("ok1") :: Frame
		local Ok2Frame    = pg:WaitForChild("ok2") :: Frame

		-- 버튼들
		local Btn_Close   = Inoculation:WaitForChild("Close") :: TextButton
		local Btn_OK1     = Inoculation:WaitForChild("OK1") :: TextButton
		local Btn_OK2     = Inoculation:WaitForChild("OK2") :: TextButton

		local Btn_HIOK    = CloseFrame:WaitForChild("HIOK") :: TextButton
		local Btn_REOK    = Ok1Frame:WaitForChild("REOK") :: TextButton
		local Btn_SOONOK  = Ok2Frame:WaitForChild("SOONOK") :: TextButton

		-- 초기 상태: 항상 Inoculation ON
		Inoculation.Visible, CloseFrame.Visible, Ok1Frame.Visible, Ok2Frame.Visible =
			true, false, false, false

		-- 공통 닫기
		local function closeMainGui()
			if pg then pg:Destroy() end
			guiOpen = false
			-- 닫힌 뒤 다시 근접 중이면 말풍선/버튼은 루프에서 자동 제어
		end

		-- 흐름 1) Inoculation -> close -> 닫기
		Btn_Close.MouseButton1Click:Connect(function()
			Inoculation.Visible = false
			CloseFrame.Visible  = true
		end)
		Btn_HIOK.MouseButton1Click:Connect(closeMainGui)

		-- OK1 흐름
		Btn_OK1.MouseButton1Click:Connect(function()
			Inoculation.Visible = false
			Ok1Frame.Visible    = true
			PoliceChoice:FireServer("ok1")
		end)
		Btn_REOK.MouseButton1Click:Connect(closeMainGui)

		-- OK2 흐름
		Btn_OK2.MouseButton1Click:Connect(function()
			Inoculation.Visible = false
			Ok2Frame.Visible    = true
			PoliceChoice:FireServer("ok2")
		end)
		Btn_SOONOK.MouseButton1Click:Connect(closeMainGui)
	end)
end

-- CivicStatus가 리셋되면(=none) 즉시 다시 뜰 수 있도록 감시
LocalPlayer:GetAttributeChangedSignal("CivicStatus"):Connect(function()
	-- GUI 열려있지 않으면 버튼/버블을 루프가 다시 처리
	if LocalPlayer:GetAttribute("CivicStatus") ~= "good"
		and LocalPlayer:GetAttribute("CivicStatus") ~= "suspicious" then
		-- 강제로 재바인딩 시도(리셋 직후 NPC를 못 잡고 있었을 수 있음)
		rebindNPC()
	end
end)

-- ===== 근접 루프 =====
task.spawn(function()
	while true do
		task.wait(0.25)

		-- NPC가 아직 없으면 재바인딩 시도
		if not npc or not npc.Parent then
			rebindNPC()
		end

		local char = LocalPlayer.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart")
		local npcPos = getModelPos(npc)

		if not (hrp and npcPos) then
			-- 캐릭터나 NPC 기준점을 못 찾으면 전부 숨김
			setBubble(false)
			destroyInteractGui()
		else
			local dist = (npcPos - hrp.Position).Magnitude

			-- 플레이어가 이미 판정되었으면(OK1/OK2 선택 완료) 항상 숨김
			local cs = LocalPlayer:GetAttribute("CivicStatus")
			if cs == "good" or cs == "suspicious" then
				setBubble(false)
				destroyInteractGui()
			else
				-- 말풍선
				if dist <= BUBBLE_DISTANCE then
					if not guiOpen then
						setBubble(true)
					end
				else
					setBubble(false)
				end

				-- NPC Click 버튼
				if dist <= INTERACT_DISTANCE and not guiOpen then
					if not interactGui then
						showInteractButton()
					end
				else
					if interactGui then
						destroyInteractGui()
					end
				end
			end
		end
	end
end)
