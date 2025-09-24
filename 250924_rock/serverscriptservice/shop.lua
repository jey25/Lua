-- ServerScriptService/ProcessReceipt.server.lua (대체본)
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Remotes 준비
local Remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder", ReplicatedStorage)
Remotes.Name = "Remotes"
local EquipChanged = Remotes:FindFirstChild("HandsEquipChanged") or Instance.new("RemoteEvent", Remotes)
EquipChanged.Name = "HandsEquipChanged"
local GetAllEquipped = Remotes:FindFirstChild("HandsGetAllEquipped") or Instance.new("RemoteFunction", Remotes)
GetAllEquipped.Name = "HandsGetAllEquipped"

local HANDS_FOLDER = ServerStorage:WaitForChild("Hands")

-- ★ productId -> 테마 폴더명 매핑
local PRODUCT_TO_THEME = {
	[3412831030] = "a",
	[3412831293] = "b",
	[3412831754] = "c",
	[3412831964] = "d",
	[3412832270] = "e",
}

-- 영구 저장
local store = DataStoreService:GetDataStore("HandsDataV1")
-- 메모리 캐시
local profile = {}  -- [userId] = { owned = {[theme]=true}, equipped="theme" }

local function readImages(themeName)
	local f = HANDS_FOLDER:FindFirstChild(themeName)
	if not f then return nil end
	local function img(n)
		local inst = f:FindFirstChild(n)
		return (inst and inst:IsA("ImageButton") and inst.Image) or ""
	end
	return { paper = img("paper"), rock = img("rock"), scissors = img("scissors") }
end

local function saveAsync(uid, data)
	task.spawn(function()
		pcall(function() store:SetAsync("u"..uid, data) end)
	end)
end

local function broadcastEquip(userId, theme)
	local images = readImages(theme)
	if images then
		EquipChanged:FireAllClients(userId, theme, images)
	end
end

local function setEquipped(plr, theme)
	local uid = plr.UserId
	profile[uid] = profile[uid] or { owned = {}, equipped = nil }
	profile[uid].owned[theme] = true
	profile[uid].equipped = theme
	saveAsync(uid, profile[uid])
	broadcastEquip(uid, theme)
end

-- 접속 시 로드 & 알려주기
local function loadProfile(uid)
	local ok, data = pcall(function() return store:GetAsync("u"..uid) end)
	if ok and typeof(data) == "table" then return data end
	return { owned = {}, equipped = nil }
end

Players.PlayerAdded:Connect(function(plr)
	profile[plr.UserId] = loadProfile(plr.UserId)
	if profile[plr.UserId].equipped then
		broadcastEquip(plr.UserId, profile[plr.UserId].equipped)
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	local p = profile[plr.UserId]
	if p then saveAsync(plr.UserId, p) end
	profile[plr.UserId] = nil
end)

-- 신규 클라이언트가 전체 상태 요청
GetAllEquipped.OnServerInvoke = function()
	local result = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local prof = profile[p.UserId]
		if prof and prof.equipped then
			result[p.UserId] = { theme = prof.equipped, images = readImages(prof.equipped) }
		end
	end
	return result
end

-- ★ 구매 처리: 마지막으로 산 테마를 '장착'으로 간주
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local plr = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not plr then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local theme = PRODUCT_TO_THEME[receiptInfo.ProductId]
	if theme and HANDS_FOLDER:FindFirstChild(theme) then
		setEquipped(plr, theme)  -- 저장 + 방송
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
