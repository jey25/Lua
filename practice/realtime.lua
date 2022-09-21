
-- 스크립트1:
local Label = script.Parent

while wait() do
	local AmorPm = os.date("%p")
	local Time = os.date("%X")
	
	if AmorPm == "AM" then
		AmorPm = "오전 "
	else
		AmorPm = "오후 "
	end
	
	Label.Text = AmorPm..Time
end

-- 스크립트2:
local Label = script.Parent

while wait() do
	local Hour = os.date("*t") ["hour"]
	local Minute = os.date("*t") ["min"]
	
	if Minute < 10 then
		Minute = "0"..Minute
	end
	
	Label.Text = Hour..":"..Minute
end

-- 스크립트3:
local Label = script.Parent

while wait() do
	local AmorPm = os.date("%p")
	local Hour = os.date("%I:")
	local Minute = os.date("%M:")
	local Second = os.date("%S")

	if AmorPm == "AM" then
		AmorPm = "오전 "
	else
		AmorPm = "오후 "
	end

	Label.Text = AmorPm..Hour..Minute..Second
end

-- 스크립트4:
local Label = script.Parent

while wait() do
	local Hour = os.date("!*t") ["hour"]
	local Minute = os.date("!*t") ["min"]
	local Second = os.date("!*t") ["sec"]
	
	if Minute < 10 then
		Minute = "0"..Minute
	end
	
	if Second < 10 then
		Second = "0"..Second
	end
	
	Label.Text = Hour..":"..Minute..":"..Second
end

-- 스크립트5:
local Label = script.Parent

while wait() do
	local Hour = os.date("*t") ["hour"]
	local Minute = os.date("*t") ["min"]
	local Second = os.date("*t") ["sec"]
	
	if Minute < 10 then
		Minute = "0"..Minute
	end

	if Second < 10 then
		Second = "0"..Second
	end
	
	local GameTime = 10
	
	if (Hour + GameTime) > 24 then
		GameTime = (Hour + GameTime) - 24
	else
		GameTime = Hour
	end
	
	Label.Text = GameTime..":"..Minute..":"..Second
end



-- 밤낮의 변화 적용

while true do
  game.Lighting.ClockTime = game.Lighting.ClockTime + 0.01
  wait()
 end