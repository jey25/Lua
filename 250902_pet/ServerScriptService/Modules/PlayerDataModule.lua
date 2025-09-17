-- ServerScriptService/PlayerDataService.lua
--!strict
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DS_NAME = "PlayerData_v2"
local store = DataStoreService:GetDataStore(DS_NAME)

type OwnedPet = { affection: number, vaccines: { count: number } }
-- 상단 타입들에 추가/수정
type BuffInfo = { expiresAt: number, params: { [string]: any } }


-- 상단 타입/DEFAULT 보강
type PlayerData = {
	coins: number,
	level: number,
	exp: number,
	selectedPetName: string?,
	vaccineCount: number,
	ownedPets: { [string]: OwnedPet },
	buffs: { [string]: BuffInfo },
	-- ⬇ 추가
	lastVaxAt: number?,   -- 마지막 접종 시각(UTC epoch)
	nextVaxAt: number?,   -- 다음 접종 가능 시각(UTC epoch)
}

local DEFAULT: PlayerData = {
	coins = 0, level = 1, exp = 0,
	selectedPetName = nil,
	vaccineCount = 0,
	ownedPets = {},
	buffs = {},
	-- ⬇ 추가 (초기 0)
	lastVaxAt = 0,
	nextVaxAt = 0,
}

local PlayerDataService = {}

local _profiles: { [number]: { data: PlayerData, dirty: boolean, lastSave: number } } = {}

local function deepCopy<T>(t: T): T
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do
		out[k] = deepCopy(v)
	end
	return (out :: any)
end

local function mergeDefault(data: any): PlayerData
	if type(data) ~= "table" then return deepCopy(DEFAULT) end
	-- 얕은 머지 + 필수 필드 보정
	local merged = deepCopy(DEFAULT)
	for k, v in pairs(data) do
		(merged :: any)[k] = v
	end
	-- ownedPets 필드 보정
	if type(merged.ownedPets) ~= "table" then
		merged.ownedPets = {}
	end
	-- 백신/애정도 같은 내부 필드 보정
	for name, pet in pairs(merged.ownedPets) do
		if type(pet) ~= "table" then merged.ownedPets[name] = { affection = 0, vaccines = { count = 0 } }
		else
			if type(pet.affection) ~= "number" then pet.affection = 0 end
			if type(pet.vaccines) ~= "table" then pet.vaccines = { count = 0 }
			elseif type(pet.vaccines.count) ~= "number" then pet.vaccines.count = 0 end
		end
	end
	
	-- 숫자 필드 보정
	merged.coins = math.max(0, tonumber(merged.coins) or 0)
	merged.level = math.max(1, tonumber(merged.level) or 1)
	merged.exp   = math.max(0, tonumber(merged.exp) or 0)
	merged.vaccineCount = math.max(0, tonumber(merged.vaccineCount) or 0)
	-- mergeDefault() 안 숫자 필드 보정 끝부분에 추가
	merged.lastVaxAt = math.max(0, tonumber(merged.lastVaxAt) or 0)
	merged.nextVaxAt = math.max(0, tonumber(merged.nextVaxAt) or 0)

	
	if type(merged.buffs) ~= "table" then
		merged.buffs = {}
	else
		for kind, info in pairs(merged.buffs) do
			if type(info) ~= "table" then
				merged.buffs[kind] = nil
			else
				info.expiresAt = tonumber(info.expiresAt) or 0
				if type(info.params) ~= "table" then info.params = {} end
			end
		end
	end
	
	
	return merged
end

-- 안전 로드
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

	local data = mergeDefault(ok and loaded or nil)
	_profiles[userId] = { data = data, dirty = false, lastSave = 0 }

	-- 편의상 속성에도 심어두면 HUD 등이 쉽게 사용 가능
	player:SetAttribute("Level", data.level)
	player:SetAttribute("Exp", data.exp)
	player:SetAttribute("ExpToNext", 0) -- 실제 값은 ExperienceService가 즉시 계산/동기화
	player:SetAttribute("VaccinationCount", data.vaccineCount)
	-- ▼ Load() 마지막의 편의 Attributes에 추가
	player:SetAttribute("VaccinationCount", data.vaccineCount)
	-- Save(): UpdateAsync 콜백 안, 필드 덮어쓰기 부분에 추가



	return data
end

-- 저장 쓰로틀 완화: 접종/수동리셋은 예외 허용
local function canSave(profile, reason: string?) : boolean
	if not profile then return false end
	if RunService:IsStudio() then return true end
	if reason == "shutdown" or reason == "vaccinate" or reason == "manual-reset" then
		return true
	end
	local now = os.clock()
	return (now - (profile.lastSave or 0)) >= 15
end



