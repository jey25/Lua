--!strict
-- ServerScriptService/Weather.server.lua
-- 서버 전역 Time/Day에 맞춘 동기 날씨 시스템
-- - 모든 플레이어 동일 날씨
-- - worldDay(서버 전역, 세션 내) 기준 요일로 비/안개 스케줄
-- - 매주(7일)마다 비/안개 요일 랜덤 재롤
-- - Rain 추적은 HRP Weld 방식(Heartbeat 좌표 갱신 제거)

local Lighting      = game:GetService("Lighting")
local Players       = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

-- ===== 설정 =====
local WEEK_LEN                 = 7
local WEATHER_TICK_SEC         = 10          -- 날씨 재평가 주기(초)
local RAIN_MODEL_NAME          = "Rain"      -- ServerStorage 안에 있는 비 이펙트(Part/Model)
local RAIN_PART_NAME           = "RainPart"  -- 캐릭터 밑에 복제될 이름
local RAIN_OFFSET              = CFrame.new(0, 10, 0) -- HRP 기준 오프셋

-- Lighting(맑음)
local CLEAR_FOG_START          = 50
local CLEAR_FOG_END            = 3000
local CLEAR_AMBIENT            = Color3.fromRGB(255, 255, 255)
local CLEAR_BRIGHTNESS         = 1

-- Lighting(안개) — 비가 아닐 때만 적용
local FOG_FOG_START            = 10
local FOG_FOG_END              = 100000
local FOG_AMBIENT              = Color3.fromRGB(150, 150, 150)
local FOG_BRIGHTNESS           = 0.8

-- ===== 내부 상태 =====
local worldHoursPrev           = (tonumber(Lighting.ClockTime) or 0) % 24
local worldDay                 = 1      -- 세션 내 전역 Day (시계 자정 래핑마다 +1)
local weekIndex                = 0      -- floor((worldDay-1)/7)

local rainDayOfWeek            = math.random(1, WEEK_LEN)
local fogDayOfWeek             = math.random(1, WEEK_LEN)

local isRainingNow             = false
local isFoggyNow               = false


-- ===== 유틸 =====
-- 유틸: 캐릭터 루트 파트 안전 획득 (Model만 허용, BasePart 보장)
local function getRootPart(m: Instance?): BasePart?
	if not (m and m:IsA("Model")) then return nil end
	local hrp = m:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then return hrp end
	local torso = m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then return torso end
	-- 최후 보루: 어떤 BasePart라도 찾기
	local any = m:FindFirstChildWhichIsA("BasePart", true)
	return any
end


local function getDayOfWeek(dayNum: number): number
	return ((dayNum - 1) % WEEK_LEN) + 1  -- 1..7
end

local function rerollWeeklySchedule()
	rainDayOfWeek = math.random(1, WEEK_LEN)
	fogDayOfWeek  = math.random(1, WEEK_LEN)
	if fogDayOfWeek == rainDayOfWeek then
		fogDayOfWeek = (fogDayOfWeek % WEEK_LEN) + 1
	end
	-- 디버깅에 유용:
	-- print(("[Weather] roll -> rain:%d, fog:%d"):format(rainDayOfWeek, fogDayOfWeek))
end

local function applyFogVisual(foggy: boolean, raining: boolean)
	-- 비가 오는 날에는 Lighting은 맑음 유지(원하면 톤 변경 가능)
	if foggy and not raining then
		Lighting.FogStart = FOG_FOG_START
		Lighting.FogEnd = FOG_FOG_END
		Lighting.OutdoorAmbient = FOG_AMBIENT
		Lighting.Brightness = FOG_BRIGHTNESS
	else
		Lighting.FogStart = CLEAR_FOG_START
		Lighting.FogEnd = CLEAR_FOG_END
		Lighting.OutdoorAmbient = CLEAR_AMBIENT
		Lighting.Brightness = CLEAR_BRIGHTNESS
	end
	-- 디버깅용 Attributes(선택)
	Lighting:SetAttribute("Weather_Rain", raining)
	Lighting:SetAttribute("Weather_Fog", foggy)
	Lighting:SetAttribute("WorldDay", worldDay)
	Lighting:SetAttribute("DoW", getDayOfWeek(worldDay))
end



-- 모델 내부 파츠를 하나의 base로 묶기
local function weldModelToBase(inst: Instance, base: BasePart)
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") and d ~= base then
			d.Anchored = false
			d.CanCollide = false
			d.Massless  = true
			local wc = Instance.new("WeldConstraint")
			wc.Part0 = base
			wc.Part1 = d
			wc.Parent = base
		end
	end
