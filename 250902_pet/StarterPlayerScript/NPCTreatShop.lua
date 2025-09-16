-- LocalScript: EpicTreat NPC
-- 레벨 10 이상일 때 NPC 근처에서 NPCClick 버튼 노출 → 클릭 시 EpicTreatGui 열림
-- 각 상품 Select 클릭 → 서버 RF로 구매 시도(레벨/코인 검증 및 차감) → 성공/실패 반영
-- 실패 시 버튼 흔들림/에러 SFX, 성공 시 창 즉시 닫힘 (재구매 제한 없음)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ===== 설정 =====
local REQUIRED_LEVEL = 10
local INTERACTION_DISTANCE = 5

-- NPC 경로(환경에 맞게 수정)
local npc = workspace:WaitForChild("NPC_LIVE"):WaitForChild("xiaoleung")

-- 템플릿
local NPCClickTemplate = ReplicatedStorage:WaitForChild("NPCClick")          :: ScreenGui
local EpicTreatTemplate = ReplicatedStorage:WaitForChild("EpicTreatGui")     :: ScreenGui

-- 리모트
local RemotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder", ReplicatedStorage)
RemotesFolder.Name = "RemoteEvents"
local CoinUpdate = RemotesFolder:FindFirstChild("CoinUpdate") or Instance.new("RemoteEvent", RemotesFolder)
CoinUpdate.Name = "CoinUpdate"

local TreatFolder = ReplicatedStorage:FindFirstChild("TreatEvents") or Instance.new("Folder", ReplicatedStorage)
TreatFolder.Name = "TreatEvents"
local TryBuyTreat = TreatFolder:FindFirstChild("TryBuyTreat") or Instance.new("RemoteFunction", TreatFolder)
TryBuyTreat.Name = "TryBuyTreat" -- 서버 스크립트에서 실제 로직 구현

-- SFX(옵션)
local SFXFolder = ReplicatedStorage:FindFirstChild("SFX")

-- ===== 상품 요구조건(클라/서버 동일 테이블) =====
-- 필요값은 마음대로 조정하세요
local TREAT_LEVEL_REQ = { Munchies = 20, DogGum = 10,  Snack = 10 }
local TREAT_COIN_COST = { Munchies = 2, DogGum = 1,  Snack = 1 }

-- ===== 상태 =====
local activeButtonGui : ScreenGui? = nil
local currentCoins = 0

-- 편의
local function levelOK() return (tonumber(LocalPlayer:GetAttribute("Level")) or 1) >= REQUIRED_LEVEL end
local function getLevel() return tonumber(LocalPlayer:GetAttribute("Level")) or 1 end
local function canAfford(name: string) return currentCoins >= (TREAT_COIN_COST[name] or math.huge) end
local function meetsLevel(name: string) return getLevel() >= (TREAT_LEVEL_REQ[name] or math.huge) end
local function isOpen(name: string) return PlayerGui:FindFirstChild(name) ~= nil end

-- 에러 사운드 & 흔들림 (이전 GUI와 동일 느낌)
local function playDenySfx()
	if not SFXFolder then return end
	local s = SFXFolder:FindFirstChild("Error")
	if s and s:IsA("Sound") then
		local c = s:Clone()
		c.Parent = PlayerGui
		c:Play()
		Debris:AddItem(c, (c.TimeLength or 0) + 0.5)
	end
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

-- 버튼 상태 렌더 (문구/색상)
local ENABLED_COLOR   = Color3.fromRGB(39,174,96)
local DISABLED_COLOR  = Color3.fromRGB(120,120,120)
local ENABLED_TXTCLR  = Color3.fromRGB(255,255,255)
local DISABLED_TXTCLR = Color3.fromRGB(220,220,220)

local function setButtonState(btn: TextButton, enabled: boolean, itemName: string)
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
		local parts = {}
		if not meetsLevel(itemName) then table.insert(parts, ("Lv %d"):format(TREAT_LEVEL_REQ[itemName] or 0)) end
		if not canAfford(itemName)   then table.insert(parts, ("C %d"):format(TREAT_COIN_COST[itemName] or 0)) end
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

