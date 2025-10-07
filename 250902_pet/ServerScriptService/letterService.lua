--!strict
-- ServerScriptService/LetterService.lua
-- Letters 폴더의 모델들을 스캔해서 "전부 읽었는지"를 판정하고 배지 지급
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local BadgeManager = require(script.Parent:WaitForChild("BadgeManager"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

-- 월드의 Letters 폴더 찾기
local World = workspace:WaitForChild("World")
local LettersFolder = World:WaitForChild("Letters")

-- 교체: LetterService.lua
local function q(n: number): number
	return math.round(n * 100) / 100
end

local function letterKey(m: Model): string
	local pos = m:GetPivot().Position
	-- 좌표(둘째 자리) + 모델 이름으로 결정적이고 유니크한 키
	return ("L_%0.2f_%0.2f_%0.2f|%s"):format(q(pos.X), q(pos.Y), q(pos.Z), m.Name)
end


-- 초기 스캔: Letters 하위의 "직계 Model"만 대상
local ALL_KEYS: {string} = {}
local MODEL_BY_KEY: {[string]: Model} = {}

local function scanLetters()
	ALL_KEYS = {}
	MODEL_BY_KEY = {}
	for _, m in ipairs(LettersFolder:GetChildren()) do
		if m:IsA("Model") then
			local k = m:GetAttribute("LetterKey") :: string?
			if not k or k == "" then
				k = letterKey(m)
				m:SetAttribute("LetterKey", k) -- 장면에 메타만 남김(런타임용)
			end
			MODEL_BY_KEY[k] = m
			table.insert(ALL_KEYS, k)
		end
	end
	table.sort(ALL_KEYS) -- 고정 순서
end

scanLetters()

-- LetterService.lua 하단 scanLetters() 호출 뒤에 추가
LettersFolder.ChildAdded:Connect(function(child)
	if child:IsA("Model") then scanLetters() end
end)
LettersFolder.ChildRemoved:Connect(function(child)
	if child:IsA("Model") then scanLetters() end
end)


local LetterService = {}

function LetterService.GetTotalCount(): number
	return #ALL_KEYS
end

-- 플레이어가 특정 Letter(모델/파트)를 읽었을 때 호출
function LetterService.OnLetterRead(player: Player, inst: Instance)
	-- 모델 찾기
	local model = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
	if not model then return end
	local k = model:GetAttribute("LetterKey") :: string?
	if not k or k == "" then
		k = letterKey(model)
		model:SetAttribute("LetterKey", k)
	end

	-- 이미 배지 보유면 아무것도 안 함(연출/토스트 재생 금지)
	if BadgeManager.HasRobloxBadge(player, BadgeManager.Keys.GreatTeam) then
		return
	end

	-- 진행 업데이트
	local changed, countNow = PlayerDataService:MarkLetterRead(player, k)
	-- 아직 이 Letter를 처음 읽은 게 아니면 종료
	if not changed then return end

	-- 전부 읽었는지 체크
	if countNow >= #ALL_KEYS then
		-- 마지막 1개를 채운 순간에만 배지 지급(1회성)
		BadgeManager.TryAward(player, BadgeManager.Keys.GreatTeam)
		-- 선택: 바로 저장(안전)
		PlayerDataService:Save(player.UserId, "letters")
	end
end

return LetterService

