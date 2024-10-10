message = 0

for i=1, 3, 1 do
    message = message + 10
end

function love.draw()
    love.graphics.setFont(love.graphics.newFont(60))
    love.graphics.print(message)
end