-- 코인 브로드캐스트 수신 → 버튼 리프레시
CoinUpdate.OnClientEvent:Connect(function(balance)
	currentCoins = tonumber(balance) or currentCoins
	-- 열려있으면 리프레시
	local gui = PlayerGui:FindFirstChild("EpicTreatGui_runtime")
	if not gui then return end
	local root = gui:FindFirstChild("Frame") or gui:FindFirstChildOfClass("Frame")
	if not root then return end
	for _, node in ipairs(root:GetChildren()) do
		if node:IsA("ImageLabel") then
			local btn = node:FindFirstChild("Select", true)
			if btn and btn:IsA("TextButton") then
				local name = node.Name
				setButtonState(btn, meetsLevel(name) and canAfford(name), name)
			end
		end
	end
end)

-- GUI 열기
local function openTreatGui()
	if isOpen("EpicTreatGui_runtime") then return end

	local gui = EpicTreatTemplate:Clone()
	gui.Name = "EpicTreatGui_runtime"
	gui.ResetOnSpawn = false
	gui.Enabled = true
	gui.Parent = PlayerGui

	local root = gui:FindFirstChild("Frame") or gui:FindFirstChildOfClass("Frame")
	if not root then return end

	-- 닫기
	local closeBtn = root:FindFirstChild("Close", true)
	if closeBtn and closeBtn:IsA("GuiButton") then
		closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)
	end

	-- 버튼 와이어링
	for _, node in ipairs(root:GetChildren()) do
		if node:IsA("ImageLabel") then
			local btn = node:FindFirstChild("Select", true)
			if btn and btn:IsA("TextButton") then
				local itemName = node.Name

				-- 초기 상태
				setButtonState(btn, meetsLevel(itemName) and canAfford(itemName), itemName)

				btn.MouseButton1Click:Connect(function()
					-- 가능 여부 최종 체크
					if not (meetsLevel(itemName) and canAfford(itemName)) then
						shakeGui(node)
						playDenySfx()
						setButtonState(btn, meetsLevel(itemName) and canAfford(itemName), itemName)
						return
					end

					-- 서버 구매 시도 (레벨/코인 서버 검증 + 차감 + 효과)
					local resp
					local ok = pcall(function()
						resp = TryBuyTreat:InvokeServer({ item = itemName })
					end)

					if ok and typeof(resp) == "table" and resp.ok then
						-- 서버에서 차감 후 최신 코인 잔액 동기
						if resp.coins ~= nil then
							currentCoins = tonumber(resp.coins) or currentCoins
						end
						gui:Destroy() -- 성공 시 즉시 닫기
					else
						shakeGui(node)
						playDenySfx()
						-- 서버 응답 기반으로 재표시
						if resp and resp.coins ~= nil then
							currentCoins = tonumber(resp.coins) or currentCoins
						end
						setButtonState(btn, meetsLevel(itemName) and canAfford(itemName), itemName)
					end
				end)
			end
		end
	end
end

-- NPC 클릭 버튼
local function showInteractButton()
	if activeButtonGui then activeButtonGui:Destroy(); activeButtonGui = nil end
	local g = NPCClickTemplate:Clone()
	g.Name = "NPCClickGui_Treat"
	g.ResetOnSpawn = false
	g.Parent = PlayerGui
	activeButtonGui = g

	local btn = g:FindFirstChild("NPCClick", true)
	if btn and btn:IsA("GuiButton") then
		btn.MouseButton1Click:Connect(function()
			if activeButtonGui then activeButtonGui:Destroy(); activeButtonGui = nil end
			openTreatGui()
		end)
	end
end

-- 레벨 변동 시 클릭버튼 숨김 처리
LocalPlayer:GetAttributeChangedSignal("Level"):Connect(function()
	if not levelOK() and activeButtonGui then
		activeButtonGui:Destroy()
		activeButtonGui = nil
	end
end)

-- NPC 근접 루프
local function getNpcPos(model: Model)
	if model.PrimaryPart then return model.PrimaryPart.Position end
	return model:GetPivot().Position
end

task.spawn(function()
	while true do
		task.wait(0.3)
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not (hrp and npc) then
			if activeButtonGui then activeButtonGui:Destroy(); activeButtonGui = nil end
			continue
		end
		local ok, pos = pcall(getNpcPos, npc)
		if not ok then continue end

		local dist = (pos - hrp.Position).Magnitude
		if dist <= INTERACTION_DISTANCE and levelOK() and not isOpen("EpicTreatGui_runtime") then
			if not activeButtonGui then showInteractButton() end
		else
			if activeButtonGui then activeButtonGui:Destroy(); activeButtonGui = nil end
		end
	end
end)
