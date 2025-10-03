--!strict
-- ServerScriptService/BadgeManager.lua
-- Roblox 기본 BadgeService를 래핑 + 저장/효과/게이팅 + 토스트/언락 동기화

local Players            = game:GetService("Players")
local BadgeService       = game:GetService("BadgeService")
local DataStoreService   = game:GetService("DataStoreService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

-- 파일 상단 어딘가
local lastToastAt: {[number]: {[string]: number}} = {}
local STORE = DataStoreService:GetDataStore("BadgeState_v1")

export type BadgeConfig = {
	badgeId: number,
	name: string?,
	effect: { mode: "permanent" } | { mode: "timed", seconds: number },
	unlockTags: {string}?,                 -- 클라/상점/버프 게이트에 쓰는 라벨
	oneTimeReward: ((player: Player) -> ())?, -- 선택: 최초 획득 시 보상 훅(지금은 비워둠)
	toastText: string?                     -- 선택: 클라 토스트 메시지
}

type BadgeState = {
	awardedAt: number,     -- 획득 시각(Unix). 과거 획득 동기화 시 현재시각으로 기록
	hasBadge: boolean,     -- Roblox 배지 보유 스냅샷(권위는 BadgeService)
}

local BadgeManager = {}
BadgeManager.__index = BadgeManager

-- =============== Remotes ===============
local function ensureRemotes()
	local folder = ReplicatedStorage:FindFirstChild("BadgeRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "BadgeRemotes"
		folder.Parent = ReplicatedStorage
	end
	local toast = folder:FindFirstChild("Toast") :: RemoteEvent?
	if not toast then
		toast = Instance.new("RemoteEvent")
		toast.Name = "Toast"          -- FireClient(player, {text="...", key="..."})
		toast.Parent = folder
	end
	local unlockSync = folder:FindFirstChild("UnlockSync") :: RemoteEvent?
	if not unlockSync then
		unlockSync = Instance.new("RemoteEvent")
		unlockSync.Name = "UnlockSync" -- FireClient(player, {tags={"ui:..." , ...}})
		unlockSync.Parent = folder
	end
	return toast :: RemoteEvent, unlockSync :: RemoteEvent
end

local ToastRE, UnlockSyncRE = ensureRemotes()

-- =============== Badge 설정(5개) ===============
-- 키는 호출 편의를 위해 공백 없는 식별자로 통일
BadgeManager.Keys = {
	Level10    = "level10",
	Level100   = "level100",
	Level200   = "level200",
	Jumper     = "jumper",
	GreatTeam  = "great_team",
}

local BADGES: {[string]: BadgeConfig} = {
	[BadgeManager.Keys.Level10] = {
		badgeId   = 953349316145249,
		name      = "Reached Level 10",
		effect    = { mode = "permanent" }, -- 말풍선만
		toastText = "I can buy pet treats",
		toastDurationSec = 4,   -- ★ 추가: 더 오래
	},
	[BadgeManager.Keys.Level100] = {
		badgeId   = 3158927442991897,
		name      = "Reached Level 100",
		effect    = { mode = "permanent" },
		toastText = "I think I got a little stronger?",
		toastDurationSec = 4,   -- ★ 추가: 더 오래
	},
	[BadgeManager.Keys.Level200] = {
		badgeId   = 1619289868703466,
		name      = "Reached Level 200",
		effect    = { mode = "permanent" },
		toastText = "I feel confident enough to own more pets",
		toastDurationSec = 4,   -- ★ 추가: 더 오래
	},
	[BadgeManager.Keys.Jumper] = {
		badgeId    = 2363518447910032,
		name       = "Jumper",
		effect     = { mode = "permanent" },              -- 영구 효과
		unlockTags = {"ui:jumper_buy_enable"},           -- NPC 근처에서 구매 버튼 활성화용
		toastText  = "I can Buy jump treats",
		toastDurationSec = 4,   -- ★ 추가: 더 오래
	},
	[BadgeManager.Keys.GreatTeam] = {
		badgeId   = 317603482120196,
		name      = "Great Team",
		effect    = { mode = "permanent" },
		toastText = "We did it!",
		toastDurationSec = 4,   -- ★ 추가: 더 오래
	},
}

-- 레거시/오타 대비 별칭(공백/대문자 등)
local KEY_ALIASES: {[string]: string} = {
	["level 10"] = BadgeManager.Keys.Level10,
	["level 100"] = BadgeManager.Keys.Level100,
	["level 200"] = BadgeManager.Keys.Level200,
	["Jumper"] = BadgeManager.Keys.Jumper,
	["Great Team"] = BadgeManager.Keys.GreatTeam,
}
local function canonKey(k: string): string
	return KEY_ALIASES[k] or k
end

-- =============== 내부 저장소/캐시 ===============
local cache: {[number]: {[string]: BadgeState}} = {}

local function now(): number
	return os.time()
end

local function loadAll(userId: number): {[string]: BadgeState}
	if cache[userId] then return cache[userId] end
	local data: {[string]: BadgeState} = {}
	local ok, res = pcall(function() return STORE:GetAsync(("u_%d"):format(userId)) end)
	if ok and type(res) == "table" then data = res end
	cache[userId] = data
	return data
end

local function saveAll(userId: number)
	local key = ("u_%d"):format(userId)
	local payload = cache[userId] or {}
	local ok, err = pcall(function()
		STORE:UpdateAsync(key, function(_) return payload end)
	end)
	if not ok then warn("[BadgeManager] saveAll failed: ", err) end
end

local function syncRobloxBadgeFlag(userId: number, key: string, badgeId: number)
	local data = loadAll(userId)
	local st = data[key]
	local has = false
	local ok, res = pcall(function()
		return BadgeService:UserHasBadgeAsync(userId, badgeId)
	end)
	if ok then has = res == true else warn("[BadgeManager] UserHasBadgeAsync error: ", res) end

	if not st then
		data[key] = { hasBadge = has, awardedAt = has and now() or 0 }
	else
		st.hasBadge = has
		if has and st.awardedAt == 0 then
			st.awardedAt = now()
		end
	end
end


local function sendToast(player: Player, key: string)
	local cfg = BADGES[key]
	if not cfg or not cfg.toastText then return end

	-- ★ 중복 방지 (0.5s)
	local u = player.UserId
	lastToastAt[u] = lastToastAt[u] or {}
	local now = os.clock()
	if (lastToastAt[u][key] or 0) > 0 and (now - lastToastAt[u][key]) < 0.5 then
		return
	end
	lastToastAt[u][key] = now

	ToastRE:FireClient(player, {
		text = cfg.toastText,
		key = key,
		duration = cfg.toastDurationSec or 3,
	})
end


local function collectActiveUnlockTags(player: Player): {string}
	local tags: {string} = {}
	local function add(tag: string)
		for _, t in ipairs(tags) do
			if t == tag then return end
		end
		table.insert(tags, tag)
	end
	for key, cfg in pairs(BADGES) do
		if cfg.unlockTags and #cfg.unlockTags > 0 then
			-- 효과 활성 중인지 체크
			local active = false
			if cfg.effect.mode == "permanent" then
				-- 배지만 있으면 활성
				local data = loadAll(player.UserId)[key]
				active = (data and data.hasBadge) == true
			else
				local data = loadAll(player.UserId)[key]
				active = data and data.hasBadge and (now() < (data.awardedAt + cfg.effect.seconds)) or false
			end
			if active then
				for _, tag in ipairs(cfg.unlockTags) do add(tag) end
			end
		end
	end
	return tags
end

local function pushUnlockTags(player: Player)
	local tags = collectActiveUnlockTags(player)
	UnlockSyncRE:FireClient(player, { tags = tags })
end

-- =============== 공개 API ===============

-- 접속/초기화 시 호출
function BadgeManager.OnPlayerReady(player: Player)
	-- 모든 배지 보유/시각 동기화
	for key, cfg in pairs(BADGES) do
		syncRobloxBadgeFlag(player.UserId, key, cfg.badgeId)
	end
	saveAll(player.UserId)
	-- 현재 활성 언락 태그를 클라에 동기화(예: Jumper 버튼 즉시 활성화)
	pushUnlockTags(player)
end

function BadgeManager.TryAward(player: Player, key: string): (boolean, string?)
	key = canonKey(key)
	local cfg = BADGES[key]
	if not cfg then return false, "unknown_badge" end

	-- 이미 보유? → 연출/동기화만 재생하고 종료 (테스트/리뷰에 유용)
	local data = loadAll(player.UserId)[key]
	local owned = data and data.hasBadge or false
	if not owned then
		local okCheck, has = pcall(function()
			return BadgeService:UserHasBadgeAsync(player.UserId, cfg.badgeId)
		end)
		owned = okCheck and has == true or false
	end
	if owned then
		sendToast(player, key)
		if cfg.unlockTags and #cfg.unlockTags > 0 then
			pushUnlockTags(player)
		end
		return true, "already_has"
	end

	-- 실제 수여
	local ok, err = pcall(function()
		BadgeService:AwardBadge(player.UserId, cfg.badgeId)
	end)
	if not ok then
		warn("[BadgeManager] AwardBadge failed: ", err)
		return false, "award_failed"
	end

	-- 저장 + 연출
	local all = loadAll(player.UserId)
	all[key] = { hasBadge = true, awardedAt = os.time() }
	saveAll(player.UserId)

	sendToast(player, key)
	if cfg.unlockTags and #cfg.unlockTags > 0 then
		pushUnlockTags(player)
	end

	if cfg.oneTimeReward then
		task.spawn(function()
			pcall(function() cfg.oneTimeReward(player) end)
		end)
	end
	return true, nil
end


-- 서버 내 모든 플레이어에게 일괄 지급 (Great Team 등)
function BadgeManager.TryAwardAllInServer(key: string): {awarded: number, failed: number}
	local result = { awarded = 0, failed = 0 }
	for _, plr in ipairs(Players:GetPlayers()) do
		local ok, err = BadgeManager.TryAward(plr, key)
		if ok then result.awarded += 1 else result.failed += 1 end
	end
	return result
end

-- Roblox 권위 기준 보유 여부
function BadgeManager.HasRobloxBadge(player: Player, key: string): boolean
	local cfg = BADGES[key]; if not cfg then return false end
	local data = loadAll(player.UserId)[key]
	if data and data.hasBadge then return true end
	-- 캐시에 없으면 동기화
	syncRobloxBadgeFlag(player.UserId, key, cfg.badgeId)
	saveAll(player.UserId)
	data = loadAll(player.UserId)[key]
	return data and data.hasBadge or false
end

-- 효과 활성 여부(영구/타임드)
function BadgeManager.IsEffectActive(player: Player, key: string): boolean
	local cfg = BADGES[key]; if not cfg then return false end
	if not BadgeManager.HasRobloxBadge(player, key) then return false end
	local st = loadAll(player.UserId)[key]; if not st then return false end
	if cfg.effect.mode == "permanent" then
		return true
	else
		return now() < (st.awardedAt + cfg.effect.seconds)
	end
end

-- 태그 게이팅(예: HasUnlock(player, "ui:jumper_buy_enable"))
function BadgeManager.HasUnlock(player: Player, tag: string): boolean
	for key, cfg in pairs(BADGES) do
		if cfg.unlockTags then
			for _, t in ipairs(cfg.unlockTags) do
				if t == tag and BadgeManager.IsEffectActive(player, key) then
					return true
				end
			end
		end
	end
	return false
end

-- 현재 언락 태그 목록을 클라에 다시 보내고 싶을 때(예: NPC 상호작용 시점)
function BadgeManager.PushActiveUnlocks(player: Player)
	pushUnlockTags(player)
end

-- 보유/활성 요약(디버그)
function BadgeManager.Snapshot(player: Player): {[string]: {has: boolean, active: boolean, awardedAt: number}}
	local out: {[string]: {has: boolean, active: boolean, awardedAt: number}} = {}
	local dataAll = loadAll(player.UserId)
	for key, cfg in pairs(BADGES) do
		local st = dataAll[key]
		local has = BadgeManager.HasRobloxBadge(player, key)
		local active = BadgeManager.IsEffectActive(player, key)
		out[key] = { has = has, active = active, awardedAt = st and st.awardedAt or 0 }
	end
	return out
end

-- 이후 배지를 쉽게 추가할 수 있는 등록 함수(선택)
function BadgeManager.Register(key: string, cfg: BadgeConfig)
	BADGES[key] = cfg
end

return BadgeManager
