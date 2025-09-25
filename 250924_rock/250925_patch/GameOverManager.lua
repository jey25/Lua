--!strict
-- ServerScriptService/GameOverManager.lua
-- 역할: 게임 종료 브로드캐스트 → (옵션) 룸 제거 → 저장 보장(Blocks 선저장 + PlayerRemoving 저장) → 유저 선택 모달 → 타임아웃 킥/텔레포트

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local SSS = game:GetService("ServerScriptService")

-- 기존 Remotes
local BlocksEvent = RS:WaitForChild("Blocks_Update") :: RemoteEvent
local ExitReq     = RS:FindFirstChild("Game_ExitRequest") :: RemoteEvent
if not ExitReq then
	-- 혹시 없다면 생성 (클라 모달이 사용)
	local ev = Instance.new("RemoteEvent")
	ev.Name = "Game_ExitRequest"
	ev.Parent = RS
	ExitReq = ev
end

-- BlockService 모듈 (선저장 사용)
local BlockService = require(SSS:WaitForChild("BlockService"))

-- === 설정 ===
local DISPLAY_SECS = 2.5         -- 종료 연출 표시 시간 (클라 showGameOver와 일치)
local PRESAVE_GRACE = 0.8         -- 선저장 그레이스 (DataStore 여유)
local FORCE_KICK_AFTER_SECS = 10  -- 모달 떠 있어도 이 시간 지나면 자동 종료

-- (옵션) 다른 Place 로비가 있다면 세팅
local USE_TELEPORT = false
local LOBBY_PLACE_ID = 0 -- 로비 place id

-- 내부 상태
local ending = false

-- 룸 제거(게임 공간 정리)
local function destroyGameRoom()
	local room = workspace:FindFirstChild("TwoSeat")
	if room then
		room:Destroy()
	end
end

-- Blocks 선저장(베스트 에포트)
local function preSaveBlocksAll()
	-- 비동기 ForceSaveAll 호출 후 잠시 대기 (spawn 기반이므로 유실 방지로 약간의 여유를 둠)
	pcall(function()
		BlockService.ForceSaveAll()
	end)
	task.wait(PRESAVE_GRACE)
end

-- 단일 플레이어 종료 처리(유저 선택 '나가기'에 대응)
local function exitOne(plr: Player)
	-- Blocks 선저장(개별로도 한 번 더 시도해도 무방)
	pcall(function()
		BlockService.ForceSave(plr.UserId)
	end)
	task.wait(0.15)

	if USE_TELEPORT and LOBBY_PLACE_ID > 0 then
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(LOBBY_PLACE_ID, {plr})
		end)
		if not ok then
			warn("[GameOverManager] Teleport failed for", plr, err)
			plr:Kick("게임이 종료되어 로비로 이동합니다. 이용해 주셔서 감사합니다!")
		end
	else
		plr:Kick("게임이 종료되었습니다. 플레이해 주셔서 감사합니다!")
	end
end

-- 유저가 모달에서 '나가기' 누름
ExitReq.OnServerEvent:Connect(function(plr: Player, action: string)
	if action == "leave" then
		exitOne(plr)
	end
end)

-- 전체 종료 시퀀스
local function endGameForAll(loserUserId: number?)
	if ending then return end
	ending = true

	-- 1) 전원 연출 브로드캐스트
	BlocksEvent:FireAllClients("gameover", loserUserId)

	-- 2) 룸 제거(선택)
	destroyGameRoom()

	-- 3) 연출 시간만큼 대기
	task.wait(DISPLAY_SECS)

	-- 4) Blocks 선저장 (Hands는 PlayerRemoving에서 안전 저장)
	preSaveBlocksAll()

	-- 5) 타임아웃 타이머: 유저가 '나가기' 안 눌러도 종료
	task.delay(FORCE_KICK_AFTER_SECS, function()
		local plrs = Players:GetPlayers()
		if #plrs == 0 then
			ending = false
			return
		end

		if USE_TELEPORT and LOBBY_PLACE_ID > 0 then
			local ok, err = pcall(function()
				TeleportService:TeleportAsync(LOBBY_PLACE_ID, plrs)
			end)
			if not ok then
				warn("[GameOverManager] Bulk Teleport failed:", err)
				for _, p in ipairs(plrs) do
					p:Kick("게임이 종료되어 로비로 이동합니다. 이용해 주셔서 감사합니다!")
				end
			end
		else
			for _, p in ipairs(plrs) do
				p:Kick("게임이 종료되었습니다. 플레이해 주셔서 감사합니다!")
			end
		end

		ending = false
	end)
end

-- 외부에서 호출할 공개 API
local GameOverManager = {}
function GameOverManager.EndGame(loserUserId: number?)
	endGameForAll(loserUserId)
end
return GameOverManager
