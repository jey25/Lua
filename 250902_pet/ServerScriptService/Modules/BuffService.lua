-- ServerScriptService/BuffService.lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local _charConn: { [number]: RBXScriptConnection } = {}

-- Remotes 세팅
local BuffFolder = ReplicatedStorage:FindFirstChild("BuffEvents")
if not BuffFolder then
	BuffFolder = Instance.new("Folder")
	BuffFolder.Name = "BuffEvents"
	BuffFolder.Parent = ReplicatedStorage
end

local BuffApplied = BuffFolder:FindFirstChild("BuffApplied") :: RemoteEvent
if not BuffApplied then
	BuffApplied = Instance.new("RemoteEvent")
	BuffApplied.Name = "BuffApplied"
	BuffApplied.Parent = BuffFolder
end

local GetActiveBuffs = BuffFolder:FindFirstChild("GetActiveBuffs") :: RemoteFunction
if not GetActiveBuffs then
	GetActiveBuffs = Instance.new("RemoteFunction")
	GetActiveBuffs.Name = "GetActiveBuffs"
	GetActiveBuffs.Parent = BuffFolder
end

-- 내부 상태
type BuffInfo = { expiresAt: number, params: {[string]: any}? }
local _active: { [number]: { [string]: BuffInfo } } = {}  -- by userId

local BuffService = {}

-- ===== 유틸 =====
local function now() return os.time() end

local function getActiveTable(player: Player)
	local t = _active[player.UserId]
	if not t then
		t = {}
		_active[player.UserId] = t
	end
	return t
end

local function ensureCharHook(player: Player, onChar: (Model?) -> ())
	-- 기존 연결 해제
	local old = _charConn[player.UserId]
	if old then old:Disconnect() end
	_charConn[player.UserId] = player.CharacterAdded:Connect(function(char)
		task.defer(function() onChar(char) end)
	end)
	-- 현재 캐릭터에도 즉시 적용
	onChar(player.Character)
end



-- applySpeedEffect 수정
local function applySpeedEffect(player: Player)
	local buffs = getActiveTable(player)
	local mult = 1
	local b = buffs["Speed"]
	if b and (b.expiresAt or 0) > now() then
		local m = tonumber(b.params and b.params.mult) or 1.5
		mult = math.max(0.1, m)
	end
	player:SetAttribute("SpeedMultiplier", mult)

	local function applyToChar(char: Model?)
		local humanoid = char and char:FindFirstChildWhichIsA("Humanoid")
		if not humanoid then return end
		local base = tonumber(player:GetAttribute("BaseWalkSpeed")) or humanoid.WalkSpeed
		player:SetAttribute("BaseWalkSpeed", base)
		humanoid.WalkSpeed = base * mult
	end

	-- ✅ 중복 방지 훅
	ensureCharHook(player, applyToChar)
end



local function applyExpEffect(player: Player)
	-- 경험치 배율 = 1 기본, Exp2x 버프 있으면 2(혹은 params.mult)
	local buffs = getActiveTable(player)
	local mult = 1
	local b = buffs["Exp2x"]
	if b and (b.expiresAt or 0) > now() then
		local m = tonumber(b.params and b.params.mult) or 2
		mult = math.max(1, m)
	end
	player:SetAttribute("ExpMultiplier", mult)
end

local function reapplyAllEffects(player: Player)
	applySpeedEffect(player)
	applyExpEffect(player)
end

-- ===== 저장/로드 동기화 =====
local function persist(player: Player)
	local data = PlayerDataService:Get(player)
	data.buffs = data.buffs or {}
	-- 현재 활성표만 저장(만료 제거)
	local out = {}
	for kind, info in pairs(getActiveTable(player)) do
		if (info.expiresAt or 0) > now() then
			out[kind] = { expiresAt = info.expiresAt, params = info.params or {} }
		end
	end
	PlayerDataService:SetBuffs(player, out)
end

local function loadFromStore(player: Player)
	local data = PlayerDataService:Load(player)
	local buffs = {}
	if type(data.buffs) == "table" then
		for kind, info in pairs(data.buffs) do
			local expAt = tonumber(info and info.expiresAt) or 0
			if expAt > now() then
				buffs[kind] = { expiresAt = expAt, params = (type(info.params)=="table" and info.params) or {} }
			end
		end
	end
	_active[player.UserId] = buffs
end

-- ===== 퍼블릭 API =====
function BuffService:ApplyBuff(player: Player, kind: string, durationSecs: number, params: {[string]: any}?, toastText: string?)
	local act = getActiveTable(player)
	local untilTs = now() + math.max(1, math.floor(durationSecs or 0))
	local cur = act[kind]

	if cur and (cur.expiresAt or 0) > now() then
		-- 남은 시간 연장(더 길게 유지)
		cur.expiresAt = math.max(cur.expiresAt, untilTs)
		cur.params = cur.params or {}
		for k,v in pairs(params or {}) do cur.params[k] = v end
	else
		act[kind] = { expiresAt = untilTs, params = params or {} }
	end

	-- 실제 효과 적용
	if kind == "Speed" then applySpeedEffect(player)
	elseif kind == "Exp2x" then applyExpEffect(player)
	end

	-- UI 동기화(클라 아이콘/타이머 생성)
	local text = toastText or (kind == "Speed" and "이동 속도 UP!" or (kind=="Exp2x" and "경험치 2배!" or "버프 적용"))
	BuffApplied:FireClient(player, { kind = kind, text = text, expiresAt = act[kind].expiresAt })

	persist(player)
end

function BuffService:ClearBuff(player: Player, kind: string)
	local act = getActiveTable(player)
	act[kind] = nil
	-- 효과 재적용(없음 = 해제)
	if kind == "Speed" then applySpeedEffect(player)
	elseif kind == "Exp2x" then applyExpEffect(player)
	end
	persist(player)
end

function BuffService:GetActive(player: Player)
	local t = {}
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
			text = (kind=="Speed" and "이동 속도 UP!") or (kind=="Exp2x" and "경험치 2배!") or "버프 적용",
			expiresAt = info.expiresAt,
		})
	end
end

-- ===== 수명 루프: 만료 처리 =====
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

-- ===== 플레이어 라이프사이클 =====
Players.PlayerAdded:Connect(function(plr)
	loadFromStore(plr)
	reapplyAllEffects(plr)
	BuffService:SyncToClient(plr)  -- 재접속 시 UI 재생성
end)

Players.PlayerRemoving:Connect(function(plr)
	persist(plr)
	_active[plr.UserId] = nil
end)

-- 클라 초기 동기화용 RF
GetActiveBuffs.OnServerInvoke = function(player: Player)
	local list = {}
	for kind, info in pairs(BuffService:GetActive(player)) do
		table.insert(list, { kind = kind, expiresAt = info.expiresAt, text = (kind=="Speed" and "이동 속도 UP!") or (kind=="Exp2x" and "경험치 2배!") or kind })
	end
	return list
end

return BuffService