end

-- HRP에 Rain을 Weld로 붙이기 (오프셋 유지)
local function attachRainToHRP(rainInst: Instance, hrp: BasePart)
	local base: BasePart? = nil
	if rainInst:IsA("BasePart") then
		base = rainInst
	elseif rainInst:IsA("Model") then
		base = rainInst.PrimaryPart
			or rainInst:FindFirstChild("HumanoidRootPart")
			or rainInst:FindFirstChildWhichIsA("BasePart", true)
	end
	if not (base and base:IsA("BasePart")) then return end

	if rainInst:IsA("Model") then
		weldModelToBase(rainInst, base)
	end

	for _, d in ipairs((rainInst:IsA("Model") and rainInst:GetDescendants()) or { base }) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless  = true
		end
	end

	-- 초기 위치
	if rainInst:IsA("Model") then
		(rainInst :: Model):PivotTo(hrp.CFrame * RAIN_OFFSET)
	else
		base.CFrame = hrp.CFrame * RAIN_OFFSET
	end

	-- 기존 Weld가 남아 있으면 정리
	local old = base:FindFirstChild("RainWeld")
	if old and old:IsA("Weld") then old:Destroy() end

	local w = Instance.new("Weld")
	w.Name  = "RainWeld"
	w.Part0 = base
	w.Part1 = hrp
	w.C0    = RAIN_OFFSET
	w.Parent= base
end


-- 캐릭터에 RainPart 부착/해제 (안전·중복 방지)
local function ensureRainForPlayer(plr: Player, enable: boolean)
	local char = plr.Character
	if not char then return end

	local have = char:FindFirstChild(RAIN_PART_NAME)
	if enable then
		if have then
			-- HRP가 바뀌었거나 Weld 유실 시 재부착
			local hrp = getRootPart(char)
			if hrp and not (have:FindFirstChild("RainWeld")) then
				attachRainToHRP(have, hrp)
			end
			return
		end

		local hrp = getRootPart(char)
		if not (hrp and hrp:IsA("BasePart")) then return end

		local template = ServerStorage:FindFirstChild(RAIN_MODEL_NAME)
		if not template then return end

		local inst = template:Clone()
		inst.Name = RAIN_PART_NAME
		inst.Parent = char
		attachRainToHRP(inst, hrp)
	else
		if have then have:Destroy() end
	end
end


local function applyRainToAll(enable: boolean)
	for _, plr in ipairs(Players:GetPlayers()) do
		ensureRainForPlayer(plr, enable)
	end
end

-- (전역) 날씨 적용
local function applyWeatherForAll()
	local dow     = getDayOfWeek(worldDay)
	local raining = (dow == rainDayOfWeek)
	local foggy   = (dow == fogDayOfWeek)

	if raining ~= isRainingNow or foggy ~= isFoggyNow then
		isRainingNow = raining
		isFoggyNow   = foggy
		applyFogVisual(foggy, raining)
		applyRainToAll(raining)
	end
end

-- ===== 입/퇴장 훅 =====
local function onCharacter(plr: Player, _char: Model)
	task.spawn(function()
		local char = plr.Character
		if not char then return end
		-- HRP 준비 대기 (최대 5초)
		local hrp = char:WaitForChild("HumanoidRootPart", 5)
			or char:FindFirstChild("UpperTorso")
			or char:FindFirstChild("Torso")
		if hrp and hrp:IsA("BasePart") then
			ensureRainForPlayer(plr, isRainingNow)
		end
	end)
end


Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function(char) onCharacter(plr, char) end)
	if plr.Character then onCharacter(plr, plr.Character) end
end)

Players.PlayerRemoving:Connect(function(plr)
	local char = plr.Character
	if not char then return end
	local rain = char:FindFirstChild(RAIN_PART_NAME)
	if rain then rain:Destroy() end
end)

-- ===== 메인 루프 =====
-- 시작 시 한 번 현재 상태 적용
applyWeatherForAll()

task.spawn(function()
	while true do
		-- 전역 시계 자정 래핑(24 -> 0) 감지
		local nowHours = (tonumber(Lighting.ClockTime) or 0) % 24
		if worldHoursPrev > nowHours then
			worldDay += 1
			local newWeekIndex = math.floor((worldDay - 1) / WEEK_LEN)
			if newWeekIndex ~= weekIndex then
				weekIndex = newWeekIndex
				rerollWeeklySchedule()
			end
		end
		worldHoursPrev = nowHours

		-- 날씨 적용
		applyWeatherForAll()

		task.wait(WEATHER_TICK_SEC)
	end
end)
