-- ===== Command Bar 전용: 모든 데이터 초기화 (온라인 + DataStore + 리더보드) =====
local DSS = game:GetService("DataStoreService")
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local STORE = DSS:GetDataStore("Blocks_V1")
local ODS   = DSS:GetOrderedDataStore("BlocksLB_V1")
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
local INITIAL_VALUE = 10 -- 초기값 지정

-- 클라이언트 갱신
local function pushDelta(userId, value)
	BlocksEvent:FireAllClients("delta", userId, value, "")
end

-- 데이터 저장 (개인 + Ordered)
local function saveUser(userId, value)
	pcall(function() STORE:SetAsync(KEY_PREFIX .. tostring(userId), value) end)
	pcall(function() ODS:SetAsync(tostring(userId), value) end)
end

-- 1️⃣ 온라인 플레이어 초기화
for _, pl in ipairs(Players:GetPlayers()) do
	blocks[pl.UserId] = INITIAL_VALUE
	pushDelta(pl.UserId, INITIAL_VALUE)
	saveUser(pl.UserId, INITIAL_VALUE)
end

-- 2️⃣ 과거 데이터스토어 유저 초기화
-- ※ 주의: 이 코드는 단순히 UserId 리스트를 수동으로 가져와야 함. 
-- 데이터스토어는 전체 키 목록 제공 안 함. 테스트용으로 몇 명만 초기화 가능
local exampleUserIds = {12345678, 23456789, 34567890} -- 초기화할 유저 ID 리스트
for _, uid in ipairs(exampleUserIds) do
	blocks[uid] = INITIAL_VALUE
	saveUser(uid, INITIAL_VALUE)
end

print("[BlockService CommandBar] 모든 블록과 리더보드 기록 초기화 완료. 초기값:", INITIAL_VALUE)
