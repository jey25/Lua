
-- StarterGui/…/shop(TextButton)/LocalScript
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local shopButton = script.Parent
local SHOP_TEMPLATE = ReplicatedStorage:WaitForChild("shop") -- ScreenGui

-- 각 슬롯(a~e)에 대응되는 Developer Product ID를 채워주세요
local PRODUCT_IDS = {
	a = 3412831030, -- 예: 157823456
	b = 3412831293,
	c = 3412831754,
	d = 3412831964,
	e = 3412832270,
}

local currentShop -- 현재 떠있는 ShopGui

local function hookShopUI(shopGui: ScreenGui)
	local frame = shopGui:WaitForChild("Frame")

	-- 닫기 버튼
	local closeBtn = frame:WaitForChild("Close")
	closeBtn.MouseButton1Click:Connect(function()
		shopGui:Destroy()
		currentShop = nil
	end)

	-- 각 이미지 하위 select 버튼 → 구매 팝업
	local function bindSlot(slotName: string)
		local slot = frame:FindFirstChild(slotName)
		if not slot then return end
		local selectBtn = slot:FindFirstChild("select")
		if selectBtn and selectBtn:IsA("TextButton") then
			local productId = PRODUCT_IDS[slotName]
			selectBtn.MouseButton1Click:Connect(function()
				if productId and productId ~= 0 then
					MarketplaceService:PromptProductPurchase(player, productId)
				else
					warn(("PRODUCT_IDS.%s 가 비어있습니다."):format(slotName))
				end
			end)
		end
	end

	for name, _ in pairs(PRODUCT_IDS) do
		bindSlot(name)
	end
end

-- 열기 버튼
shopButton.MouseButton1Click:Connect(function()
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
