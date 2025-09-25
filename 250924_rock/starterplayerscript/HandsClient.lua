local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EquipChanged = Remotes:WaitForChild("HandsEquipChanged")
local GetAllEquipped = Remotes:WaitForChild("HandsGetAllEquipped")
local HandsState = require(ReplicatedStorage:WaitForChild("HandsClientState"))

-- ===== 유틸 =====
local function findBoardsForUser(userId: number)
	local targets = {}
	for _, inst in ipairs(playerGui:GetDescendants()) do
		if inst:IsA("Frame") or inst:IsA("Folder") or inst:IsA("ScreenGui") then
			local tag = inst:FindFirstChild("OwnerUserId")
			if tag and tag:IsA("IntValue") and tag.Value == userId then
				table.insert(targets, inst)
			end
		end
	end
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
	if not images then return end
	for _, choice in ipairs({"paper", "rock", "scissors"}) do
		for _, obj in ipairs(container:GetDescendants()) do
			if (obj:IsA("ImageButton") or obj:IsA("ImageLabel")) and obj.Name:lower() == choice then
				obj.Image = images[choice] or ""
			end
		end
	end
end

local function applyForUser(userId)
	local data = HandsState.Get(userId)
	if not data or not data.images then return end
	local targets = findBoardsForUser(userId)
	for _, t in ipairs(targets) do
		applyImagesToContainer(t, data.images)
	end
end

-- ===== 초기 동기화 =====
local all = GetAllEquipped:InvokeServer()
for uid, info in pairs(all) do
	local id = tonumber(uid) or uid
	HandsState.Set(id, { theme = info.theme, images = info.images })
	applyForUser(id)
end

-- 내 보드 fallback 적용 (board_runtime)
task.defer(function()
	local me = HandsState.Get(player.UserId)
	if me and me.images then
		local board = playerGui:FindFirstChild("board_runtime")
		if board then
			applyImagesToContainer(board, me.images)
		end
	end
end)

-- ===== 서버 이벤트 =====
EquipChanged.OnClientEvent:Connect(function(userId, themeName, images)
	HandsState.Set(userId, { theme = themeName, images = images })
	applyForUser(userId)
end)

-- ===== 결과 화면 헬퍼 =====
local function setResultIcon(imageLabel: ImageLabel, userId: number, choiceName: "paper"|"rock"|"scissors")
	local pack = HandsState.Get(userId)
	if pack and pack.images then
		imageLabel.Image = pack.images[choiceName] or ""
	end
end

-- ===== 보드 동적 생성 대응 =====
playerGui.DescendantAdded:Connect(function(obj)
	if not (obj:IsA("ScreenGui") or obj:IsA("Frame") or obj:IsA("Folder")) then return end
	local tag = obj:FindFirstChild("OwnerUserId")
	if tag and tag.Value == player.UserId or obj.Name:lower() == "board_runtime" then
		task.defer(function()
			applyForUser(player.UserId)
		end)
	end
end)