-- 안전 저장(UpdateAsync)
function PlayerDataService:Save(userId: number, reason: string?): boolean
	local profile = _profiles[userId]
	if not profile then return false end

	-- ✅ autosave만 쿨다운 적용, leave/shutdown은 무조건 허용
	if reason == "autosave" and not canSave(profile) then
		return false
	end
	
	-- Save 호출부에서 canSave(profile, reason) 사용
	if not canSave(profile, reason) then return false end

	local key = ("u_%d"):format(userId)
	local data = profile.data

	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old)
			old = mergeDefault(old)
			-- 최신 상태로 덮어쓰기
			old.coins = math.max(0, tonumber(data.coins) or 0)
			old.level = math.max(1, tonumber(data.level) or 1)
			old.exp   = math.max(0, tonumber(data.exp) or 0)
			old.selectedPetName = data.selectedPetName
			old.vaccineCount = math.max(0, tonumber(data.vaccineCount) or 0)
			old.ownedPets = deepCopy(data.ownedPets or {})
			-- Save()의 UpdateAsync 콜백 안에서:
			old.buffs = deepCopy(data.buffs or {})
			-- ▼ Save()의 UpdateAsync 콜백 안에 추가
			old.lastVaxAt = math.max(0, tonumber(data.lastVaxAt) or 0)
			old.nextVaxAt = math.max(0, tonumber(data.nextVaxAt) or 0)

			return old
		end)
	end)

	if ok then
		profile.dirty = false
		profile.lastSave = os.clock()
	else
		warn(("[PDS] Save failed for %d (%s): %s"):format(userId, reason or "n/a", tostring(err)))
	end
	return ok
end

function PlayerDataService:MarkDirty(player: Player)
	local p = _profiles[player.UserId]; if not p then return end
	p.dirty = true
end

function PlayerDataService:Get(player: Player): PlayerData
	local p = _profiles[player.UserId]
	return p and p.data or self:Load(player)
end

-- 편의 메서드들 ------------------------------

-- ▼ 편의 메서드 추가

-- 편의 함수 추가
function PlayerDataService:GetLastVaxAt(player: Player): number
	return math.max(0, tonumber(self:Get(player).lastVaxAt) or 0)
end
function PlayerDataService:SetLastVaxAt(player: Player, ts: number)
	local d = self:Get(player); d.lastVaxAt = math.max(0, math.floor(ts or 0)); self:MarkDirty(player)
end
function PlayerDataService:GetNextVaccinationAt(player: Player): number
	local d = self:Get(player)
	return math.max(0, tonumber(d.nextVaxAt) or 0)
end
function PlayerDataService:SetNextVaccinationAt(player: Player, ts: number)
	local d = self:Get(player); d.nextVaxAt = math.max(0, math.floor(ts or 0)); self:MarkDirty(player)
end



function PlayerDataService:GetCoins(player: Player): number
	return self:Get(player).coins
end

function PlayerDataService:SetCoins(player: Player, amount: number)
	local d = self:Get(player)
	d.coins = math.max(0, math.floor(amount or 0))
	self:MarkDirty(player)
end

function PlayerDataService:AddCoins(player: Player, delta: number): number
	local d = self:Get(player)
	d.coins = math.max(0, math.floor((d.coins or 0) + (delta or 0)))
	self:MarkDirty(player)
	return d.coins
end

function PlayerDataService:GetLevelExp(player: Player): (number, number)
	local d = self:Get(player)
	return d.level, d.exp
end

function PlayerDataService:SetBuffs(player: Player, buffs: { [string]: BuffInfo })
	local d = self:Get(player)
	-- 만료된 것만 필터링해서 저장해도 되지만, BuffService.persist에서 이미 필터링했음.
	d.buffs = deepCopy(buffs or {})
	self:MarkDirty(player)
end

function PlayerDataService:GetBuffs(player: Player): { [string]: BuffInfo }
	local d = self:Get(player)
	return d.buffs or {}
end

function PlayerDataService:SetLevelExp(player: Player, level: number, exp: number)
	local d = self:Get(player)
	d.level = math.max(1, math.floor(level or 1))
	d.exp   = math.max(0, math.floor(exp or 0))
	self:MarkDirty(player)
end

function PlayerDataService:GetVaccineCount(player: Player): number
	return self:Get(player).vaccineCount or 0
end

function PlayerDataService:SetVaccineCount(player: Player, count: number)
	local d = self:Get(player)
	d.vaccineCount = math.max(0, math.floor(count or 0))
	player:SetAttribute("VaccinationCount", d.vaccineCount)
	self:MarkDirty(player)
end

function PlayerDataService:IncVaccineCount(player: Player, by: number?): number
	local d = self:Get(player)
	d.vaccineCount = math.max(0, math.floor((d.vaccineCount or 0) + (by or 1)))
	player:SetAttribute("VaccinationCount", d.vaccineCount)
	self:MarkDirty(player)
	return d.vaccineCount
end

function PlayerDataService:AddOwnedPet(player: Player, petName: string)
	local d = self:Get(player)
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
	info.affection = math.max(0, (info.affection or 0) + (delta or 0))
	self:MarkDirty(player)
	return info.affection
end

function PlayerDataService:IncPetVaccine(player: Player, petName: string, by: number?): number
	self:AddOwnedPet(player, petName)
	local d = self:Get(player)
	local info = d.ownedPets[petName]
	info.vaccines.count = math.max(0, (info.vaccines.count or 0) + (by or 1))
	self:MarkDirty(player)
	return info.vaccines.count
end

function PlayerDataService:SetSelectedPet(player: Player, petName: string?)
	local d = self:Get(player)
	d.selectedPetName = petName
	self:MarkDirty(player)
end

-- 루프/정리 ------------------------------

task.spawn(function()
	while task.wait(30) do
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

