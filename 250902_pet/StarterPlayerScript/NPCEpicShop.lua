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
local PET_LEVEL_REQ = {
	golden_dog   = 100,
	Skeleton_Dog = 150,
	Robot_Dog    = 200,
}

local PET_COIN_COST = {
	golden_dog   = 15,
	Skeleton_Dog = 20,
	Robot_Dog    = 25,
}

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

-- 프로젝트에 맞게 경로 확인
local PetEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
local PetSelectedEvent = PetEvents and PetEvents:FindFirstChild("PetSelected")
local CoinUpdate        = PetEvents and PetEvents:FindFirstChild("CoinUpdate")             -- RemoteEvent (서버가 잔액 브로드캐스트)
local TrySelectEpicPet  = PetEvents and PetEvents:FindFirstChild("TrySelectEpicPet")       -- RemoteFunction (있으면 사용; 없으면 생략)


-- 색상/텍스트
local ENABLED_COLOR   = Color3.fromRGB(39,174,96)   -- 활성 녹색
local DISABLED_COLOR  = Color3.fromRGB(120,120,120) -- 비활성 회색
local ENABLED_TXTCLR  = Color3.fromRGB(255,255,255)
local DISABLED_TXTCLR = Color3.fromRGB(220,220,220)
local SELECT_TEXT     = "Select"

-- ===== 클라이언트 상태 =====
local currentCoins = 0
local ownedOrDisabled = {}   -- [petName] = true  → 이 세션 동안 영구 비활성


-- 코인 업데이트 수신
if CoinUpdate and CoinUpdate:IsA("RemoteEvent") then
	CoinUpdate.OnClientEvent:Connect(function(balance)
		currentCoins = tonumber(balance) or currentCoins
		-- 열려있는 선택창이 있으면 그곳에서 refresh를 호출(아래 함수 내부에서 처리)
	end)
end


-- 상단 서비스들 근처에 추가
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SFXFolder = ReplicatedStorage:FindFirstChild("SFX")


local function playDenySfx()
	local cand = {"Error"}
	if not SFXFolder then return end
	local s
	for _, name in ipairs(cand) do
		local c = SFXFolder:FindFirstChild(name)
		if c and c:IsA("Sound") then s = c; break end
	end
	if not s then return end
	local clone = s:Clone()
	clone.Parent = PlayerGui
	clone:Play()
	Debris:AddItem(clone, (clone.TimeLength or 0) + 0.5)
end


local function shakeGui(obj: GuiObject)
	if not obj or not obj:IsA("GuiObject") then return end
	if obj:GetAttribute("Shaking") then return end
	obj:SetAttribute("Shaking", true)
	local origRot = obj.Rotation

	-- 좌우로 두 번 흔들고 원상복귀
	local tInfo = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true, 0)
	local t1 = TweenService:Create(obj, tInfo, {Rotation = origRot + 6})
	t1:Play(); t1.Completed:Wait()

	local t2 = TweenService:Create(obj, tInfo, {Rotation = origRot - 6})
	t2:Play(); t2.Completed:Wait()

	obj.Rotation = origRot
	obj:SetAttribute("Shaking", false)
end




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

-- 유틸
local function getLevel()  return tonumber(LocalPlayer:GetAttribute("Level")) or 1 end
local function canAfford(pet) return currentCoins >= (PET_COIN_COST[pet] or math.huge) end
local function meetsLevel(pet) return getLevel() >= (PET_LEVEL_REQ[pet] or math.huge) end


-- 버튼 비주얼/입력 상태 + 텍스트 설정

-- 기존 setButtonState를 이 버전으로 교체
local function setButtonState(btn: TextButton, enabled: boolean, petName: string)
	-- 클릭 이벤트는 항상 받되, 시각/자동컬러만 제어
	btn.Active = true
	btn.Selectable = enabled
	btn.AutoButtonColor = enabled

	if enabled then
		btn.Text = "Select"
		btn.TextColor3 = ENABLED_TXTCLR
		btn.BackgroundColor3 = ENABLED_COLOR
		btn.TextTransparency = 0
		btn.BackgroundTransparency = 0
	else
		local needLv  = PET_LEVEL_REQ[petName]
		local needC   = PET_COIN_COST[petName]
		local parts = {}
		if not meetsLevel(petName) then table.insert(parts, ("Lv %d"):format(needLv or 0)) end
		if not canAfford(petName)   then table.insert(parts, ("C %d"):format(needC or 0)) end
		btn.Text = table.concat(parts, " • ")
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



