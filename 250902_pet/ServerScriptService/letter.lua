-- 서버 스크립트 (예: workspace.MyModel.Part.Script)
local part = script.Parent
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- BillboardGui 템플릿
local billboardTemplate = ReplicatedStorage:WaitForChild("playerGui")

-- ProximityPrompt 생성
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Letter"
prompt.ObjectText = "NPC"
prompt.HoldDuration = 0 -- E 키 누르자마자 실행
prompt.RequiresLineOfSight = false
prompt.Parent = part

-- 프롬프트 트리거 처리
prompt.Triggered:Connect(function(player)
	if not player.Character then return end
	local head = player.Character:FindFirstChild("Head")
	if not head then return end

	-- 이미 있으면 중복 생성 방지
	if head:FindFirstChild("NoEntryMessage") then return end

	-- 복제해서 머리에 부착
	local billboard = billboardTemplate:Clone()
	billboard.Name = "NoEntryMessage"
	billboard.Parent = head

	-- 안쪽 TextLabel 찾아서 메시지 수정
	local label = billboard:FindFirstChildWhichIsA("TextLabel", true)
	if label then
		label.Text = "Life feels like a pendulum swinging between pain and boredom"
	end

	-- 3초 후 자동 제거
	task.delay(6, function()
		if billboard and billboard.Parent then
			billboard:Destroy()
		end
	end)
end)

