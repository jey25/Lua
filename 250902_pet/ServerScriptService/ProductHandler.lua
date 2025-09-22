--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local CoinService = require(script.Parent:WaitForChild("CoinService"))

-- 등록한 Developer Product ID와 지급할 코인 양 매핑
local PRODUCTS = {
	[3411337008] = 1, -- 1 Coin
	[3411337007] = 5, -- 5 Coin
}

-- 구매 처리
local function processReceipt(receiptInfo: ReceiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local coinAmount = PRODUCTS[receiptInfo.ProductId]
	if not coinAmount then
		warn(("알 수 없는 ProductId: %s"):format(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 코인 지급
	CoinService:_add(player, coinAmount)

	-- 성공적으로 처리됨 → Roblox에 알림
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt

