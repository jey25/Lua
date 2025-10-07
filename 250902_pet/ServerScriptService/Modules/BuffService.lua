--!strict
-- ServerScriptService/BuffService.lua  (세션 한정 버프, 모노토닉 만료)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
-- 파일 상단의 상태 정의 근처에 추가
local _attrConn: { [number]: { exp: RBXScriptConnection? } } = {}

-- ===== 설정 =====
-- 세션 한정 버프(저장 안 함) → 영속 전환: false
local EPHEMERAL_BUFFS = false

-- TreatServer(duckbone)과 동일 수치: 50 -> 80 (= 1.6배)
local JUMP_BASE   = 50
local JUMP_TARGET = 80

-- (파일 상단 근처) getActiveTable을 먼저 둠
type BuffParams = { [string]: any }
type BuffInfo = { expiresAt: number, params: BuffParams } -- expiresAt는 os.clock() 기준
type ActiveMap = { [string]: BuffInfo }

local _active: { [number]: ActiveMap } = {}

-- 필요 시 JumpUp을 영속시키려면 여기 화이트리스트에 추가하면 됨.
-- (요청사항은 기존 동작 유지이므로 Speed만 유지)
local PERSIST_WHITELIST = { Speed = true }

-- 만료 체크 시계: 세션 경과 시간(모노토닉)
local function now(): number
	return os.clock()
end

local function getActiveTable(player: Player): ActiveMap
	local t = _active[player.UserId]
	if not t then t = {}; _active[player.UserId] = t end
	return t
end

-- 그 다음 expectedExpMult 정의
local function expectedExpMult(player: Player): number
	local act = getActiveTable(player)
	local b = act["Exp2x"]
	if b and (b.expiresAt or 0) > now() then
		local m = tonumber(b.params and b.params.mult) or 2
		return math.max(1, m)
	end
	return 1
end

local function hookExpAttrGuard(player: Player)
	local uid = player.UserId
	_attrConn[uid] = _attrConn[uid] or {}
	if _attrConn[uid].exp then _attrConn[uid].exp:Disconnect() end

	-- 클라/다른 코드가 ExpMultiplier를 바꿔도 서버가 즉시 되돌림
	_attrConn[uid].exp = player:GetAttributeChangedSignal("ExpMultiplier"):Connect(function()
		local want = expectedExpMult(player)
		local got = tonumber(player:GetAttribute("ExpMultiplier")) or 1
		if math.abs(got - want) > 1e-4 then
			player:SetAttribute("ExpMultiplier", want)
		end
	end)

	-- 초기 강제 세팅
	player:SetAttribute("ExpMultiplier", expectedExpMult(player))
end

-- 클라 UI용 만료 시각(벽시계)이 필요할 때 변환
local function toWallExpires(clockExpiry: number): number
	local remain = math.max(0, math.floor(clockExpiry - now()))
	-- UI가 절대시각을 쓰는 경우를 위해 현재 벽시계 + 남은 시간으로 계산
	return os.time() + remain
end

-- ===== Remotes =====
local BuffFolder = ReplicatedStorage:FindFirstChild("BuffEvents") :: Folder
if not BuffFolder or not BuffFolder:IsA("Folder") then
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

local GetActiveBuffsRF = BuffFolder:FindFirstChild("GetActiveBuffs") :: RemoteFunction
if not GetActiveBuffsRF then
	GetActiveBuffsRF = Instance.new("RemoteFunction")
	GetActiveBuffsRF.Name = "GetActiveBuffs"
	GetActiveBuffsRF.Parent = BuffFolder
end

-- ===== 타입/상태 =====
--(이미 위에서 선언됨)
-- type BuffParams = { [string]: any }
-- type BuffInfo = { expiresAt: number, params: BuffParams }
-- type ActiveMap = { [string]: BuffInfo }

--(이미 위에서 선언됨)
-- local _active: { [number]: ActiveMap } = {}
local _charConn: { [number]: RBXScriptConnection } = {}

