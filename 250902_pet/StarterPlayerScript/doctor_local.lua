-- LocalScript: 내 캐릭터만 감시+UI 제어
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- 리소스(이름 정확히 맞추기)
local NPCClickTemplate = ReplicatedStorage:WaitForChild("NPCClick")      -- ScreenGui (안에 TextButton "NPCClick")
local PetDoctorTemplate = ReplicatedStorage:WaitForChild("petdoctor")    -- ScreenGui (Children: hi, Inoculation, result, toosoon)
local DoctorTryVaccinate = ReplicatedStorage:WaitForChild("DoctorTryVaccinate") :: RemoteFunction
local RemoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local VaccinationFX = RemoteFolder:WaitForChild("VaccinationFX", 10)
if not VaccinationFX then
	warn("[Vaccination] VaccinationFX RemoteEvent not found within 10s; FX will be skipped.")
end
-- NPC 위치
local npc_doctor = workspace.World.Building["Pet Hospital"].Doctor
local interactionDistance = 5


-- 우측 상단 카운트 미니 UI (클라 표시용)
local maxVaccinations = 5

local function ensureCountGui()
	local pg = LocalPlayer:WaitForChild("PlayerGui")
	local gui = pg:FindFirstChild("VaccinationCountGui") :: ScreenGui
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "VaccinationCountGui"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.Parent = pg

		local title = Instance.new("TextLabel")
		title.Name = "TitleLabel"
		title.Size = UDim2.new(0, 120, 0, 24)
		title.Position = UDim2.new(1, -220, 0, 160)
		title.BackgroundTransparency = 1
		title.TextColor3 = Color3.fromRGB(234,234,234)
		title.Font = Enum.Font.SourceSansBold
		title.TextScaled = true
		title.Text = "Vaccinations"
		title.Parent = gui

		local count = Instance.new("TextLabel")
		count.Name = "CountLabel"
		count.Size = UDim2.new(0, 120, 0, 40)
		count.Position = UDim2.new(1, -220, 0, 200)
		count.BackgroundTransparency = 0.35
		count.BackgroundColor3 = Color3.fromRGB(0,0,0)
		count.TextColor3 = Color3.fromRGB(234,234,234)
		count.Font = Enum.Font.SourceSansBold
		count.TextScaled = true
		count.Text = "0/"..maxVaccinations
		count.Parent = gui
	end

	-- ▼ 이미 있던 GUI에도 동일 스타일 적용(중복 안전)
	local title = gui:FindFirstChild("TitleLabel") :: TextLabel?
	local count = gui:FindFirstChild("CountLabel") :: TextLabel?

	if title then
		title.Font = Enum.Font.GothamBlack          -- 더 두껍게
		title.TextStrokeTransparency = 0.6          -- 살짝 두께감
		title.TextStrokeColor3 = Color3.new(0,0,0)
	end

	if count then
		count.Font = Enum.Font.GothamBlack          -- 더 두껍게
		count.TextStrokeTransparency = 0.45         -- 테두리 얇게
		count.TextStrokeColor3 = Color3.new(0,0,0)

		-- 모서리 둥글게(테두리만 변경, 위치/크기 그대로)
		local corner = count:FindFirstChildOfClass("UICorner")
		if not corner then
			corner = Instance.new("UICorner")
			corner.Parent = count
		end
		(corner :: UICorner).CornerRadius = UDim.new(0, 8)
	end

	return gui, count
end



local function setCountLabel(n)
	local _, lbl = ensureCountGui()
	if lbl then
		lbl.Text = ("%d/%d"):format(n or 0, maxVaccinations)
		if (n or 0) >= maxVaccinations then
			-- 꽉 차면 그냥 고정표시 (원하면 gui:Destroy() 가능)
		end
	end
end

-- 서버가 Player Attribute로 심어둔 값을 즉시 반영
local function syncVaccinationFromAttr()
	local n = LocalPlayer:GetAttribute("VaccinationCount")
	setCountLabel(tonumber(n) or 0)
end

-- 최초 1회
syncVaccinationFromAttr()
-- 서버가 값을 바꾸면 즉시 반영
LocalPlayer:GetAttributeChangedSignal("VaccinationCount"):Connect(syncVaccinationFromAttr)

local activeButtonGui: ScreenGui? = nil
local docOpen = false

