
function love.load( ... )
    wf = require("libraries/windfield") 
    world = wf.newWorld(0, 800)

    world:addCollisionClass('platform')
    world:addCollisionClass('player', {ignores = 'platform'})

    player = world:newRectangleCollider(360, 100, 80, 80, {collision_class = 'player'})
    player.speed = 200

    platform = world:newRectangleCollider(250, 400, 300, 100, {collision_class = 'platform'})
    platform:setType('static')
end


function love.update(dt)
    world:update(dt)

    local px, py = player:getPosition()
    if love.keyboard.isDown('right') then
        player:setX(px + player.speed* dt)
    end
    if love.keyboard.isDown('left') then
        player:setX(px - player.speed* dt)
    end
end


function love.draw( ... )
    world:draw()
end

function love.keypressed( key )
    if key == 'up' then
        player:applyLinearImpulse(0, -7000)
    end
end