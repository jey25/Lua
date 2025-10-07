--!strict

-- ServerScriptService/PlayerDataService.lua
-- Reviewed & revised on 2025-09-23
-- Key changes:
--  * Buff persistence is disabled by default (session-only buffs) → prevents EXP multiplier from resurrecting after rejoin
--  * De-duplicated attribute writes; safer default merging & sanitization
--  * Save throttling clarified; retries added for UpdateAsync
--  * Autosave interval constant; clearer "reason" handling
--  * Active pets list cleaned & deduplicated against ownedPets

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

-- =====================
-- Config
-- =====================
local DS_NAME = "PlayerData_v2"
local AUTOSAVE_INTERVAL = 30            -- seconds
local SAVE_COOLDOWN_SECS = 15           -- seconds between saves per profile (except whitelisted reasons)
local MAX_UPDATE_RETRIES = 3            -- retries for UpdateAsync on transient failures

-- Important: session-only buffs should not be persisted
local PERSIST_BUFFS = true  -- ✅ 영속화 켬 (Exp2x/Speed만 저장되도록 BuffService가 필터링)

-- =====================
-- Types
-- =====================
local store = DataStoreService:GetDataStore(DS_NAME)

type OwnedPet = { affection: number, vaccines: { count: number } }
type BuffInfo = { expiresAt: number, params: { [string]: any } }

-- type PlayerData = {...} 정의에 필드 추가
type PlayerData = {
	coins: number,
	level: number,
	exp: number,
	selectedPetName: string?,
	vaccineCount: number,
	ownedPets: { [string]: OwnedPet },
	buffs: { [string]: BuffInfo },
	lettersRead: {[string]: boolean}?, -- ★ 추가: Letter 진행(키→true)
	lastVaxAt: number?,
	nextVaxAt: number?,
	activePets: { string }?,
	civicStatus: string?, -- "none" | "good" | "suspicious"
}

-- DEFAULT 에도 추가
local DEFAULT: PlayerData = {
	coins = 0, level = 1, exp = 0,
	selectedPetName = nil,
	vaccineCount = 0,
	ownedPets = {},
	buffs = {},
	lettersRead = {}, -- ★ 추가
	lastVaxAt = 0,
	nextVaxAt = 0,
	activePets = {},
	civicStatus = "none",
}

local PlayerDataService = {}

-- Internal profile table
local _profiles: { [number]: { data: PlayerData, dirty: boolean, lastSave: number } } = {}

-- =====================
-- Utils
-- =====================
local function deepCopy<T>(t: T): T
	if type(t) ~= "table" then return t end
	local out: any = {}
	for k, v in pairs(t) do
		out[k] = deepCopy(v)
	end
	return out
end

local function clampNonNeg(n: number): number
	return math.max(0, math.floor(n))
end

local function isStringArray(a: any): boolean
	if type(a) ~= "table" then return false end
	for i, v in ipairs(a) do
		if type(v) ~= "string" then return false end
	end
	return true
end

local function sanitizeLettersMap(anyMap: any): {[string]: boolean}
	local out: {[string]: boolean} = {}
	if type(anyMap) ~= "table" then return out end
	for k, v in pairs(anyMap) do
		if type(k) == "string" and v == true then
			out[k] = true
		end
	end
	return out
end

-- Utils 부근에 추가
local function normalizeCivicStatus(s: any): string
	s = tostring(s or "none")
	if s == "good" or s == "suspicious" then return s end
	return "none"
end


local function sanitizeOwnedPets(tbl: any): { [string]: OwnedPet }
	local owned: { [string]: OwnedPet } = {}
	if type(tbl) ~= "table" then return owned end
	for name, pet in pairs(tbl) do
		if type(name) == "string" then
			if type(pet) ~= "table" then
				owned[name] = { affection = 0, vaccines = { count = 0 } }
			else
				local affection = tonumber((pet :: any).affection) or 0
				local vaccines = (type((pet :: any).vaccines) == "table") and (pet :: any).vaccines or { count = 0 }
				local count = tonumber((vaccines :: any).count) or 0
				owned[name] = { affection = clampNonNeg(affection), vaccines = { count = clampNonNeg(count) } }
			end
		end
	end
	return owned
end

local function sanitizeActivePets(list: any, owned: { [string]: OwnedPet }): { string }
	local out: { string } = {}
	if not isStringArray(list) then return out end
	local seen: { [string]: boolean } = {}
	for _, name in ipairs(list :: { string }) do
		if owned[name] and not seen[name] then
			seen[name] = true
			table.insert(out, name)
		end
	end
	return out
end

