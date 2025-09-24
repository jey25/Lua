--!strict
-- Workspace.TwoSeat.Script
-- Workspace.TwoSeat.Script  (기존 내용 상단 그대로 유지)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local BlockService = require(game.ServerScriptService:WaitForChild("BlockService"))

-- 안전 플래그: 종료 처리 중복 방지
local endingInProgress = false

-- ReplicatedStorage SFX 폴더(사운드 객체들) 참조
local sfxFolder = RS:FindFirstChild("SFX")

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

-- 사운드 이름이 정해져 있다면 직접 참조해도 되고(예: "Win","Lose"), 없다면 첫 2개 사용
local function pickSfxPair()
	if not sfxFolder then return nil, nil end
	local winSound = sfxFolder:FindFirstChild("Win") or sfxFolder:FindFirstChild("Winner")
	local loseSound = sfxFolder:FindFirstChild("Lose") or sfxFolder:FindFirstChild("Loser")
	if winSound and loseSound then return winSound, loseSound end
	-- fallback: 첫 두 Sound 자식
	local sounds = {}
	for _, c in ipairs(sfxFolder:GetChildren()) do
		if c:IsA("Sound") then table.insert(sounds, c) end
		if #sounds >= 2 then break end
	end
	return sounds[1], sounds[2]
end

local function safePlaySfxToPlayer(plr: Player, soundTemplate: Sound?)
	if not plr or not soundTemplate or not soundTemplate:IsA("Sound") then return end
	-- 캐릭터가 존재하면 HRP/Head에 붙여서 재생
	local char = plr.Character
	if not char then return end
	local primary = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
	if not primary then return end
	local s = soundTemplate:Clone()
	s.Parent = primary
	-- 서버에서 재생해도 클라이언트에서 들리도록 LocalSound가 아닌 Sound 사용 (서버 권한으로 재생)
	pcall(function() s:Play() end)
	-- 파기 (안전하게 8초 후 제거)
	task.delay(8, function()
		pcall(function() s:Stop(); s:Destroy() end)
	end)
end


local function handleZeroBlocks(pWinner: Player, pLoser: Player)
	if endingInProgress then return end
	endingInProgress = true

	-- 1) 게임/매치 플래그 정리(즉시 멈추게 함)
	activeMatch.running = false
	gameStarted = false
	setPromptsEnabled(true)
	unlockAll()

	-- 2) 사운드 재생 (ReplicatedStorage/SFX에서 두 사운드 취득)
	local winSfx, loseSfx = pickSfxPair()
	-- 안전: 둘 다 없으면 재생 없이 진행
	if winSfx then
		pcall(function() safePlaySfxToPlayer(pWinner, winSfx) end)
	end
	if loseSfx then
		pcall(function() safePlaySfxToPlayer(pLoser, loseSfx) end)
	end

	-- 3) 5초 대기 (사운드가 재생되는 동안)
	task.wait(5)

	-- 4) 블록 수 데이터 강제 저장
	-- BlockService 측에 M.ForceSave(userId) 를 추가했음을 전제
	pcall(function()
		if pWinner and pWinner.Parent then BlockService.ForceSave(pWinner.UserId) end
		if pLoser  and pLoser.Parent  then BlockService.ForceSave(pLoser.UserId)  end
	end)

	-- 5) 룸 제거 및 플레이어 로비 복귀
	-- (a) 좌석 강제 해제
	forceStandAll()
	-- (b) 룸(좌석 폴더) 제거: script.Parent 는 이 스크립트의 폴더. 안전하게 Destroy
	local parentFolder = script.Parent
	if parentFolder and parentFolder:IsA("Instance") then
		-- 먼저 부모가 남아있다면 잠깐 노티/딜레이 주고 제거
		pcall(function()
			-- 두 플레이어가 안전히 LoadCharacter 되도록 강제 리스폰 호출
			if pWinner and pWinner.Parent then
				pWinner:LoadCharacter()
			end
			if pLoser and pLoser.Parent then
				pLoser:LoadCharacter()
			end
			-- 약간 지연 후 룸 제거
			task.delay(0.5, function()
				if parentFolder and parentFolder.Parent then
					pcall(function() parentFolder:Destroy() end)
				end
			end)
		end)
	else
		-- fallback: 플레이어들만 리스폰
		if pWinner and pWinner.Parent then pWinner:LoadCharacter() end
		if pLoser  and pLoser.Parent  then pLoser:LoadCharacter()  end
	end

	-- 6) 모든 정리 보장 (Ordered값 반영 등)
	if pWinner and pWinner.Parent then
		pcall(function() BlockService.ForceSave(pWinner.UserId) end)
	end
	if pLoser and pLoser.Parent then
		pcall(function() BlockService.ForceSave(pLoser.UserId) end)
	end

	-- 7) 매치/잠금 상태 초기화
	activeMatch.p1 = nil
	activeMatch.p2 = nil
	activeMatch.round = 0
	activeMatch.choices = {}
	waitingHumanoid = nil
	unlockAll()
	setPromptsEnabled(true)

	-- 8) 플래그 내려주기
	endingInProgress = false
end

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

		do
			-- 최신 블록 값 확인
			local p1Blocks = BlockService.Get(p1.UserId) or 0
			local p2Blocks = BlockService.Get(p2.UserId) or 0

			-- 어느 한 쪽이 0이면 종료 플로우
			if p1Blocks <= 0 or p2Blocks <= 0 then
				-- 누가 승자/패자인지 판정
				local winner, loser
				if p1Blocks <= 0 and p2Blocks <= 0 then
					-- 둘 다 0이면 무승부 처리: 그냥 룸 삭제 흐름으로 처리 (winner/loser 없이 동시 종료)
					-- 편의상 p2를 winner로 두거나 null 처리 가능 — 여기선 둘다 리스폰 + 저장
					handleZeroBlocks(p1, p2) -- 호출하면 내부에서 안전히 처리(둘 다 저장/리스폰)
				else
					if p1Blocks <= 0 then
						-- p2 승리
						handleZeroBlocks(p2, p1)
					else
						-- p1 승리
						handleZeroBlocks(p1, p2)
					end
				end
				-- runMatch 루프는 activeMatch.running 플래그가 false가 되어 곧 종료됩니다.
				-- 더 이상의 라운드 처리를 막기 위해 바로 return
				return
			end
		end

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

