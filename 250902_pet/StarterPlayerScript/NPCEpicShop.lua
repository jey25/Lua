-- LocalScript: "EpicPet NPC" 상호작용 + 레벨 게이트 + 2단계 GUI 플로우
local Players            = game:GetService("Players")
local LocalPlayer        = Players.LocalPlayer
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local PlayerGui          = LocalPlayer:WaitForChild("PlayerGui")

-- ===== 설정 =====
local REQUIRED_LEVEL = 100
local INTERACTION_DISTANCE = 5

-- 이 NPC의 모델 경로(PrimaryPart 필수)
-- TODO: 실제 경로로 바꿔주세요.
local npc_epic = workspace:WaitForChild("NPC_LIVE"):WaitForChild("vendor_ninja(Lv.200)")

-- 템플릿들
local NPCClickTemplate       = ReplicatedStorage:WaitForChild("NPCClick")              :: ScreenGui
local EpicNpcIntroGuiTemplate= ReplicatedStorage:WaitForChild("EpicNpcIntroGui")       :: ScreenGui
local EpicPetSelectionTemplate = ReplicatedStorage:WaitForChild("EpicPetSelectionGui") :: ScreenGui

-- (선택) 펫 선택 서버 알림 이벤트
local PetEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
local PetSelectedEvent = PetEvents and PetEvents:FindFirstChild("PetSelected")
local LevelSync = ReplicatedStorage:FindFirstChild("LevelSync") -- 서버가 쏘던 그 이벤트

-- (권장) 서버 더블체크가 필요하면 RemoteFunction 사용 예:
-- local GateCheck = ReplicatedStorage:FindFirstChild("CanOpenEpicPet") :: RemoteFunction?

-- ===== 상태 =====
local activeButtonGui : ScreenGui? = nil
-- 기존:
-- local selectionOpen = false
-- local introOpen = false

-- 변경: 플래그 지우고 GUI 존재 체크 함수 사용
local function isOpen(name: string)
	return PlayerGui:FindFirstChild(name) ~= nil
end
local function isIntroOpen()     return isOpen("EpicNpcIntroGui_runtime") end
local function isSelectionOpen() return isOpen("EpicPetSelectionGui_runtime") end

local hasRequiredLevel = false

-- 요구 레벨 (ImageLabel 이름과 정확히 일치)
local PET_REQUIREMENTS = {
	golden_dog   = 100,
	Skeleton_Dog = 150,
	Robot_Dog    = 200,
}

-- 색상/텍스트
local ENABLED_COLOR   = Color3.fromRGB(39,174,96)   -- 활성 녹색
local DISABLED_COLOR  = Color3.fromRGB(120,120,120) -- 비활성 회색
local ENABLED_TXTCLR  = Color3.fromRGB(255,255,255)
local DISABLED_TXTCLR = Color3.fromRGB(220,220,220)
local SELECT_TEXT     = "Select"

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

-- 프로젝트에 맞게 경로 확인
local PetEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
local PetSelectedEvent = PetEvents and PetEvents:FindFirstChild("PetSelected")

-- 레벨 재계산 함수 + 와이어링
local function recomputeLevel(from)
	local lv = tonumber(LocalPlayer:GetAttribute("Level")) or 1
	hasRequiredLevel = (lv >= REQUIRED_LEVEL)
	-- print(("level=%d ok=%s (%s)"):format(lv, tostring(hasRequiredLevel), from or ""))
	-- 부족해지면 즉시 버튼 제거
	if not hasRequiredLevel and activeButtonGui then
		activeButtonGui:Destroy()
		activeButtonGui = nil
	end
end

-- 초기 1회
recomputeLevel("init")

-- 서버 동기화 수신 시 갱신
if LevelSync and LevelSync:IsA("RemoteEvent") then
	LevelSync.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and payload.Level then
			-- 굳이 SetAttribute 안 해도 되지만, 로컬 HUD/로직 통일을 위해 반영
			LocalPlayer:SetAttribute("Level", payload.Level)
			recomputeLevel("LevelSync")
		end
	end)
end

