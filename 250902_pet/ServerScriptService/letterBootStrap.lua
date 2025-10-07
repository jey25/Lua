-- ServerScriptService/LettersBootstrap.server.lua
--!strict
local RS  = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local LetterService = require(SSS:WaitForChild("LetterService"))
local LettersRoot = workspace:WaitForChild("World"):WaitForChild("Letters") :: Folder
local billboardTemplate = RS:WaitForChild("playerGui") :: BillboardGui

-- 문구(중복 제거 버전)
local RAW = {
	"Life feels like a pendulum swinging between pain and boredom",
	"Be despairing often, be happy sometimes",
	"A person discovers himself when he is alone",
	"If you feel lonely, you will be free",
	"What doesn't kill me makes me stronger",
	"Life is suffering. But a life without suffering is also meaningless",
	"Life feels like a pendulum swinging between pain and boredom",
	"A life without music is a tiring life",
	"Who dreams for a long time eventually becomes like that dream",
	"Live your life, not someone else",
	"Opportunity comes to those who are prepared",
	"Truly high self-esteem doesn't need to be advertised to others",
	"Starting to be conscious of other people means getting old",
	"A new challenge is always right",
	"The moment realize I can be wrong, That become a real adult",
	"What is impossible alone can be accomplished together",
	"Only new things change the world",
}
local UNIQUE: {string} = (function()
	local seen: {[string]: boolean} = {}
	local out = {}
	for _,t in ipairs(RAW) do if not seen[t] then seen[t]=true; table.insert(out,t) end end
	return out
end)()

local function quantize(n: number): number
	-- 좌표를 소수 둘째 자리로 고정해 미세한 부동소수 오차 제거
	return math.round(n * 100) / 100
end

local function modelKey(m: Model): string
	local p = m:GetPivot().Position
	return string.format("%0.2f|%0.2f|%0.2f", quantize(p.X), quantize(p.Y), quantize(p.Z))
end

local function hash(s: string): number
	-- 단순 롤링 해시(비트연산 없이 결정적)
	local h = 0
	for i = 1, #s do
		h = (h * 131 + string.byte(s, i)) % 2147483647
	end
	return h
end

local function getLetterPart(model: Instance): BasePart?
	local p = model:FindFirstChild("Part")
	if typeof(p) == "Instance" and p:IsA("BasePart") then return p end
	return model:FindFirstChildWhichIsA("BasePart", true)
end

local function attachPrompt(part: BasePart, message: string)
	-- ProximityPrompt (중복 방지)
	local prompt = part:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	prompt.ActionText = "Letter"
	prompt.ObjectText = "Letter"
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 8
	prompt.Parent = part

	prompt.Triggered:Connect(function(player: Player)
		local char = player.Character; if not char then return end
		local head = char:FindFirstChild("Head"); if not head then return end

		if head:FindFirstChild("NoEntryMessage") then
			LetterService.OnLetterRead(player, part)
			return
		end

		local billboard = billboardTemplate:Clone()
		billboard.Name = "NoEntryMessage"
		billboard.Parent = head
		local label = billboard:FindFirstChildWhichIsA("TextLabel", true)
		if label then label.Text = message end

		task.delay(6, function() if billboard and billboard.Parent then billboard:Destroy() end end)
		LetterService.OnLetterRead(player, part)
	end)
end

local function setupDeterministic()
	-- 1) 모든 Letter 모델 수집
	local entries: {{model: Model, part: BasePart, key: string}} = {}
	for _, child in ipairs(LettersRoot:GetChildren()) do
		if child:IsA("Model") then
			local bp = getLetterPart(child)
			if bp then
				table.insert(entries, {model = child, part = bp, key = modelKey(child)})
			end
		end
	end

	-- 2) 키 정렬(서버 간 동일한 순서 확보)
	table.sort(entries, function(a,b) return a.key < b.key end)

	-- 3) 해시 → 인덱스 결정 + 중복 방지(선형 탐색)
	local N = #UNIQUE
	local used = table.create(N, false)

	for _, e in ipairs(entries) do
		if N == 0 then
			warn("[Letters] No messages defined.")
			break
		end

		local idx = (hash(e.key) % N) + 1
		local start = idx
		if used[idx] then
			repeat
				idx = (idx % N) + 1
			until not used[idx] or idx == start
		end

		local line: string
		if not used[idx] then
			used[idx] = true
			line = UNIQUE[idx]
		else
			-- 문구 수 < 모델 수: 불가피한 재사용(그래도 서버 간 동일)
			line = UNIQUE[(hash(e.key) % N) + 1]
			warn(("[Letters] Messages fewer than models; reusing for %s"):format(e.key))
		end

		attachPrompt(e.part, line)
	end
end

setupDeterministic()

-- 런타임 추가 모델도 동일 규칙으로 배정
LettersRoot.ChildAdded:Connect(function(child)
	if not child:IsA("Model") then return end
	task.defer(function()
		local bp = getLetterPart(child); if not bp then return end
		local key = modelKey(child)
		local N = #UNIQUE
		local idx = (hash(key) % N) + 1
		local line = UNIQUE[idx]
		attachPrompt(bp, line)
	end)
end)

