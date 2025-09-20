--!strict
-- ServerScriptService/ExperienceService.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

-- Remote: 하나만 만들고 재사용
local LevelSync = ReplicatedStorage:FindFirstChild("LevelSync") :: RemoteEvent
if not LevelSync then
	LevelSync = Instance.new("RemoteEvent")
	LevelSync.Name = "LevelSync"
	LevelSync.Parent = ReplicatedStorage
end

-- ✅ 안전 로더(단일)만 사용
local CoinService: any
do
	local ok, modOrErr = pcall(function()
		local inst = ServerScriptService:WaitForChild("CoinService", 10)
		assert(inst and inst:IsA("ModuleScript"), ("CoinService must be ModuleScript, got %s"):format(inst and inst.ClassName or "nil"))
		return require(inst)
	end)
	if ok then
		CoinService = modOrErr
	else
		warn("[ExperienceService] require(CoinService) failed:", modOrErr)
		CoinService = nil
	end
end

local ExperienceService = {}
local lastLevel: {[Player]: number} = {}

local function ExpToNext(level: number): number
	return math.floor(100 + 50 * (level - 1) * (level - 1))
end

local function initPlayerState(player: Player)
	local data = PlayerDataService:Load(player)
	local level = math.max(1, tonumber(data.level) or 1)
	local exp   = math.max(0, tonumber(data.exp) or 0)
	local goal  = ExpToNext(level)

	-- 🔒 방탄: 세션 시작 시 기본 배율 확정
	player:SetAttribute("ExpMultiplier", 1)
	-- (원하면) 속도 관련도 초기화
	-- player:SetAttribute("SpeedMultiplier", 1)

	player:SetAttribute("Level", level)
	player:SetAttribute("Exp", exp)
	player:SetAttribute("ExpToNext", goal)

	lastLevel[player] = level

	-- 레벨 변화 감시 → 코인 보상 연동
	player:GetAttributeChangedSignal("Level"):Connect(function()
		local oldLv = lastLevel[player] or level
		local newLv = math.max(1, tonumber(player:GetAttribute("Level")) or oldLv)
		if newLv > oldLv and CoinService and CoinService.OnLevelChanged then
			local ok, err = pcall(function()
				CoinService:OnLevelChanged(player, oldLv, newLv)
			end)
			if not ok then warn("[ExperienceService] OnLevelChanged error:", err) end
		end
		lastLevel[player] = newLv
	end)

	LevelSync:FireClient(player, { Level = level, Exp = exp, ExpToNext = goal })
end

local function addExp(player: Player, amount: number)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return end

	-- ✅ 버프 배율 적용 (클램프)
	local multRaw = tonumber(player:GetAttribute("ExpMultiplier")) or 1
	local mult = math.max(1, multRaw)
	amount = math.floor(amount * mult)

	local level = player:GetAttribute("Level") or 1
	local exp   = player:GetAttribute("Exp") or 0
	local goal  = player:GetAttribute("ExpToNext") or ExpToNext(level)

	exp += amount
	while exp >= goal do
		exp -= goal
		level += 1

		if CoinService and type(CoinService.Award) == "function" then
			if level % 10 == 0 then
				CoinService:Award(player, ("LV_%d"):format(level))
			end
		end

		goal = ExpToNext(level)
	end

	player:SetAttribute("Level", level)
	player:SetAttribute("Exp",   exp)
	player:SetAttribute("ExpToNext", goal)

	-- 저장 갱신
	local okPDS, PDS = pcall(function() return require(script.Parent:WaitForChild("PlayerDataService")) end)
	if okPDS and PDS and type(PDS.SetLevelExp) == "function" then
		PDS:SetLevelExp(player, level, exp)
	end

	LevelSync:FireClient(player, {Level = level, Exp = exp, ExpToNext = goal})
end

Players.PlayerAdded:Connect(initPlayerState)

Players.PlayerRemoving:Connect(function(plr)
	-- 🔒 방탄: 퇴장 시 배율을 1로 되돌려 다음 세션 잔존 리스크 제거
	plr:SetAttribute("ExpMultiplier", 1)
	lastLevel[plr] = nil
end)

ExperienceService.AddExp = addExp
ExperienceService.ExpToNext = ExpToNext
ExperienceService.InitPlayerState = initPlayerState
return ExperienceService