local function showInteractButton()
	local pg = LocalPlayer:WaitForChild("PlayerGui")

	-- 이미 열려 있거나 버튼 있음 → 재생성 방지
	if docOpen then return end
	if activeButtonGui then activeButtonGui:Destroy(); activeButtonGui = nil end

	-- 1) 상호작용 버튼 클론
	local clickGui = NPCClickTemplate:Clone()
	clickGui.Name = "NPCClickGui"       -- 버튼 TextButton 이름과 구분
	clickGui.ResetOnSpawn = false
	clickGui.Parent = pg
	activeButtonGui = clickGui

	local btn = clickGui:WaitForChild("NPCClick") :: TextButton

	btn.MouseButton1Click:Connect(function()
		-- 버튼은 제거
		if activeButtonGui then activeButtonGui:Destroy(); activeButtonGui = nil end

		-- 2) petdoctor GUI를 그대로 클론해서 PlayerGui에 붙이고 바로 켬
		local docGui = PetDoctorTemplate:Clone() :: ScreenGui
		docGui.Name = "petdoctor_runtime"
		docGui.ResetOnSpawn = false
		docGui.IgnoreGuiInset = true
		docGui.Enabled = true
		docGui.Parent = pg
		docOpen = true

		-- 프레임/버튼 참조
		local hiFrame          = docGui:WaitForChild("hi") :: Frame
		local inoculationFrame = docGui:WaitForChild("Inoculation") :: Frame
		local resultFrame      = docGui:WaitForChild("result") :: Frame
		local tooSoonFrame     = docGui:WaitForChild("toosoon") :: Frame

		local hiOK     = hiFrame:WaitForChild("HIOK") :: TextButton
		local inocOK   = inoculationFrame:WaitForChild("OK") :: TextButton
		local resultOK = resultFrame:WaitForChild("REOK") :: TextButton
		local soonOK   = tooSoonFrame:WaitForChild("SOONOK") :: TextButton

		-- 초기 표시 상태
		hiFrame.Visible, inoculationFrame.Visible, resultFrame.Visible, tooSoonFrame.Visible =
			true, false, false, false

		-- hi → 접종 확인 화면
		hiOK.MouseButton1Click:Connect(function()
			hiFrame.Visible = false
			inoculationFrame.Visible = true
		end)

		inocOK.MouseButton1Click:Connect(function()
			local result
			local callOK = pcall(function()
				result = DoctorTryVaccinate:InvokeServer("try")
			end)

			inoculationFrame.Visible = false

			if callOK and result and result.ok then
				-- ✅ 성공: 결과 화면 + 카운트 갱신
				resultFrame.Visible = true
				setCountLabel(result.count)

			else
				-- 실패(쿨다운/최대치/기타) 화면
				tooSoonFrame.Visible = true
				setCountLabel(result and result.count or nil)

				local msgLabel = tooSoonFrame:FindFirstChild("TextLabel") :: TextLabel?
				if msgLabel then
					local function formatRemain(waitSecs: number): string
						-- 분 단위로 올림 → 총 분
						local totalMins = math.max(1, math.ceil(waitSecs / 60))

						local minsPerDay = 24 * 60
						local days  = math.floor(totalMins / minsPerDay)
						totalMins   = totalMins % minsPerDay
						local hours = math.floor(totalMins / 60)
						local mins  = totalMins % 60

						local parts = {}
						if days > 0 then table.insert(parts, string.format("%d일", days)) end
						if hours > 0 or days > 0 then table.insert(parts, string.format("%d시간", hours)) end
						table.insert(parts, string.format("%d분", mins)) -- 분은 항상 노출

						return ("다음 접종까지 %s 남음"):format(table.concat(parts, " "))
					end

					local msg: string
					if result and result.reason == "wait" and typeof(result.wait) == "number" then
						msg = formatRemain(result.wait)
					elseif result and result.reason == "max" then
						msg = "최대 접종 횟수에 도달했습니다."
					else
						msg = "지금은 접종할 수 없어요."
					end
					msgLabel.Text = msg
				end


			end
		end)


		local function closeDoc()
			if docGui then docGui:Destroy() end
			docOpen = false
		end
		resultOK.MouseButton1Click:Connect(closeDoc)
		soonOK.MouseButton1Click:Connect(closeDoc)
	end)
end


local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")

-- ========= [Clear 이펙트 실행 (명시적 신호에만)] =========
local function runClearEffect()
	local ok, ClearModule = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ClearModule"))
	end)
	if ok and ClearModule and ClearModule.showClearEffect then
		pcall(function() ClearModule.showClearEffect(LocalPlayer) end)
	end
end


local function playClearFXWithModule(player: Player): boolean
	local okReq, ClearModule = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ClearModule"))
	end)
	if not okReq or type(ClearModule) ~= "table" or type(ClearModule.showClearEffect) ~= "function" then
		return false
	end

	local character = player.Character or player.CharacterAdded:Wait()
	-- 모듈이 Player를 받는 구현도 있을 수 있어 둘 다 시도
	local okCall, ret = pcall(function()
		return ClearModule.showClearEffect(character) or ClearModule.showClearEffect(player)
	end)
	-- 모듈이 성공/실패를 true/false로 돌려주지 않는 경우도 있어 okCall만 신뢰
	return okCall and (ret ~= false)
end


if VaccinationFX then
	VaccinationFX.OnClientEvent:Connect(function(data)
		-- data.count 같은 값 확인 가능
		print("VaccinationFX event received. Count:", data and data.count)

		if not playClearFXWithModule(LocalPlayer) then
			runClearEffect()
		end
	end)
end



-- NPC 근처면 버튼 띄우기(내 클라에서만 체크)
task.spawn(function()
	while true do
		task.wait(0.3)
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local npcPP = npc_doctor and npc_doctor.PrimaryPart
		if not (hrp and npcPP) then
			-- 대기
		else
			local dist = (npcPP.Position - hrp.Position).Magnitude
			if dist <= interactionDistance then
				if not activeButtonGui then
					showInteractButton()
				end
			else
				if activeButtonGui then
					activeButtonGui:Destroy()
					activeButtonGui = nil
				end
			end
		end
	end
end)

-- 교체본:
ensureCountGui()
