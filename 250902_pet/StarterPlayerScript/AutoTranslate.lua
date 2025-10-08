-- StarterPlayerScripts/AutoTranslate.client.lua
-- 모든 TextLabel/TextButton/TextBox를 자동 감지해서 번역
-- 전제: LocalizationTable에 키(LocKey) 또는 원문(Text)이 등록되어 있어야 함.

local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- 유틸: 번역 대상 판별
local function isTextObject(inst: Instance): boolean
	if not inst then return false end
	local className = inst.ClassName
	return className == "TextLabel" or className == "TextButton" or className == "TextBox"
end

-- 한 인스턴스에 대한 번역 적용
local function applyTranslationFor(inst: TextLabel, translator)
	if not inst or not inst:IsDescendantOf(game) then return end
	if not isTextObject(inst) then return end
	if inst:GetAttribute("DoNotAutoTranslate") then return end

	-- 이미 자동로컬라이즈가 켜져 있으면 Roblox가 치환할 수도 있으니, 충돌 방지
	-- (키 기반 직접 치환을 쓸 거면 꺼두는 편이 안전)
	pcall(function() inst.AutoLocalize = false end)

	-- 소스 원문: LocSource 속성이 있으면 우선 사용, 없으면 현재 Text를 원문으로 간주
	local sourceText = inst:GetAttribute("LocSource")
	if type(sourceText) ~= "string" or sourceText == "" then
		sourceText = inst.Text or ""
	end

	-- 키 기반이 있으면 우선 사용
	local key = inst:GetAttribute("LocKey")
	local ok, translated = false, nil

	if type(key) == "string" and key ~= "" then
		-- 선택: 자리표시자 인자가 있으면 LocArgs(JSON)로 전달
		local argsJson = inst:GetAttribute("LocArgs")
		local args = nil
		if type(argsJson) == "string" and argsJson ~= "" then
			-- JSON → table (실패해도 무시)
			local success, decoded = pcall(function()
				return game:GetService("HttpService"):JSONDecode(argsJson)
			end)
			if success and type(decoded) == "table" then
				args = decoded
			end
		end
		ok, translated = pcall(function()
			if args then
				return translator:FormatByKey(key, args)
			else
				return translator:FormatByKey(key)
			end
		end)
	else
		-- 키가 없으면 원문 문자열로 조회
		ok, translated = pcall(function()
			return translator:Translate(game, sourceText)
		end)
	end

	if ok and type(translated) == "string" and translated ~= "" then
		-- 번역 루프 방지: 현재 설정한 번역이 다시 원문으로 오인되지 않도록 원문을 저장
		inst:SetAttribute("OrigText", sourceText)
		inst.Text = translated
	else
		-- 번역 실패 시: 원문 유지 (아무 것도 하지 않음)
	end
end

-- 텍스트 변경을 감지해 재번역(스크립트가 Text를 바꾸는 경우)
local function hookTextChanges(inst: TextLabel, translator)
	if not inst or not isTextObject(inst) then return end
	-- 이미 연결된 거 중복 방지용 토큰
	if inst:GetAttribute("_AutoTransHooked") then return end
	inst:SetAttribute("_AutoTransHooked", true)

	inst:GetPropertyChangedSignal("Text"):Connect(function()
		-- 외부에서 Text가 바뀐 경우만 재번역
		local lastSource = inst:GetAttribute("OrigText")
		local now = inst.Text or ""
		if lastSource ~= now then
			-- 새 원문으로 간주해서 다시 번역
			inst:SetAttribute("LocSource", now)
			applyTranslationFor(inst, translator)
		end
	end)
end

-- 컨테이너(예: PlayerGui, Workspace) 하위 전체 스캔 + 추가 감시
local function watchContainer(container: Instance, translator)
	if not container then return end

	-- 기존 것 처리
	for _, inst in ipairs(container:GetDescendants()) do
		if isTextObject(inst) then
			applyTranslationFor(inst, translator)
			hookTextChanges(inst, translator)
		end
	end

	-- 새로 생기는 것 처리
	container.DescendantAdded:Connect(function(inst)
		if isTextObject(inst) then
			-- 프레임 한 틱 뒤에 실행하면 Text/속성들이 먼저 세팅된 뒤 번역됨
			RunService.Heartbeat:Wait()
			applyTranslationFor(inst, translator)
			hookTextChanges(inst, translator)
		end
	end)
end

-- 메인: 플레이어별 번역기 준비 후 감시 시작
task.spawn(function()
	local translator
	-- 번역기 확보(네트워크/테이블 로드 지연 대비)
	while not translator do
		local ok, tr = pcall(function()
			return LocalizationService:GetTranslatorForPlayerAsync(LocalPlayer)
		end)
		if ok and tr then
			translator = tr
			break
		end
		task.wait(0.5)
	end

	-- PlayerGui (화면 UI) 감시
	watchContainer(PlayerGui, translator)

	-- Workspace (BillboardGui/SurfaceGui 같은 3D UI)도 감시
	watchContainer(workspace, translator)
end)
