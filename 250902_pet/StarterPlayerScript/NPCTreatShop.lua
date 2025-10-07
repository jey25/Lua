-- LocalScript: EpicTreat NPC
-- 레벨 10 이상만 상점 열기 가능, duckbone(Jump up) 버튼은 Jumper 배지 보유자만 활성화

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ===== 설정 =====
local REQUIRED_LEVEL = 10
local INTERACTION_DISTANCE = 5

-- NPC 경로
local npc = workspace:WaitForChild("NPC_LIVE"):WaitForChild("xiaoleung")

-- 템플릿
local NPCClickTemplate = ReplicatedStorage:WaitForChild("NPCClick")      :: ScreenGui
local EpicTreatTemplate = ReplicatedStorage:WaitForChild("EpicTreatGui") :: ScreenGui

-- 리모트
local RemotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents") or Instance.new("Folder", ReplicatedStorage)
RemotesFolder.Name = "RemoteEvents"
local CoinUpdate = RemotesFolder:FindFirstChild("CoinUpdate") or Instance.new("RemoteEvent", RemotesFolder)
CoinUpdate.Name = "CoinUpdate"

local TreatFolder = ReplicatedStorage:FindFirstChild("TreatEvents") or Instance.new("Folder", ReplicatedStorage)
TreatFolder.Name = "TreatEvents"
local TryBuyTreat     = TreatFolder:WaitForChild("TryBuyTreat")     :: RemoteFunction
local GetTreatUnlocks = TreatFolder:WaitForChild("GetTreatUnlocks") :: RemoteFunction -- ★ Jumper 배지 언락 질의

-- SFX(옵션)
local SFXFolder = ReplicatedStorage:FindFirstChild("SFX")

-- ===== 상품 요구조건(클라/서버 동일 테이블) =====
local TREAT_LEVEL_REQ = { Munchies = 30, duckbone = 20, DogGum = 10,  Snack = 10 }
local TREAT_COIN_COST = { Munchies = 5,  duckbone = 3,  DogGum = 3,   Snack = 1 }

-- ===== 상태 =====
local activeButtonGui : ScreenGui? = nil
local currentCoins = 0
local badgeUnlocks = { duckbone = false, jumpup = false } -- 서버 응답 캐시

-- 편의
local function levelOK() return (tonumber(LocalPlayer:GetAttribute("Level")) or 1) >= REQUIRED_LEVEL end
local function getLevel() return tonumber(LocalPlayer:GetAttribute("Level")) or 1 end
local function isOpen(name: string) return PlayerGui:FindFirstChild(name) ~= nil end

-- 아이템 키 유틸 (원래 있던 canon 유지)
local function canon(s: string): string
	local v = string.lower(s or "")
	v = (v:gsub("%s+", "")):gsub("_", "")
	return v
end

-- ★ 추가: 표기 → 실제 테이블 키 매핑
local function realKey(name: string): string
	local k = canon(name)
	if k == "munchies" then return "Munchies" end
	if k == "doggum"   then return "DogGum"   end
	if k == "snack"    then return "Snack"    end
	if k == "duckbone" or k == "jumpup" then return "duckbone" end
	return name -- 안전 fallback (이미 정확 키일 때)
end

local function needsJumper(itemName: string): boolean
	local k = canon(itemName)
	return (k == "duckbone" or k == "jumpup")
end

-- ★ 수정: 서버 속성도 인정 + 캐시 병행
local function isBadgeUnlocked(itemName: string): boolean
	if not needsJumper(itemName) then return true end
	if LocalPlayer:GetAttribute("HasJumperBadge") == true then return true end
	return badgeUnlocks.duckbone or badgeUnlocks.jumpup
end

-- ★ 수정: 비용/레벨 판단에 realKey 사용
local function canAfford(name: string) return currentCoins >= (TREAT_COIN_COST[realKey(name)] or math.huge) end
local function meetsLevel(name: string) return getLevel() >= (TREAT_LEVEL_REQ[realKey(name)] or math.huge) end

local function canEnable(itemName: string): boolean
	return meetsLevel(itemName) and canAfford(itemName) and isBadgeUnlocked(itemName)
end

-- 에러 사운드 & 흔들림
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

-- 버튼 상태 렌더
local ENABLED_COLOR   = Color3.fromRGB(39,174,96)
local DISABLED_COLOR  = Color3.fromRGB(120,120,120)
local ENABLED_TXTCLR  = Color3.fromRGB(255,255,255)
local DISABLED_TXTCLR = Color3.fromRGB(220,220,220)

