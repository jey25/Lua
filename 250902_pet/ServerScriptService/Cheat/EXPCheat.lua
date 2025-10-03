
--!strict
local ServerStorage     = game:GetService("ServerStorage")
local Players           = game:GetService("Players")

-- ExperienceService 모듈 경로에 맞게 require 하세요.
local ExperienceService = require(game:GetService("ServerScriptService"):WaitForChild("ExperienceService"))

-- CheatBus 확보
local CheatBus = ServerStorage:WaitForChild("CheatBus") :: BindableEvent

-- n레벨 올리기: 부족한 경험치를 계산해 한 번에 지급
local function levelUpBy(player: Player, n: number)
	if not player or not player.Parent then return end
	n = math.max(0, math.floor(n))
	if n == 0 then return end

	-- 상태 미초기화 대비: Level Attribute 없으면 초기화
	if player:GetAttribute("Level") == nil or player:GetAttribute("Exp") == nil then
		if ExperienceService.InitPlayerState then
			ExperienceService.InitPlayerState(player)
		end
	end

	local curLevel = player:GetAttribute("Level") or 1
	local curExp   = player:GetAttribute("Exp") or 0
	local targetLv = curLevel + n

	-- 필요한 총 경험치 계산
	local totalExpToGive = 0

	-- 먼저, 현재 레벨의 남은 구간
	local expToNext = ExperienceService.ExpToNext(curLevel)
	totalExpToGive += math.max(0, expToNext - curExp)

	-- 중간 레벨 구간(예: curLevel+1 ~ targetLv-1)
	for lv = curLevel + 1, targetLv - 1 do
		totalExpToGive += ExperienceService.ExpToNext(lv)
	end

	-- 지급
	if totalExpToGive > 0 then
		ExperienceService.AddExp(player, totalExpToGive)
	end
end

-- CheatBus 구독
(CheatBus :: BindableEvent).Event:Connect(function(msg: any)
	local action = msg and msg.action
	if action == "exp.lvup10" then
		local plr = msg.player :: Player
		if plr then
			levelUpBy(plr, 10)
			print(("[Cheat/EXP] %s → +10 levels"):format(plr.Name))
		end
	end
end)

-- (선택) 테스트 편의: 새로 들어온 플레이어도 상태 보장
Players.PlayerAdded:Connect(function(plr)
	if ExperienceService.InitPlayerState then
		ExperienceService.InitPlayerState(plr)
	end
end)
