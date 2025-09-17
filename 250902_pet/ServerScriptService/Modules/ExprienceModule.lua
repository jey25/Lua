-- ServerScriptService/ExperienceService.lua
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local LevelSync = ReplicatedStorage:FindFirstChild("LevelSync") or Instance.new("RemoteEvent", ReplicatedStorage)
LevelSync.Name = "LevelSync"


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

local LevelSync = ReplicatedStorage:FindFirstChild("LevelSync") or Instance.new("RemoteEvent", ReplicatedStorage)
LevelSync.Name = "LevelSync"

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

	player:SetAttribute("Level", level)
	player:SetAttribute("Exp", exp)
	player:SetAttribute("ExpToNext", goal)

	lastLevel[player] = level

	-- ✅ 레벨 Attribute 감시자: 어디서 올리든 코인 보상 보장
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

	local level = player:GetAttribute("Level") or 1
	local exp   = player:GetAttribute("Exp") or 0
	local goal  = player:GetAttribute("ExpToNext") or ExpToNext(level)

	exp += amount
	while exp >= goal do
		exp -= goal
		level += 1

		-- ✅ 여기서 즉시 10단계 보상
		if CoinService and type(CoinService.Award) == "function" then
			if level % 10 == 0 then
				-- 콜론 대신 언더스코어 권장(Attributes 이름 안전)
				CoinService:Award(player, ("LV_%d"):format(level))
			end
		end

		goal = ExpToNext(level)
	end

	-- 상태 반영 (기존)
	player:SetAttribute("Level", level)
	player:SetAttribute("Exp",   exp)
	player:SetAttribute("ExpToNext", goal)

	-- ✅ 저장 데이터에도 즉시 반영 (중요!)
	local okPDS, PDS = pcall(function() return require(script.Parent:WaitForChild("PlayerDataService")) end)
	if okPDS and PDS and type(PDS.SetLevelExp) == "function" then
		PDS:SetLevelExp(player, level, exp)   -- dirty 플래그 함께 설정됨
	end

	LevelSync:FireClient(player, {Level = level, Exp = exp, ExpToNext = goal})
end

Players.PlayerAdded:Connect(initPlayerState)
Players.PlayerRemoving:Connect(function(plr) lastLevel[plr] = nil end)

ExperienceService.AddExp = addExp
ExperienceService.ExpToNext = ExpToNext
ExperienceService.InitPlayerState = initPlayerState
return ExperienceService
