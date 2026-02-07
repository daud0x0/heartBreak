-- OPERATION: NEON HEARTBREAK (Ver 6.2 - Crash Fix)
-- Made with Love2D

-- === CONFIG ===
local friendName = "LEGEND"
local bossName = "THE EX"
-- =================

function love.load()
    love.window.setTitle("Operation: Neon Heartbreak")
    love.window.setMode(800, 600)
    math.randomseed(os.time())

    -- PALETTE
    colors = {
        bg = {0.02, 0.02, 0.05}, 
        grid = {0.1, 0.0, 0.3, 0.3},
        sunTop = {0.8, 0.0, 0.5, 0.6},
        sunBot = {1.0, 0.2, 0.0, 0.1},
        player = {0, 1, 1}, 
        bullet = {0.8, 1, 1},
        shield = {0, 0.5, 1, 0.5},
        enemies = {
            normal = {1, 0, 0.3},
            ghost = {0.5, 0.5, 1.0},
            gaslight = {0.2, 1, 0.2},
            bomber = {1, 0.5, 0}
        },
        gold = {1, 0.9, 0.2},
        text = {1, 1, 1}
    }

    -- Fonts
    fontBig = love.graphics.newFont(40)
    fontMed = love.graphics.newFont(20)
    fontSmall = love.graphics.newFont(12)
    
    -- Audio
    sounds = {
        shoot = generateSound("shoot"),
        hit = generateSound("hit"),
        explode = generateSound("explode"),
        powerup = generateSound("powerup"),
        shield = generateSound("shield"),
        win = generateSound("win")
    }

    resetGame()
end

function resetGame()
    state = "menu"
    score = 0
    timer = 0
    timeToBoss = 45
    
    -- GRID SETTINGS
    gridOffset = 0
    gridSpacing = 40 
    
    player = { 
        x = 400, y = 500, w = 30, h = 30, speed = 450, 
        weaponLevel = 1, hp = 3, bombs = 2, 
        shieldTime = 0, invulnTimer = 0, engineTimer = 0 
    }

    bullets = {}
    enemies = {}
    particles = {}
    popups = {}
    
    spawnTimer = 0
    spawnRate = 0.8
    difficulty = 1

    boss = {
        active = false, x = 400, y = -150, w = 140, h = 120,
        hp = 200, maxHp = 200,
        quote = "", quoteTimer = 0, moveT = 0
    }
end

function love.update(dt)
    -- GRID FIX
    gridOffset = (gridOffset + dt * 60) % gridSpacing

    if state == "menu" or state == "gameover" or state == "win" then
        if love.keyboard.isDown("space") then
            resetGame()
            state = "playing"
        end
        return
    end

    -- === PLAYER ===
    if love.keyboard.isDown("left") and player.x > 0 then player.x = player.x - player.speed * dt end
    if love.keyboard.isDown("right") and player.x < 800 - player.w then player.x = player.x + player.speed * dt end
    
    player.engineTimer = player.engineTimer - dt
    if player.engineTimer <= 0 then
        spawnParticle(player.x + player.w/2, player.y + player.h, {0, 1, 1}, "engine")
        player.engineTimer = 0.05
    end

    if love.keyboard.isDown("space") then spawnBullet(dt) end
    if love.keyboard.isDown("lshift") and player.bombs > 0 then useBomb() end

    player.invulnTimer = player.invulnTimer - dt
    player.shieldTime = player.shieldTime - dt
    
    updateBullets(dt)
    updateParticles(dt)
    updatePopups(dt)

    -- === GAME LOOP ===
    if state == "playing" then
        timer = timer + dt
        difficulty = 1 + math.floor(timer/15)
        
        spawnTimer = spawnTimer - dt
        if spawnTimer <= 0 then
            spawnEnemy()
            spawnTimer = 1.0 - (difficulty * 0.08)
            if spawnTimer < 0.3 then spawnTimer = 0.3 end
        end

        if timer >= timeToBoss then
            state = "boss_warning"
            enemies = {} 
        end
        updateEnemies(dt)

    elseif state == "boss_warning" then
        boss.y = boss.y + 20 * dt
        if boss.y > 100 then
            boss.y = 100
            boss.active = true
            state = "boss_fight"
            spawnPopup(400, 300, "WARNING: " .. bossName, {1,0,0}, 3)
        end
    elseif state == "boss_fight" then
        updateBoss(dt)
        updateEnemies(dt)
    end
