--!strict
-- StarterGui/.../shop(TextButton)/LocalScript
-- 변경점 반영 버전: HandsPublic/HandsService 구조 호환, 장착 테마 실시간 반영

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local shopButton = script.Parent
local SHOP_TEMPLATE = ReplicatedStorage:WaitForChild("shop") :: ScreenGui

-- 각 테마 슬롯명 -> Dev Product ID
local PRODUCT_IDS: {[string]: number} = {
	a = 3412831030,
	b = 3412831293,
	c = 3412831754,
	d = 3412831964,
	e = 3412832270,
}

-- 데이터 소스
local HANDS_PUBLIC = ReplicatedStorage:WaitForChild("HandsPublic") :: Folder
local BOARD = ReplicatedStorage:FindFirstChild("board")

-- 유틸: 인스턴스에서 이미지 문자열 추출 + 정규화
local function normalizeAsset(s: any): string
	if typeof(s) == "string" then
		if s == "" then return "" end
		if s:match("^%d+$") then return "rbxassetid://"..s end
		return s
	end
	return ""
end

local function assetFromAny(inst: Instance?): string
	if not inst then return "" end
	if inst:IsA("StringValue") then
		return normalizeAsset(inst.Value)
	end
	local any = inst :: any
	if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		return normalizeAsset(any.Image)
	elseif inst:IsA("Decal") or inst:IsA("Texture") then
		return normalizeAsset(any.Texture)
	end
	return ""
end

local function fallbackBoard(): {[string]: string}
	local function grab(n: string): string
		return BOARD and assetFromAny(BOARD:FindFirstChild(n)) or ""
	end
	return {
		paper = grab("paper"),
		rock = grab("rock"),
		scissors = grab("scissors"),
	}
end

local function getThemeImages(theme: string): {[string]: string}
	local fb = fallbackBoard()
	local f = HANDS_PUBLIC:FindFirstChild(theme)
	if f and f:IsA("Folder") then
		local p = assetFromAny(f:FindFirstChild("paper"))
		local r = assetFromAny(f:FindFirstChild("rock"))
		local s = assetFromAny(f:FindFirstChild("scissors"))
		return {
			paper = (p ~= "" and p) or fb.paper,
			rock = (r ~= "" and r) or fb.rock,
			scissors = (s ~= "" and s) or fb.scissors,
		}
	end
	return fb
end

-- === Shop UI 바인딩 ===
local currentShop: ScreenGui? = nil
local conns: {RBXScriptConnection} = {}

local function disconnectAll()
	for _, c in ipairs(conns) do
		pcall(function() c:Disconnect() end)
	end
	table.clear(conns)
end

-- 슬롯 UI 보조: 상태 라벨/버튼 찾기
local function findSlotControls(slot: Instance)
	local selectBtn: TextButton? = slot:FindFirstChild("select") :: TextButton?
	local status: TextLabel? = slot:FindFirstChild("status") :: TextLabel?
	-- 썸네일 후보: "icon" 우선, 없으면 첫 번째 ImageLabel/ImageButton
	local icon: (ImageLabel | ImageButton)?
	local ic = slot:FindFirstChild("icon")
	if ic and (ic:IsA("ImageLabel") or ic:IsA("ImageButton")) then
		icon = ic
	else
		for _, d in ipairs(slot:GetDescendants()) do
			if d:IsA("ImageLabel") or d:IsA("ImageButton") then
				icon = d
				break
			end
		end
	end
	return selectBtn, status, icon
end

-- 슬롯 썸네일 채우기(테마 대표 이미지는 rock 사용, 없으면 paper)
local function setSlotThumbnail(slot: Instance, theme: string)
	local _, _, icon = findSlotControls(slot)
	if not icon then return end
	local imgs = getThemeImages(theme)
	local preview = imgs.rock ~= "" and imgs.rock or imgs.paper
	if preview ~= "" then
		pcall(function() ContentProvider:PreloadAsync({preview}) end)
		icon.Image = preview
	end
end

-- 장착 상태 표시(HandsTheme 기준)
local function refreshEquippedUI(shopGui: ScreenGui)
	local frame = shopGui:FindFirstChild("Frame")
	if not frame then return end
	local equipped = player:GetAttribute("HandsTheme")

	for theme, _ in pairs(PRODUCT_IDS) do
		local slot = frame:FindFirstChild(theme)
		if slot then
			local selectBtn, status, _ = findSlotControls(slot)
			local isEq = (equipped == theme)
			-- status 라벨이 있으면 텍스트/가시성 갱신
			if status then
				status.Visible = isEq
				status.Text = isEq and "Equipped" or ""
			end
			-- 버튼 텍스트/활성화
			if selectBtn then
				selectBtn.Text = isEq and "Equipped" or "Buy"
				selectBtn.AutoButtonColor = not isEq
				selectBtn.Active = not isEq
			end
		end
	end
end

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local EquipChanged: RemoteEvent? = Remotes and Remotes:FindFirstChild("HandsEquipChanged") :: RemoteEvent

local function hookShopUI(shopGui: ScreenGui)
	local frame = shopGui:WaitForChild("Frame")

	-- 닫기
	local closeBtn = frame:FindFirstChild("Close")
	if closeBtn and closeBtn:IsA("TextButton") then
		table.insert(conns, closeBtn.MouseButton1Click:Connect(function()
			disconnectAll()
			shopGui:Destroy()
			currentShop = nil
		end))
	end

	-- 슬롯 바인딩
	for theme, productId in pairs(PRODUCT_IDS) do
		local slot = frame:FindFirstChild(theme)
		if slot then
			-- 썸네일
			setSlotThumbnail(slot, theme)

			-- 버튼
			local selectBtn, _, _ = findSlotControls(slot)
			if selectBtn and typeof(productId) == "number" then
				table.insert(conns, selectBtn.MouseButton1Click:Connect(function()
					-- 이미 장착이면 무시
					if player:GetAttribute("HandsTheme") == theme then return end
					MarketplaceService:PromptProductPurchase(player, productId)
				end))
			end
		end
	end

	-- 내 장착 테마 변경 시 UI 갱신
	table.insert(conns, player:GetAttributeChangedSignal("HandsTheme"):Connect(function()
		refreshEquippedUI(shopGui)
	end))

	-- (옵션) 서버 브로드캐스트 보조: 내 유저 장착 변동이면 갱신
	if EquipChanged then
		table.insert(conns, EquipChanged.OnClientEvent:Connect(function(userId: number, newTheme: string, _images: {[string]: string})
			if userId == player.UserId then
				-- HandsService가 이미 Attribute도 세팅하지만, 혹시 순서가 바뀌어도 UI 보정
				refreshEquippedUI(shopGui)
			end
		end))
	end

	-- 첫 렌더 상태
	refreshEquippedUI(shopGui)
end

-- 열기 버튼
shopButton.MouseButton1Click:Connect(function()
	if currentShop and currentShop.Parent then
		currentShop.Enabled = true
		refreshEquippedUI(currentShop)
		return
	end
	local clone = SHOP_TEMPLATE:Clone()
	clone.ResetOnSpawn = false
	clone.IgnoreGuiInset = true
	clone.Parent = playerGui
	currentShop = clone
	hookShopUI(clone)
end)
