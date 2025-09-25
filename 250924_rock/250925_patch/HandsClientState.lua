--!strict
-- ReplicatedStorage/HandsClientState (ModuleScript)
-- 역할:
--  - 클라이언트 메모리(byUser)로 각 유저의 {theme, images} 상태 보관
--  - ReplicatedStorage.HandsPublic(테마→AssetID)와 RS.board(기본 폴백)를 이용해 이미지 해석
--  - 이미지 프리로드/변경 이벤트 제공
--  - 기존 API: Get(userId), Set(userId, data) 유지 + SetTheme(userId, theme) 추가

local RS = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

type Images = {[string]: string} -- {paper="rbxassetid://...", rock=..., scissors=...}
type Data = { theme: string?, images: Images? }

local M = {
	byUser = {} :: {[number]: Data},
}

-- ===== 내부 유틸 =====
local function assetFromAny(inst: Instance?): string
	if not inst then return "" end
	if inst:IsA("StringValue") then
		return inst.Value
	end
	local any = inst :: any
	if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		return any.Image
	elseif inst:IsA("Decal") or inst:IsA("Texture") then
		return any.Texture
	end
	return ""
end

local function safeGet(folder: Instance?, name: string): Instance?
	if not folder then return nil end
	return (folder :: Instance):FindFirstChild(name)
end

local BOARD = RS:FindFirstChild("board")
local HANDS_PUBLIC = RS:FindFirstChild("HandsPublic")

local _boardFallback: Images? = nil
local function boardFallback(): Images
	if _boardFallback then return _boardFallback end
	local function grab(n: string): string
		return assetFromAny(safeGet(BOARD, n))
	end
	_boardFallback = {
		paper = grab("paper"),
		rock = grab("rock"),
		scissors = grab("scissors"),
	}
	return _boardFallback
end

local function themeImages(theme: string?): Images?
	if not theme or theme == "" then return nil end
	local tf = safeGet(HANDS_PUBLIC, theme)
	if not tf then return nil end
	-- StringValue 권장 구조(HandsPublic/<theme>/<paper|rock|scissors>)
	local p = assetFromAny(safeGet(tf, "paper"))
	local r = assetFromAny(safeGet(tf, "rock"))
	local s = assetFromAny(safeGet(tf, "scissors"))
	-- 값이 하나라도 없으면 nil 반환 대신 폴백을 섞어 채움
	local fb = boardFallback()
	return {
		paper = (p ~= "" and p) or fb.paper,
		rock  = (r ~= "" and r) or fb.rock,
		scissors = (s ~= "" and s) or fb.scissors,
	}
end

local function mergedImages(primary: Images?, fb: Images): Images
	primary = primary or {}
	return {
		paper = (primary.paper and primary.paper ~= "" and primary.paper) or fb.paper,
		rock = (primary.rock and primary.rock ~= "" and primary.rock) or fb.rock,
		scissors = (primary.scissors and primary.scissors ~= "" and primary.scissors) or fb.scissors,
	}
end

local function preloadImages(imgs: Images?)
	if not imgs then return end
	local toLoad = {}
	if imgs.paper and imgs.paper ~= "" then table.insert(toLoad, imgs.paper) end
	if imgs.rock and imgs.rock ~= "" then table.insert(toLoad, imgs.rock) end
	if imgs.scissors and imgs.scissors ~= "" then table.insert(toLoad, imgs.scissors) end
	if #toLoad > 0 then
		pcall(function() ContentProvider:PreloadAsync(toLoad) end)
	end
end

-- ===== 변경 이벤트(옵셔널) =====
-- 모듈 외부에서 변경 감지하고 싶을 때 사용:
-- HandsClientState.Changed:Connect(function(userId, data) ... end)
local changed = Instance.new("BindableEvent")
M.Changed = changed.Event

local function fireChanged(userId: number)
	local d = M.byUser[userId]
	changed:Fire(userId, d)
end

-- ===== 공개 API =====

-- 기존 호환: data = {theme=string?, images=Images?}
function M.Set(userId: number, data: Data)
	local fb = boardFallback()
	local final: Data = {
		theme = data.theme,
		images = mergedImages(data.images, fb),
	}
	M.byUser[userId] = final
	preloadImages(final.images)
	fireChanged(userId)
end

-- 추천: 테마 이름만으로 세팅(HandsPublic에서 ID들을 자동 해석, 부족하면 board 폴백)
function M.SetTheme(userId: number, theme: string)
	local imgs = themeImages(theme) or boardFallback()
	M.byUser[userId] = { theme = theme, images = imgs }
	preloadImages(imgs)
	fireChanged(userId)
end

-- 직접 이미지 묶음을 지정하고 싶을 때(테마명도 함께)
function M.SetDirect(userId: number, theme: string?, images: Images)
	local fb = boardFallback()
	local imgs = mergedImages(images, fb)
	M.byUser[userId] = { theme = theme, images = imgs }
	preloadImages(imgs)
	fireChanged(userId)
end

function M.Get(userId: number): Data?
	return M.byUser[userId]
end

-- 해당 유저의 특정 선택지("paper"|"rock"|"scissors") 이미지 얻기 (폴백 포함)
function M.PickImage(userId: number, choice: "paper"|"rock"|"scissors"): string
	local d = M.byUser[userId]
	if d and d.images and d.images[choice] and d.images[choice] ~= "" then
		return d.images[choice]
	end
	return boardFallback()[choice]
end

-- 필요 시 외부에서 프리로드만 하고 싶을 때
function M.Preload(userId: number)
	local d = M.byUser[userId]
	if d then preloadImages(d.images) end
end

-- 상태 제거(로그아웃/정리 등)
function M.Clear(userId: number)
	M.byUser[userId] = nil
	fireChanged(userId)
end

return M
