--!strict
-- Workspace.TwoSeat.Script (교체본)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local BlockService = require(game.ServerScriptService:WaitForChild("BlockService"))

-- ===== Remotes 보장 =====
local function ensureRemote(name: string): RemoteEvent
	local ev = RS:FindFirstChild(name)
	if not ev then
		ev = Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = RS
	end
	return ev :: RemoteEvent
end

local startEvent   = ensureRemote("TwoSeatStart")    -- (seatA, seatB, p1Id, p2Id)
local uiEvent      = ensureRemote("TwoSeatUI")       -- "showWaiting" | "hideWaiting"
local roundStart   = ensureRemote("RPS_RoundStart")  -- (roundNum, duration)
local chooseEv     = ensureRemote("RPS_Choose")      -- client -> server (roundNum, "rock|paper|scissors")
local resultEv     = ensureRemote("RPS_Result")      -- (roundNum, myChoice, oppChoice, "win|lose|draw")
local reqCancel    = ensureRemote("RPS_RequestCancel")
local cancelledEv  = ensureRemote("RPS_Cancelled")
local matchEndEv   = ensureRemote("RPS_MatchEnd")    -- ★ 정상 종료 알림(카메라/보드 원복용)

-- ===== 좌석 수집 =====
local seatsFolder = script.Parent
local seats = {} :: {Seat}
for _, child in ipairs(seatsFolder:GetChildren()) do
	if child:IsA("Seat") or child:IsA("VehicleSeat") then
		table.insert(seats, child)
	end
end
assert(#seats == 2, "TwoSeat 폴더에는 Seat가 정확히 2개 있어야 합니다 (SeatA, SeatB).")

-- ===== 상태 =====
local prompts = {} :: {[Seat]: ProximityPrompt}
for _, seat in ipairs(seats) do
	prompts[seat] = seat:WaitForChild("ProximityPrompt") :: ProximityPrompt
end

local gameStarted = false
local waitingHumanoid: Humanoid? = nil
local endingInProgress = false

-- ★ 반드시 “가장 위쪽”에 두어, 아래 모든 함수에서 같은 로컬을 참조하도록
local activeMatch = {
	running = false,
	p1 = nil :: Player?, p2 = nil :: Player?,
	round = 0,
	deadline = 0.0,   -- os.clock 기준
	lockTime = 0.0,
	cancelUntil = 0.0,
	choices = {} :: {[number]: string?}, -- [UserId] = "rock"|"paper"|"scissors"|nil
}

-- ===== 유틸 =====
local function getPlayerFromHumanoid(h: Humanoid?): Player?
	if not h then return nil end
	return Players:GetPlayerFromCharacter(h.Parent)
end

local function sendWaiting(h: Humanoid?, show: boolean)
	local plr = getPlayerFromHumanoid(h)
	if plr then
		uiEvent:FireClient(plr, show and "showWaiting" or "hideWaiting")
	end
end

local function setPromptsEnabled(enabled: boolean)
	for _, prompt in pairs(prompts) do
		prompt.Enabled = enabled
	end
end

local function disconnectAll(arr: {RBXScriptConnection}?)
	if not arr then return end
	for _, c in ipairs(arr) do
		pcall(function() c:Disconnect() end)
	end
end

-- 좌석 강제 해제
local function forceStandAll()
	for _, seat in ipairs(seats) do
		local hum = seat.Occupant
		if hum then hum.Sit = false end
		local weld = seat:FindFirstChild("SeatWeld") or seat:FindFirstChild("GameSeatWeld")
		if weld then weld:Destroy() end
	end
end

-- 좌석 잠금
local seatLocks = {} :: {[Humanoid]: {
	conns: {RBXScriptConnection},
	seat: Seat,
	prev: {useJumpPower: boolean, jumpPower: number, jumpHeight: number}
}}
local function lockHumanoidToSeat(hum: Humanoid, seat: Seat)
	if seatLocks[hum] then return end
	local prev = {
		useJumpPower = hum.UseJumpPower,
		jumpPower = hum.JumpPower,
		jumpHeight = hum.JumpHeight,
	}
	pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)
	hum.Jump = false
	hum.UseJumpPower = true
	hum.JumpPower = 0
	hum.JumpHeight = 0

	local conns = {} :: {RBXScriptConnection}
	table.insert(conns, hum:GetPropertyChangedSignal("Jump"):Connect(function()
		if seatLocks[hum] then hum.Jump = false end
	end))
	table.insert(conns, hum:GetPropertyChangedSignal("Sit"):Connect(function()
		if seatLocks[hum] and not hum.Sit then
			hum.Sit = true
			task.defer(function()
				if seat.Occupant ~= hum and hum.Health > 0 then
					seat:Sit(hum)
				end
			end)
		end
	end))
	table.insert(conns, seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seatLocks[hum] and seat.Occupant ~= hum and hum.Health > 0 then
			task.defer(function() seat:Sit(hum) end)
		end
	end))
	table.insert(conns, hum.Died:Connect(function()
		pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end)
		disconnectAll(seatLocks[hum].conns)
		seatLocks[hum] = nil
	end))

	seatLocks[hum] = { conns = conns, seat = seat, prev = prev }
