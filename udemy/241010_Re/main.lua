message = 5
message2 = 10
output = message + message2

function love.draw()
    love.graphics.setFont(love.graphics.newFont(60))
    love.graphics.print(output)
    love.graphics.print(type(output))
end