-- 클라에서 Attribute가 바뀌어도 즉시 반영(치트/테스트 포함)
LocalPlayer:GetAttributeChangedSignal("Level"):Connect(function()
	recomputeLevel("AttrChanged")
end)

local function currentLevel()
	return tonumber(LocalPlayer:GetAttribute("Level")) or 1
end

-- 버튼 비주얼/입력 상태 + 텍스트 설정
local function setButtonState(btn: TextButton, allowed: boolean, reqLevel: number?)
	if not btn then return end
	btn.Active = allowed
	btn.Selectable = allowed
	btn.AutoButtonColor = allowed

	-- 텍스트: 가능이면 "Select", 아니면 "Level XXX"
	btn.Text = allowed and SELECT_TEXT or string.format("Level %d", tonumber(reqLevel) or 0)

	-- 색/투명도
	pcall(function()
		btn.BackgroundColor3    = allowed and ENABLED_COLOR or DISABLED_COLOR
		btn.TextColor3          = allowed and ENABLED_TXTCLR or DISABLED_TXTCLR
		btn.TextTransparency    = allowed and 0 or 0.1
		btn.BackgroundTransparency = allowed and 0 or 0.15
	end)

	-- 썸네일도 약간 어둡게
	local parentImg = btn.Parent
	if parentImg and parentImg:IsA("ImageLabel") then
		pcall(function()
			parentImg.ImageTransparency = allowed and 0 or 0.15
		end)
	end
end


-- 이름→요구레벨 조회
local function canSelectPet(level: number, petName: string)
	local req = PET_REQUIREMENTS[petName]
	if not req then
		-- 정의가 없으면 기본적으로 선택 불가로 처리(원하면 true로 바꿔도 됨)
		return false, 9e9
	end
	return level >= req, req
end

-- ★ 이 함수만 기존 것 대신 사용
local function wireEpicSelectionGui(selectionGui: ScreenGui)
	local root = selectionGui:FindFirstChildOfClass("Frame") or selectionGui:FindFirstChild("Frame")
	if not root then return end

	local connections = {}

	local function refreshButtons()
		local lv = currentLevel()
		for _, node in ipairs(root:GetChildren()) do
			if node:IsA("ImageLabel") then
				local btn = node:FindFirstChild("Select")
				if btn and btn:IsA("TextButton") then
					local req = PET_REQUIREMENTS[node.Name]
					local allowed = req and (lv >= req) or false
					setButtonState(btn, allowed, req)
				end
			end
		end
	end

	-- Select 배선(미달이면 완전 무반응)
	for _, node in ipairs(root:GetChildren()) do
		if node:IsA("ImageLabel") then
			local btn = node:FindFirstChild("Select")
			if btn and btn:IsA("TextButton") then
				table.insert(connections, btn.MouseButton1Click:Connect(function()
					local lv  = currentLevel()
					local req = PET_REQUIREMENTS[node.Name]
					if not (req and lv >= req) then
						return -- 요구 레벨 미달: 아무 동작 X
					end
					-- 선택 가능: 서버에 전달 후 창 닫기
					if PetSelectedEvent and PetSelectedEvent:IsA("RemoteEvent") then
						PetSelectedEvent:FireServer(node.Name)
					end
					selectionGui:Destroy()
					for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
				end))
			end
		end
	end

	-- Close 버튼 → 그냥 닫기
	local closeBtn = root:FindFirstChild("Close")
	if closeBtn and closeBtn:IsA("TextButton") then
		table.insert(connections, closeBtn.MouseButton1Click:Connect(function()
			selectionGui:Destroy()
			for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
		end))
	end

	-- 레벨 변경 시 즉시 UI 반영 (치트/레벨업/서버 동기화 모두)
	table.insert(connections, LocalPlayer:GetAttributeChangedSignal("Level"):Connect(refreshButtons))
	local LevelSync = ReplicatedStorage:FindFirstChild("LevelSync")
	if LevelSync and LevelSync:IsA("RemoteEvent") then
		table.insert(connections, LevelSync.OnClientEvent:Connect(function(payload)
			if typeof(payload) == "table" and payload.Level then
				LocalPlayer:SetAttribute("Level", payload.Level)
				refreshButtons()
			end
		end))
	end

	-- 초기 1회 반영
	refreshButtons()

	-- 안전 정리
	table.insert(connections, selectionGui.Destroying:Connect(function()
		for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	end))