local function sanitizeBuffsMap(buffsAny: any): { [string]: BuffInfo }
	local out = {}
	if type(buffsAny) ~= "table" then return out end
	for kind, info in pairs(buffsAny) do
		if type(kind) == "string" and type(info) == "table" then
			local expiresAt = tonumber(info.expiresAt) or 0  -- 벽시계(UNIX)로 보정
			local params = type(info.params) == "table" and info.params or {}
			out[kind] = { expiresAt = expiresAt, params = deepCopy(params) }
		end
	end
	return out
end


local function mergeDefault(dataAny: any): PlayerData
	if type(dataAny) ~= "table" then
		return deepCopy(DEFAULT)
	end

	local merged: PlayerData = deepCopy(DEFAULT)
	for k, v in pairs(dataAny) do
		(merged :: any)[k] = v
	end

	merged.ownedPets = sanitizeOwnedPets(merged.ownedPets)
	merged.activePets = sanitizeActivePets(merged.activePets, merged.ownedPets)

	merged.coins = clampNonNeg(tonumber(merged.coins) or 0)
	merged.level = math.max(1, math.floor(tonumber(merged.level) or 1))
	merged.exp   = clampNonNeg(tonumber(merged.exp) or 0)
	merged.vaccineCount = clampNonNeg(tonumber(merged.vaccineCount) or 0)
	merged.lastVaxAt = clampNonNeg(tonumber(merged.lastVaxAt) or 0)
	merged.nextVaxAt = clampNonNeg(tonumber(merged.nextVaxAt) or 0)

	-- Buffs: may be ignored depending on PERSIST_BUFFS
	merged.buffs = sanitizeBuffsMap(merged.buffs)
	merged.civicStatus = normalizeCivicStatus(merged.civicStatus)
	merged.lettersRead = sanitizeLettersMap(merged.lettersRead)

	return merged
end

-- =====================
-- Profile access
-- =====================
function PlayerDataService:Get(player: Player): PlayerData
	local p = _profiles[player.UserId]
	return p and p.data or self:Load(player)
end

function PlayerDataService:MarkDirty(player: Player)
	local p = _profiles[player.UserId]
	if p then p.dirty = true end
end

-- =====================
-- Load
-- =====================
function PlayerDataService:Load(player: Player): PlayerData
	local userId = player.UserId
	if _profiles[userId] then
		return _profiles[userId].data
	end

	local key = ("u_%d"):format(userId)
	local loaded: any
	local ok, err = pcall(function()
		loaded = store:GetAsync(key)
	end)
	if not ok then
		warn(('[PDS] GetAsync failed for %d: %s'):format(userId, tostring(err)))
	end

	local data = mergeDefault(loaded)
	_profiles[userId] = { data = data, dirty = false, lastSave = 0 }

	-- Convenience attributes for HUD (ExperienceService will recompute ExpToNext)
	player:SetAttribute("Level", data.level)
	player:SetAttribute("Exp", data.exp)
	player:SetAttribute("ExpToNext", 0)
	player:SetAttribute("VaccinationCount", data.vaccineCount)
	
	-- PlayerDataService:Load 마지막의 HUD attribute 설정 직후에 추가
	local cs = data.civicStatus or "none"
	player:SetAttribute("CivicStatus", cs)
	player:SetAttribute("IsGoodCitizen", cs == "good")
	player:SetAttribute("IsSuspiciousPerson", cs == "suspicious")


	return data
end

-- =====================
-- Save
-- =====================
local function shouldSave(profile: { data: PlayerData, dirty: boolean, lastSave: number }?, reason: string?): boolean
	if not profile then return false end
	if RunService:IsStudio() then return true end
	if reason == "shutdown" or reason == "leave" or reason == "vaccinate" or reason == "manual-reset" then
		return true
	end
	local now = os.clock()
	return (now - (profile.lastSave or 0)) >= SAVE_COOLDOWN_SECS
end

