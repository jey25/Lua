-- ===== Command Bar: 글로벌 랭킹 & 유저 블록 0 초기화 =====
do
	local Players = game:GetService("Players")
	local RS = game:GetService("ReplicatedStorage")
	local DSS = game:GetService("DataStoreService")

	-- 프로젝트에 맞게 확인
	local USER_STORE = DSS:GetDataStore("Blocks_V1")             -- 유저별 누적치
	local RANK_STORE = DSS:GetOrderedDataStore("BlocksLB_V1")    -- 글로벌 랭킹(Ordered)
	local KEY_PREFIX = "blocks_"

	-- RemoteEvent 확보
	local BlocksEvent = RS:FindFirstChild("Blocks_Update")
	if not BlocksEvent then
		BlocksEvent = Instance.new("RemoteEvent")
		BlocksEvent.Name = "Blocks_Update"
		BlocksEvent.Parent = RS
	end
	local LBEvent = RS:FindFirstChild("BlocksLeaderboard")
	if not LBEvent then
		LBEvent = Instance.new("RemoteEvent")
		LBEvent.Name = "BlocksLeaderboard"
		LBEvent.Parent = RS
	end

	local function setZero(userId: number)
		local key = KEY_PREFIX .. tostring(userId)
		pcall(function() USER_STORE:SetAsync(key, 0) end)                 -- 유저 누적치 0
		pcall(function() RANK_STORE:SetAsync(tostring(userId), 0) end)    -- 랭킹 값 0
		pcall(function() BlocksEvent:FireAllClients("delta", userId, 0, "") end) -- HUD 즉시 반영
	end

	-- 1) 현재 접속 중인 플레이어들 0
	for _, pl in ipairs(Players:GetPlayers()) do
		setZero(pl.UserId)
		task.wait(0.05) -- 버짓 여유
	end

	-- 2) 랭킹(오프라인 포함) 전체 순회하며 0
	local ok, pages = pcall(function()
		-- ✅ min/max 생략: 전체 범위
		return RANK_STORE:GetSortedAsync(true, 100)
	end)

	if ok and pages then
		local collected = {}
		while true do
			local items = pages:GetCurrentPage()
			for _, item in ipairs(items) do
				local uid = tonumber(item.key)
				if uid and not collected[uid] then
					collected[uid] = true
					setZero(uid)
					task.wait(0.05)
				end
			end
			if pages.IsFinished then break end
			local advOk = pcall(function() pages:AdvanceToNextPage() end)
			if not advOk then break end
			task.wait(0.1)
		end

		-- (선택) 클라이언트 리더보드에 즉시 0 리스트 샘플 브로드캐스트
		local top, n = {}, 0
		for uid in pairs(collected) do
			if n >= 50 then break end
			local name = ("User_%d"):format(uid)
			local okN, got = pcall(function() return Players:GetNameFromUserIdAsync(uid) end)
			if okN and got then name = got end
			table.insert(top, {userId = uid, name = name, blocks = 0})
			n += 1
		end
		table.sort(top, function(a, b) return a.name < b.name end)
		pcall(function() LBEvent:FireAllClients("top", top) end)

		print("[Blocks Wipe] 접속자 + 랭킹 등록자 0 초기화 완료.")
	else
		warn("[Blocks Wipe] 랭킹 OrderedDataStore 순회 실패. 스토어 이름/권한/버짓을 확인하세요.")
	end
end