end

function love.draw()
    -- 1. BACKGROUND
    love.graphics.setBlendMode("alpha")
    drawBackground()

    -- 2. NEON OBJECTS (Additive)
    love.graphics.setBlendMode("add")

    if state == "menu" then
        drawNeonText("NEON HEARTBREAK", 400, 200, 50, {1, 0, 0.5})
        drawNeonText("PRESS SPACE", 400, 350, 20, {0, 1, 1})
        love.graphics.setColor(1,1,1,0.5)
        love.graphics.setFont(fontSmall)
        love.graphics.printf("ARROWS: Move  |  SPACE: Receipts (Fire)  |  SHIFT: Block (Bomb)", 0, 550, 800, "center")
        love.graphics.setBlendMode("alpha")
        return
    end

    -- Player
    if player.invulnTimer <= 0 or (love.timer.getTime()*15)%2 > 1 then
        love.graphics.setColor(colors.player)
        love.graphics.polygon("line", 
            player.x, player.y+player.h, 
            player.x+player.w/2, player.y, 
            player.x+player.w, player.y+player.h
        )
        if player.shieldTime > 0 then
            love.graphics.setColor(colors.shield)
            love.graphics.circle("line", player.x+player.w/2, player.y+player.h/2, 35)
            love.graphics.setColor(colors.shield[1], colors.shield[2], colors.shield[3], 0.2)
            love.graphics.circle("fill", player.x+player.w/2, player.y+player.h/2, 35)
        end
    end

    -- Bullets
    love.graphics.setColor(colors.bullet)
    for _, b in ipairs(bullets) do
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
    end

    -- Enemies
    for _, e in ipairs(enemies) do
        local c = colors.enemies.normal
        if e.behavior == "ghost" then c = colors.enemies.ghost 
        elseif e.behavior == "gaslight" then c = colors.enemies.gaslight
        elseif e.behavior == "bomber" then c = colors.enemies.bomber 
        elseif e.type == "gold" then c = colors.gold end

        local alpha = 1
        if e.behavior == "ghost" then alpha = e.alpha or 1 end -- Safety fallback
        
        love.graphics.setColor(c[1], c[2], c[3], alpha)
        
        local pulse = 1
        if e.behavior == "bomber" then pulse = 1 + math.sin(love.timer.getTime()*20)*0.2 end
        
        drawNeonHeart(e.x + e.w/2, e.y + e.h/2, (e.w/2)*pulse, c, alpha)
        
        if e.label and alpha > 0.5 then
            love.graphics.setBlendMode("alpha")
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.setFont(fontSmall)
            love.graphics.printf(e.label, e.x-20, e.y - 20, e.w+40, "center")
            love.graphics.setBlendMode("add")
        end
    end

    -- Boss
    if boss.active then
        local bx, by = boss.x + math.random(-1,1), boss.y
        drawNeonHeart(bx + boss.w/2, by + boss.h/2, boss.w/2, {1, 0, 0}, 1)
        
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(0.3, 0, 0)
        love.graphics.rectangle("fill", 200, 50, 400, 15)
        love.graphics.setColor(1, 0, 0.3)
        love.graphics.rectangle("fill", 200, 50, 400 * (boss.hp/boss.maxHp), 15)
        
        if boss.quote ~= "" then
            love.graphics.setColor(1,1,1)
            love.graphics.setFont(fontMed)
            love.graphics.printf(boss.quote, bx - 100, by + boss.h + 20, boss.w + 200, "center")
        end
        love.graphics.setBlendMode("add")
    end

    -- Particles
    for _, p in ipairs(particles) do
        love.graphics.setColor(p.c)
        love.graphics.circle("fill", p.x, p.y, p.size)
    end

    -- 3. UI
    love.graphics.setBlendMode("alpha")
    
    -- CRT Lines
    love.graphics.setColor(0, 0, 0, 0.2)
    for y = 0, 600, 3 do love.graphics.line(0, y, 800, y) end
    
    -- HUD
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fontMed)
    love.graphics.print("SCORE: " .. score, 10, 10)
    love.graphics.print("HP: " .. player.hp, 10, 35)
    love.graphics.print("BOMBS: " .. player.bombs, 10, 60)

    for _, p in ipairs(popups) do
        love.graphics.setColor(p.c[1], p.c[2], p.c[3], p.life)
        love.graphics.setFont(fontMed)
        love.graphics.print(p.text, p.x, p.y)
    end

    if state == "gameover" then
        love.graphics.setColor(0,0,0,0.85)
        love.graphics.rectangle("fill",0,0,800,600)
        drawNeonText("TOXICITY OVERLOAD", 400, 250, 40, {1, 0, 0})
        drawNeonText("SCORE: " .. score, 400, 320, 20, {1, 1, 1})
    elseif state == "win" then
        love.graphics.setColor(0,0,0,0.85)
        love.graphics.rectangle("fill",0,0,800,600)
        drawNeonText("HEALING COMPLETE", 400, 250, 35, {1, 1, 0})
        drawNeonText(friendName .. " IS THRIVING", 400, 320, 20, {1, 1, 1})
    end
