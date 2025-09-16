--!strict
local RunService = game:GetService("RunService")

-- ⬇ 본인/QA UserId만 넣으세요
local WHITELIST: {[number]: boolean} = {
	[3857750238] = true, -- 예: sgq
}

local ENABLED = true

local DevGate = {}

function DevGate.isDev(plr: Player): boolean
	if not ENABLED then return false end
	if RunService:IsStudio() then return true end
	return WHITELIST[plr.UserId] == true
end

function DevGate.setEnabled(v: boolean) ENABLED = v and true or false end

return DevGate