end

local function unlockHumanoid(hum: Humanoid)
	local lock = seatLocks[hum]
	if not lock then return end
	local prev = lock.prev
	pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end)
	hum.UseJumpPower = prev.useJumpPower
	hum.JumpPower = prev.jumpPower
	hum.JumpHeight = prev.jumpHeight
	disconnectAll(lock.conns)
	seatLocks[hum] = nil
end

local function unlockAll()
	for hum, _ in pairs(seatLocks) do
		unlockHumanoid(hum)
	end
end

-- ===== 판정 =====
local beats = { rock = "scissors", paper = "rock", scissors = "paper" }
local function judge(a: string?, b: string?): ("p1"|"p2"|"draw")
	if not a and not b then return "draw" end
	if a and not b then return "p1" end
	if b and not a then return "p2" end
	if a == b then return "draw" end
	if beats[a] == b then return "p1" else return "p2" end
end

-- ===== 매치 취소 =====
local function cancelCurrentMatch(reason: string)
	if not activeMatch.running then return end
	activeMatch.running = false
	gameStarted = false
	unlockAll()
	setPromptsEnabled(true)
	if waitingHumanoid then
		sendWaiting(waitingHumanoid, false)
		waitingHumanoid = nil
	end
	if activeMatch.p1 then cancelledEv:FireClient(activeMatch.p1, reason) end
	if activeMatch.p2 then cancelledEv:FireClient(activeMatch.p2, reason) end
	forceStandAll()
end

-- ===== 0블록 종료 처리(정상 종료 플로우) =====
local function handleZeroBlocks(pWinner: Player?, pLoser: Player?)
	if endingInProgress then return end
	endingInProgress = true

	-- 매치 중단
	activeMatch.running = false
	gameStarted = false
	unlockAll()
	setPromptsEnabled(true)

	-- 클라에 “정상 종료” 알림(카메라/보드 원복)
	if activeMatch.p1 then matchEndEv:FireClient(activeMatch.p1) end
	if activeMatch.p2 then matchEndEv:FireClient(activeMatch.p2) end

	-- 강제 서서히 정리
	forceStandAll()

	-- 저장 (BlockService에 ForceSave / Get 이 있어야 함)
	pcall(function()
		if pWinner then BlockService.ForceSave(pWinner.UserId) end
		if pLoser  then BlockService.ForceSave(pLoser.UserId)  end
	end)

	-- 플레이어 리스폰
	pcall(function() if pWinner then pWinner:LoadCharacter() end end)
	pcall(function() if pLoser  then pLoser:LoadCharacter()  end end)

	-- 상태 초기화
	activeMatch.p1, activeMatch.p2 = nil, nil
	activeMatch.round = 0
	activeMatch.choices = {}
	waitingHumanoid = nil
	unlockAll()
	setPromptsEnabled(true)

	endingInProgress = false
end

-- ===== 선택 수신 =====
chooseEv.OnServerEvent:Connect(function(plr: Player, roundNum: number, choice: string)
	if not activeMatch.running then return end
	-- ★ 참가자 가드
	if plr ~= activeMatch.p1 and plr ~= activeMatch.p2 then return end
	if roundNum ~= activeMatch.round then return end

	local now = os.clock()
	if now > activeMatch.deadline then return end
	if now >= activeMatch.lockTime and activeMatch.choices[plr.UserId] ~= nil then return end

	if choice == "rock" or choice == "paper" or choice == "scissors" then
		activeMatch.choices[plr.UserId] = choice
	end
end)

-- ===== 라운드 루프 =====
local function waitUntil(deadline: number): boolean
	while os.clock() < deadline do
		if not activeMatch.running then return false end
		task.wait(0.05)
	end
	return activeMatch.running
end

