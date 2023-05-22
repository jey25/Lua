
--캐릭터가 특정 part 에 도달했을 때 SpawnLocation 을 옮겨준다
local part = script.Parent

part.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChild("Humanoid")
	if humanoid then
		workspace.SpawnLocation.Position = Vector3.new(-16, 6.5, 18.5)
	end
end)

