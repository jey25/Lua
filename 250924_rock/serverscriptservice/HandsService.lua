local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ServerStorage = game:GetService("ServerStorage")

-- Remotes 확보
local Remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder", ReplicatedStorage)
Remotes.Name = "Remotes"
local EquipChanged = Remotes:FindFirstChild("HandsEquipChanged") or Instance.new("RemoteEvent", Remotes)
EquipChanged.Name = "HandsEquipChanged"
local GetAllEquipped = Remotes:FindFirstChild("HandsGetAllEquipped") or Instance.new("RemoteFunction", Remotes)
GetAllEquipped.Name = "HandsGetAllEquipped"

-- 필수 폴더
local HANDS_FOLDER = ServerStorage:WaitForChild("Hands")

-- ★ productId -> 테마 이름 매핑 채워주세요
local PRODUCT_TO_THEME = {
	[3412831030] = "a",
	[3412831293] = "b",
	[3412831754] = "c",
	[3412831964] = "d",
	[3412832270] = "e",
}

-- 영구 저장용
local store = DataStoreService:GetDataStore("HandsDataV1")
-- 메모리 캐시: userId -> {owned = {[theme]=true}, equipped="theme"}
local profileByUserId = {}

-- 기존
-- local function readImages(themeName)
--     local f = HANDS_FOLDER:FindFirstChild(themeName)
--     if not f then return nil end
--     local function img(n)
--         local inst = f:FindFirstChild(n)
--         return (inst and inst:IsA("ImageButton") and inst.Image) or ""
--     end
--     return { paper = img("paper"), rock = img("rock"), scissors = img("scissors") }
-- end

-- 교체
local function readImages(themeName)
	local f = HANDS_FOLDER:FindFirstChild(themeName)
	if not f then return nil end

	local function normalize(s: any): string
		if typeof(s) == "string" then
			if s == "" then return "" end
			-- 숫자만 온 경우 "rbxassetid://" 접두사 보정
			if s:match("^%d+$") then return "rbxassetid://"..s end
			return s
		end
		return ""
	end

	local function img(n: string): string
		local inst = f:FindFirstChild(n)
		if not inst then return "" end
		if inst:IsA("ImageButton") or inst:IsA("ImageLabel") then
			return normalize(inst.Image)
		elseif inst:IsA("Decal") or inst:IsA("Texture") then
			return normalize(inst.Texture)
		else
			return ""
		end
	end

	return {
		paper = img("paper"),
		rock = img("rock"),
		scissors = img("scissors")
	}
end


local function broadcastEquip(plr, themeName)
	local images = readImages(themeName)
	if images then
		EquipChanged:FireAllClients(plr.UserId, themeName, images) -- 모두에게 실시간 반영
	end
end

local function saveAsync(userId, data)
	task.spawn(function()
		local ok, err = pcall(function() store:SetAsync("u"..userId, data) end)
		if not ok then warn("HandsData save failed:", err) end
	end)
end

local function setEquipped(plr, themeName)
	local uid = plr.UserId
	local prof = profileByUserId[uid]
	if not prof then return end
	prof.owned = prof.owned or {}
	prof.owned[themeName] = true
	prof.equipped = themeName
	saveAsync(uid, prof)
	broadcastEquip(plr, themeName)
end

local function loadProfile(uid)
	local ok, data = pcall(function() return store:GetAsync("u"..uid) end)
	if ok and typeof(data) == "table" then return data end
	return { owned = {}, equipped = nil }
end

Players.PlayerAdded:Connect(function(plr)
	local prof = loadProfile(plr.UserId)
	profileByUserId[plr.UserId] = prof
	if prof.equipped then
		broadcastEquip(plr, prof.equipped) -- 접속 시 본인/상대 모두에게 현재 장착 테마 전파
	else
		-- 기본값을 두려면 여기서 지정 (예: 첫 접속은 'a')
		local defaultTheme = "a"
		if HANDS_FOLDER:FindFirstChild(defaultTheme) then
			setEquipped(plr, defaultTheme)
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	local prof = profileByUserId[plr.UserId]
	if prof then saveAsync(plr.UserId, prof) end
	profileByUserId[plr.UserId] = nil
end)

-- 새로 들어온 클라이언트가 모든 플레이어의 현재 장착 상태를 한 번에 받아갈 수 있게 함
GetAllEquipped.OnServerInvoke = function(requester)
	local result = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local prof = profileByUserId[p.UserId]
		if prof and prof.equipped then
			result[p.UserId] = { theme = prof.equipped, images = readImages(prof.equipped) }
		end
	end
	return result
end

-- 구매 처리: 마지막으로 산 테마를 "장착"으로 간주하여 즉시 적용 + 영구 저장
MarketplaceService.ProcessReceipt = function(receipt)
	local plr = Players:GetPlayerByUserId(receipt.PlayerId)
	if not plr then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local theme = PRODUCT_TO_THEME[receipt.ProductId]
	if theme then
		if not profileByUserId[plr.UserId] then
			profileByUserId[plr.UserId] = loadProfile(plr.UserId)
		end
		setEquipped(plr, theme)
	else
		warn("Unknown productId:", receipt.ProductId)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

