message = 0

if message < 10 then
    message = message + 5
end


function love.draw()
    love.graphics.setFont(love.graphics.newFont(60))
    love.graphics.print(message)
end