end



-- 첫 GUI 표시 (플래그 대신 존재 여부로 가드)
local function openIntroGui()
	if isIntroOpen() or isSelectionOpen() then return end
	if not EpicNpcIntroGuiTemplate then return end

	local gui = EpicNpcIntroGuiTemplate:Clone()
	gui.Name = "EpicNpcIntroGui_runtime"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Enabled = true
	gui.Parent = PlayerGui

	-- 연결들 관리
	local cons = {}
	local function cleanup()
		for _, c in ipairs(cons) do pcall(function() c:Disconnect() end) end
	end
	table.insert(cons, gui.Destroying:Connect(cleanup))

	local function closeIntro()
		if gui and gui.Parent then gui:Destroy() end
	end

	local function openSelection()
		if isSelectionOpen() or not EpicPetSelectionTemplate then return end
		local selectionGui = EpicPetSelectionTemplate:Clone()
		selectionGui.Name = "EpicPetSelectionGui_runtime"
		selectionGui.ResetOnSpawn = false
		selectionGui.IgnoreGuiInset = true
		selectionGui.Enabled = true
		selectionGui.Parent = PlayerGui
		if wireEpicSelectionGui then wireEpicSelectionGui(selectionGui) end
	end

	-- "OK" 또는 "OpenEpicPet" 버튼 연결 (둘 중 있는 걸 사용)
	local openBtn
	for _, name in ipairs({"OK", "OpenEpicPet"}) do
		openBtn = gui:FindFirstChild(name, true)
		if openBtn then break end
	end
	if openBtn and openBtn:IsA("TextButton") then
		local clicked = false
		table.insert(cons, openBtn.MouseButton1Click:Connect(function()
			if clicked then return end
			clicked = true
			closeIntro()
			openSelection()
		end))
	end

	-- Close 버튼 연결 (대소문자 변형 모두 탐색)
	local closeBtn = gui:FindFirstChild("Close", true) or gui:FindFirstChild("CLOSE", true)
	if closeBtn and closeBtn:IsA("TextButton") then
		table.insert(cons, closeBtn.MouseButton1Click:Connect(closeIntro))
	end
end



-- 상호작용 버튼 표시
local function showInteractButton()
	if isIntroOpen() or isSelectionOpen() then return end
	if not hasRequiredLevel then return end
	if activeButtonGui then activeButtonGui:Destroy() activeButtonGui = nil end

	local clickGui = NPCClickTemplate:Clone()
	clickGui.Name = "NPCClickGui_Epic"
	clickGui.ResetOnSpawn = false
	clickGui.Parent = PlayerGui
	activeButtonGui = clickGui

	local btn = clickGui:WaitForChild("NPCClick")
	if btn and btn:IsA("TextButton") then
		btn.MouseButton1Click:Connect(function()
			if activeButtonGui then activeButtonGui:Destroy() activeButtonGui = nil end
			openIntroGui()
		end)
	end
end

-- NPC 근접 체크(PrimaryPart 없을 때 폴백)
local function getNpcPos(model: Model)
	if model.PrimaryPart then return model.PrimaryPart.Position end
	-- PrimaryPart 미설정 시 피벗으로 계산
	return model:GetPivot().Position
end

task.spawn(function()
	while true do
		task.wait(0.3)
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp and npc_epic then
			local ok, npcPos = pcall(getNpcPos, npc_epic)
			if ok and npcPos then
				local dist = (npcPos - hrp.Position).Magnitude
				if dist <= INTERACTION_DISTANCE then
					if not activeButtonGui and hasRequiredLevel and (not isIntroOpen()) and (not isSelectionOpen()) then
						showInteractButton()
					end
				else
					if activeButtonGui then activeButtonGui:Destroy(); activeButtonGui = nil end
				end
			end
		end
	end
end)