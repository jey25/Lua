-- !strict
local Players = game:GetService("Players")
local BadgeManager = require(script.Parent:WaitForChild("BadgeManager"))
game:GetService("Players").PlayerAdded:Connect(function(plr)
    BadgeManager.OnPlayerReady(plr)
end)