function PlayerDataService:Save(userId: number, reason: string?): boolean
	local profile = _profiles[userId]
	if not profile then return false end
	if not shouldSave(profile, reason) then return false end

	local key = ("u_%d"):format(userId)
	local data = profile.data

	local function updateOnce()
		store:UpdateAsync(key, function(old)
			old = mergeDefault(old)
			-- overwrite fields from current profile
			old.coins = clampNonNeg(tonumber(data.coins) or 0)
			old.level = math.max(1, math.floor(tonumber(data.level) or 1))
			old.exp   = clampNonNeg(tonumber(data.exp) or 0)
			old.selectedPetName = data.selectedPetName
			old.vaccineCount = clampNonNeg(tonumber(data.vaccineCount) or 0)
			old.ownedPets = deepCopy(data.ownedPets or {})
			old.lastVaxAt = clampNonNeg(tonumber(data.lastVaxAt) or 0)
			old.nextVaxAt = clampNonNeg(tonumber(data.nextVaxAt) or 0)
			old.activePets = deepCopy(data.activePets or {})
			-- Save() 의 updateOnce() 내부에서 overwrite 부분에 추가
			old.civicStatus = normalizeCivicStatus(data.civicStatus)
			old.lettersRead = sanitizeLettersMap(data.lettersRead)


			if PERSIST_BUFFS then
				old.buffs = sanitizeBuffsMap(data.buffs)
			else
				old.buffs = {}
			end

			return old
		end)
	end

	local ok = false
	local lastErr: any = nil
	for attempt = 1, MAX_UPDATE_RETRIES do
		ok, lastErr = pcall(updateOnce)
		if ok then break end
		if attempt < MAX_UPDATE_RETRIES then
			-- simple backoff
			task.wait(attempt * 0.5)
		end
	end

	if ok then
		profile.dirty = false
		profile.lastSave = os.clock()
	else
		warn(('[PDS] Save failed for %d (%s): %s'):format(userId, tostring(reason or 'n/a'), tostring(lastErr)))
	end
	return ok
end

-- =====================
-- Public getters / setters
-- =====================
function PlayerDataService:GetOwnedPetNames(player: Player): {string}
	local d = self:Get(player)
	local arr: {string} = {}
	for name in pairs(d.ownedPets or {}) do
		table.insert(arr, name)
	end
	return arr
end

-- PlayerDataService.lua (public API 섹션에 추가)
function PlayerDataService:ResetCivicStatus(player: Player)
	local d = self:Get(player)
	d.civicStatus = "none"
	player:SetAttribute("CivicStatus", "none")
	player:SetAttribute("IsGoodCitizen", false)
	player:SetAttribute("IsSuspiciousPerson", false)
	self:MarkDirty(player)
end


function PlayerDataService:GetCivicStatus(player: Player): string
	return normalizeCivicStatus(self:Get(player).civicStatus)
end

function PlayerDataService:SetCivicStatus(player: Player, status: string)
	status = normalizeCivicStatus(status)
	local d = self:Get(player)
	d.civicStatus = status
	-- 속성으로도 즉시 노출 (클라/다른 NPC 분기 용이)
	player:SetAttribute("CivicStatus", status)
	player:SetAttribute("IsGoodCitizen", status == "good")
	player:SetAttribute("IsSuspiciousPerson", status == "suspicious")
	self:MarkDirty(player)
end


function PlayerDataService:GetActivePets(player: Player): {string}
	local d = self:Get(player)
	return sanitizeActivePets(d.activePets, d.ownedPets)
end

function PlayerDataService:SetActivePets(player: Player, names: {string})
	local d = self:Get(player)
	d.activePets = sanitizeActivePets(names, d.ownedPets)
	self:MarkDirty(player)
end

-- PlayerDataService.lua 내 Public getters / setters 근처에 추가
function PlayerDataService:GetVaccineCount(player: Player): number
	return clampNonNeg(tonumber(self:Get(player).vaccineCount) or 0)
end

function PlayerDataService:IncVaccineCount(player: Player, by: number?): number
	local d = self:Get(player)
	d.vaccineCount = clampNonNeg((d.vaccineCount or 0) + (by or 1))
	-- HUD 동기화도 같이
	local attr = d.vaccineCount
	if player and player.Parent then
		player:SetAttribute("VaccinationCount", attr)
	end
	self:MarkDirty(player)
	return d.vaccineCount
end


-- Vaccination timestamps
function PlayerDataService:GetLastVaxAt(player: Player): number
	return clampNonNeg(tonumber(self:Get(player).lastVaxAt) or 0)
end
function PlayerDataService:SetLastVaxAt(player: Player, ts: number)
	local d = self:Get(player); d.lastVaxAt = clampNonNeg(ts); self:MarkDirty(player)
end
function PlayerDataService:GetNextVaccinationAt(player: Player): number
	return clampNonNeg(tonumber(self:Get(player).nextVaxAt) or 0)
end
function PlayerDataService:SetNextVaccinationAt(player: Player, ts: number)
	local d = self:Get(player); d.nextVaxAt = clampNonNeg(ts); self:MarkDirty(player)
end

-- Coins
function PlayerDataService:GetCoins(player: Player): number
	return self:Get(player).coins
end
function PlayerDataService:SetCoins(player: Player, amount: number)
	local d = self:Get(player)
	d.coins = clampNonNeg(amount)
	self:MarkDirty(player)
