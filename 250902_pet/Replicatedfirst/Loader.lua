-- ReplicatedFirst/Loader.client.lua
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local CollectionService = game:GetService("CollectionService")

-- 1) 플레이어/GUI 준비
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 2) 내 로딩 UI를 '먼저' 붙인다 (필요 최소 요소만)
local screen = Instance.new("ScreenGui")
screen.Name = "BootLoader"
screen.IgnoreGuiInset = true
screen.DisplayOrder = 1_000_000
screen.ResetOnSpawn = false
screen.Parent = playerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1,1)
bg.BackgroundColor3 = Color3.fromRGB(12,12,16)
bg.Parent = screen

local title = Instance.new("TextLabel")
title.Size = UDim2.fromScale(1, 0.1)
title.Position = UDim2.fromScale(0, 0.45)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(235,235,240)
title.Text = "로딩 중..."
title.Parent = bg

local barBG = Instance.new("Frame")
barBG.Size = UDim2.fromScale(0.5, 0.02)
barBG.Position = UDim2.fromScale(0.25, 0.58)
barBG.BackgroundColor3 = Color3.fromRGB(40,40,50)
barBG.BorderSizePixel = 0
barBG.Parent = bg

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.fromRGB(0,170,255)
barFill.BorderSizePixel = 0
barFill.Parent = barBG

local percent = Instance.new("TextLabel")
percent.Size = UDim2.fromScale(1, 3)
percent.Position = UDim2.fromScale(0, 1.4)
percent.BackgroundTransparency = 1
percent.Font = Enum.Font.Gotham
percent.TextScaled = true
percent.TextColor3 = Color3.fromRGB(200,200,210)
percent.Text = "0%"
percent.Parent = barBG

local function setProgress(p) -- 0~1
	p = math.clamp(p, 0, 1)
	barFill.Size = UDim2.fromScale(p, 1)
	percent.Text = string.format("%d%%", math.floor(p*100 + 0.5))
end

-- 기본 로딩 화면을 가장 먼저 제거
pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)

-- UI가 바로 보이도록 한 프레임 보장
RunService.RenderStepped:Wait()
setProgress(0) -- 바로 0% 표시


-- 5) 무거운 작업은 지연 실행: UI가 뜬 뒤 시작
task.defer(function()
	-- (A) 프리로드 대상 수집: 태그 기반으로 '꼭 필요한 것'만
	local toPreload = {}
	for _, inst in ipairs(CollectionService:GetTagged("Preload")) do
		if inst and inst.Parent then
			table.insert(toPreload, inst)
		end
	end

	-- 필요하다면 여기에 소량의 추가 대상만 (예: 시작존 폴더, UI 이미지 몇 개)
	-- toPreload[#toPreload+1] = workspace:WaitForChild("StartZone", 1)

	-- (B) 배치 프리로드 (큰 리스트 한방에 돌리면 렌더가 굼떠짐)
	local function batchedPreload(list, batchSize)
		local loaded, total = 0, #list
		if total == 0 then
			setProgress(1)
			return
		end
		local i = 1
		while i <= total do
			local j = math.min(i + batchSize - 1, total)
			local batch = table.create(j - i + 1)
			for k = i, j do batch[#batch+1] = list[k] end

			-- 콜백으로 세부 진행률 반영
			local ok, err = pcall(function()
				ContentProvider:PreloadAsync(batch, function()
					loaded += 1
					setProgress(loaded / total)
				end)
			end)
			if not ok then warn("[Preload] error: ", err) end

			i = j + 1
			task.wait() -- 렌더 및 입력에 양보
		end
	end

	batchedPreload(toPreload, 64) -- 배치 크기는 환경에 맞게 32~128 사이로 조절

	-- 최소 표시 시간(선택)
	task.wait(0.6)

	-- 페이드아웃
	local tween = TweenService:Create(bg, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundTransparency = 1})
	tween:Play()
	tween.Completed:Wait()
	screen:Destroy()
end)