end

-- --- VISUALS ---

function drawBackground()
    love.graphics.setColor(colors.bg)
    love.graphics.rectangle("fill", 0, 0, 800, 600)
    
    -- Sun
    for i=0, 100 do
        local t = i/100
        love.graphics.setColor(
            colors.sunTop[1]*(1-t) + colors.sunBot[1]*t,
            colors.sunTop[2]*(1-t) + colors.sunBot[2]*t,
            colors.sunTop[3]*(1-t) + colors.sunBot[3]*t,
            0.5
        )
        local sunY = 400 + i*2
        if (sunY % 15) > 5 then
             local width = math.sqrt(100*100 - (i-50)*(i-50)) * 2.5
             if width == width then
                love.graphics.rectangle("fill", 400 - width/2, sunY - 200, width, 2)
             end
        end
    end
    
    -- Grid (SMOOTH FIX)
    love.graphics.setColor(colors.grid)
    local horizon = 300
    for x = -800, 1600, 80 do 
        love.graphics.line(400 + (x-400)*0.2, horizon, x, 600) 
    end 
    
    for y = 0, 600, gridSpacing do 
        local py = (y + gridOffset) % 300 + horizon
        love.graphics.line(0, py, 800, py)
    end
end

function drawNeonText(text, x, y, size, color)
    local font = love.graphics.newFont(size)
    love.graphics.setFont(font)
    local w = font:getWidth(text)
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.print(text, x - w/2, y)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(color[1], color[2], color[3], 0.3)
    love.graphics.print(text, x - w/2 - 2, y)
    love.graphics.print(text, x - w/2 + 2, y)
    love.graphics.setBlendMode("alpha")
end

function drawNeonHeart(x, y, r, c, alpha)
    love.graphics.setColor(c[1], c[2], c[3], 0.2 * alpha) 
    drawHeartShape(x, y, r, "fill")
    love.graphics.setColor(c[1], c[2], c[3], 1.0 * alpha)
    love.graphics.setLineWidth(2)
    drawHeartShape(x, y, r, "line")
end

function drawHeartShape(x, y, r, mode)
    local vertices = {}
    for t = 0, math.pi * 2, 0.2 do
        local hx = 16 * math.pow(math.sin(t), 3)
        local hy = -(13 * math.cos(t) - 5 * math.cos(2*t) - 2 * math.cos(3*t) - math.cos(4*t))
        table.insert(vertices, x + hx * (r/20))
        table.insert(vertices, y + hy * (r/20))
    end
    if mode == "line" then love.graphics.polygon("line", vertices)
    else love.graphics.polygon("fill", vertices) end
end

-- --- LOGIC ---