end
function PlayerDataService:AddCoins(player: Player, delta: number): number
	local d = self:Get(player)
	d.coins = clampNonNeg((d.coins or 0) + (delta or 0))
	self:MarkDirty(player)
	return d.coins
end

-- Level / Exp
function PlayerDataService:GetLevelExp(player: Player): (number, number)
	local d = self:Get(player)
	return d.level, d.exp
end
function PlayerDataService:SetLevelExp(player: Player, level: number, exp: number)
	local d = self:Get(player)
	d.level = math.max(1, math.floor(level or 1))
	d.exp   = clampNonNeg(exp)
	self:MarkDirty(player)
end

-- Buffs (persist optional)
function PlayerDataService:SetBuffs(player: Player, buffs: { [string]: BuffInfo })
	local d = self:Get(player)
	if PERSIST_BUFFS then
		d.buffs = sanitizeBuffsMap(buffs)
	else
		d.buffs = {}
	end
	self:MarkDirty(player)
end
function PlayerDataService:GetBuffs(player: Player): { [string]: BuffInfo }
	local d = self:Get(player)
	if PERSIST_BUFFS then
		return sanitizeBuffsMap(d.buffs)
	end
	return {}
end

-- Pets
function PlayerDataService:AddOwnedPet(player: Player, petName: string)
	local d = self:Get(player)
	if type(petName) ~= "string" or petName == "" then return end
	d.ownedPets[petName] = d.ownedPets[petName] or { affection = 0, vaccines = { count = 0 } }
	self:MarkDirty(player)
end
function PlayerDataService:HasOwnedPet(player: Player, petName: string): boolean
	local d = self:Get(player)
	return d.ownedPets[petName] ~= nil
end
function PlayerDataService:GetOwnedPetInfo(player: Player, petName: string): OwnedPet
	local d = self:Get(player)
	return d.ownedPets[petName]
end
function PlayerDataService:AddAffection(player: Player, petName: string, delta: number): number
	self:AddOwnedPet(player, petName)
	local d = self:Get(player)
	local info = d.ownedPets[petName]
	info.affection = clampNonNeg((info.affection or 0) + (delta or 0))
	self:MarkDirty(player)
	return info.affection
end
function PlayerDataService:IncPetVaccine(player: Player, petName: string, by: number?): number
	self:AddOwnedPet(player, petName)
	local d = self:Get(player)
	local info = d.ownedPets[petName]
	info.vaccines.count = clampNonNeg((info.vaccines.count or 0) + (by or 1))
	self:MarkDirty(player)
	return info.vaccines.count
end
function PlayerDataService:SetSelectedPet(player: Player, petName: string?)
	local d = self:Get(player)
	d.selectedPetName = petName
	self:MarkDirty(player)
end

-- Letter 진행 읽기
function PlayerDataService:GetLettersRead(player: Player): {[string]: boolean}
	local d = self:Get(player)
	return sanitizeLettersMap(d.lettersRead)
end

-- 특정 Letter 키를 읽음 처리. (이미 읽었으면 changed=false)
function PlayerDataService:MarkLetterRead(player: Player, key: string): (boolean, number)
	if type(key) ~= "string" or key == "" then return false, 0 end
	local d = self:Get(player)
	d.lettersRead = d.lettersRead or {}
	if d.lettersRead[key] then
		-- 이미 기록 있음
		local cnt = 0
		for _, v in pairs(d.lettersRead) do if v then cnt += 1 end end
		return false, cnt
	end
	d.lettersRead[key] = true
	self:MarkDirty(player)
	-- 카운트 반환
	local cnt = 0
	for _, v in pairs(d.lettersRead) do if v then cnt += 1 end end
	return true, cnt
end

function PlayerDataService:GetLetterReadCount(player: Player): number
	local d = self:Get(player)
	local cnt = 0
	for _, v in pairs(d.lettersRead or {}) do
		if v then cnt += 1 end
	end
	return cnt
end


-- =====================
-- Autosave & lifecycle
-- =====================

task.spawn(function()
	while task.wait(AUTOSAVE_INTERVAL) do
		for userId, p in pairs(_profiles) do
			if p.dirty then
				PlayerDataService:Save(userId, "autosave")
			end
		end
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	PlayerDataService:Save(plr.UserId, "leave")
	_profiles[plr.UserId] = nil
end)

game:BindToClose(function()
	for _, plr in ipairs(Players:GetPlayers()) do
		PlayerDataService:Save(plr.UserId, "shutdown")
	end
end)

return PlayerDataService
