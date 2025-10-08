-- LocalScript: 내 캐릭터만 감시+UI 제어 (교체본)
--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- 리소스
local NPCClickTemplate = ReplicatedStorage:WaitForChild("NPCClick")      :: ScreenGui
local PetDoctorTemplate = ReplicatedStorage:WaitForChild("petdoctor")    :: ScreenGui
local DoctorTryVaccinate = ReplicatedStorage:WaitForChild("DoctorTryVaccinate") :: RemoteFunction
local RemoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents")

-- NPC 위치
local npc_doctor = workspace.World.Building["Pet Hospital"].Doctor
local interactionDistance = 5

-- HUD
local maxVaccinations = 5
local RIGHT_MARGIN = 16
local TOP_MARGIN_SCALE = 0.04

local function ensureCountGui()
	local pg = LocalPlayer:WaitForChild("PlayerGui")
	local gui = pg:FindFirstChild("VaccinationCountGui") :: ScreenGui
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "VaccinationCountGui"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = pg
	end

	local hud = gui:FindFirstChild("CounterHud") :: Frame
	if not hud then
		hud = Instance.new("Frame")
		hud.Name = "CounterHud"
		hud.AnchorPoint = Vector2.new(1, 0)
		hud.Position = UDim2.new(1, -RIGHT_MARGIN, TOP_MARGIN_SCALE, 0)
		hud.Size = UDim2.new(0, 180, 0, 0)
		hud.BackgroundTransparency = 1
		hud.Parent = gui

		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Vertical
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.VerticalAlignment = Enum.VerticalAlignment.Top
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		layout.Padding = UDim.new(0, 6)
		layout.Parent = hud
	else
		hud.AnchorPoint = Vector2.new(1, 0)
		hud.Position = UDim2.new(1, -RIGHT_MARGIN, TOP_MARGIN_SCALE, 0)
	end

	local title = hud:FindFirstChild("TitleLabel") :: TextLabel
	if not title then
		title = Instance.new("TextLabel")
		title.Name = "TitleLabel"
		title.LayoutOrder = 1
		title.Size = UDim2.new(1, 0, 0, 24)
		title.BackgroundTransparency = 1
		title.TextColor3 = Color3.fromRGB(234,234,234)
		title.Font = Enum.Font.GothamBlack
		title.TextScaled = true
		title.Text = "Vaccinations"
		title.Parent = hud
	end

	local count = hud:FindFirstChild("CountLabel") :: TextLabel
	if not count then
		count = Instance.new("TextLabel")
		count.Name = "CountLabel"
		count.LayoutOrder = 2
		count.Size = UDim2.new(1, 0, 0, 40)
		count.BackgroundTransparency = 0.35
		count.BackgroundColor3 = Color3.fromRGB(0,0,0)
		count.TextColor3 = Color3.fromRGB(234,234,234)
		count.Font = Enum.Font.GothamBlack
		count.TextScaled = true
		count.Text = "0/"..maxVaccinations
		count.Parent = hud

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = count
	end

	title.TextStrokeTransparency = 0.6
	title.TextStrokeColor3 = Color3.new(0,0,0)

	local countLbl = hud:FindFirstChild("CountLabel") :: TextLabel
	countLbl.TextStrokeTransparency = 0.45
	countLbl.TextStrokeColor3 = Color3.new(0,0,0)

	return gui, countLbl
end

local function setCountLabel(n: number?)
	local _, lbl = ensureCountGui()
	if lbl then
		lbl.Text = ("%d/%d"):format(tonumber(n) or 0, maxVaccinations)
	end
end

local function syncVaccinationFromAttr()
	local n = LocalPlayer:GetAttribute("VaccinationCount")
	setCountLabel(tonumber(n) or 0)
end

syncVaccinationFromAttr()
LocalPlayer:GetAttributeChangedSignal("VaccinationCount"):Connect(syncVaccinationFromAttr)

-- 이펙트 호출(중복 방지 가드)
local lastFxAt = 0
local function tryPlayFX()
	local now = time()
	if now - lastFxAt < 0.25 then return end
	lastFxAt = now

	-- ClearModule 시도 → 실패 시 폴백
	local okReq, ClearModule = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ClearModule"))
	end)
	if okReq and type(ClearModule) == "table" and type(ClearModule.showClearEffect) == "function" then
		pcall(function() ClearModule.showClearEffect(LocalPlayer) end)
	else
		-- 간단 폴백(원하면 제거 가능)
		local pg = LocalPlayer:WaitForChild("PlayerGui")
		local sg = Instance.new("ScreenGui"); sg.Parent = pg
		local tl = Instance.new("TextLabel"); tl.Parent = sg
		tl.Size = UDim2.new(1,0,0,80); tl.Position = UDim2.new(0,0,0.4,0)
		tl.BackgroundTransparency = 1; tl.TextScaled = true
		tl.Text = "Clear !!"
		task.delay(1.2, function() sg:Destroy() end)
	end
