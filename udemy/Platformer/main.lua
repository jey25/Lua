
function love.load( ... )
    love.window.setMode(1000, 768)

    wf = require("libraries/windfield") 
    anim8 = require("libraries/anim8/anim8") 
    sti = require("libraries/Simple-Tiled-Implementation-master/sti")
    world = wf.newWorld(0, 800, false)

    -- 캐릭터 이미지 불러오기 및 Animation 세팅
    sprites = {}
    sprites.playerSheet = love.graphics.newImage('sprites/playerSheet.png')

    -- 전체 이미지를 한장의 Grid 로 나누어 저장
    local grid = anim8.newGrid(614, 564, sprites.playerSheet:getWidth(), sprites.playerSheet:getHeight())

    animations = {}
    animations.idle = anim8.newAnimation(grid('1-15', 1), 0.05)
    animations.jump = anim8.newAnimation(grid('1-7', 2), 0.05)
    animations.run = anim8.newAnimation(grid('1-15', 3), 0.05)


    world:setQueryDebugDrawing(true)
    world:addCollisionClass('Platform')
    world:addCollisionClass('Player' --[[, {ignores = {'Platform'}}]])
    world:addCollisionClass('Danger')

    require('player')

    platform = world:newRectangleCollider(250, 400, 300, 100, {collision_class = 'Platform'})
    platform:setType('static')

    dangerZone = world:newRectangleCollider(0, 550, 800, 50, {collision_class = 'Danger'})
    dangerZone:setType('static')

end


function love.update(dt)
    world:update(dt)
    gameMap:update(dt)
    PlayerUpdate(dt)
end


function love.draw()
    world:draw()
    gameMap:drawLayer()
    DrawPlayer()
end

function love.keypressed( key )
    if key == 'up' then
        if player.grounded then
            player:applyLinearImpulse(0, -4000)
        end
    end
end

function love.mousepressed( x, y, button )
    if button == 1 then
        local colliders = world:queryCircleArea(x, y, 200, {'Platform', 'Danger'})
        for i,c in ipairs(colliders) do
            c:destroy()
        end
    end
end

function loadMap( ... )
    gameMap = sti("maps/level1.lua")
end