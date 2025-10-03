--!strict
-- ReplicatedStorage/Modules/BadgeClient.lua
local BadgeClient = {}

local _tags: {string} = {}
local listeners: {RBXScriptSignal} = {}
local Event = Instance.new("BindableEvent")
BadgeClient.Changed = Event.Event -- 다른 스크립트가 .Changed:Connect(...) 로 구독 가능

function BadgeClient._setTags(tags: {string})
	_tags = {}
	for _, t in ipairs(tags or {}) do
		if typeof(t) == "string" then
			table.insert(_tags, t)
		end
	end
	Event:Fire(BadgeClient.GetAll())
end

function BadgeClient.HasUnlock(tag: string): boolean
	for _, t in ipairs(_tags) do
		if t == tag then return true end
	end
	return false
end

function BadgeClient.GetAll(): {string}
	local copy = table.clone(_tags)
	return copy
end

return BadgeClient

