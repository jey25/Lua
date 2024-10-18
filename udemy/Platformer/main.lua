
function love.load( ... )
    love.window.setMode(1000, 768)

    wf = require("libraries/windfield") 
    world = wf.newWorld(0, 800, false)

    anim8 = require("libraries/anim8/anim8") 
    sti = require("libraries/Simple-Tiled-Implementation-master/sti")

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

    -- 동일 경로에 위치한 player.lua 파일을 require
    require('player')

    dangerZone = world:newRectangleCollider(0, 550, 800, 50, {collision_class = 'Danger'})
    dangerZone:setType('static')

    Platforms = {}

    loadMap()

end

function love.update(dt)
    world:update(dt)
    gameMap:update(dt)
    PlayerUpdate(dt)
end

function love.draw()
    gameMap:drawLayer(gameMap.layers["Tile Layer 1"])
    -- world:draw()
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

function spawnPlatform(x, y, width, height)
    if width > 0 and height > 0 then
        local platform = world:newRectangleCollider(x, y, width, height, {collision_class = 'Platform'})
        platform:setType('static')
        table.insert( Platforms, platform)
    end
end

function loadMap()
    gameMap = sti("maps/level1.lua")
    for i, obj in pairs(gameMap.layers["Platforms"].objects) do
        spawnPlatform(obj.x, obj.y, obj.width, obj.height)
    end

end