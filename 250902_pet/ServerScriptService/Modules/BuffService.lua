--!strict
-- ServerScriptService/BuffService.lua

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Deps
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

-- ===== Helpers: typed remote creators =====
local function ensureRemoteEvent(parent: Instance, name: string): RemoteEvent
	local inst = parent:FindFirstChild(name)
	if inst and inst:IsA("RemoteEvent") then return inst end
	local re = Instance.new("RemoteEvent")
	re.Name = name
	re.Parent = parent
	return re
end

local function ensureRemoteFunction(parent: Instance, name: string): RemoteFunction
	local inst = parent:FindFirstChild(name)
	if inst and inst:IsA("RemoteFunction") then return inst end
	local rf = Instance.new("RemoteFunction")
	rf.Name = name
	rf.Parent = parent
	return rf
end

-- ===== Remotes / Folder =====
local BuffFolder = ReplicatedStorage:FindFirstChild("BuffEvents")
if not BuffFolder or not BuffFolder:IsA("Folder") then
	BuffFolder = Instance.new("Folder")
	BuffFolder.Name = "BuffEvents"
	BuffFolder.Parent = ReplicatedStorage
end

local BuffApplied: RemoteEvent = ensureRemoteEvent(BuffFolder, "BuffApplied")
local GetActiveBuffsRF: RemoteFunction = ensureRemoteFunction(BuffFolder, "GetActiveBuffs")

-- ===== Types / State =====
type BuffParams = { [string]: any }
-- PlayerDataService가 기대하는 형태와 일치: params는 반드시 table
type BuffInfo = { expiresAt: number, params: BuffParams }
type ActiveMap = { [string]: BuffInfo }

local _active: { [number]: ActiveMap } = {}              -- by userId
local _charConn: { [number]: RBXScriptConnection } = {}  -- CharacterAdded hook

local BuffService = {}

-- ===== Utils =====
local function now(): number
	return os.time()
end

local function getActiveTable(player: Player): ActiveMap
	local t = _active[player.UserId]
	if not t then
		t = {}
		_active[player.UserId] = t
	end
	return t
end

local function ensureCharHook(player: Player, onChar: (Model?) -> ())
	-- 기존 훅 제거
	local old = _charConn[player.UserId]
	if old then old:Disconnect() end

	_charConn[player.UserId] = player.CharacterAdded:Connect(function(char: Model)
		task.defer(function() onChar(char) end)
	end)

	-- 현재 캐릭터에도 즉시 적용
	onChar(player.Character)
end

-- ===== Effects =====
local function applySpeedEffect(player: Player)
	local buffs = getActiveTable(player)
	local mult = 1.0
	local b = buffs["Speed"]
	if b and (b.expiresAt or 0) > now() then
		local params = b.params or {} :: BuffParams
		local m = tonumber(params.mult) or 1.5
		mult = math.max(0.1, m)
	end
	player:SetAttribute("SpeedMultiplier", mult)

	local function applyToChar(char: Model?)
		if not char then return end
		local humanoid = char:FindFirstChildWhichIsA("Humanoid")
		if not humanoid then return end
		local baseAttr = player:GetAttribute("BaseWalkSpeed")
		local base = (typeof(baseAttr) == "number") and baseAttr or humanoid.WalkSpeed
		if typeof(baseAttr) ~= "number" then
			player:SetAttribute("BaseWalkSpeed", base)
		end
		humanoid.WalkSpeed = base * mult
	end

	ensureCharHook(player, applyToChar)
end

local function applyExpEffect(player: Player)
	local buffs = getActiveTable(player)
	local mult = 1.0
	local b = buffs["Exp2x"]
	if b and (b.expiresAt or 0) > now() then
		local params = b.params or {} :: BuffParams
		local m = tonumber(params.mult) or 2
		mult = math.max(1, m)
	end
	player:SetAttribute("ExpMultiplier", mult)
end

local function reapplyAllEffects(player: Player)
	applySpeedEffect(player)
	applyExpEffect(player)
end

-- ===== Persist / Load =====
local function persist(player: Player)
	-- 현재 활성만 (만료 제거) — params는 반드시 table 보장
	local out: ActiveMap = {}
	for kind, info in pairs(getActiveTable(player)) do
		if (info.expiresAt or 0) > now() then
			out[kind] = {
				expiresAt = info.expiresAt,
				params = info.params or {}, -- non-nil 보장
			}
		end
	end
	-- ▼ 타입 일치: PlayerDataService는 params가 반드시 table인 BuffInfo를 기대
	PlayerDataService:SetBuffs(player, out)
