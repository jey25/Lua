local BuffService = require(game.ServerScriptService:WaitForChild("BuffService"))
local Players = game:GetService("Players")
local plr = Players:GetPlayers()[1]
-- 2분 이속 1.5배, 1분 EXP 2배
BuffService:ApplyBuff(plr, "Speed", 120, {mult=1.5}, "이속 +50% (2분)")
BuffService:ApplyBuff(plr, "Exp2x", 60, {mult=2}, "경험치 2배 (1분)")