-- LocalScript: "EpicPet NPC" 상호작용 + 레벨 게이트 + 2단계 GUI 플로우
local Players            = game:GetService("Players")
local LocalPlayer        = Players.LocalPlayer
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local PlayerGui          = LocalPlayer:WaitForChild("PlayerGui")
local TweenService       = game:GetService("TweenService")
local Debris             = game:GetService("Debris")

-- ===== 설정 =====
local REQUIRED_LEVEL = 100
local INTERACTION_DISTANCE = 5

-- ✅ Demon_Dog 전용 상수
local DEMON_NAME       = "Demon_Dog"
local DEMON_LEVEL_REQ  = 250
local DEMON_COIN_COST  = 30
local GREATTEAM_TAG    = "ui:greatteam_pet_enable"  -- BadgeManager에 등록한 태그와 일치해야 함

local npc_epic = workspace:WaitForChild("NPC_LIVE"):WaitForChild("vendor_ninja(Lv.100)")

-- 템플릿들
local NPCClickTemplate        = ReplicatedStorage:WaitForChild("NPCClick")              :: ScreenGui
local EpicNpcIntroGuiTemplate = ReplicatedStorage:WaitForChild("EpicNpcIntroGui")       :: ScreenGui
local EpicPetSelectionTemplate= ReplicatedStorage:WaitForChild("EpicPetSelectionGui")   :: ScreenGui
local LevelSync               = ReplicatedStorage:FindFirstChild("LevelSync")

-- Remotes
local PetEventsFolder  = ReplicatedStorage:WaitForChild("PetEvents")
local PetSelectedEvent = PetEventsFolder:WaitForChild("PetSelected")
local TrySelectEpicPet = PetEventsFolder:FindFirstChild("TrySelectEpicPet")

local RemotesFolder    = ReplicatedStorage:WaitForChild("RemoteEvents")
local CoinUpdate       = RemotesFolder:WaitForChild("CoinUpdate")

-- ✅ 배지 언락 태그 동기화(RemoteEvent)
local BadgeFolder      = ReplicatedStorage:FindFirstChild("BadgeRemotes")
local UnlockSyncRE     = BadgeFolder and BadgeFolder:FindFirstChild("UnlockSync")

-- ===== 상태 =====
local activeButtonGui : ScreenGui? = nil
local hasRequiredLevel = false
local currentCoins = 0
local ownedOrDisabled = {}   -- [petName] = true  → 이 세션 동안 영구 비활성

-- 클라/서버 동일 테이블(기존 3종)
local PET_LEVEL_REQ = { golden_dog=100, Skeleton_Dog=150, Robot_Dog=200 }
local PET_COIN_COST = { golden_dog=15,  Skeleton_Dog=20,  Robot_Dog=25  }

-- ✅ Demon_Dog 요구조건을 테이블에 합류
PET_LEVEL_REQ[DEMON_NAME] = DEMON_LEVEL_REQ
PET_COIN_COST[DEMON_NAME] = DEMON_COIN_COST

-- 색/텍스트
local ENABLED_COLOR   = Color3.fromRGB(39,174,96)
local DISABLED_COLOR  = Color3.fromRGB(120,120,120)
local ENABLED_TXTCLR  = Color3.fromRGB(255,255,255)
local DISABLED_TXTCLR = Color3.fromRGB(220,220,220)
local SELECT_TEXT     = "Select"

-- 유틸
local function isOpen(name: string) return PlayerGui:FindFirstChild(name) ~= nil end
local function isIntroOpen()     return isOpen("EpicNpcIntroGui_runtime") end
local function isSelectionOpen() return isOpen("EpicPetSelectionGui_runtime") end

-- ===== 배지 언락 상태 =====
local hasGreatTeamUnlock = (LocalPlayer:GetAttribute("HasGreatTeamBadge") == true)

local function setHasGreatTeam(v: boolean)
	hasGreatTeamUnlock = v and true or false
	-- 속성으로도 노출(다른 GUI와 공유 가능)
	LocalPlayer:SetAttribute("HasGreatTeamBadge", hasGreatTeamUnlock)
	-- 선택창 열려 있으면 즉시 새 상태 반영
	if isSelectionOpen() then
		local g = PlayerGui:FindFirstChild("EpicPetSelectionGui_runtime") :: ScreenGui?
		if g and _G.refreshEpicDemonSlot then _G.refreshEpicDemonSlot(g) end
	end
end

-- UnlockSync 수신(배지 지급/접속 시 동기화)
if UnlockSyncRE and UnlockSyncRE:IsA("RemoteEvent") then
	UnlockSyncRE.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and typeof(payload.tags) == "table" then
			local ok = false
			for _, tag in ipairs(payload.tags) do
				if tag == GREATTEAM_TAG then ok = true break end
			end
			setHasGreatTeam(ok)
		end
	end)
end

