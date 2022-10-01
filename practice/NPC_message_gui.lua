
-- #1

local dialogue = game.ReplicatedStorage.Yellooo
local Yellow = Enum.ThumbnailType.HeadShot
local size = Enum.ThumbnailSize.Size180x180

function Yeelottt(player, id)
 dialogue:FireAllClients(player, id)
end
wait(1)
local players = game.Players:GetChildren()
local player = players[math.random(1, #players)]
local id = game.Players:GetUserThumbnailAsync(player.UserId, Yellow, size)
Yeelottt(player, id)


-- #2

local dialogue = game.ReplicatedStorage.Yellooo
local thumbnail = script.Parent.Thumbnail
local text = script.Parent.TextLabel

local message11 = "안녕하세요"
local message22 = "옐롯티비 아시나요?"
local message33 = "모르시나 봐요.."
local message44 = "구독할때까지 쫒아 갈꺼예요!!"
local message55 = "꺅!!!!!!!!"
local message66 = "도망쳐"

function message(message11)
 for i = 1, #message11 do
  text.Text = string.sub(message11, 1, i)
  wait()
 end
end

function message2(message22)
 for i = 1, #message22 do
  text.Text = string.sub(message22, 1, i)
  wait()
 end
end

function message3(message33)
 for i = 1, #message33 do
  text.Text = string.sub(message33, 1, i)
  wait()
 end
end

function message4(message44)
 for i = 1, #message44 do
  text.Text = string.sub(message44, 1, i)
  wait()
 end
end

function message5(message55)
 for i = 1, #message55 do
  text.Text = string.sub(message55, 1, i)
  wait()
 end
end

function message6(message66)
 for i = 1, #message66 do
  text.Text = string.sub(message66, 1, i)
  wait()
 end
end

dialogue.OnClientEvent:Connect(function(plr, id)
 wait(5)
 script.Parent.Visible = true
 
 thumbnail.Image = id
 message(message11)
 wait(2)
 
 message2(message22)
 wait(2)
 
 message3(message33)
 wait(2)
 
 thumbnail.Image = id
 message4(message44)
 wait(2)
 
 thumbnail.Image = id
 message5(message55)
 wait(2)
 
 thumbnail.Image = id
 message6(message66)
 wait(2)

 script.Parent.Visible = false
end)
