local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- RemoteFunction 준비
local rf = ReplicatedStorage:FindFirstChild("DoctorTryVaccinate")
if not rf then
	rf = Instance.new("RemoteFunction")
	rf.Name = "DoctorTryVaccinate"
	rf.Parent = ReplicatedStorage
end

-- 서버 상태 (유저별 접종 수/마지막 시간)
local maxVaccinations = 6
local twoWeeksInSeconds = 1209600 -- 2주
local vaccinationCounts = {}
local lastVaccinationTime = {}

rf.OnServerInvoke = function(player, action)
	-- action: "try" 접종 시도
	if action ~= "try" then
		return { ok = false, reason = "bad_request" }
	end

	local uid = player.UserId
	local now = os.time()
	local count = vaccinationCounts[uid] or 0
	local lastT = lastVaccinationTime[uid] or 0

	if count >= maxVaccinations then
		return { ok = false, reason = "maxed", count = count }
	end
	if now - lastT < twoWeeksInSeconds then
		return { ok = false, reason = "tooSoon", count = count, wait = twoWeeksInSeconds - (now - lastT) }
	end

	-- 접종 성공 처리
	count += 1
	vaccinationCounts[uid] = count
	lastVaccinationTime[uid] = now
	return { ok = true, reason = "ok", count = count }
end