-- 속성 변동도 감시(서버에서 속성만 갱신해줄 수도 있음)
LocalPlayer:GetAttributeChangedSignal("HasGreatTeamBadge"):Connect(function()
	setHasGreatTeam(LocalPlayer:GetAttribute("HasGreatTeamBadge") == true)
end)

-- ===== 코인/레벨 동기화 =====
if CoinUpdate and CoinUpdate:IsA("RemoteEvent") then
	CoinUpdate.OnClientEvent:Connect(function(balance)
		currentCoins = tonumber(balance) or currentCoins
		if isSelectionOpen() then
			local g = PlayerGui:FindFirstChild("EpicPetSelectionGui_runtime")
			if g and _G.refreshEpicButtons then _G.refreshEpicButtons(g) end
		end
	end)
end

-- SFX
local SFXFolder = ReplicatedStorage:FindFirstChild("SFX")
local function playDenySfx()
	if not SFXFolder then return end
	local s = SFXFolder:FindFirstChild("Error")
	if not (s and s:IsA("Sound")) then return end
	local c = s:Clone(); c.Parent = PlayerGui; c:Play()
	Debris:AddItem(c, (c.TimeLength or 0) + 0.5)
end
local function shakeGui(obj: GuiObject)
	if not obj or not obj:IsA("GuiObject") then return end
	if obj:GetAttribute("Shaking") then return end
	obj:SetAttribute("Shaking", true)
	local base = obj.Rotation
	local info = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0)
	local t1 = TweenService:Create(obj, info, {Rotation = base + 6}); t1:Play(); t1.Completed:Wait()
	local t2 = TweenService:Create(obj, info, {Rotation = base - 6}); t2:Play(); t2.Completed:Wait()
	obj.Rotation = base
	obj:SetAttribute("Shaking", false)
end

-- 레벨 재계산
local function recomputeLevel()
	local lv = tonumber(LocalPlayer:GetAttribute("Level")) or 1
	hasRequiredLevel = (lv >= REQUIRED_LEVEL)
	if not hasRequiredLevel and activeButtonGui then
		activeButtonGui:Destroy(); activeButtonGui = nil
	end
end
recomputeLevel()
if LevelSync and LevelSync:IsA("RemoteEvent") then
	LevelSync.OnClientEvent:Connect(function(payload)
		if typeof(payload) == "table" and payload.Level then
			LocalPlayer:SetAttribute("Level", payload.Level)
			recomputeLevel()
			if isSelectionOpen() then
				local g = PlayerGui:FindFirstChild("EpicPetSelectionGui_runtime")
				if g and _G.refreshEpicButtons then _G.refreshEpicButtons(g) end
			end
		end
	end)
end
LocalPlayer:GetAttributeChangedSignal("Level"):Connect(function()
	recomputeLevel()
	if isSelectionOpen() then
		local g = PlayerGui:FindFirstChild("EpicPetSelectionGui_runtime")
		if g and _G.refreshEpicButtons then _G.refreshEpicButtons(g) end
	end
end)

local function getLevel() return tonumber(LocalPlayer:GetAttribute("Level")) or 1 end
local function canAfford(pet) return currentCoins >= (PET_COIN_COST[pet] or math.huge) end
local function meetsLevel(pet) return getLevel() >= (PET_LEVEL_REQ[pet] or math.huge) end

