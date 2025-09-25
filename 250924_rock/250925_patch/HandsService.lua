--!strict
-- ServerScriptService/HandsService.server.lua
-- 역할:
--  - Dev Product 구매 → 테마 장착/저장/실시간 반영
--  - 플레이어 입장/퇴장 시 테마 복원/저장
--  - ReplicatedStorage.HandsPublic(테마→AssetID) 자동 구성(없으면 ServerStorage/Hands에서 가져와 생성)
--  - 클라 호환용 Remotes(HandsEquipChanged, HandsGetAllEquipped) 지원

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local ServerStorage = game:GetService("ServerStorage")

-- ===== Remotes =====
local Remotes = RS:FindFirstChild("Remotes") or Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = RS

local EquipChanged = Remotes:FindFirstChild("HandsEquipChanged") :: RemoteEvent
if not EquipChanged then
	EquipChanged = Instance.new("RemoteEvent")
	EquipChanged.Name = "HandsEquipChanged"
	EquipChanged.Parent = Remotes
end

local GetAllEquipped = Remotes:FindFirstChild("HandsGetAllEquipped") :: RemoteFunction
if not GetAllEquipped then
	GetAllEquipped = Instance.new("RemoteFunction")
	GetAllEquipped.Name = "HandsGetAllEquipped"
	GetAllEquipped.Parent = Remotes
end

-- ===== 폴더(카탈로그/아트 소스) =====
local HANDS_SS: Folder = ServerStorage:WaitForChild("Hands") :: Folder -- (선택) 아티스트 소스
local HANDS_PUBLIC: Folder = RS:FindFirstChild("HandsPublic") as Folder or Instance.new("Folder")
HANDS_PUBLIC.Name = "HandsPublic"
HANDS_PUBLIC.Parent = RS

-- 기본 폴백(보드 기본 아이콘)
local BOARD: Instance? = RS:FindFirstChild("board")

-- Dev Product → 테마 이름 매핑 (필요 시 계속 추가)
local PRODUCT_TO_THEME: {[number]: string} = {
	[3412831030] = "a",
	[3412831293] = "b",
	[3412831754] = "c",
	[3412831964] = "d",
	[3412832270] = "e",
}

-- DataStore
local STORE = DataStoreService:GetDataStore("HandsDataV1")
type Profile = { owned: {[string]: boolean}, equipped: string? }
local profileByUserId: {[number]: Profile} = {}

-- ===== 유틸: Asset 문자열 정규화 =====
local function normalizeAsset(s: any): string
	if typeof(s) == "string" then
		if s == "" then return "" end
		if s:match("^%d+$") then return "rbxassetid://"..s end
		return s
	end
	return ""
end

-- ===== 유틸: 인스턴스에서 Image/Texture 문자열 추출 =====
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

-- ===== 폴백: RS.board에서 paper/rock/scissors 읽기 =====
local _fallbackCache: {[string]: string}? = nil
local function getFallbackBoardImages(): {[string]: string}
	if _fallbackCache then return _fallbackCache end
	local function grab(name: string): string
		local ch = BOARD and BOARD:FindFirstChild(name) or nil
		return assetFromAny(ch)
	end
	_fallbackCache = {
		paper = grab("paper"),
		rock = grab("rock"),
		scissors = grab("scissors"),
	}
	return _fallbackCache
end

-- ===== HandsPublic(정답표) 보강: ServerStorage/Hands → RS/HandsPublic 복제(없을 때만/또는 누락값 채우기) =====
local function ensureHandsPublicTheme(themeName: string)
	local src = HANDS_SS:FindFirstChild(themeName)
	local pub = HANDS_PUBLIC:FindFirstChild(themeName) :: Folder?
	if not pub then
		pub = Instance.new("Folder")
		pub.Name = themeName
		pub.Parent = HANDS_PUBLIC
	end

	local function ensureSV(key: string, value: string)
		local sv = pub:FindFirstChild(key) :: StringValue?
		if not sv then
			sv = Instance.new("StringValue")
			sv.Name = key
			sv.Parent = pub
		end
		if sv.Value == "" and value ~= "" then
			sv.Value = value
		end
	end

	-- ServerStorage 소스가 있으면 그 값을 사용
	local function fromSS(key: string): string
		if not src then return "" end
		return assetFromAny(src:FindFirstChild(key))
	end

	-- 값을 채움(이미 값이 있으면 유지, 비어있으면 보강)
	ensureSV("paper", fromSS("paper"))
	ensureSV("rock",  fromSS("rock"))
	ensureSV("scissors", fromSS("scissors"))
end

local function bootstrapHandsPublic()
	-- 1) ServerStorage/Hands의 테마를 HandsPublic에 보강
	for _, f in ipairs(HANDS_SS:GetChildren()) do
		if f:IsA("Folder") then
			ensureHandsPublicTheme(f.Name)
		end
	end
	-- 2) HandsPublic에 이미 존재하는 테마 폴더도 3키가 비어있다면 생성
	for _, f in ipairs(HANDS_PUBLIC:GetChildren()) do
		if f:IsA("Folder") then
			for _, key in ipairs({"paper","rock","scissors"}) do
				local sv = f:FindFirstChild(key) :: StringValue?
				if not sv then
					sv = Instance.new("StringValue")
					sv.Name = key
					sv.Value = ""
					sv.Parent = f
				end
			end
		end
	end
end
bootstrapHandsPublic()