-- ★ 수정: 라벨 문구도 realKey 기준으로
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
		local rk = realKey(itemName)
		local parts = {}
		if not meetsLevel(itemName) then table.insert(parts, ("Lv %d"):format(TREAT_LEVEL_REQ[rk] or 0)) end
		if not canAfford(itemName)   then table.insert(parts, ("C %d"):format(TREAT_COIN_COST[rk] or 0)) end
		if not isBadgeUnlocked(itemName) and needsJumper(itemName) then
			table.insert(parts, "Jumper Badge")
		end
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

-- ▼ 공통 재렌더
local function rerenderButtons()
	local gui = PlayerGui:FindFirstChild("EpicTreatGui_runtime")
	if not gui then return end
	local root = gui:FindFirstChild("Frame") or gui:FindFirstChildOfClass("Frame")
	if not root then return end
	for _, node in ipairs(root:GetChildren()) do
		if node:IsA("ImageLabel") then
			local btn = node:FindFirstChild("Select", true)
			if btn and btn:IsA("TextButton") then
				local name = node.Name
				setButtonState(btn, canEnable(name), name)
			end
		end
	end
end

-- 코인 갱신 시 버튼 리프레시
CoinUpdate.OnClientEvent:Connect(function(balance)
	currentCoins = tonumber(balance) or currentCoins
	rerenderButtons()
end)

-- 배지 언락 상태 질의
local function refreshBadgeUnlocks()
	local ok, resp = pcall(function()
		return GetTreatUnlocks:InvokeServer()
	end)
	if ok and typeof(resp) == "table" then
		badgeUnlocks.duckbone = resp.duckbone and true or false
		badgeUnlocks.jumpup   = resp.jumpup and true or false
	end
end

-- 서버가 HasJumperBadge 갱신 시 즉시 반영
LocalPlayer:GetAttributeChangedSignal("HasJumperBadge"):Connect(function()
	refreshBadgeUnlocks()
	rerenderButtons()
end)

-- GUI 열기 (레벨 10 이상만)
local function openTreatGui()
	if not levelOK() then return end
	if isOpen("EpicTreatGui_runtime") then return end

	refreshBadgeUnlocks() -- 서버와 동기화(서버가 HasJumperBadge도 세팅)

	local gui = EpicTreatTemplate:Clone()
	gui.Name = "EpicTreatGui_runtime"
	gui.ResetOnSpawn = false
	gui.Enabled = true
	gui.Parent = PlayerGui

	local root = gui:FindFirstChild("Frame") or gui:FindFirstChildOfClass("Frame")
	if not root then return end

	local closeBtn = root:FindFirstChild("Close", true)
	if closeBtn and closeBtn:IsA("GuiButton") then
		closeBtn.MouseButton1Click:Connect(function() gui:Destroy() end)
	end

	for _, node in ipairs(root:GetChildren()) do
		if node:IsA("ImageLabel") then
			local btn = node:FindFirstChild("Select", true)
			if btn and btn:IsA("TextButton") then
				local itemName = node.Name
				setButtonState(btn, canEnable(itemName), itemName)

				btn.MouseButton1Click:Connect(function()
					if not canEnable(itemName) then
						shakeGui(node); playDenySfx()
						setButtonState(btn, canEnable(itemName), itemName)
						return
					end

					local resp
					local ok = pcall(function()
						resp = TryBuyTreat:InvokeServer({ item = itemName })
					end)

					if ok and typeof(resp) == "table" and resp.ok then
						if resp.coins ~= nil then
							currentCoins = tonumber(resp.coins) or currentCoins
						end
						gui:Destroy()
					else
						shakeGui(node); playDenySfx()
						if resp and resp.coins ~= nil then
							currentCoins = tonumber(resp.coins) or currentCoins
						end
						if resp and resp.reason == "LockedByBadge" then
							refreshBadgeUnlocks()
						end
						setButtonState(btn, canEnable(itemName), itemName)
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
		btn.AutoButtonColor = true
		btn.Active = true
		btn.Modal = false
		btn.MouseButton1Click:Connect(function()
			if not levelOK() then
				shakeGui(btn); playDenySfx()
				return
			end
			if activeButtonGui then activeButtonGui:Destroy(); activeButtonGui = nil end
			openTreatGui()
		end)
	end
end

-- 레벨 변동 시 버튼 숨김/재렌더
LocalPlayer:GetAttributeChangedSignal("Level"):Connect(function()
	if not levelOK() and activeButtonGui then
		activeButtonGui:Destroy()
		activeButtonGui = nil
	end
	rerenderButtons()
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