-- 버튼 비주얼
local function setButtonState(btn: TextButton, enabled: boolean, petName: string)
	btn.Active = true
	btn.Selectable = enabled
	btn.AutoButtonColor = enabled
	if enabled then
		local cost = PET_COIN_COST[petName] or 0
		btn.Text = ("%d coin %s"):format(cost, SELECT_TEXT)
		btn.TextColor3 = ENABLED_TXTCLR
		btn.BackgroundColor3 = ENABLED_COLOR
		btn.TextTransparency = 0
		btn.BackgroundTransparency = 0
	else
		local parts = {}
		if not meetsLevel(petName) then table.insert(parts, ("Lv %d"):format(PET_LEVEL_REQ[petName] or 0)) end
		if not canAfford(petName)   then table.insert(parts, ("C %d"):format(PET_COIN_COST[petName] or 0)) end
		btn.Text = (#parts > 0) and table.concat(parts, " • ") or "Locked"
		btn.TextColor3 = DISABLED_TXTCLR
		btn.BackgroundColor3 = DISABLED_COLOR
		btn.TextTransparency = 0.1
		btn.BackgroundTransparency = 0.15
	end
	local parentImg = btn.Parent
	if parentImg and parentImg:IsA("ImageLabel") then
		parentImg.ImageTransparency = enabled and 0 or 0.15
	end
end

-- 선택 GUI 배선
local function wireEpicSelectionGui(selectionGui: ScreenGui)
	local root = selectionGui:FindFirstChildOfClass("Frame") or selectionGui:FindFirstChild("Frame")
	if not root then return end

	local cons = {}

	-- ✅ Demon_Dog 가시성 제어 (배지 없으면 "아예 안 보임 & 클릭 불가")
	local function refreshDemonVisibility()
		local node = root:FindFirstChild(DEMON_NAME)
		if not node or not node:IsA("ImageLabel") then return end
		local show = hasGreatTeamUnlock  -- 오직 배지 여부로만 visibility 결정
		node.Visible = show
		local btn = node:FindFirstChild("Select", true)
		if btn and btn:IsA("GuiButton") then
			btn.Active = show
			btn.AutoButtonColor = show
		end
	end

	local function isEnabledFor(pet: string)
		if ownedOrDisabled[pet] then return false end
		-- Demon_Dog는 배지까지 체크
		if pet == DEMON_NAME then
			if not hasGreatTeamUnlock then return false end
			return (getLevel() >= DEMON_LEVEL_REQ) and (currentCoins >= DEMON_COIN_COST)
		end
		return meetsLevel(pet) and canAfford(pet)
	end

	local function refreshButtons()
		-- Demon 먼저 가시성 갱신
		refreshDemonVisibility()
		for _, node in ipairs(root:GetChildren()) do
			if node:IsA("ImageLabel") then
				local btn = node:FindFirstChild("Select", true)
				if btn and btn:IsA("TextButton") then
					local petName = node.Name
					setButtonState(btn, isEnabledFor(petName), petName)
				end
			end
		end
	end

	-- Select 클릭 핸들러
	for _, node in ipairs(root:GetChildren()) do
		if node:IsA("ImageLabel") then
			local btn = node:FindFirstChild("Select", true)
			if btn and btn:IsA("GuiButton") then
				table.insert(cons, btn.MouseButton1Click:Connect(function()
					local petName = node.Name
					if not isEnabledFor(petName) then
						shakeGui(node); playDenySfx(); refreshButtons(); return
					end

					local cost = PET_COIN_COST[petName] or 0
					local ok = false
					if TrySelectEpicPet and TrySelectEpicPet:IsA("RemoteFunction") then
						local resp
						local success = pcall(function()
							resp = TrySelectEpicPet:InvokeServer({pet = petName, cost = cost})
						end)
						ok = success and resp and resp.ok == true
						if resp and resp.coins ~= nil then
							currentCoins = tonumber(resp.coins) or currentCoins
						end
					else
						if PetSelectedEvent and PetSelectedEvent:IsA("RemoteEvent") then
							PetSelectedEvent:FireServer(petName)
						end
						ok = false
					end

					if ok then
						ownedOrDisabled[petName] = true   -- 세션 즉시 비활성
						refreshButtons()
						selectionGui:Destroy()
						for _, c in ipairs(cons) do pcall(function() c:Disconnect() end) end
					else
						refreshButtons()
					end
				end))
			end
		end
	end

	-- Close
	local closeBtn = root:FindFirstChild("Close", true)
	if closeBtn and closeBtn:IsA("TextButton") then
		table.insert(cons, closeBtn.MouseButton1Click:Connect(function()
			selectionGui:Destroy()
			for _, c in ipairs(cons) do pcall(function() c:Disconnect() end) end
		end))
	end

	-- 동적 갱신 이벤트들
	table.insert(cons, LocalPlayer:GetAttributeChangedSignal("Level"):Connect(refreshButtons))
	if LevelSync and LevelSync:IsA("RemoteEvent") then
		table.insert(cons, LevelSync.OnClientEvent:Connect(function(payload)
			if typeof(payload) == "table" and payload.Level then
				LocalPlayer:SetAttribute("Level", payload.Level)
				refreshButtons()
			end
		end))
	end
	if CoinUpdate and CoinUpdate:IsA("RemoteEvent") then
		table.insert(cons, CoinUpdate.OnClientEvent:Connect(function(balance)
			currentCoins = tonumber(balance) or currentCoins
			refreshButtons()
		end))
	end
	if UnlockSyncRE and UnlockSyncRE:IsA("RemoteEvent") then
		table.insert(cons, UnlockSyncRE.OnClientEvent:Connect(function(payload)
			-- setHasGreatTeam() 내부에서 가시성/버튼 갱신을 호출하게 해도 되지만,
			-- 이 GUI가 열려 있을 때 확실히 새로고침
			refreshButtons()
		end))
	end
	table.insert(cons, LocalPlayer:GetAttributeChangedSignal("HasGreatTeamBadge"):Connect(refreshButtons))

	-- 초기 반영
	refreshButtons()

	-- 안전 정리
	table.insert(cons, selectionGui.Destroying:Connect(function()
		for _, c in ipairs(cons) do pcall(function() c:Disconnect() end) end
	end))

	-- 외부에서 강제 새로고침할 때 호출할 수 있게 export
	_G.refreshEpicButtons   = function(g) if g == selectionGui then refreshButtons() end end
	_G.refreshEpicDemonSlot = function(g) if g == selectionGui then refreshDemonVisibility() end end
end
_G.wireEpicSelectionGui = wireEpicSelectionGui

-- === 이하: 인트로/상호작용 버튼/근접 체크는 기존 그대로 ===
-- (생략: 너의 원본 코드를 유지)




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

