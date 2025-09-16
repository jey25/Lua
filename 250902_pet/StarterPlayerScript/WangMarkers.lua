--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarkerClient = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("MarkerClient"))

local RemoteFolder  = ReplicatedStorage:WaitForChild("RemoteEvents")
local WangEvent     = RemoteFolder:WaitForChild("WangEvent")

-- 서버에서 넘겨주는 명령:
--   ShowMarker { target = <Model|BasePart>, preset="touch", key="wang_touch" }
--   HideMarker { target = <Model|BasePart>, key="wang_touch" }

WangEvent.OnClientEvent:Connect(function(cmd: string, arg: any)
	if cmd == "ShowMarker" and typeof(arg) == "table" then
		local target = arg.target
		if typeof(target) == "Instance" then
			MarkerClient.show(target, {
				key = arg.key or "wang_touch",
				preset = arg.preset or "TouchIcon",  -- ReplicatedStorage/UI/Markers/TouchIcon
				image  = arg.image,                  -- or direct ImageId
				transparency = arg.transparency or 0.15,
				size   = arg.size,                   -- e.g. UDim2.fromOffset(72,72)
				pulse  = (arg.pulse ~= false),       -- 기본 펄스 on
				pulsePeriod = arg.pulsePeriod or 0.8,
				offsetY = arg.offsetY or 2.0,
				alwaysOnTop = (arg.alwaysOnTop ~= false),
			})
		end
	elseif cmd == "HideMarker" and typeof(arg) == "table" then
		local target = arg.target
		if typeof(target) == "Instance" then
			MarkerClient.hide(target, arg.key or "wang_touch")
		end
	end
end)

