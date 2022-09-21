
-- 서버 추가 스크립트
local zombie = game.Lighting.Zombie:Clone()

game.ReplicatedStorage.Timerr.OnServerEvent:Connect(function()
 zombie.Parent = game.Workspace
 wait(10)
 zombie:Remove()
end)



-- 카운트 다운 스크립트

game.ReplicatedStorage.Timerr.OnServerEvent:Connect(function()
 script.Parent.Visible = true
 local time = 10
 for i = 1, 10 do
  wait(1) 
  time = time - 1 
  script.Parent.Text = tostring(time) 
 end
 if script.Parent.Text == "0" then
  script.Parent:Destroy()
 end
end)



-- 메시지 스크립트
 game.ReplicatedStorage.Timerr:FireServer()
 wait(10)
 
 script.Parent.Visible = true