-- (선택) 런타임 보강: 아티스트가 서버에서 Hands 폴더를 수정하면 HandsPublic도 채움
HANDS_SS.ChildAdded:Connect(function(ch)
	if ch:IsA("Folder") then
		ensureHandsPublicTheme(ch.Name)
	end
end)

-- ===== 테마 → 이미지(문자열 3개) 조회 =====
local function getImagesForTheme(theme: string): {[string]: string}
	-- HandsPublic 우선
	local pub = HANDS_PUBLIC:FindFirstChild(theme)
	local fb = getFallbackBoardImages()
	if pub and pub:IsA("Folder") then
		local paper = assetFromAny(pub:FindFirstChild("paper")); if paper == "" then paper = fb.paper end
		local rock  = assetFromAny(pub:FindFirstChild("rock"));  if rock  == "" then rock  = fb.rock  end
		local scissors = assetFromAny(pub:FindFirstChild("scissors")); if scissors == "" then scissors = fb.scissors end
		return { paper = paper, rock = rock, scissors = scissors }
	end

	-- 다음: ServerStorage/Hands 직접 조회(레거시 소스)
	local src = HANDS_SS:FindFirstChild(theme)
	if src and src:IsA("Folder") then
		local function img(n: string) return assetFromAny(src:FindFirstChild(n)) end
		return {
			paper = img("paper") ~= "" and img("paper") or fb.paper,
			rock  = img("rock")  ~= "" and img("rock")  or fb.rock,
			scissors = img("scissors") ~= "" and img("scissors") or fb.scissors,
		}
	end

	-- 마지막 폴백
	return { paper = fb.paper, rock = fb.rock, scissors = fb.scissors }
end

-- ===== 영구 저장 로드/세이브 =====
local function loadProfile(uid: number): Profile
	local ok, data = pcall(function() return STORE:GetAsync("u"..uid) end)
	if ok and typeof(data) == "table" then
		local t = data :: any
		t.owned = t.owned or {}
		return t
	end
	return { owned = {}, equipped = nil }
end

local function saveProfile(uid: number, p: Profile)
	-- UpdateAsync + 재시도
	for attempt = 1, 5 do
		local ok, err = pcall(function()
			STORE:UpdateAsync("u"..uid, function(_old) return p end)
		end)
		if ok then return true end
		warn(("[HandsService] Save retry %d for %d: %s"):format(attempt, uid, tostring(err)))
		task.wait(0.3 * attempt)
	end
	return false
end

-- ===== 브로드캐스트(호환용) =====
local function broadcastEquip(plr: Player, themeName: string)
	local images = getImagesForTheme(themeName)
	-- 기존 클라 호환: userId, theme, images 테이블 전송
	EquipChanged:FireAllClients(plr.UserId, themeName, images)
end

-- ===== 장착 처리(권위) =====
local function setEquipped(plr: Player, themeName: string)
	local uid = plr.UserId
	local p = profileByUserId[uid]
	if not p then return end

	p.owned = p.owned or {}
	p.owned[themeName] = true
	p.equipped = themeName

	-- 1) Attribute 복제 → 모든 클라 실시간 반영
	plr:SetAttribute("HandsTheme", themeName)

	-- 2) (호환) RemoteEvent 브로드캐스트
	broadcastEquip(plr, themeName)

	-- 3) 저장
	saveProfile(uid, p)
end

-- ===== 플레이어 입퇴장 =====
Players.PlayerAdded:Connect(function(plr)
	local uid = plr.UserId
	local p = loadProfile(uid)
	profileByUserId[uid] = p

	-- 기본 테마 결정
	local theme = p.equipped
	if not theme or theme == "" then
		theme = "a" -- 기본값
		p.equipped = theme
		saveProfile(uid, p)
	end

	-- 입장 즉시 Attribute로 복제(클라 자동 반영)
	plr:SetAttribute("HandsTheme", theme)

	-- (호환) 현재 장착 브로드캐스트
	broadcastEquip(plr, theme)
end)

Players.PlayerRemoving:Connect(function(plr)
	local uid = plr.UserId
	local p = profileByUserId[uid]
	if p then saveProfile(uid, p) end
	profileByUserId[uid] = nil
end)

-- ===== 초기 동기화(RemoteFunction): 현재 접속자들의 장착 상태 반환 =====
GetAllEquipped.OnServerInvoke = function(_requester: Player)
	local result: {[number]: {theme: string, images: {[string]: string}}} = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local prof = profileByUserId[p.UserId]
		if prof and prof.equipped then
			result[p.UserId] = {
				theme = prof.equipped,
				images = getImagesForTheme(prof.equipped),
			}
		end
	end
	return result
end

-- ===== Dev Product 구매 처리 =====
MarketplaceService.ProcessReceipt = function(receipt)
	local uid = receipt.PlayerId
	local plr = Players:GetPlayerByUserId(uid)
	if not plr then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local theme = PRODUCT_TO_THEME[receipt.ProductId]
	if theme then
		if not profileByUserId[uid] then
			profileByUserId[uid] = loadProfile(uid)
		end
		setEquipped(plr, theme)
	else
		warn("[HandsService] Unknown productId:", receipt.ProductId)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ===== 서버 종료 시 베스트-에포트 세이브 =====
game:BindToClose(function()
	for uid, p in pairs(profileByUserId) do
		pcall(function() STORE:SetAsync("u"..uid, p) end)
	end
end)
