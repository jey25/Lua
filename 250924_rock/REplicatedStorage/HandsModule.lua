-- HandsClientState (ModuleScript)
local M = { byUser = {} }

function M.Set(userId, data)  -- {theme=string, images={paper=...,rock=...,scissors=...}}
	M.byUser[userId] = data
end

function M.Get(userId)
	return M.byUser[userId]
end

return M

