--!strict
-- Workspace.TwoSeat.Script
-- Workspace.TwoSeat.Script  (기존 내용 상단 그대로 유지)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local BlockService = require(game.ServerScriptService:WaitForChild("BlockService"))


local startEvent = RS:WaitForChild("TwoSeatStart") :: RemoteEvent
local seatsFolder = script.Parent
local seats = {} :: {Seat}
for _, child in ipairs(seatsFolder:GetChildren()) do
	if child:IsA("Seat") or child:IsA("VehicleSeat") then
		table.insert(seats, child)
	end
end

-- ▼ 플레이어 좌석 잠금 유틸
local seatLocks = {} :: {[Humanoid]: {
	conns: {RBXScriptConnection},
	seat: Seat,
	prev: {useJumpPower: boolean, jumpPower: number, jumpHeight: number}
}}

-- ▼ 추가: RPS 이벤트 보장
-- 맨 위 RemoteEvent 보장 구역에 추가
local uiEvent = RS:FindFirstChild("TwoSeatUI") :: RemoteEvent
if not uiEvent then
	uiEvent = Instance.new("RemoteEvent")
	uiEvent.Name = "TwoSeatUI"
	uiEvent.Parent = RS
end
local roundStart = RS:FindFirstChild("RPS_RoundStart") :: RemoteEvent
if not roundStart then roundStart = Instance.new("RemoteEvent"); roundStart.Name = "RPS_RoundStart"; roundStart.Parent = RS end
local chooseEv = RS:FindFirstChild("RPS_Choose") :: RemoteEvent
if not chooseEv then chooseEv = Instance.new("RemoteEvent"); chooseEv.Name = "RPS_Choose"; chooseEv.Parent = RS end
local resultEv = RS:FindFirstChild("RPS_Result") :: RemoteEvent
if not resultEv then resultEv = Instance.new("RemoteEvent"); resultEv.Name = "RPS_Result"; resultEv.Parent = RS end
-- Workspace.TwoSeat.Script 상단의 RemoteEvent 보장 섹션에 추가
local reqCancel = RS:FindFirstChild("RPS_RequestCancel") :: RemoteEvent
if not reqCancel then reqCancel = Instance.new("RemoteEvent"); reqCancel.Name = "RPS_RequestCancel"; reqCancel.Parent = RS end
local cancelledEv = RS:FindFirstChild("RPS_Cancelled") :: RemoteEvent
if not cancelledEv then cancelledEv = Instance.new("RemoteEvent"); cancelledEv.Name = "RPS_Cancelled"; cancelledEv.Parent = RS end


assert(#seats == 2, "TwoSeat 폴더에는 Seat가 정확히 2개 있어야 합니다 (SeatA, SeatB).")

local prompts = {} :: {[Seat]: ProximityPrompt}
for _, seat in ipairs(seats) do
	local prompt = seat:WaitForChild("ProximityPrompt") :: ProximityPrompt
	prompts[seat] = prompt
end

local gameStarted = false
local waitingHumanoid: Humanoid? = nil

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
	for _,c in ipairs(arr) do
		pcall(function() c:Disconnect() end)
	end
end

-- 스크립트 상단 근처에 추가
local function hookPrompt(seat: Seat, prompt: ProximityPrompt)
	prompts[seat] = prompt
	prompt.Enabled = true
	prompt.Triggered:Connect(function(player: Player)
		if gameStarted then return end
		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildWhichIsA("Humanoid") :: Humanoid?
		if not hum then return end

		if seat.Occupant == hum then
			local sw = seat:FindFirstChild("SeatWeld") or seat:FindFirstChild("GameSeatWeld")
			if sw then sw:Destroy() end
		elseif seat.Occupant == nil then
			seat:Sit(hum)
		end
	end)
end


-- Workspace.TwoSeat.Script 내부 어딘가(로컬 함수들 근처)에 추가
local function forceStandAll()
	for _, seat in ipairs(seats) do
		local hum = seat.Occupant
		if hum then
			hum.Sit = false
		end
		local weld = seat:FindFirstChild("SeatWeld") or seat:FindFirstChild("GameSeatWeld")
		if weld then weld:Destroy() end
	end
end

-- ▼ 추가: 현재 매치 상태
local activeMatch = {
	running = false,
	p1 = nil :: Player?, p2 = nil :: Player?,
	round = 0,
	deadline = 0.0, -- os.clock 기준
	lockTime = 0.0,
	choices = {} :: {[number]: string?}, -- [UserId] = "rock"|"paper"|"scissors"|nil
}





local function lockHumanoidToSeat(hum: Humanoid, seat: Seat)
	if seatLocks[hum] then return end
	local prev = {
		useJumpPower = hum.UseJumpPower,
		jumpPower = hum.JumpPower,
		jumpHeight = hum.JumpHeight,
	}
	-- 점프/일어서기 시도 차단
	pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)
	hum.Jump = false
	hum.UseJumpPower = true
	hum.JumpPower = 0
	hum.JumpHeight = 0

	-- 앉은 상태 유지 + 떨어지면 즉시 재착석
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
		-- 사망 시엔 잠금 정리
		local _ = pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end)
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
	for hum,_ in pairs(seatLocks) do
		unlockHumanoid(hum)
	end
end


