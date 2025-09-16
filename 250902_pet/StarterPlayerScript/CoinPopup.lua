--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local RemoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local CoinPopupEvent = RemoteFolder:WaitForChild("CoinPopupEvent")

-- ReplicatedStorage/UI/Markers/coin (Decal)
local coinImage = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Icons"):WaitForChild("CoinIcon")

local player = Players.LocalPlayer

-- 캐릭터 머리 위에 코인 마커 표시
local function showCoinAboveCharacter(character: Model)
	local head = character:WaitForChild("Head")

	-- BillboardGui 생성
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(2, 0, 2, 0) -- 크기 조정 가능
	billboard.Adornee = head
	billboard.AlwaysOnTop = true
	billboard.StudsOffset = Vector3.new(0, 2, 0) -- 머리 위로 띄우기
	billboard.Parent = head

	-- 이미지 라벨 추가
	local imageLabel = Instance.new("ImageLabel")
	imageLabel.Size = UDim2.new(1, 0, 1, 0)
	imageLabel.BackgroundTransparency = 1
	imageLabel.Image = coinImage.Image
	imageLabel.Parent = billboard

	-- 2초 후 자동 삭제
	Debris:AddItem(billboard, 2)
end

-- 서버에서 신호 받으면 실행
CoinPopupEvent.OnClientEvent:Connect(function(playerSent: Player)
	local character = player.Character or player.CharacterAdded:Wait()
	showCoinAboveCharacter(character)
end)