-- 이름→요구레벨 조회
local function canSelectPet(level: number, petName: string)
	local req = PET_LEVEL_REQ[petName]
	if not req then
		-- 정의가 없으면 기본적으로 선택 불가로 처리(원하면 true로 바꿔도 됨)
		return false, 9e9
	end
	return level >= req, req
end



-- ★ 선택 GUI 배선(레벨+코인+영구 비활성)
local function wireEpicSelectionGui(selectionGui: ScreenGui)
	local root = selectionGui:FindFirstChildOfClass("Frame") or selectionGui:FindFirstChild("Frame")
	if not root then return end

	local cons = {}

	local function isEnabledFor(p)
		if ownedOrDisabled[p] then return false end
		return meetsLevel(p) and canAfford(p)
	end

	local function refreshButtons()
		for _, node in ipairs(root:GetChildren()) do
			if node:IsA("ImageLabel") then
				local btn = node:FindFirstChild("Select")
				if btn and btn:IsA("TextButton") then
					setButtonState(btn, isEnabledFor(node.Name), node.Name)
				end
			end
		end
	end

	-- Select 클릭: 서버 검증/차감/소유 기록은 RemoteFunction 있으면 거기서 처리
	for _, node in ipairs(root:GetChildren()) do
		if node:IsA("ImageLabel") then
			local btn = node:FindFirstChild("Select")
			if btn and btn:IsA("TextButton") then
				-- wireEpicSelectionGui 내부, btn.MouseButton1Click:Connect(...) 부분 교체
				table.insert(cons, btn.MouseButton1Click:Connect(function()
					local petName = node.Name
					if not isEnabledFor(petName) then
						-- ✅ 선택 불가: 흔들림 + 사운드만
						shakeGui(node)      -- 썸네일 통째로 흔들기(또는 shakeGui(btn)로 버튼만)
						playDenySfx()
						return
					end

					-- ⬇️ 기존 가능 로직 그대로 유지
					local cost = PET_COIN_COST[petName] or 0
					local ok = false
					if TrySelectEpicPet and TrySelectEpicPet:IsA("RemoteFunction") then
						local resp
						local success = pcall(function()
							resp = TrySelectEpicPet:InvokeServer({pet = petName, cost = cost})
						end)
						ok = success and resp and resp.ok == true
						if ok and resp.coins ~= nil then
							currentCoins = tonumber(resp.coins) or currentCoins
						end
					else
						ok = true
						if PetSelectedEvent and PetSelectedEvent:IsA("RemoteEvent") then
							PetSelectedEvent:FireServer(petName)
						end
					end

					if ok then
						ownedOrDisabled[petName] = true
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

				-- Close → 닫기
local closeBtn = root:FindFirstChild("Close")
if closeBtn and closeBtn:IsA("TextButton") then
	table.insert(cons, closeBtn.MouseButton1Click:Connect(function()
		selectionGui:Destroy()
		for _, c in ipairs(cons) do pcall(function() c:Disconnect() end) end
	end))
end

-- 레벨/코인 변동 시 즉시 갱신
table.insert(cons, LocalPlayer:GetAttributeChangedSignal("Level"):Connect(refreshButtons))
local LevelSync = ReplicatedStorage:FindFirstChild("LevelSync")
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

-- 초기 반영
refreshButtons()

-- 안전 정리
table.insert(cons, selectionGui.Destroying:Connect(function()
	for _, c in ipairs(cons) do pcall(function() c:Disconnect() end) end
end))
end

-- 필요 시 외부에서 호출할 수 있게
_G.wireEpicSelectionGui = wireEpicSelectionGui



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

