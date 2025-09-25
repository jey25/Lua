
-- StarterGui/…/shop(TextButton)/LocalScript
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local shopButton = script.Parent
local SHOP_TEMPLATE = ReplicatedStorage:WaitForChild("shop") -- ScreenGui
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ShopStateEvent = Remotes:WaitForChild("ShopState")

-- 각 슬롯(a~e)에 대응되는 Developer Product ID를 채워주세요
local PRODUCT_IDS = {
	a = 3412831030, -- 예: 157823456
	b = 3412831293,
	c = 3412831754,
	d = 3412831964,
	e = 3412832270,
	f = 3413851547,
	g = 3413902573,
	h = 3413906749,
}

local currentShop -- 현재 떠있는 ShopGui

local function hookShopUI(shopGui)
	local frame = shopGui:WaitForChild("Frame")
	local closeBtn = frame:WaitForChild("Close")
	closeBtn.MouseButton1Click:Connect(function()
		shopGui:Destroy()
		currentShop = nil
	end)

	local function bindSlot(slotName)
		local slot = frame:FindFirstChild(slotName)
		if not slot then return end
		local selectBtn = slot:FindFirstChild("select")
		if selectBtn and selectBtn:IsA("TextButton") then
			local productId = PRODUCT_IDS[slotName]
			selectBtn.MouseButton1Click:Connect(function()
				if productId and productId ~= 0 then
					MarketplaceService:PromptProductPurchase(player, productId)
				end
			end)
		end
	end

	for name, _ in pairs(PRODUCT_IDS) do
		bindSlot(name)
	end
end

shopButton.MouseButton1Click:Connect(function()
	if not shopButton.Active then return end -- 비활성화 상태면 클릭 무시
	if currentShop then
		currentShop.Enabled = true
		return
	end
	local clone = SHOP_TEMPLATE:Clone()
	clone.ResetOnSpawn = false
	clone.IgnoreGuiInset = true
	clone.Parent = playerGui
	currentShop = clone
	hookShopUI(clone)
end)

-- 서버에서 Shop 활성 여부 수신
ShopStateEvent.OnClientEvent:Connect(function(enable)
	shopButton.Active = enable
	shopButton.AutoButtonColor = enable
	shopButton.TextColor3 = enable and Color3.new(1,1,1) or Color3.fromRGB(120,120,120)
end)