local function cancelCurrentMatch(reason: string)
	if not activeMatch.running then return end
	activeMatch.running = false -- 루프 빠지도록 플래그 내림
	gameStarted = false
	unlockAll() -- ★ 추가
	setPromptsEnabled(true)
	if waitingHumanoid then
		sendWaiting(waitingHumanoid, false)
		waitingHumanoid = nil
	end
	-- 클라에 취소 알림
	if activeMatch.p1 then cancelledEv:FireClient(activeMatch.p1, reason) end
	if activeMatch.p2 then cancelledEv:FireClient(activeMatch.p2, reason) end
	-- 좌석에서 강제 해제
	forceStandAll()
end

-- ▼ 추가: 판정
local beats = { rock = "scissors", paper = "rock", scissors = "paper" }
local function judge(a: string?, b: string?): ("p1"|"p2"|"draw")
	-- 미선택(nil) 처리: 한쪽만 선택했으면 선택한 쪽 승
	if not a and not b then return "draw" end
	if a and not b then return "p1" end
	if b and not a then return "p2" end
	if a == b then return "draw" end
	if beats[a] == b then return "p1" else return "p2" end
end

-- ▼ 추가: 선택 수신 (라운드 중 변경 허용은 lock 전까지만)
chooseEv.OnServerEvent:Connect(function(plr: Player, roundNum: number, choice: string)
	if not activeMatch.running then return end
	if roundNum ~= activeMatch.round then return end
	local now = os.clock()
	if now > activeMatch.deadline then return end -- 라운드 종료 후 무시
	-- lockTime 이후엔 최초 선택만 인정 (변경 불가)
	if now >= activeMatch.lockTime and activeMatch.choices[plr.UserId] ~= nil then return end
	if choice == "rock" or choice == "paper" or choice == "scissors" then
		activeMatch.choices[plr.UserId] = choice
	end
end)

-- 기존 runMatch 내부 일부 교체/추가
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
		BlockService.ApplyRoundResult(p1, p2, who)

		

		if not waitUntil(os.clock() + 1.6) then break end
	end

	-- 루프 종료 시 러닝 플래그 내리고(이미 내려갔을 수도 있음) UI/프롬프트 복구 보장
	activeMatch.running = false
	if gameStarted then
		gameStarted = false
		setPromptsEnabled(true)
	end
	unlockAll() -- ★ 추가: 종료 시 모두 잠금 해제
end



-- 기존 updateState 맨 앞의 'if gameStarted then return end' 제거하고 아래처럼 전체 교체
local function updateState()
	-- 현재 착석자 상태
	local occ1 = seats[1].Occupant
	local occ2 = seats[2].Occupant
	local p1 = getPlayerFromHumanoid(occ1)
	local p2 = getPlayerFromHumanoid(occ2)
	local occCount = (occ1 and 1 or 0) + (occ2 and 1 or 0)

	-- ★ 게임 도중 한 명이라도 일어나면 즉시 취소 + 프롬프트 재활성화
	if gameStarted then
		if occCount < 2 or not p1 or not p2 or p1 == p2 then
			cancelCurrentMatch("seat_vacated")
		end
		return
	end

	-- 이하: 기존 로직 유지 (0/1명 대기 UI, 2명일 때 시작)
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

			for _, seat in ipairs(seats) do
				local sw = seat:FindFirstChild("SeatWeld")
				if sw then sw.Name = "GameSeatWeld" end
			end

			-- ★ 추가: 앉은 두 명 잠금
			local h1 = seats[1].Occupant
			local h2 = seats[2].Occupant
			-- 변경:
			startEvent:FireClient(p1, seats[1], seats[2], p1.UserId, p2.UserId)
			startEvent:FireClient(p2, seats[1], seats[2], p1.UserId, p2.UserId)
			task.spawn(function() runMatch(p1, p2) end)
		end
	end
end


-- 좌석 점유 변화 감지
for _, seat in ipairs(seats) do
	seat:GetPropertyChangedSignal("Occupant"):Connect(updateState)

	-- E키 눌렀을 때 처리 (앉기/내리기)
	local prompt = prompts[seat]
	prompt.Triggered:Connect(function(player: Player)
		if gameStarted then return end

		local char = player.Character
		if not char then return end
		local hum = char:FindFirstChildWhichIsA("Humanoid") :: Humanoid?
		if not hum then return end

		if seat.Occupant == hum then
			-- 아직 게임 시작 전이라면 E로 일어날 수 있게
			local sw = seat:FindFirstChild("SeatWeld")
			if sw then sw:Destroy() end
		elseif seat.Occupant == nil then
			seat:Sit(hum)
		else
			-- 이미 다른 사람이 점유 중
		end
	end)
end

-- Workspace.TwoSeat.Script 내부에 추가
reqCancel.OnServerEvent:Connect(function(plr: Player, roundNum: number)
	if not activeMatch.running then return end
	if roundNum ~= activeMatch.round then return end
	-- 오직 현재 매치 참가자만
	if plr ~= activeMatch.p1 and plr ~= activeMatch.p2 then return end
	-- "카운트다운 시작 후 2초까지"만 허용
	local now = os.clock()
	if now <= activeMatch.cancelUntil then
		cancelCurrentMatch("player_cancel")
	end
end)


-- 누군가 나가거나 죽어서 내려앉을 때도 상태 갱신되도록
Players.PlayerRemoving:Connect(function()
	updateState()
end)

updateState()

