local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipChanged = Remotes:WaitForChild("HandsEquipChanged")
local GetAllEquipped = Remotes:WaitForChild("HandsGetAllEquipped")
local HandsState = require(ReplicatedStorage:WaitForChild("HandsClientState"))


local function findBoardsForUser(userId: number)
	local targets = {}
	-- 1) OwnerUserId(IntValue)로 명시된 보드가 있으면 그것부터
	for _, inst in ipairs(playerGui:GetDescendants()) do
		if inst:IsA("Frame") or inst:IsA("Folder") or inst:IsA("ScreenGui") then
			local tag = inst:FindFirstChild("OwnerUserId")
			if tag and tag:IsA("IntValue") and tag.Value == userId then
				table.insert(targets, inst)
			end
		end
	end
	-- 2) 로컬 유저 보드 기본 탐색 (이름이 'board'인 컨테이너)
	if #targets == 0 and userId == player.UserId then
		for _, inst in ipairs(playerGui:GetDescendants()) do
			if (inst:IsA("Frame") or inst:IsA("ScreenGui") or inst:IsA("Folder")) and inst.Name:lower() == "board" then
				table.insert(targets, inst)
			end
		end
	end
	return targets
end

local function applyImagesToContainer(container, images)
	local map = { "paper", "rock", "scissors" }
	for _, btnName in ipairs(map) do
		for _, d in ipairs(container:GetDescendants()) do
			if (d:IsA("ImageButton") or d:IsA("ImageLabel")) and d.Name:lower() == btnName then
				if images[btnName] and images[btnName] ~= "" then
					d.Image = images[btnName]
				end
			end
		end
	end
end

-- findBoardsForUser()는 유지하되, applyForUser의 fallback만 수정

local function applyForUser(userId, images)
	local targets = findBoardsForUser(userId)
	if #targets == 0 then
		if userId == player.UserId then
			task.spawn(function()
				-- ⬇️ 'board' -> 'board_runtime' 으로 변경
				local board = playerGui:WaitForChild("board_runtime", 10)
				if board then applyImagesToContainer(board, images) end
			end)
		end
		return
	end
	for _, t in ipairs(targets) do
		applyImagesToContainer(t, images)
	end
end


-- 초기 동기화
local all = GetAllEquipped:InvokeServer()
for uid, info in pairs(all) do
	local id = tonumber(uid) or uid
	HandsState.Set(id, { theme = info.theme, images = info.images })
	applyForUser(id, info.images)
end

EquipChanged.OnClientEvent:Connect(function(userId, themeName, images)
	HandsState.Set(userId, { theme = themeName, images = images })
	applyForUser(userId, images)
end)


-- 결과 화면 아이콘 설정 헬퍼
local function setResultIcon(imageLabel: ImageLabel, userId: number, choiceName: "paper"|"rock"|"scissors")
	local pack = HandsState[userId]
	local img = pack and pack.images and pack.images[choiceName]
	if img then
		imageLabel.Image = img
	end
end

-- 보드가 라운드 시작 때 동적으로 생성되므로, 생성 감지해서 즉시 칠하기
playerGui.DescendantAdded:Connect(function(obj)
	if obj:IsA("ScreenGui") and obj.Name == "board_runtime" then
		task.defer(function()
			local me = HandsState[player.UserId]
			if me and me.images then
				applyImagesToContainer(obj, me.images)
			end
		end)
	end
end)