local BuffService = {}

--(이미 위에서 선언됨)
-- local function getActiveTable(player: Player): ActiveMap ...

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

-- ===== 효과 적용 =====
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
		local h = char:FindFirstChildWhichIsA("Humanoid")
		if not h then return end
		local baseAttr = player:GetAttribute("BaseWalkSpeed")
		local base = (typeof(baseAttr) == "number") and baseAttr or h.WalkSpeed
		if typeof(baseAttr) ~= "number" then
			player:SetAttribute("BaseWalkSpeed", base)
		end
		h.WalkSpeed = base * mult
	end

	ensureCharHook(player, applyToChar)
end

-- JumpUp(duckbone) 효과: 상점과 동일 50 -> 80 (1.6배)
local function applyJumpEffect(player: Player)
	local buffs = getActiveTable(player)
	local mult = 1.0
	local b = buffs["JumpUp"]
	if b and (b.expiresAt or 0) > now() then
		local params = b.params or {} :: BuffParams
		-- 파라미터 없으면 기본 80/50
		local m = tonumber(params.mult) or (JUMP_TARGET / JUMP_BASE)
		mult = math.max(0.1, m)
	end
	player:SetAttribute("JumpMultiplier", mult)

	local function applyToChar(char: Model?)
		if not char then return end
		local h = char:FindFirstChildWhichIsA("Humanoid")
		if not h then return end

		-- 상점과 동일한 기준: 기본점프력 50을 기준으로 세팅(처음만 기록)
		local baseAttr = player:GetAttribute("BaseJumpPower")
		local base: number
		if typeof(baseAttr) == "number" then
			base = baseAttr
		else
			h.UseJumpPower = true
			base = JUMP_BASE
			player:SetAttribute("BaseJumpPower", base)
		end

		h.UseJumpPower = true
		h.JumpPower = base * mult -- 기본50 * 1.6 = 80
	end

	ensureCharHook(player, applyToChar)
end

-- 깔끔하게: 계산 → 한 번만 세팅
local function applyExpEffect(player: Player)
	player:SetAttribute("ExpMultiplier", expectedExpMult(player))
end

local function reapplyAllEffects(player: Player)
	applySpeedEffect(player)
	applyJumpEffect(player) -- ★ 추가: 점프 효과 재적용
	applyExpEffect(player)
	hookExpAttrGuard(player)
end

-- ===== 저장/로드 =====
local function persist(player: Player)
	-- 저장 시에는 "남은 시간"을 벽시계 만료로 변환하여 저장한다.
	local out: ActiveMap = {}
	for kind, info in pairs(getActiveTable(player)) do
		if PERSIST_WHITELIST[kind] then
			local remain = math.max(0, (info.expiresAt or 0) - now())      -- clock 기준 남은 시간
			if remain > 0 then
				out[kind] = {
					expiresAt = os.time() + remain,                         -- 저장은 벽시계 만료(UNIX)
					params    = info.params or {}
				}
			end
		end
	end
	PlayerDataService:SetBuffs(player, out)
end

