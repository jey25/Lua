--!strict
-- StarterPlayerScripts/HandsClient.client.lua
-- 역할: 서버에서 내려주는 "손(테마) 스킨" 상태를 클라이언트 모듈(HandsClientState)에 동기화만 한다.
-- UI 갱신(보드 버튼/결과 아이콘)은 RPSClient에서 처리한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipChanged = Remotes:WaitForChild("HandsEquipChanged") :: RemoteEvent
local GetAllEquipped = Remotes:WaitForChild("HandsGetAllEquipped") :: RemoteFunction

-- 상태 모듈 (ReplicatedStorage/HandsClientState)
local HandsState = require(ReplicatedStorage:WaitForChild("HandsClientState"))

-- 초기 전체 동기화
local function initialSync()
	local ok, all = pcall(function()
		return GetAllEquipped:InvokeServer()
	end)
	if not ok or type(all) ~= "table" then
		warn("[HandsClient] GetAllEquipped 실패:", all)
		return
	end

	for uid, info in pairs(all) do
		local id = tonumber(uid) or (uid :: any)
		local theme = (info and info.theme) or nil
		local images = (info and info.images) or nil
		if id and theme and images then
			HandsState.Set(id, { theme = theme, images = images })
		end
	end
end

-- 실시간 갱신
EquipChanged.OnClientEvent:Connect(function(userId: number, themeName: string, images: {[string]: string})
	if typeof(userId) ~= "number" or typeof(themeName) ~= "string" or typeof(images) ~= "table" then
		return
	end
	HandsState.Set(userId, { theme = themeName, images = images })
end)

-- 시작 시 1회 동기화
initialSync()
