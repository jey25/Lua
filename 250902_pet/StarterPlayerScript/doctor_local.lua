-- LocalScript: 내 캐릭터만 감시+UI 제어
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- 리소스(이름 정확히 맞추기)
local NPCClickTemplate = ReplicatedStorage:WaitForChild("NPCClick")      -- ScreenGui (안에 TextButton "NPCClick")
local PetDoctorTemplate = ReplicatedStorage:WaitForChild("petdoctor")    -- ScreenGui (Children: hi, Inoculation, result, toosoon)
local DoctorTryVaccinate = ReplicatedStorage:WaitForChild("DoctorTryVaccinate") :: RemoteFunction

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
	return gui, gui:FindFirstChild("CountLabel") :: TextLabel
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
	if activeButtonGui then activeButtonGui:Destroy() activeButtonGui = nil end

	-- 1) 상호작용 버튼 클론
	local clickGui = NPCClickTemplate:Clone()
	clickGui.Name = "NPCClickGui"       -- 버튼 TextButton 이름과 구분
	clickGui.ResetOnSpawn = false
	clickGui.Parent = pg
	activeButtonGui = clickGui

	local btn = clickGui:WaitForChild("NPCClick") :: TextButton

	btn.MouseButton1Click:Connect(function()
		-- 버튼은 제거
		if activeButtonGui then activeButtonGui:Destroy() activeButtonGui = nil end

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

		-- OK → 서버에 접종 시도
		inocOK.MouseButton1Click:Connect(function()
			local result
			local ok = pcall(function()
				result = DoctorTryVaccinate:InvokeServer("try")
			end)
			
			inoculationFrame.Visible = false
			if ok and result and result.ok then
				resultFrame.Visible = true
				setCountLabel(result.count)
				
				local ok, ClearModule = pcall(function()
					return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ClearModule"))
				end)
				if ok and ClearModule and ClearModule.showClearEffect then
					pcall(function() ClearModule.showClearEffect(LocalPlayer) end)
				end
				
			else
				tooSoonFrame.Visible = true
				setCountLabel(result and result.count or nil)
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
