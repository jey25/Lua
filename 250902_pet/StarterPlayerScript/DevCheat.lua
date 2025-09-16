--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local me = Players.LocalPlayer
-- ✅ 서버에서 ReplicatedStorage.RemoteEvents.DevCheat 가 존재해야 합니다.
local Remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local DevCheatRE = Remotes:WaitForChild("DevCheat") :: RemoteEvent

-- (편의) 클라 표시 가드만; 보안은 서버에서 DevGate로 재검증합니다.
local DEV_WHITELIST: {[number]: boolean} = {
	[3857750238] = true, -- 서버 DevGate와 동일하게 유지
}
local canShow = RunService:IsStudio() or DEV_WHITELIST[me.UserId] == true
if not canShow then return end

-- ===== UI =====
local gui = Instance.new("ScreenGui")
gui.Name = "DevCheatUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = me:WaitForChild("PlayerGui")

-- 패널 (버튼 2개 세로 배치 → 높이만 약간 증가)
local frame = Instance.new("Frame")
frame.Name = "Panel"
-- 패널 높이만 살짝 키움(기존 100 → 150)
frame.Size = UDim2.fromOffset(140, 180)
frame.AnchorPoint = Vector2.new(1, 1)
frame.Position = UDim2.new(0.985, 0, 0.88, 0) -- 우측 중앙하단 쪽
frame.BackgroundTransparency = 0.2
frame.Parent = gui
local corner = Instance.new("UICorner", frame); corner.CornerRadius = UDim.new(0, 12)
local layout = Instance.new("UIListLayout", frame)
layout.FillDirection = Enum.FillDirection.Vertical
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center

-- 버튼 팩토리
local function mkBtn(text: string, onClick: ()->())
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(120, 36)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.AutoButtonColor = true
	b.BackgroundTransparency = 0.1
	b.Parent = frame
	local c = Instance.new("UICorner", b); c.CornerRadius = UDim.new(0, 10)
	b.MouseButton1Click:Connect(onClick)
end



-- ===== 치트 버튼 정의 =====
local BUTTONS: { {label: string, action: string, payload: any}? } = {
	{ label = "LvUp10", action = "exp.lvup10", payload = nil },
	{ label = "coin5",  action = "coin.add5",  payload = nil }, -- ⬅ 추가
	{ label = "night",  action = "time.night", payload = nil },
	{ label = "day",    action = "time.day",   payload = nil },
}



for _, def in ipairs(BUTTONS) do
	if def then
		mkBtn(def.label, function()
			DevCheatRE:FireServer(def.action, def.payload)
		end)
	end
end
