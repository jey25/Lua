--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- GUI 참조
local coinShopBtn = script.Parent :: ImageButton
local coinShopTemplate = ReplicatedStorage:WaitForChild("CoinShopGui") :: ScreenGui

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local CoinUpdate = Remotes:WaitForChild("CoinUpdate") :: RemoteEvent
local GetCoinState = Remotes:WaitForChild("GetCoinState") :: RemoteFunction

-- Developer Product IDs
local PRODUCTS: {[string]: number} = {
	["1coin"] = 3411337008,
	["5coin"] = 3411337007,
}

-- 상태
local currentCoins: number = 0
local maxCoins: number = 0
local activeGui: ScreenGui? = nil

-- 버튼 색상
local ENABLED_COLOR = Color3.fromRGB(39, 174, 96)
local DISABLED_COLOR = Color3.fromRGB(120, 120, 120)
local ENABLED_TXTCLR  = Color3.fromRGB(255, 255, 255)
local DISABLED_TXTCLR = Color3.fromRGB(220, 220, 220)

-- SFX
local ErrorSFX = ReplicatedStorage:WaitForChild("SFX"):WaitForChild("Error") :: Sound

-- ① 서버에서 현재 값 1회 동기화 (GUI 띄우기 전에 호출)
local function syncOnceFromServer(): ()
	local ok, balance, maxBalance = pcall(function()
		return GetCoinState:InvokeServer()
	end)
	if ok then
		currentCoins = tonumber(balance) or 0
		maxCoins = tonumber(maxBalance) or 0
	end
end

local function playErrorSFX(): ()
	local sfx = ErrorSFX:Clone()
	sfx.Parent = SoundService
	sfx:Play()
	Debris:AddItem(sfx, 2)
end

local function shakeUI(obj: GuiObject?): ()
	if not obj then return end
	local basePos = obj.Position
	local tweenInfo = TweenInfo.new(0.05, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 3, true)
	local goal = { Position = basePos + UDim2.new(0, 5, 0, 0) }
	local tween = TweenService:Create(obj, tweenInfo, goal)
	tween:Play()
end

local function setButtonState(btn: TextButton, enabled: boolean): ()
	btn.Active = enabled
	btn.AutoButtonColor = enabled
	btn.Selectable = enabled
	if enabled then
		btn.Text = "Select"
		btn.TextColor3 = ENABLED_TXTCLR
		btn.BackgroundColor3 = ENABLED_COLOR
	else
		btn.Text = "Full"
		btn.TextColor3 = DISABLED_TXTCLR
		btn.BackgroundColor3 = DISABLED_COLOR
	end
end

-- ✅ 현재 열린 GUI의 모든 Select 버튼을 한 번에 새로고침 (중복 리스너 방지)
local function refreshAllButtons(): ()
	if not activeGui then return end
	for _, node in ipairs(activeGui:GetDescendants()) do
		if node:IsA("TextButton") and node.Name == "Select" then
			local parentLabel = node.Parent
			if parentLabel and parentLabel:IsA("ImageLabel") then
				local itemName = parentLabel.Name
				local addAmount = (itemName == "1coin") and 1 or 5
				local canBuy = (currentCoins + addAmount) <= maxCoins
				setButtonState(node, canBuy)
			end
		end
	end
end

-- ✅ CoinUpdate는 스크립트 전역에서 "딱 1번" 구독
CoinUpdate.OnClientEvent:Connect(function(balance: any, maxBalance: any)
	currentCoins = tonumber(balance) or currentCoins
	maxCoins = tonumber(maxBalance) or maxCoins
	refreshAllButtons()
end)

-- GUI 열기
local function openCoinShop(): ()
	-- 이미 열려있으면 리턴
	if activeGui and activeGui.Parent then return end

	-- ✅ 최초 동기화 후 GUI 생성
	syncOnceFromServer()

	local gui = coinShopTemplate:Clone()
	gui.Name = "CoinShopGui_runtime"
	gui.ResetOnSpawn = false
	gui.Parent = PlayerGui
	activeGui = gui

	-- Close 버튼
	local closeBtn = gui:FindFirstChild("Close", true)
	if closeBtn and closeBtn:IsA("GuiButton") then
		closeBtn.MouseButton1Click:Connect(function()
			if activeGui then
				activeGui:Destroy()
				activeGui = nil
			end
		end)
	end

	-- Select 버튼: 클릭 핸들러만 연결 (CoinUpdate 리스너는 전역 1개)
	for _, node in ipairs(gui:GetDescendants()) do
		if node:IsA("TextButton") and node.Name == "Select" then
			local parentLabel = node.Parent
			if parentLabel and parentLabel:IsA("ImageLabel") then
				local itemName = parentLabel.Name
				local productId = PRODUCTS[itemName]

				-- 최초 렌더 상태 반영
				do
					local addAmount = (itemName == "1coin") and 1 or 5
					local canBuy = (currentCoins + addAmount) <= maxCoins
					setButtonState(node, canBuy)
				end

				-- 클릭 시 구매
				node.MouseButton1Click:Connect(function()
					local addAmount = (itemName == "1coin") and 1 or 5

					-- 클릭 시점에 한 번 더 검증 (경합 대비)
					if (currentCoins + addAmount) > maxCoins then
						shakeUI(node)
						playErrorSFX()
						return
					end

					if productId then
						MarketplaceService:PromptProductPurchase(LocalPlayer, productId)
					else
						-- 정의 안 된 상품
						shakeUI(node)
						playErrorSFX()
					end
				end)
			end
		end
	end
end

-- CoinShop 버튼 클릭 시 GUI 열기
coinShopBtn.MouseButton1Click:Connect(openCoinShop)
