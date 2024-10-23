
function love.load( ... )
    love.window.setMode(1000, 768)

    wf = require("libraries/windfield") 
    world = wf.newWorld(0, 800, false)

    anim8 = require("libraries/anim8/anim8")
    sti = require("libraries/Simple-Tiled-Implementation-master/sti")

    -- 카메라 코드
    cameraFile = require("hump/camera") 
    cam = cameraFile()

    -- 캐릭터 이미지 불러오기 및 Animation 세팅
    sprites = {}
    sprites.playerSheet = love.graphics.newImage('sprites/playerSheet.png')
    sprites.enemySheet = love.graphics.newImage('sprites/enemySheet.png')

    -- 전체 이미지를 한장의 Grid 로 나누어 저장
    local grid = anim8.newGrid(614, 564, sprites.playerSheet:getWidth(), sprites.playerSheet:getHeight())
    local enemyGird = anim8.newGrid(100, 79, sprites.enemySheet:getWidth(), sprites.enemySheet:getHeight())

    animations = {}
    animations.idle = anim8.newAnimation(grid('1-15', 1), 0.05)
    animations.jump = anim8.newAnimation(grid('1-7', 2), 0.05)
    animations.run = anim8.newAnimation(grid('1-15', 3), 0.05)
    animations.enemy = anim8.newAnimation(enemyGird('1-2', 1), 0.03)

    world:setQueryDebugDrawing(true)
    world:addCollisionClass('platform')
    world:addCollisionClass('Player' --[[, {ignores = {'Platform'}}]])
    world:addCollisionClass('Danger')

    -- 동일 경로에 위치한 player.lua 파일을 require
    require('player')
    require('enemy')

    dangerZone = world:newRectangleCollider(0, 550, 800, 50, {collision_class = 'Danger'})
    dangerZone:setType('static')

    platforms = {}

    flagX = 0
    flagY = 0

    currentLevel  = "level1"

    loadMap(currentLevel)

end

function love.update(dt)
    world:update(dt)
    gameMap:update(dt)
    PlayerUpdate(dt)
    updateEnemies(dt)

    local px, py = player:getPosition()
    cam:lookAt(px, love.graphics.getHeight()/2)

    local colliders = world:queryCircleArea(flagX, flagY, 10, {'Player'})
    if #colliders > 0 then
        if currentLevel == "level1" then
            loadMap("level2")
        elseif currentLevel == "level2" then
            loadMap("level1")
        end
    end

end

function love.draw()
    cam:attach()
        gameMap:drawLayer(gameMap.layers["Tile Layer 1"])
        world:draw()
        DrawPlayer()
        drawEnemies()
    cam:detach()
end

function love.keypressed( key )
    if key == 'up' then
        if player.grounded then
            player:applyLinearImpulse(0, -4000)
        end
    end

    if key == 'r' then
        loadMap("level2")
    end

end

function love.mousepressed( x, y, button )
    if button == 1 then
        local colliders = world:queryCircleArea(x, y, 200, {'platform', 'Danger'})
        for i,c in ipairs(colliders) do
            c:destroy()
        end
    end
end

function spawnPlatform(x, y, width, height)
    if width > 0 and height > 0 then
        local platform = world:newRectangleCollider(x, y, width, height, {collision_class = 'platform'})
        platform:setType('static')
        table.insert( platforms, platform)
    end
end

function destroyAll()

    local i = #platforms

    while i > -1 do
        if platforms[i] ~= nil then
            platforms[i]:destroy()
        end
        table.remove( platforms, i )
        i = i - 1
    end

    local i = #enemies

    while i > -1 do
        if enemies[i] ~= nil then
            enemies[i]:destroy()
        end
        table.remove(enemies, i)
        i = i - 1
    end
end

function loadMap(mapName)
    currentLevel = mapName
    destroyAll()
    player:setPosition(360, 100)
    gameMap = sti("maps/" .. mapName .. ".lua")
    
    for i, obj in pairs(gameMap.layers["platforms"].objects) do
        spawnPlatform(obj.x, obj.y, obj.width, obj.height)
    end

    for i, obj in pairs(gameMap.layers["enemies"].objects) do
        spawnEnemy(obj.x, obj.y)
    end

    for i, obj in pairs(gameMap.layers["flag"].objects) do
        flagX = obj.x
        flagY = obj.y
    end

end