local function runMatch(p1: Player, p2: Player)
	activeMatch.running = true
	activeMatch.p1, activeMatch.p2 = p1, p2
	activeMatch.round = 0

	while activeMatch.running do
		if not p1.Parent or not p2.Parent then break end

		activeMatch.round += 1
		activeMatch.choices = {}
		local startT = os.clock()
		local duration = 5.0
		activeMatch.lockTime = startT + (duration - 1.0)
		activeMatch.deadline = startT + duration
		activeMatch.cancelUntil = startT + 2.0

		roundStart:FireClient(p1, activeMatch.round, duration)
		roundStart:FireClient(p2, activeMatch.round, duration)

		if not waitUntil(activeMatch.deadline) then break end
		if not activeMatch.running then break end

		local a = activeMatch.choices[p1.UserId]
		local b = activeMatch.choices[p2.UserId]
		local who = judge(a, b)

		local out1 = (who == "p1" and "win") or (who == "p2" and "lose") or "draw"
		local out2 = (who == "p2" and "win") or (who == "p1" and "lose") or "draw"
		resultEv:FireClient(p1, activeMatch.round, a, b, out1)
		resultEv:FireClient(p2, activeMatch.round, b, a, out2)

		-- BlockService는 빠르게(또는 task.spawn) 처리 권장
		BlockService.ApplyRoundResult(p1, p2, who)

		-- 즉시 블록 체크 (BlockService.Get 필요)
		local p1Blocks = BlockService.Get(p1.UserId) or 0
		local p2Blocks = BlockService.Get(p2.UserId) or 0
		if p1Blocks <= 0 or p2Blocks <= 0 then
			if p1Blocks <= 0 and p2Blocks <= 0 then
				handleZeroBlocks(p1, p2) -- 동시 0 → 둘 다 저장/리스폰
			elseif p1Blocks <= 0 then
				handleZeroBlocks(p2, p1)
			else
				handleZeroBlocks(p1, p2)
			end
			return
		end

		if not waitUntil(os.clock() + 1.6) then break end
	end

	-- ★ 정상 루프 종료(취소 아님) → 클라 원복 신호
	activeMatch.running = false
	if activeMatch.p1 then matchEndEv:FireClient(activeMatch.p1) end
	if activeMatch.p2 then matchEndEv:FireClient(activeMatch.p2) end

	if gameStarted then
		gameStarted = false
		setPromptsEnabled(true)
	end
	unlockAll()
end

-- ===== 상태 갱신 =====
local function updateState()
	local occ1 = seats[1].Occupant
	local occ2 = seats[2].Occupant
	local p1 = getPlayerFromHumanoid(occ1)
	local p2 = getPlayerFromHumanoid(occ2)
	local occCount = (occ1 and 1 or 0) + (occ2 and 1 or 0)

	-- 매치 중 한 명이라도 이탈 → 취소
	if gameStarted then
		if occCount < 2 or not p1 or not p2 or p1 == p2 then
			cancelCurrentMatch("seat_vacated")
		end
		return
	end

	if occCount == 0 then
		if waitingHumanoid then
			sendWaiting(waitingHumanoid, false)
			waitingHumanoid = nil
		end
		setPromptsEnabled(true)

	elseif occCount == 1 then
		if waitingHumanoid ~= occ1 and waitingHumanoid ~= occ2 then
			if waitingHumanoid then sendWaiting(waitingHumanoid, false) end
			waitingHumanoid = occ1 or occ2
			sendWaiting(waitingHumanoid, true)
		end
		setPromptsEnabled(true)

	elseif occCount == 2 then
		if p1 and p2 and p1 ~= p2 then
			if waitingHumanoid then
				sendWaiting(waitingHumanoid, false)
				waitingHumanoid = nil
			end

			gameStarted = true
			setPromptsEnabled(false)

			-- 좌석 웰드 태그
			for _, seat in ipairs(seats) do
				local sw = seat:FindFirstChild("SeatWeld")
				if sw then sw.Name = "GameSeatWeld" end
			end

			-- ★ 실제로 잠금 적용(누락되기 쉬웠던 부분)
			local h1 = seats[1].Occupant
			local h2 = seats[2].Occupant
			if h1 then lockHumanoidToSeat(h1, seats[1]) end
			if h2 then lockHumanoidToSeat(h2, seats[2]) end

			-- 대기 문구 숨김(안전)
			uiEvent:FireClient(p1, "hideWaiting")
			uiEvent:FireClient(p2, "hideWaiting")

			-- 시작 알림: 두 플레이어에게 동일 파라미터
			startEvent:FireClient(p1, seats[1], seats[2], p1.UserId, p2.UserId)
			startEvent:FireClient(p2, seats[1], seats[2], p1.UserId, p2.UserId)

			task.spawn(function() runMatch(p1, p2) end)
		end
	end
end

-- ===== 좌석/프롬프트 =====
for _, seat in ipairs(seats) do
	seat:GetPropertyChangedSignal("Occupant"):Connect(updateState)

	local prompt = prompts[seat]
	prompt.Triggered:Connect(function(player: Player)
		if gameStarted then return end
		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildWhichIsA("Humanoid") :: Humanoid?
		if not hum then return end

		if seat.Occupant == hum then
			local sw = seat:FindFirstChild("SeatWeld")
			if sw then sw:Destroy() end
		elseif seat.Occupant == nil then
			seat:Sit(hum)
		end
	end)
end

-- ===== 취소 요청 =====
reqCancel.OnServerEvent:Connect(function(plr: Player, roundNum: number)
	if not activeMatch.running then return end
	if roundNum ~= activeMatch.round then return end
	if plr ~= activeMatch.p1 and plr ~= activeMatch.p2 then return end
	if os.clock() <= activeMatch.cancelUntil then
		cancelCurrentMatch("player_cancel")
	end
end)

-- ===== 플레이어 이탈 =====
Players.PlayerRemoving:Connect(function()
	updateState()
end)

-- 최초 1회 상태 스냅샷
updateState()
