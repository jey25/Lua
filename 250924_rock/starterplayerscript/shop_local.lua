
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

local currentShop 

-- ✅ 공통 닫기 함수: 열려 있으면 파괴하고 포인터 정리
local function closeShop()
	if currentShop and currentShop.Parent then
		currentShop:Destroy()
	end
	currentShop = nil
end

local function hookShopUI(shopGui: ScreenGui)
	local frame = shopGui:WaitForChild("Frame")
	local closeBtn = frame:WaitForChild("Close")

	-- 닫기 버튼도 동일 로직 사용
	closeBtn.MouseButton1Click:Connect(closeShop)

	local function bindSlot(slotName: string)
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

	for name in pairs(PRODUCT_IDS) do
		bindSlot(name)
	end
end

-- ✅ 버튼 토글: 열려 있으면 닫고, 없으면 연다
shopButton.MouseButton1Click:Connect(function()
	if not shopButton.Active then return end

	if currentShop and currentShop.Parent then
		-- 이미 열려있다면: 한 번 더 클릭 → 닫기
		if currentShop.Enabled then
			closeShop()
		else
			-- 혹시 비활성화돼 있었다면 다시 보여주기
			currentShop.Enabled = true
		end
		return
	end

	-- 열려있지 않다면: 새로 열기
	local clone = SHOP_TEMPLATE:Clone()
	clone.ResetOnSpawn = false
	clone.IgnoreGuiInset = true
	clone.Parent = playerGui
	currentShop = clone
	hookShopUI(clone)
end)

-- 서버에서 Shop 활성 여부 수신
ShopStateEvent.OnClientEvent:Connect(function(enable: boolean)
	shopButton.Active = enable
	shopButton.AutoButtonColor = enable
	shopButton.TextColor3 = enable and Color3.new(1,1,1) or Color3.fromRGB(120,120,120)
end)