function spawnBullet(dt)
    player.reload = (player.reload or 0) - dt
    if player.reload <= 0 then
        player.reload = (player.weaponLevel >= 2) and 0.1 or 0.2
        playSound(sounds.shoot)
        table.insert(bullets, {x = player.x + player.w/2 - 3, y = player.y, w=6, h=15})
        if player.weaponLevel >= 3 then 
             table.insert(bullets, {x = player.x, y = player.y, w=6, h=15, dx=-100})
             table.insert(bullets, {x = player.x + player.w, y = player.y, w=6, h=15, dx=100})
        end
    end
end

function updateBullets(dt)
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.y = b.y - 700 * dt
        if b.dx then b.x = b.x + b.dx * dt end
        local hit = false
        for j = #enemies, 1, -1 do
            local e = enemies[j]
            local canHit = (e.behavior ~= "ghost") or (e.alpha > 0.3)
            if canHit and checkCol(b, e) then
                e.hp = e.hp - 1
                hit = true
                spawnParticle(b.x, b.y, colors.bullet, "spark")
                if e.hp <= 0 then killEnemy(e, j) end
                break
            end
        end
        if not hit and boss.active and checkCol(b, boss) then
            damageBoss(1)
            hit = true
            spawnParticle(b.x, b.y, {1,0,0}, "spark")
        end
        if hit or b.y < -50 then table.remove(bullets, i) end
    end
end

function updateEnemies(dt)
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        
        -- Fix: Ensure timer exists
        e.timer = (e.timer or 0) + dt

        if e.behavior == "ghost" then
            e.y = e.y + e.speed * dt
            e.alpha = 0.2 + 0.8 * math.abs(math.sin(e.timer * 2))
        elseif e.behavior == "gaslight" then
            e.y = e.y + e.speed * dt
            e.x = e.x + math.sin(e.timer * 10) * 2
        elseif e.behavior == "bomber" then
            e.y = e.y + e.speed * dt
            local dir = (player.x - e.x)
            e.x = e.x + (dir * 2 * dt)
        else 
            e.y = e.y + e.speed * dt
        end

        local canHitPlayer = (player.invulnTimer <= 0) and (player.shieldTime <= 0)
        
        if canHitPlayer and checkCol(player, e) then
            player.hp = player.hp - 1
            player.invulnTimer = 2
            player.weaponLevel = 1
            spawnExplosion(player.x, player.y, colors.player)
            playSound(sounds.explode)
            table.remove(enemies, i)
            if player.hp <= 0 then state = "gameover" end
        elseif player.shieldTime > 0 and checkCol(player, e) then
            killEnemy(e, i)
            playSound(sounds.shield)
        elseif e.y > 650 then
            table.remove(enemies, i)
        end
    end
end

