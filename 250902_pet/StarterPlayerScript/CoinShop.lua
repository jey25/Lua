
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- GUI 참조
local coinShopBtn = script.Parent :: ImageButton
local coinShopTemplate = ReplicatedStorage:WaitForChild("CoinShopGui") :: ScreenGui

-- RemoteEvents
local Remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local CoinUpdate = Remotes:WaitForChild("CoinUpdate") :: RemoteEvent
local TweenService = game:GetService("TweenService")

-- Developer Product IDs
local PRODUCTS = {
	["1coin"] = 3411337008,
	["5coin"] = 3411337007,
}

-- 현재 코인 상태
local currentCoins = 0
local maxCoins = 0

-- 버튼 색상
local ENABLED_COLOR = Color3.fromRGB(39,174,96)
local DISABLED_COLOR = Color3.fromRGB(120,120,120)
local ENABLED_TXTCLR  = Color3.fromRGB(255,255,255)
local DISABLED_TXTCLR = Color3.fromRGB(220,220,220)


local ErrorSFX = ReplicatedStorage:WaitForChild("SFX"):WaitForChild("Error") :: Sound

local function playErrorSFX()
	local sfx = ErrorSFX:Clone()
	sfx.Parent = game:GetService("SoundService")
	sfx:Play()
	game:GetService("Debris"):AddItem(sfx, 2) -- 자동 삭제
end

local function shakeUI(obj: GuiObject)
	if not obj then return end

	local basePos = obj.Position
	local tweenInfo = TweenInfo.new(0.05, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 3, true)

	local goal = {}
	goal.Position = basePos + UDim2.new(0,5,0,0)

	local tween = TweenService:Create(obj, tweenInfo, goal)
	tween:Play()
end

-- 버튼 활성화/비활성 처리
local function setButtonState(btn: TextButton, enabled: boolean)
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

-- GUI 열기
local function openCoinShop()
	-- 이미 열려있으면 리턴
	if PlayerGui:FindFirstChild("CoinShopGui_runtime") then return end

	local gui = coinShopTemplate:Clone()
	gui.Name = "CoinShopGui_runtime"
	gui.ResetOnSpawn = false
	gui.Parent = PlayerGui

	-- Close 버튼 처리
	local closeBtn = gui:FindFirstChild("Close", true)
	if closeBtn and closeBtn:IsA("GuiButton") then
		closeBtn.MouseButton1Click:Connect(function()
			gui:Destroy()
		end)
	end

	-- Select 버튼 처리
	for _, node in ipairs(gui:GetDescendants()) do
		if node:IsA("TextButton") and node.Name == "Select" then
			local parentLabel = node.Parent
			if parentLabel and parentLabel:IsA("ImageLabel") then
				local itemName = parentLabel.Name
				local productId = PRODUCTS[itemName]

				-- 초기 상태 반영
				local function refresh()
					local addAmount = (itemName == "1coin") and 1 or 5
					local canBuy = (currentCoins + addAmount) <= maxCoins
					setButtonState(node, canBuy)
				end
				refresh()

				-- 클릭 시 구매
				node.MouseButton1Click:Connect(function()
					local addAmount = (itemName == "1coin") and 1 or 5
					if (currentCoins + addAmount) > maxCoins then
						-- 불가능 → 흔들림 + 에러 사운드
						shakeUI(node)
						playErrorSFX()
						return
					end
					if productId then
						MarketplaceService:PromptProductPurchase(LocalPlayer, productId)
					end
				end)


				-- 코인 업데이트 시 마다 버튼 리프레시
				CoinUpdate.OnClientEvent:Connect(function(balance, maxBalance)
					currentCoins = tonumber(balance) or currentCoins
					maxCoins = tonumber(maxBalance) or maxCoins
					refresh()
				end)
			end
		end
	end
end

-- CoinShop 버튼 클릭 시 GUI 열기
coinShopBtn.MouseButton1Click:Connect(openCoinShop)

-- 초기 동기화
CoinUpdate.OnClientEvent:Connect(function(balance, maxBalance)
	currentCoins = tonumber(balance) or currentCoins
	maxCoins = tonumber(maxBalance) or maxCoins
end)