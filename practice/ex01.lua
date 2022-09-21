
-- 체력 감소 스크립트

local Debounce = false

script.Parent.Touched:connect(function(hit)
 if hit.Parent:FindFirstChild("Humanoid")and Debounce == false then
  Debounce = true
  hit.Parent.Humanoid:TakeDamage(10)
  wait(0)
  Debounce = false
 end
end)