function spawnEnemy()
    local type = "normal"
    local behavior = "normal"
    local hp = 1
    local speed = 150 + (difficulty * 10)
    local w = 35
    local label = nil
    
    local roll = math.random()
    if roll > 0.95 then 
        type = "gold"
        if math.random() > 0.5 then label = "BOUNDARIES" else label = "RECEIPTS" end
    elseif roll > 0.85 then 
        behavior = "ghost"
        label = "GHOST"
        speed = 100
    elseif roll > 0.75 then 
        behavior = "gaslight"
        label = "TOXIC"
        speed = 200
    elseif roll > 0.65 then 
        behavior = "bomber"
        label = "CLINGY"
        speed = 250
        hp = 2
    else
        local flags = {"LAZY", "BORING", "CHEATER", "LIAR"}
        label = flags[math.random(#flags)]
    end

    table.insert(enemies, {
        x = math.random(20, 750), y = -50, w = w, h = w, 
        type = type, behavior = behavior, speed = speed, hp = hp, label = label,
        timer = math.random(0,10), alpha = 1
    })
end

function killEnemy(e, i)
    table.remove(enemies, i)
    spawnExplosion(e.x, e.y, (e.type=="gold" and colors.gold or colors.enemies[e.behavior] or colors.enemies.normal))
    playSound(sounds.hit)
    
    if e.type == "gold" then
        if e.label == "BOUNDARIES" then
            player.shieldTime = 10 
            spawnPopup(e.x, e.y, "SHIELD UP", colors.shield)
        else
            player.weaponLevel = 3
            spawnPopup(e.x, e.y, "RAPID FIRE", colors.gold)
        end
        score = score + 200
        playSound(sounds.powerup)
    else
        score = score + 50
    end
end

function updateBoss(dt)
    boss.moveT = boss.moveT + dt
    boss.x = 400 + math.sin(boss.moveT) * 250
    boss.quoteTimer = boss.quoteTimer - dt
    if boss.quoteTimer < 0 then boss.quote = "" end
    
    if math.random() < 0.04 then 
        -- THE FIX: Added timer=0 to the boss projectile
        table.insert(enemies, {
            x=boss.x+boss.w/2, y=boss.y+boss.h, w=25, h=25, 
            hp=1, speed=350, type="bullet", behavior="gaslight",
            timer=0, alpha=1
        })
    end
end

function damageBoss(amt)
    boss.hp = boss.hp - amt
    if math.random() > 0.8 then
        local qs = {"I changed!", "Unblock me!", "Just one coffee?", "You're crazy", "So dramatic"}
        boss.quote = qs[math.random(#qs)]
        boss.quoteTimer = 1
    end
    if boss.hp <= 0 then
        state = "win"
        playSound(sounds.win)
    end
end

function useBomb()
    player.bombs = player.bombs - 1
    player.invulnTimer = 2
    playSound(sounds.explode)
    spawnExplosion(400, 300, {1,1,1}) 
    enemies = {} 
    if boss.active then damageBoss(30) end
    spawnPopup(player.x, player.y - 50, "BLOCKED ALL!", {0, 1, 1}, 2)
end

-- --- HELPERS ---
function spawnParticle(x, y, c, type)
    local size = (type=="engine") and math.random(2,4) or math.random(3,6)
    local life = (type=="engine") and 0.2 or 0.6
    local vy = (type=="engine") and 100 or math.random(-100, 100)
    table.insert(particles, {x=x, y=y, vx=math.random(-50,50), vy=vy, life=life, size=size, c=c})
end

function spawnExplosion(x, y, c) for i=1, 15 do spawnParticle(x, y, c, "spark") end end

function updateParticles(dt)
    for i = #particles, 1, -1 do
        particles[i].x = particles[i].x + particles[i].vx * dt
        particles[i].y = particles[i].y + particles[i].vy * dt
        particles[i].life = particles[i].life - dt
        if particles[i].life <= 0 then table.remove(particles, i) end
    end
end

function spawnPopup(x, y, text, c, life) table.insert(popups, {x=x, y=y, text=text, c=c, life=life or 1}) end

function updatePopups(dt)
    for i=#popups, 1, -1 do
        popups[i].y = popups[i].y - 30 * dt
        popups[i].life = popups[i].life - dt
        if popups[i].life <= 0 then table.remove(popups, i) end
    end
end

function checkCol(a, b) return a.x < b.x+b.w and a.x+a.w > b.x and a.y < b.y+b.h and a.y+a.h > b.y end

-- --- SOUNDS ---
function playSound(s) s:clone():play() end
function generateSound(type)
    local rate = 44100; local len = 0.1; local data
    if type == "shoot" then len=0.1; data=love.sound.newSoundData(len*rate, rate, 16, 1)
        for i=0,len*rate-1 do data:setSample(i, math.random()*(1-i/(len*rate))*0.2) end
    elseif type == "explode" then len=0.4; data=love.sound.newSoundData(len*rate, rate, 16, 1)
        for i=0,len*rate-1 do data:setSample(i, (math.random()*2-1)*(1-i/(len*rate))*0.5) end
    elseif type == "shield" then len=0.5; data=love.sound.newSoundData(len*rate, rate, 16, 1)
        for i=0,len*rate-1 do local t=i/rate; data:setSample(i, math.sin(t*200*math.pi)*0.3) end
    elseif type == "win" then len=1.5; data=love.sound.newSoundData(len*rate, rate, 16, 1)
        for i=0,len*rate-1 do local t=i/rate; data:setSample(i, math.sin(t*(400+t*200)*math.pi)*0.3) end
    else len=0.1; data=love.sound.newSoundData(len*rate, rate, 16, 1)
        for i=0,len*rate-1 do data:setSample(i, math.sin(i/10)*0.2) end
    end
    return love.audio.newSource(data, "static")
end