local function loadFromStore(player: Player)
	local data = PlayerDataService:Load(player) :: any
	local buffs: ActiveMap = {}
	local wallNow = os.time()

	if type(data) == "table" and type(data.buffs) == "table" then
		for kind, info in pairs(data.buffs) do
			if PERSIST_WHITELIST[kind] and type(info) == "table" then
				local wallExp = tonumber(info.expiresAt) or 0              -- 저장된 만료는 벽시계
				local remain  = wallExp - wallNow
				if remain > 0 then
					buffs[kind] = {
						expiresAt = now() + remain,                        -- 활성 테이블은 clock 기준
						params    = (type(info.params) == "table") and info.params or {}
					}
				end
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
		cur.expiresAt = math.max(cur.expiresAt, untilTs)
		cur.params = cur.params or {}
		for k, v in pairs(params or {}) do (cur.params :: BuffParams)[k] = v end
	else
		act[kind] = { expiresAt = untilTs, params = params or {} }
	end

	if kind == "Speed" then
		applySpeedEffect(player)
	elseif kind == "Exp2x" then
		applyExpEffect(player)
		hookExpAttrGuard(player)  -- ★ 가드 연결 보장
	elseif kind == "JumpUp" then
		applyJumpEffect(player)
	end

	local text = toastText
	if not text then
		if kind == "Speed" then text = "Speed UP!"
		elseif kind == "Exp2x" then text = "Exp 2x!"
		elseif kind == "JumpUp" then text = "JUMP UP!"
		else text = "Buff Apply" end
	end

	-- UI에는 벽시계 만료시각(또는 남은시간 계산용)을 내려줌
	local wallExpires = toWallExpires((act[kind] :: BuffInfo).expiresAt)
	BuffApplied:FireClient(player, { kind = kind, text = text, expiresAt = wallExpires })

	persist(player)
end

function BuffService:ClearBuff(player: Player, kind: string)
	local act = getActiveTable(player)
	act[kind] = nil

	if kind == "Speed" then
		applySpeedEffect(player)
	elseif kind == "Exp2x" then
		applyExpEffect(player)
	elseif kind == "JumpUp" then
		applyJumpEffect(player)
	end

	persist(player)
end

function BuffService:GetActive(player: Player): ActiveMap
	-- 외부 로직에서 쓰더라도 내부는 clock 기반 시각을 유지
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
			text = (kind == "Speed" and "Speed UP!")
				or (kind == "Exp2x" and "Exp 2x!")
				or (kind == "JumpUp" and "JUMP UP!")
				or "Buff Apply",
			expiresAt = toWallExpires(info.expiresAt),
		})
	end
end

-- ===== 만료 루프 =====
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

-- ===== 라이프사이클 =====
Players.PlayerAdded:Connect(function(plr: Player)
	loadFromStore(plr)
	reapplyAllEffects(plr)
	BuffService:SyncToClient(plr)
end)

Players.PlayerRemoving:Connect(function(plr: Player)
	-- 세션 종료 시 반드시 초기화
	_active[plr.UserId] = {}
	plr:SetAttribute("ExpMultiplier", 1)
	plr:SetAttribute("SpeedMultiplier", 1)
	plr:SetAttribute("JumpMultiplier", 1)

	local h = plr.Character and plr.Character:FindFirstChildWhichIsA("Humanoid")
	if h then
		local baseAttr = plr:GetAttribute("BaseWalkSpeed")
		local base = (typeof(baseAttr) == "number") and baseAttr or 16
		h.WalkSpeed = base

		local baseJump = (typeof(plr:GetAttribute("BaseJumpPower")) == "number") and (plr:GetAttribute("BaseJumpPower") :: number) or JUMP_BASE
		h.UseJumpPower = true
		h.JumpPower = baseJump
	end

	local c = _attrConn[plr.UserId]
	if c and c.exp then c.exp:Disconnect() end
	_attrConn[plr.UserId] = nil

	persist(plr) -- EPHEMERAL이면 빈 값 저장되어 다음 접속에 잔존 안 됨
	local ok = pcall(function()
		PlayerDataService:Save(plr.UserId, "leave")
	end)
	if not ok then
		warn("[BuffService] Save on leave failed for", plr.UserId)
	end
end)

-- 클라 초기 동기화용 RF
GetActiveBuffsRF.OnServerInvoke = function(player: Player)
	local list = {}
	for kind, info in pairs(BuffService:GetActive(player)) do
		table.insert(list, {
			kind = kind,
			expiresAt = toWallExpires(info.expiresAt), -- UI 호환
			text = (kind == "Speed" and "Speed UP!")
				or (kind == "Exp2x" and "EXP 2x!")
				or (kind == "JumpUp" and "JUMP UP!")
				or kind,
		})
	end
	return list
end

return BuffService
