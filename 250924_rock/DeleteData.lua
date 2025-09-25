-- ===== Command Bar 전용: 모든 블록 초기화 =====
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local DSS = game:GetService("DataStoreService")
local STORE = DSS:GetDataStore("Blocks_V1")
local KEY_PREFIX = "blocks_"

-- RemoteEvent 준비
local BlocksEvent = RS:FindFirstChild("Blocks_Update")
if not BlocksEvent then
	BlocksEvent = Instance.new("RemoteEvent")
	BlocksEvent.Name = "Blocks_Update"
	BlocksEvent.Parent = RS
end

-- 블록 값 테이블
local blocks = {}

-- 클라이언트 갱신
local function pushDelta(userId, value)
	BlocksEvent:FireAllClients("delta", userId, value, "")
end

-- 데이터 저장
local function saveUser(userId, value)
	local ok, err = pcall(function()
		STORE:SetAsync(KEY_PREFIX .. tostring(userId), value)
	end)
	if not ok then warn("[BlockService CommandBar] Save failed:", userId, err) end
end

-- 초기값 설정
local INITIAL_VALUE = 10
for _, pl in ipairs(Players:GetPlayers()) do
	blocks[pl.UserId] = INITIAL_VALUE
	pushDelta(pl.UserId, INITIAL_VALUE)
	saveUser(pl.UserId, INITIAL_VALUE)
end

print("[BlockService CommandBar] 모든 블록이 초기화되었습니다. 초기값:", INITIAL_VALUE)