end

local function bindVaccinationFX(ev: Instance)
	if ev and ev:IsA("RemoteEvent") and ev.Name == "VaccinationFX" then
		-- 이미 바인딩돼 있으면 재바인딩 방지
		if ev:GetAttribute("Bound_"..LocalPlayer.UserId) then return end
		ev:SetAttribute("Bound_"..LocalPlayer.UserId, true)

		ev.OnClientEvent:Connect(function(data)
			-- ⛳️ 의미 검증: 성공 이벤트만 허용
			if type(data) ~= "table" or data.ok ~= true or data.kind ~= "vaccinate_ok" then
				return
			end

			local newCount = tonumber(data.count) or 0
			local curAttr = tonumber(LocalPlayer:GetAttribute("VaccinationCount")) or 0

			-- ⛳️ 증분 검증: 실제 카운트가 증가했을 때만 FX
			if newCount > curAttr then
				-- HUD도 함께 올려주면 시각적으로 일관
				setCountLabel(newCount)
				tryPlayFX()
			end
		end)
	end
end


local existing = RemoteFolder:FindFirstChild("VaccinationFX")
if existing then bindVaccinationFX(existing) end
RemoteFolder.ChildAdded:Connect(bindVaccinationFX)

-- 닥터 UI
local activeButtonGui: ScreenGui? = nil
local docOpen = false

local function showInteractButton()
	local pg = LocalPlayer:WaitForChild("PlayerGui")
	if docOpen then return end
	if activeButtonGui then activeButtonGui:Destroy(); activeButtonGui = nil end

	local clickGui = NPCClickTemplate:Clone()
	clickGui.Name = "NPCClickGui"
	clickGui.ResetOnSpawn = false
	clickGui.Parent = pg
	activeButtonGui = clickGui

	local btn = clickGui:WaitForChild("NPCClick") :: TextButton
	btn.MouseButton1Click:Connect(function()
		if activeButtonGui then activeButtonGui:Destroy(); activeButtonGui = nil end

		local docGui = PetDoctorTemplate:Clone() :: ScreenGui
		docGui.Name = "petdoctor_runtime"
		docGui.ResetOnSpawn = false
		docGui.IgnoreGuiInset = true
		docGui.Enabled = true
		docGui.Parent = pg
		docOpen = true

		local hiFrame          = docGui:WaitForChild("hi") :: Frame
		local inoculationFrame = docGui:WaitForChild("Inoculation") :: Frame
		local resultFrame      = docGui:WaitForChild("result") :: Frame
		local tooSoonFrame     = docGui:WaitForChild("toosoon") :: Frame

		local hiOK     = hiFrame:WaitForChild("HIOK") :: TextButton
		local inocOK   = inoculationFrame:WaitForChild("OK") :: TextButton
		local resultOK = resultFrame:WaitForChild("REOK") :: TextButton
		local soonOK   = tooSoonFrame:WaitForChild("SOONOK") :: TextButton

		hiFrame.Visible, inoculationFrame.Visible, resultFrame.Visible, tooSoonFrame.Visible =
			true, false, false, false

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
				resultFrame.Visible = true
				setCountLabel(result.count) -- HUD 갱신(서버도 Attribute로 쏴줌)

				-- FX는 서버 VaccinationFX에서 트리거됨(tryPlayFX 중복 방지)

			else
				tooSoonFrame.Visible = true
				setCountLabel(result and result.count or nil)

				local msgLabel = tooSoonFrame:FindFirstChild("TextLabel") :: TextLabel?
				if msgLabel then
					local function formatRemain(waitSecs: number): string
						local totalMins = math.max(1, math.ceil(waitSecs / 60))
						local minsPerDay = 24 * 60
						local days  = math.floor(totalMins / minsPerDay)
						totalMins   = totalMins % minsPerDay
						local hours = math.floor(totalMins / 60)   -- ✅ 오타 수정 (hour → hours)
						local mins  = totalMins % 60

						local parts = {}
						if days > 0 then table.insert(parts, string.format("%d day", days)) end
						if hours > 0 or days > 0 then table.insert(parts, string.format("%d hour", hours)) end
						table.insert(parts, string.format("%d min", mins))
						return ("Next vaccination %s"):format(table.concat(parts, " "))
					end

					local msg: string
					if result and result.reason == "wait" and typeof(result.wait) == "number" then
						msg = formatRemain(result.wait)
					elseif result and result.reason == "max" then
						msg = "The maximum number of vaccinations"
					else
						msg = "I can't get vaccinated yet"
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

-- NPC 근접 루프
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

ensureCountGui()
