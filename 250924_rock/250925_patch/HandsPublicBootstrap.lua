--!strict
-- ServerScriptService/HandsPublicBootstrap.server.lua
-- 역할:
--  - ReplicatedStorage/HandsPublic(테마→paper/rock/scissors StringValue) 생성/보강
--  - 우선순위: HandsCatalog 모듈 > ServerStorage/Hands 폴더 > 기존 값 유지
--  - 문자열 정규화(숫자만 → rbxassetid:// 접두사)

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")

local HANDS_PUBLIC: Folder = RS:FindFirstChild("HandsPublic") as Folder or Instance.new("Folder")
HANDS_PUBLIC.Name = "HandsPublic"
HANDS_PUBLIC.Parent = RS

local HANDS_SS: Folder? = SS:FindFirstChild("Hands") :: Folder?

-- 숫자만 온 경우 rbxassetid:// 보정
local function normalizeAsset(s: any): string
	if typeof(s) == "string" then
		if s == "" then return "" end
		if s:match("^%d+$") then return "rbxassetid://"..s end
		return s
	end
	return ""
end

-- 인스턴스에서 Image/Texture/StringValue.Value 추출
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

-- HandsPublic/<theme> 폴더와 3개 키 확보
local function ensureThemeFolder(theme: string): Folder
	local f = HANDS_PUBLIC:FindFirstChild(theme) :: Folder?
	if not f then
		f = Instance.new("Folder")
		f.Name = theme
		f.Parent = HANDS_PUBLIC
	end
	for _, key in ipairs({"paper", "rock", "scissors"}) do
		local sv = f:FindFirstChild(key) :: StringValue?
		if not sv then
			sv = Instance.new("StringValue")
			sv.Name = key
			sv.Value = ""  -- 비어 있으면 나중 폴백(board)을 쓰게 됨
			sv.Parent = f
		end
	end
	return f
end

-- 값 채우기(override=true면 무조건 덮어씀, false면 비어있을 때만)
local function setThemeImages(theme: string, images: {[string]: string}, override: boolean)
	local f = ensureThemeFolder(theme)
	for _, key in ipairs({"paper","rock","scissors"}) do
		local sv = f:FindFirstChild(key) :: StringValue
		local v = normalizeAsset(images[key])
		if override then
			if v ~= "" then sv.Value = v end
		else
			if sv.Value == "" and v ~= "" then sv.Value = v end
		end
	end
end

-- 1) HandsCatalog 모듈 반영(있으면 권위, 덮어쓰기)
local function applyCatalog()
	local ok, catalog = pcall(function()
		local mod = RS:FindFirstChild("HandsCatalog")
		return mod and require(mod)
	end)
	if ok and type(catalog) == "table" then
		for theme, imgs in pairs(catalog) do
			if type(imgs) == "table" then
				setThemeImages(theme, imgs, true) -- ★ override = true
			end
		end
	end
end

-- 2) ServerStorage/Hands 스캔(없거나 빈 칸만 보강)
local function applyFromServerStorage()
	if not HANDS_SS then return end
	for _, themeFolder in ipairs(HANDS_SS:GetChildren()) do
		if themeFolder:IsA("Folder") then
			local imgs = {
				paper    = assetFromAny(themeFolder:FindFirstChild("paper")),
				rock     = assetFromAny(themeFolder:FindFirstChild("rock")),
				scissors = assetFromAny(themeFolder:FindFirstChild("scissors")),
			}
			setThemeImages(themeFolder.Name, imgs, false) -- ★ override = false
		end
	end
end

-- 3) 런타임 추가 보강: Hands 폴더에 새 테마가 생기면 즉시 보강
local function hookServerStorageHands()
	if not HANDS_SS then return end
	HANDS_SS.ChildAdded:Connect(function(ch)
		if ch:IsA("Folder") then
			local imgs = {
				paper    = assetFromAny(ch:FindFirstChild("paper")),
				rock     = assetFromAny(ch:FindFirstChild("rock")),
				scissors = assetFromAny(ch:FindFirstChild("scissors")),
			}
			setThemeImages(ch.Name, imgs, false)
		end
	end)
end

-- 실행
applyCatalog()
applyFromServerStorage()
hookServerStorageHands()

print("[HandsPublicBootstrap] HandsPublic ready. Themes:", #HANDS_PUBLIC:GetChildren())
