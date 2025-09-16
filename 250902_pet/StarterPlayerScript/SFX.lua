--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local ContentProvider = game:GetService("ContentProvider")
local RemoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local WalkQuestEvent = RemoteFolder:WaitForChild("WalkQuestEvent")
local WangEvent    = RemoteFolder:WaitForChild("WangEvent")
local PetEvents  = ReplicatedStorage:WaitForChild("PetEvents")
local PetSfxEvent = PetEvents:WaitForChild("PetSfx")
local StreetFoodEvent   = RemoteFolder:WaitForChild("StreetFoodEvent")


-- (선택) 스팸 방지
local lastPlayAt: {[string]: number} = {}
local function canPlay(key: string, cooldown: number)
	local now = os.clock()
	if (lastPlayAt[key] or 0) + cooldown <= now then
		lastPlayAt[key] = now
		return true
	end
	return false
end

local function playFromTemplate(tpl: Sound)
	local s = tpl:Clone()
	s.Parent = SoundService   -- 2D UI 사운드
	s.PlayOnRemove = false

	pcall(function() ContentProvider:PreloadAsync({ s }) end)
	s:Play()

	local ttl = (s.TimeLength and s.TimeLength > 0) and (s.TimeLength + 1.5) or 5
	Debris:AddItem(s, ttl)
end



StreetFoodEvent.OnClientEvent:Connect(function(cmd: string, arg: any)
	if cmd == "PlaySfxTemplate" and typeof(arg) == "Instance" and arg:IsA("Sound") then
		playFromTemplate(arg)
	end
end)

PetSfxEvent.OnClientEvent:Connect(function(cmd: string, arg: any)
	if cmd == "PlaySfxTemplate" and typeof(arg) == "Instance" and arg:IsA("Sound") then
		playFromTemplate(arg)
	end
end)

WangEvent.OnClientEvent:Connect(function(cmd, tpl: any, tag: string?)
	if cmd == "PlaySfxTemplate" and typeof(tpl)=="Instance" and tpl:IsA("Sound") then
		-- 태그별 쿨다운 분리
		local key = (tpl.Name .. ":" .. (tag or "default"))
		local cd = (tag == "click") and 0.12 or 0.9
		if canPlay(key, cd) then
			local s = tpl:Clone(); s.Parent = SoundService; s:Play()
			Debris:AddItem(s, (s.TimeLength>0 and s.TimeLength+1.2) or 5)
		end
	end
end)

-- arg를 인스턴스(Sound)로 직접 받음
WalkQuestEvent.OnClientEvent:Connect(function(cmd: string, arg: any)
	if cmd == "PlaySfxTemplate" and typeof(arg) == "Instance" and arg:IsA("Sound") then
		if canPlay(arg.Name, 0.3) then
			playFromTemplate(arg)
		end
	end
end)
