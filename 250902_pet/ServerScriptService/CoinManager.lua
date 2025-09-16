-- ServerScriptService/CoinManager.server.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoinService = require(script.Parent:WaitForChild("CoinService"))

local Remotes = ReplicatedStorage:FindFirstChild("RemoteEvents")
local CoinUpdate = Remotes:FindFirstChild("CoinUpdate") or Instance.new("RemoteEvent", Remotes)
CoinUpdate.Name = "CoinUpdate"

-- (기존) 퀘스트/레벨 Remote (클라에서 쏘지만, 실제 코인 지급은 서버가 검증한 시점에서 호출 권장)
local QuestCleared = ReplicatedStorage:WaitForChild("QuestCleared")
local LevelSync = ReplicatedStorage:WaitForChild("LevelSync") -- 참고용(코인 지급은 Attribute 변화로 처리)

Players.PlayerAdded:Connect(function(plr)
	CoinService:_load(plr)
	-- 🔔 레벨 Attribute 변화 감지 → 구간 달성 시 1회 지급
	plr:GetAttributeChangedSignal("Level"):Connect(function()
		local lv = plr:GetAttribute("Level") or 1
		CoinService:OnLevelChanged(plr, lv)
	end)
end)

Players.PlayerRemoving:Connect(function(plr)
	CoinService:_remove(plr)
end)

-- ⚠️ 예시: 퀘스트 완료 시 1회성 코인 지급 (실제론 서버 검증 지점에서 호출하세요)
QuestCleared.OnServerEvent:Connect(function(player, payload)
	-- payload 예: { questId = "WolvesCave" }
	local questId = (typeof(payload)=="table" and payload.questId) or "UNKNOWN"
	CoinService:Award(player, "Q:"..questId)
end)
