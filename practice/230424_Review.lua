

local ball1 = game.ServerStorage:FindFirstChild("rollingStone1")
local ball2 = game.ServerStorage:FindFirstChild("rollingStone2")
local ball3 = game.ServerStorage:FindFirstChild("rollingStone3")
local balls = {ball1, ball2, ball3}
local destroyHeight = 20

while true do
	for i=1, 3 do	
		balls[i].Parent = workspace
		balls[i].Position = Vector3.new(-150, 80, 363)
		wait(1)
		balls[i].Parent = workspace
		balls[i].Position = Vector3.new(-170, 80, 363)
		wait(1)
		balls[i].Parent = workspace
		balls[i].Position = Vector3.new(-183, 80, 363)
		if balls[i].Position.Y <= destroyHeight then -- Y값이 파괴 높이 이하라면
			balls[i]:Destroy() -- Part를 파괴합니다.
		end
	end
end