end

local function loadFromStore(player: Player)
	local data = PlayerDataService:Load(player) :: any
	local buffs: ActiveMap = {}
	if type(data) == "table" and type(data.buffs) == "table" then
		for kind, info in pairs(data.buffs) do
			local expAt = tonumber(info and info.expiresAt) or 0
			if expAt > now() then
				local params = (type(info.params) == "table") and info.params or {}
				buffs[kind] = { expiresAt = expAt, params = params }
			end
		end
	end
	_active[player.UserId] = buffs
end

-- ===== Public API =====
function BuffService:ApplyBuff(player: Player, kind: string, durationSecs: number, params: BuffParams?, toastText: string?)
	local act = getActiveTable(player)
	local untilTs = now() + math.max(1, math.floor(tonumber(durationSecs) or 0))
	local cur = act[kind]

	if cur and (cur.expiresAt or 0) > now() then
		-- 연장
		cur.expiresAt = math.max(cur.expiresAt, untilTs)
		cur.params = cur.params or {}
		for k, v in pairs(params or {}) do
			(cur.params :: BuffParams)[k] = v
		end
	else
		act[kind] = { expiresAt = untilTs, params = params or {} }
	end

	-- 효과 적용
	if kind == "Speed" then
		applySpeedEffect(player)
	elseif kind == "Exp2x" then
		applyExpEffect(player)
	end

	-- UI 동기화
	local text = toastText
	if not text then
		if kind == "Speed" then text = "이동 속도 UP!"
		elseif kind == "Exp2x" then text = "경험치 2배!"
		else text = "버프 적용" end
	end
	BuffApplied:FireClient(player, {
		kind = kind,
		text = text,
		expiresAt = (act[kind] :: BuffInfo).expiresAt,
	})

	persist(player)
end

function BuffService:ClearBuff(player: Player, kind: string)
	local act = getActiveTable(player)
	act[kind] = nil

	if kind == "Speed" then
		applySpeedEffect(player)
	elseif kind == "Exp2x" then
		applyExpEffect(player)
	end

	persist(player)
end

function BuffService:GetActive(player: Player): ActiveMap
	local t: ActiveMap = {}
	for k, info in pairs(getActiveTable(player)) do
		if (info.expiresAt or 0) > now() then
			t[k] = { expiresAt = info.expiresAt, params = info.params or {} }
		end
	end
	return t
end

function BuffService:SyncToClient(player: Player)
	for kind, info in pairs(self:GetActive(player)) do
		BuffApplied:FireClient(player, {
			kind = kind,
			text = (kind == "Speed" and "이동 속도 UP!")
				or (kind == "Exp2x" and "경험치 2배!")
				or "버프 적용",
			expiresAt = info.expiresAt,
		})
	end
end

-- ===== Expiration loop =====
task.spawn(function()
	while task.wait(1) do
		for _, plr in ipairs(Players:GetPlayers()) do
			local act = getActiveTable(plr)
			local dirty = false
			local n = now()
			for kind, info in pairs(act) do
				if (info.expiresAt or 0) <= n then
					act[kind] = nil
					dirty = true
				end
			end
			if dirty then
				reapplyAllEffects(plr)
				persist(plr)
			end
		end
	end
end)

-- ===== Lifecycle =====
Players.PlayerAdded:Connect(function(plr: Player)
	loadFromStore(plr)
	reapplyAllEffects(plr)
	BuffService:SyncToClient(plr)
end)

Players.PlayerRemoving:Connect(function(plr: Player)
	local c = _charConn[plr.UserId]
	if c then c:Disconnect(); _charConn[plr.UserId] = nil end
	persist(plr)
	_active[plr.UserId] = nil
end)

-- ===== Client sync RF (typed 변수로 OnServerInvoke 설정) =====
GetActiveBuffsRF.OnServerInvoke = function(player: Player)
	local list = {}
	for kind, info in pairs(BuffService:GetActive(player)) do
		table.insert(list, {
			kind = kind,
			expiresAt = info.expiresAt,
			text = (kind == "Speed" and "이동 속도 UP!")
				or (kind == "Exp2x" and "경험치 2배!")
				or kind,
		})
	end
	return list
end

return BuffService
