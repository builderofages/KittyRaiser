local function getOrMake(parent, className, name)
    local existing = parent:FindFirstChild(name)
    if existing and existing.ClassName == className then return existing end
    if existing then existing:Destroy() end
    local obj = Instance.new(className)
    obj.Name = name
    obj.Parent = parent
    return obj
end
local modulesFolder = getOrMake(game.ReplicatedStorage, 'Folder', 'Modules')
do
    local s = getOrMake(game.ServerScriptService, 'Script', 'WeatherSystem')
    s.Source = [[
-- WeatherSystem.server.lua
-- Cycles Sunny / Rainy / Foggy / RedMist. Broadcasts state, applies bonuses.
-- Place in: ServerScriptService > WeatherSystem (Script)

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local function waitFor(g) while not _G[g] do task.wait() end return _G[g] end
local DataHandler = waitFor("KittyRaiserData")

local CurrentWeather = "Sunny"
local CurrentMultBonus = 1.0

local function pickWeather()
    local roll = math.random()
    local cum = 0
    for k, w in pairs(GameConfig.WEATHER_WEIGHTS) do
        cum = cum + w
        if roll <= cum then return k end
    end
    return "Sunny"
end

local function applyVisuals(weather)
    if weather == "Sunny" then
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1000
        Lighting.FogStart = 200
        Lighting.FogColor = Color3.fromRGB(180, 180, 200)
    elseif weather == "Rainy" then
        Lighting.ClockTime = 13
        Lighting.FogEnd = 400
        Lighting.FogStart = 50
        Lighting.FogColor = Color3.fromRGB(100, 100, 130)
    elseif weather == "Foggy" then
        Lighting.ClockTime = 18
        Lighting.FogEnd = 200
        Lighting.FogStart = 20
        Lighting.FogColor = Color3.fromRGB(220, 220, 220)
    elseif weather == "RedMist" then
        Lighting.ClockTime = 22
        Lighting.FogEnd = 250
        Lighting.FogStart = 30
        Lighting.FogColor = Color3.fromRGB(180, 0, 0)
    end
end

function _G.KittyRaiserGetWeatherMult()
    return CurrentMultBonus
end

local function setWeather(weather)
    CurrentWeather = weather
    CurrentMultBonus = (weather == "RedMist") and GameConfig.RED_MIST_CHAOS_MULT or 1.0
    applyVisuals(weather)
    Remotes.WeatherChanged:FireAllClients(weather)
    Remotes.EventBroadcast:FireAllClients(
        weather == "RedMist" and "RED MIST! 2x Chaos for "..GameConfig.RED_MIST_DURATION_MIN.." min!"
        or weather:upper(),
        weather
    )
end

task.spawn(function()
    while true do
        local weather = pickWeather()
        setWeather(weather)
        local dur = (weather == "RedMist") and GameConfig.RED_MIST_DURATION_MIN or GameConfig.WEATHER_CYCLE_MIN
        task.wait(dur * 60)
    end
end)

return true

]]
end

do
    local s = getOrMake(game.ServerScriptService, 'Script', 'DailyRewardSystem')
    s.Source = [[
-- DailyRewardSystem.server.lua
-- Daily login reward with 7-day streak cycle.
-- Place in: ServerScriptService > DailyRewardSystem (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local function waitFor(g) while not _G[g] do task.wait() end return _G[g] end
local DataHandler = waitFor("KittyRaiserData")

local DAY_SECONDS = 86400

-- 7-day streak rewards
local REWARDS = {
    [1] = {chaos = 500, hellTokens = 0, msg = "Day 1: 500 Chaos"},
    [2] = {chaos = 1500, hellTokens = 0, msg = "Day 2: 1.5K Chaos"},
    [3] = {chaos = 3000, hellTokens = 1, msg = "Day 3: 3K Chaos + 1 Hell Token"},
    [4] = {chaos = 5000, hellTokens = 0, msg = "Day 4: 5K Chaos"},
    [5] = {chaos = 7500, hellTokens = 2, msg = "Day 5: 7.5K Chaos + 2 Hell Tokens"},
    [6] = {chaos = 10000, hellTokens = 0, msg = "Day 6: 10K Chaos"},
    [7] = {chaos = 25000, hellTokens = 5, msg = "Day 7: 25K Chaos + 5 Hell Tokens! 🎉"},
}

local function isAvailable(data)
    if not data.lastDailyClaim then return true end
    return (os.time() - data.lastDailyClaim) >= DAY_SECONDS
end

local function streakBroken(data)
    if not data.lastDailyClaim then return true end
    return (os.time() - data.lastDailyClaim) >= (DAY_SECONDS * 2)
end

Remotes.RequestClaimDaily.OnServerInvoke = function(player)
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end
    if not isAvailable(data) then
        local nextAt = (data.lastDailyClaim or 0) + DAY_SECONDS
        return false, "wait", nextAt - os.time()
    end
    local newStreak
    if streakBroken(data) then newStreak = 1
    else newStreak = ((data.dailyStreak or 0) % 7) + 1 end
    local reward = REWARDS[newStreak]
    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) + reward.chaos
        d.hellTokens = (d.hellTokens or 0) + reward.hellTokens
        d.dailyStreak = newStreak
        d.lastDailyClaim = os.time()
    end)
    Remotes.NotifyClient:FireClient(player, reward.msg, "success")
    return true, newStreak
end

Players.PlayerAdded:Connect(function(player)
    task.wait(3)
    local data = DataHandler.getData(player)
    if data and isAvailable(data) then
        local nextStreak
        if streakBroken(data) then nextStreak = 1
        else nextStreak = ((data.dailyStreak or 0) % 7) + 1 end
        Remotes.DailyAvailable:FireClient(player, nextStreak, REWARDS[nextStreak])
    end
end)

return true

]]
end

do
    local s = getOrMake(game.ServerScriptService, 'Script', 'EmoteSystem')
    s.Source = [[
-- EmoteSystem.server.lua
-- Broadcasts emote requests to nearby players.
-- Place in: ServerScriptService > EmoteSystem (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local EMOTE_COOLDOWN = 1.5
local lastUse = {}

Remotes.RequestEmote.OnServerEvent:Connect(function(player, emoteName)
    if not table.find(GameConfig.EMOTES, emoteName) then return end
    local now = os.clock()
    if lastUse[player.UserId] and (now - lastUse[player.UserId]) < EMOTE_COOLDOWN then return end
    lastUse[player.UserId] = now
    local char = player.Character
    if not char or not char.PrimaryPart then return end
    local origin = char.PrimaryPart.Position
    -- Broadcast to nearby players (within 80 studs) for FX
    for _, p in ipairs(Players:GetPlayers()) do
        local pchar = p.Character
        if pchar and pchar.PrimaryPart and (pchar.PrimaryPart.Position - origin).Magnitude < 80 then
            Remotes.EmoteBroadcast:FireClient(p, player.UserId, emoteName)
        end
    end
end)

Players.PlayerRemoving:Connect(function(p) lastUse[p.UserId] = nil end)

return true

]]
end

do
    local s = getOrMake(game.ServerScriptService, 'Script', 'AdminSystem')
    s.Source = [[
-- AdminSystem.server.lua
-- Admin-only chat commands and remote calls. Edit ADMIN_USERIDS below.
-- Place in: ServerScriptService > AdminSystem (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local function waitFor(g) while not _G[g] do task.wait() end return _G[g] end
local DataHandler = waitFor("KittyRaiserData")

-- TODO: replace with real admin UserIds (yours + trusted staff)
local ADMIN_USERIDS = {
    -- 12345678,
}

local function isAdmin(player)
    return table.find(ADMIN_USERIDS, player.UserId) ~= nil or player:GetAttribute("AdminOverride") == true
end

local Commands = {}

Commands.chaos = function(player, amount)
    amount = tonumber(amount) or 0
    DataHandler.modify(player, function(d) d.chaosPoints = (d.chaosPoints or 0) + amount end)
    return "chaos +" .. amount
end

Commands.helltokens = function(player, amount)
    amount = tonumber(amount) or 0
    DataHandler.modify(player, function(d) d.hellTokens = (d.hellTokens or 0) + amount end)
    return "hellTokens +" .. amount
end

Commands.level = function(player, amount)
    amount = tonumber(amount) or 1
    DataHandler.modify(player, function(d) d.level = math.clamp(amount, 1, 100); d.xp = 0 end)
    return "level set to " .. amount
end

Commands.skin = function(player, skinId)
    DataHandler.modify(player, function(d)
        if not table.find(d.ownedSkins, skinId) then table.insert(d.ownedSkins, skinId) end
        d.equippedSkin = skinId
    end)
    return "skin set " .. tostring(skinId)
end

Commands.reset = function(player)
    DataHandler.modify(player, function(d)
        d.chaosPoints = 0
        d.level = 1
        d.xp = 0
        d.rebirths = 0
        d.perks = {}
        d.unspentStatPoints = 0
        d.stats = {Speed=0,Jump=0,Luck=0,Strength=0,Agility=0}
    end)
    return "reset"
end

Commands.kick = function(player, targetName, reason)
    local target = Players:FindFirstChild(targetName)
    if target then target:Kick(reason or "Admin kick"); return "kicked "..targetName end
    return "not found"
end

local function processChatCommand(player, msg)
    if not msg or msg:sub(1,1) ~= "/" then return end
    if not isAdmin(player) then return end
    local parts = msg:sub(2):split(" ")
    local cmd = parts[1]
    local args = {}
    for i = 2, #parts do args[i-1] = parts[i] end
    local fn = Commands[cmd]
    if fn then
        local ok, result = pcall(fn, player, table.unpack(args))
        if ok then
            Remotes.NotifyClient:FireClient(player, "admin: "..tostring(result), "success")
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(msg)
        processChatCommand(player, msg)
    end)
end)

-- Allow Studio testing without admin list (auto-admin in Studio)
local RunService = game:GetService("RunService")
if RunService:IsStudio() then
    Players.PlayerAdded:Connect(function(player)
        player:SetAttribute("AdminOverride", true)
        print("[AdminSystem] Studio auto-admin granted to", player.Name)
    end)
end

Remotes.RequestAdminCommand.OnServerInvoke = function(player, cmd, ...)
    if not isAdmin(player) then return false, "not_admin" end
    local fn = Commands[cmd]
    if not fn then return false, "unknown_cmd" end
    local args = {...}
    local ok, result = pcall(fn, player, table.unpack(args))
    return ok, result
end

return true

]]
end

do
    local s = getOrMake(game.ServerScriptService, 'Script', 'MapBuilder')
    s.Source = [[
-- MapBuilder.server.lua
-- Programmatically builds Cat Alley (200x200 stud zone) on server start.
-- Place in: ServerScriptService > MapBuilder (Script)
-- Run once per server boot, idempotent (skips if map already built).

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local MAP_NAME = "CatAlley"
local MAP_SIZE = 200
local FLOOR_THICKNESS = 4

local function part(props)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = props.CanCollide ~= false
    for k, v in pairs(props) do
        if k ~= "CanCollide" and k ~= "Children" then
            p[k] = v
        end
    end
    if props.Children then
        for _, c in ipairs(props.Children) do c.Parent = p end
    end
    return p
end

local function buildLighting()
    Lighting.Ambient = Color3.fromRGB(60, 30, 80)
    Lighting.Brightness = 1.5
    Lighting.ColorShift_Bottom = Color3.fromRGB(100, 50, 150)
    Lighting.ColorShift_Top = Color3.fromRGB(255, 100, 200)
    Lighting.ClockTime = 19.5  -- dusk
    Lighting.FogColor = Color3.fromRGB(80, 40, 100)
    Lighting.FogEnd = 500
    Lighting.FogStart = 100
    Lighting.GlobalShadows = true

    -- Bloom
    local existingBloom = Lighting:FindFirstChildOfClass("BloomEffect")
    if not existingBloom then
        local bloom = Instance.new("BloomEffect")
        bloom.Intensity = 0.6
        bloom.Size = 24
        bloom.Threshold = 1.5
        bloom.Parent = Lighting
    end

    -- ColorCorrection for purple tint
    if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
        local cc = Instance.new("ColorCorrectionEffect")
        cc.Saturation = 0.15
        cc.Contrast = 0.1
        cc.TintColor = Color3.fromRGB(255, 230, 240)
        cc.Parent = Lighting
    end
end

local function buildBaseplate(parent)
    local floor = part({
        Name = "Baseplate",
        Size = Vector3.new(MAP_SIZE, FLOOR_THICKNESS, MAP_SIZE),
        Position = Vector3.new(0, -FLOOR_THICKNESS/2, 0),
        Color = Color3.fromRGB(40, 30, 50),
        Material = Enum.Material.Concrete,
        Parent = parent,
    })
    return floor
end

local function buildAlleyWalls(parent)
    local wallH = 30
    local thickness = 4
    local positions = {
        {Vector3.new(0, wallH/2, MAP_SIZE/2), Vector3.new(MAP_SIZE, wallH, thickness)},
        {Vector3.new(0, wallH/2, -MAP_SIZE/2), Vector3.new(MAP_SIZE, wallH, thickness)},
        {Vector3.new(MAP_SIZE/2, wallH/2, 0), Vector3.new(thickness, wallH, MAP_SIZE)},
        {Vector3.new(-MAP_SIZE/2, wallH/2, 0), Vector3.new(thickness, wallH, MAP_SIZE)},
    }
    for i, def in ipairs(positions) do
        part({
            Name = "Wall_" .. i,
            Size = def[2],
            Position = def[1],
            Color = Color3.fromRGB(60, 40, 70),
            Material = Enum.Material.Brick,
            Parent = parent,
        })
    end
end

local function buildSpawnPads(parent)
    local padFolder = Workspace:FindFirstChild("SpawnPads") or Instance.new("Folder")
    padFolder.Name = "SpawnPads"
    padFolder.Parent = Workspace
    -- 4 pads in corners-ish, well inside walls
    local positions = {
        Vector3.new(-60, 1, -60),
        Vector3.new(60, 1, -60),
        Vector3.new(-60, 1, 60),
        Vector3.new(60, 1, 60),
    }
    for i, pos in ipairs(positions) do
        part({
            Name = "SpawnPad_" .. i,
            Size = Vector3.new(8, 0.4, 8),
            Position = pos,
            Color = Color3.fromRGB(255, 100, 200),
            Material = Enum.Material.Neon,
            Parent = padFolder,
        })
    end
end

local function buildCosmeticShop(parent)
    local shop = Instance.new("Model")
    shop.Name = "CosmeticShop"
    local base = part({
        Name = "Floor",
        Size = Vector3.new(20, 1, 20),
        Position = Vector3.new(-70, 0.5, 0),
        Color = Color3.fromRGB(80, 40, 120),
        Material = Enum.Material.Neon,
        Parent = shop,
    })
    -- 3 walls
    part({Name="Back", Size=Vector3.new(20, 14, 1), Position=Vector3.new(-70, 7, -10), Color=Color3.fromRGB(120,40,200), Material=Enum.Material.Brick, Parent=shop})
    part({Name="Left", Size=Vector3.new(1, 14, 20), Position=Vector3.new(-80, 7, 0), Color=Color3.fromRGB(120,40,200), Material=Enum.Material.Brick, Parent=shop})
    part({Name="Right", Size=Vector3.new(1, 14, 20), Position=Vector3.new(-60, 7, 0), Color=Color3.fromRGB(120,40,200), Material=Enum.Material.Brick, Parent=shop})
    -- Sign
    local sign = part({
        Name = "Sign",
        Size = Vector3.new(16, 4, 0.5),
        Position = Vector3.new(-70, 12, -9.4),
        Color = Color3.fromRGB(0, 255, 100),
        Material = Enum.Material.Neon,
        Parent = shop,
    })
    local signGui = Instance.new("SurfaceGui")
    signGui.Face = Enum.NormalId.Front
    signGui.Parent = sign
    local signLabel = Instance.new("TextLabel")
    signLabel.Size = UDim2.new(1,0,1,0)
    signLabel.BackgroundTransparency = 1
    signLabel.Text = "COSMETIC SHOP"
    signLabel.TextColor3 = Color3.fromRGB(0,0,0)
    signLabel.Font = Enum.Font.GothamBlack
    signLabel.TextScaled = true
    signLabel.Parent = signGui
    -- Shop trigger (touch part inside)
    local trigger = part({
        Name = "ShopTrigger",
        Size = Vector3.new(10, 4, 10),
        Position = Vector3.new(-70, 2, 0),
        Color = Color3.fromRGB(0, 255, 100),
        Material = Enum.Material.ForceField,
        Transparency = 0.7,
        CanCollide = false,
        Parent = shop,
    })
    trigger:SetAttribute("ShopTrigger", true)
    shop.Parent = parent
end

local function buildRebirthStatue(parent)
    local statue = Instance.new("Model")
    statue.Name = "RebirthStatue"
    -- Pedestal
    part({Name="Pedestal", Size=Vector3.new(10,4,10), Position=Vector3.new(0,2,-50), Color=Color3.fromRGB(40,40,40), Material=Enum.Material.Slate, Parent=statue})
    -- Cat block (simplified statue)
    part({Name="StatueBody", Size=Vector3.new(4,8,4), Position=Vector3.new(0,8,-50), Color=Color3.fromRGB(255,200,80), Material=Enum.Material.Neon, Parent=statue})
    part({Name="StatueHead", Size=Vector3.new(3,3,3), Position=Vector3.new(0,13.5,-50), Color=Color3.fromRGB(255,200,80), Material=Enum.Material.Neon, Parent=statue})
    -- Trigger
    local trig = part({
        Name = "RebirthTrigger",
        Size = Vector3.new(12, 4, 12),
        Position = Vector3.new(0, 2, -50),
        Material = Enum.Material.ForceField,
        Color = Color3.fromRGB(255, 200, 80),
        Transparency = 0.7,
        CanCollide = false,
        Parent = statue,
    })
    trig:SetAttribute("RebirthTrigger", true)
    statue.Parent = parent
end

local function buildLeaderboardPillar(parent)
    local pillar = Instance.new("Model")
    pillar.Name = "LeaderboardPillar"
    local body = part({
        Name = "Body",
        Size = Vector3.new(4, 20, 4),
        Position = Vector3.new(50, 10, 0),
        Color = Color3.fromRGB(0, 100, 255),
        Material = Enum.Material.Neon,
        Parent = pillar,
    })
    -- SurfaceGui front face
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.Name = "LeaderboardSurfaceGui"
    sg.Parent = body
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,1,0)
    frame.BackgroundColor3 = Color3.fromRGB(0,0,0)
    frame.BackgroundTransparency = 0.3
    frame.Name = "Container"
    frame.Parent = sg
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,0,0.1,0)
    title.Text = "TOP CHAOS"
    title.Font = Enum.Font.GothamBlack
    title.TextColor3 = Color3.fromRGB(0, 255, 100)
    title.BackgroundTransparency = 1
    title.TextScaled = true
    title.Parent = frame
    local listFrame = Instance.new("Frame")
    listFrame.Position = UDim2.new(0, 0, 0.1, 0)
    listFrame.Size = UDim2.new(1, 0, 0.9, 0)
    listFrame.BackgroundTransparency = 1
    listFrame.Name = "ListFrame"
    listFrame.Parent = frame
    pillar.Parent = parent
end

local function buildFoodSources(parent)
    -- Taco stand (food) + water puddle (drink)
    local taco = part({
        Name = "TacoStand",
        Size = Vector3.new(6, 4, 4),
        Position = Vector3.new(40, 2, -40),
        Color = Color3.fromRGB(255, 200, 80),
        Material = Enum.Material.Plastic,
        Parent = parent,
    })
    taco:SetAttribute("FoodSource", true)
    local tacoSign = Instance.new("BillboardGui")
    tacoSign.Size = UDim2.new(0, 100, 0, 30)
    tacoSign.StudsOffset = Vector3.new(0, 4, 0)
    tacoSign.Parent = taco
    local tacoLbl = Instance.new("TextLabel")
    tacoLbl.Size = UDim2.new(1, 0, 1, 0)
    tacoLbl.BackgroundTransparency = 1
    tacoLbl.Text = "🌮 FOOD"
    tacoLbl.TextColor3 = Color3.fromRGB(255, 200, 80)
    tacoLbl.TextStrokeTransparency = 0
    tacoLbl.Font = Enum.Font.GothamBlack
    tacoLbl.TextScaled = true
    tacoLbl.Parent = tacoSign

    local puddle = part({
        Name = "WaterPuddle",
        Size = Vector3.new(8, 0.4, 8),
        Position = Vector3.new(-40, 0.2, 40),
        Color = Color3.fromRGB(60, 180, 255),
        Material = Enum.Material.Glass,
        Transparency = 0.3,
        Parent = parent,
    })
    puddle:SetAttribute("WaterSource", true)
    local pSign = Instance.new("BillboardGui")
    pSign.Size = UDim2.new(0, 100, 0, 30)
    pSign.StudsOffset = Vector3.new(0, 4, 0)
    pSign.Parent = puddle
    local pLbl = Instance.new("TextLabel")
    pLbl.Size = UDim2.new(1, 0, 1, 0)
    pLbl.BackgroundTransparency = 1
    pLbl.Text = "💧 WATER"
    pLbl.TextColor3 = Color3.fromRGB(60, 180, 255)
    pLbl.TextStrokeTransparency = 0
    pLbl.Font = Enum.Font.GothamBlack
    pLbl.TextScaled = true
    pLbl.Parent = pSign

    -- Garbage can
    local garbage = part({
        Name = "GarbageCan",
        Size = Vector3.new(3, 5, 3),
        Position = Vector3.new(20, 2.5, 60),
        Color = Color3.fromRGB(80, 80, 80),
        Material = Enum.Material.Metal,
        Parent = parent,
    })
    garbage:SetAttribute("FoodSource", true)
end

local function buildSpawnLocation(parent)
    local sl = Instance.new("SpawnLocation")
    sl.Name = "MainSpawn"
    sl.Size = Vector3.new(8, 1, 8)
    sl.Position = Vector3.new(0, 1, 0)
    sl.Anchored = true
    sl.Color = Color3.fromRGB(150, 50, 200)
    sl.Material = Enum.Material.Neon
    sl.TopSurface = Enum.SurfaceType.Smooth
    sl.Parent = parent
end

local function buildNeonSigns(parent)
    -- A few decorative neon signs
    local signs = {
        {pos=Vector3.new(-30, 18, -98), text="MEOW", color=Color3.fromRGB(255, 50, 200)},
        {pos=Vector3.new(30, 22, -98), text="CHAOS", color=Color3.fromRGB(0, 255, 100)},
        {pos=Vector3.new(-50, 16, 98), text="24/7", color=Color3.fromRGB(255, 200, 0)},
    }
    for i, def in ipairs(signs) do
        local p = part({
            Name = "Sign_" .. i,
            Size = Vector3.new(12, 4, 0.5),
            Position = def.pos,
            Color = def.color,
            Material = Enum.Material.Neon,
            Parent = parent,
        })
        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Front
        sg.Parent = p
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1,0,1,0)
        lbl.Text = def.text
        lbl.TextScaled = true
        lbl.Font = Enum.Font.GothamBlack
        lbl.TextColor3 = Color3.fromRGB(255,255,255)
        lbl.BackgroundTransparency = 1
        lbl.Parent = sg
    end
end

-- =========================================================================
local function build()
    local existing = Workspace:FindFirstChild(MAP_NAME)
    if existing then
        warn("[MapBuilder] Map already exists, skipping rebuild")
        return existing
    end

    buildLighting()

    local mapModel = Instance.new("Model")
    mapModel.Name = MAP_NAME
    mapModel.Parent = Workspace

    buildBaseplate(mapModel)
    buildAlleyWalls(mapModel)
    buildSpawnPads(mapModel)
    buildCosmeticShop(mapModel)
    buildRebirthStatue(mapModel)
    buildLeaderboardPillar(mapModel)
    buildNeonSigns(mapModel)
    buildFoodSources(mapModel)
    buildSpawnLocation(mapModel)

    print("[MapBuilder] Cat Alley built.")
    return mapModel
end

build()
return true

]]
end

do
    local s = getOrMake(game.StarterGui, 'LocalScript', 'HUDBuilder')
    s.Source = [[
-- HUDBuilder.client.lua
-- Programmatically constructs the entire MainHUD ScreenGui.
-- Place in: StarterGui > HUDBuilder (LocalScript)
-- Other client scripts (HUDController, InputHandler) reference its named children.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))
local PrankConfig = require(ReplicatedStorage.Modules.PrankConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remove any existing MainHUD (dev hot reload)
local existing = playerGui:FindFirstChild("MainHUD")
if existing then existing:Destroy() end

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ===== Helpers =====
local function makeFrame(props)
    local f = Instance.new("Frame")
    for k, v in pairs(props) do f[k] = v end
    return f
end

local function makeLabel(props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamBlack
    l.TextColor3 = Color3.fromRGB(255,255,255)
    l.TextStrokeTransparency = 0
    l.TextStrokeColor3 = Color3.new(0,0,0)
    l.TextScaled = true
    for k, v in pairs(props) do l[k] = v end
    return l
end

local function makeButton(props)
    local b = Instance.new("TextButton")
    b.AutoButtonColor = false
    b.Font = Enum.Font.GothamBlack
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.TextScaled = true
    b.BorderSizePixel = 0
    for k, v in pairs(props) do b[k] = v end
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = b
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.new(0,0,0)
    stroke.Parent = b
    return b
end

-- ===== TOP BAR =====
local topBar = makeFrame({
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, IS_MOBILE and 80 or 70),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = Color3.fromRGB(20, 10, 30),
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Parent = screenGui,
})
local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = GameConfig.HUD_PRIMARY_COLOR
stroke.Parent = topBar

makeLabel({
    Name = "ChaosLabel",
    Size = UDim2.new(0.3, 0, 0.7, 0),
    Position = UDim2.new(0.01, 0, 0.15, 0),
    Text = "💚 0",
    TextColor3 = GameConfig.HUD_ACCENT_COLOR,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = topBar,
}).Parent = topBar

local levelContainer = makeFrame({
    Name = "LevelContainer",
    Size = UDim2.new(0.3, 0, 0.7, 0),
    Position = UDim2.new(0.35, 0, 0.15, 0),
    BackgroundTransparency = 1,
    Parent = topBar,
})
makeLabel({
    Name = "LevelLabel",
    Size = UDim2.new(1, 0, 0.5, 0),
    Position = UDim2.new(0, 0, 0, 0),
    Text = "Level 1",
    Parent = levelContainer,
})
local xpBarBg = makeFrame({
    Name = "XPBarBG",
    Size = UDim2.new(0.9, 0, 0.3, 0),
    Position = UDim2.new(0.05, 0, 0.6, 0),
    BackgroundColor3 = Color3.fromRGB(40, 20, 60),
    BorderSizePixel = 0,
    Parent = levelContainer,
})
Instance.new("UICorner", xpBarBg).CornerRadius = UDim.new(1, 0)
local xpBarFill = makeFrame({
    Name = "XPBarFill",
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = GameConfig.HUD_ACCENT_COLOR,
    BorderSizePixel = 0,
    Parent = xpBarBg,
})
Instance.new("UICorner", xpBarFill).CornerRadius = UDim.new(1, 0)

makeLabel({
    Name = "RebirthLabel",
    Size = UDim2.new(0.3, 0, 0.7, 0),
    Position = UDim2.new(0.69, 0, 0.15, 0),
    Text = "👑 0",
    TextXAlignment = Enum.TextXAlignment.Right,
    Parent = topBar,
})

-- ===== CENTER BOTTOM: SUMMON BUTTON =====
local summonSize = IS_MOBILE and 180 or 140
local summonBtn = makeButton({
    Name = "SummonButton",
    Size = UDim2.new(0, summonSize, 0, summonSize),
    Position = UDim2.new(0.5, -summonSize/2, 1, -(summonSize + 30)),
    BackgroundColor3 = GameConfig.HUD_DANGER_COLOR,
    Text = "SUMMON\nHUMAN",
    Parent = screenGui,
})

-- ===== RIGHT SIDE: PRANK BUTTONS =====
local prankColumn = makeFrame({
    Name = "PrankColumn",
    Size = UDim2.new(0, IS_MOBILE and 80 or 70, 0, 4 * (IS_MOBILE and 90 or 80)),
    Position = UDim2.new(1, -(IS_MOBILE and 90 or 80), 0.5, -(2 * (IS_MOBILE and 90 or 80))),
    BackgroundTransparency = 1,
    Parent = screenGui,
})
local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Padding = UDim.new(0, 6)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = prankColumn

for i, prankName in ipairs(PrankConfig.Order) do
    local prank = PrankConfig.Pranks[prankName]
    local btn = makeButton({
        Name = "Prank_" .. prankName,
        Size = UDim2.new(0, IS_MOBILE and 70 or 60, 0, IS_MOBILE and 70 or 60),
        BackgroundColor3 = Color3.fromRGB(60, 30, 90),
        Text = prankName == "Pie" and "🥧" or prankName == "Anvil" and "🔨" or prankName == "FartCloud" and "💨" or "👁️",
        TextSize = 36,
        LayoutOrder = i,
        Parent = prankColumn,
    })
    btn:SetAttribute("PrankName", prankName)
    btn:SetAttribute("Locked", true)
    btn:SetAttribute("UnlockLevel", prank.unlockLevel)
    -- Locked overlay
    local lock = makeLabel({
        Name = "LockOverlay",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.new(0,0,0),
        BackgroundTransparency = 0.5,
        Text = "🔒\nLv " .. prank.unlockLevel,
        TextSize = 18,
    })
    lock.BackgroundTransparency = 0.5
    lock.Parent = btn
    -- Cooldown overlay
    local cd = makeFrame({
        Name = "CooldownOverlay",
        Size = UDim2.new(1, 0, 0, 0),
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Color3.new(0,0,0),
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        Visible = false,
    })
    cd.Parent = btn
end

-- ===== BOTTOM BAR: SHOP / INVENTORY / REBIRTH / LEADERBOARD =====
local bottomBar = makeFrame({
    Name = "BottomBar",
    Size = UDim2.new(0, IS_MOBILE and 360 or 320, 0, IS_MOBILE and 60 or 50),
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -10),
    BackgroundTransparency = 1,
    Parent = screenGui,
})
local botLayout = Instance.new("UIListLayout")
botLayout.FillDirection = Enum.FillDirection.Horizontal
botLayout.Padding = UDim.new(0, 6)
botLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
botLayout.Parent = bottomBar

local function bottomButton(name, text, color, layoutOrder)
    return makeButton({
        Name = name,
        Size = UDim2.new(0, IS_MOBILE and 80 or 70, 0, IS_MOBILE and 56 or 44),
        BackgroundColor3 = color,
        Text = text,
        TextSize = IS_MOBILE and 18 or 14,
        LayoutOrder = layoutOrder,
        Parent = bottomBar,
    })
end

bottomButton("ShopButton", "SHOP", Color3.fromRGB(0, 200, 100), 1)
bottomButton("InventoryButton", "INV", Color3.fromRGB(80, 60, 200), 2)
bottomButton("RebirthButton", "REBIRTH", Color3.fromRGB(255, 150, 0), 3)
bottomButton("LeaderboardButton", "TOP", Color3.fromRGB(0, 150, 255), 4)

-- ===== NOTIFICATION TOAST AREA =====
local toastFrame = makeFrame({
    Name = "ToastFrame",
    Size = UDim2.new(0, 400, 0, 60),
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 90),
    BackgroundTransparency = 1,
    Parent = screenGui,
})

-- ===== SHOP MODAL (hidden by default) =====
local shopModal = makeFrame({
    Name = "ShopModal",
    Size = UDim2.new(0, 600, 0, 500),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundColor3 = Color3.fromRGB(20, 10, 30),
    BorderSizePixel = 0,
    Visible = false,
    Parent = screenGui,
})
Instance.new("UICorner", shopModal).CornerRadius = UDim.new(0, 16)
local shopStroke = Instance.new("UIStroke")
shopStroke.Thickness = 3
shopStroke.Color = GameConfig.HUD_PRIMARY_COLOR
shopStroke.Parent = shopModal

makeLabel({
    Name = "ShopTitle",
    Size = UDim2.new(1, -20, 0, 50),
    Position = UDim2.new(0, 10, 0, 10),
    Text = "COSMETIC SHOP",
    TextColor3 = GameConfig.HUD_ACCENT_COLOR,
    Parent = shopModal,
})

local shopClose = makeButton({
    Name = "CloseButton",
    Size = UDim2.new(0, 40, 0, 40),
    Position = UDim2.new(1, -50, 0, 10),
    BackgroundColor3 = GameConfig.HUD_DANGER_COLOR,
    Text = "X",
    Parent = shopModal,
})

local shopList = Instance.new("ScrollingFrame")
shopList.Name = "ShopList"
shopList.Size = UDim2.new(1, -20, 1, -80)
shopList.Position = UDim2.new(0, 10, 0, 70)
shopList.BackgroundTransparency = 1
shopList.BorderSizePixel = 0
shopList.CanvasSize = UDim2.new(0, 0, 0, 0)
shopList.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopList.ScrollBarThickness = 8
shopList.Parent = shopModal
local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 8)
shopLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopLayout.Parent = shopList

-- ===== LEADERBOARD MODAL =====
local lbModal = makeFrame({
    Name = "LeaderboardModal",
    Size = UDim2.new(0, 360, 0, 480),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundColor3 = Color3.fromRGB(20, 10, 30),
    BorderSizePixel = 0,
    Visible = false,
    Parent = screenGui,
})
Instance.new("UICorner", lbModal).CornerRadius = UDim.new(0, 16)
local lbStroke = Instance.new("UIStroke")
lbStroke.Thickness = 3
lbStroke.Color = GameConfig.HUD_ACCENT_COLOR
lbStroke.Parent = lbModal

makeLabel({
    Name = "LBTitle",
    Size = UDim2.new(1, -20, 0, 50),
    Position = UDim2.new(0, 10, 0, 10),
    Text = "TOP CHAOS",
    TextColor3 = GameConfig.HUD_ACCENT_COLOR,
    Parent = lbModal,
})
local lbClose = makeButton({
    Name = "CloseButton",
    Size = UDim2.new(0, 40, 0, 40),
    Position = UDim2.new(1, -50, 0, 10),
    BackgroundColor3 = GameConfig.HUD_DANGER_COLOR,
    Text = "X",
    Parent = lbModal,
})
local lbList = Instance.new("Frame")
lbList.Name = "LBList"
lbList.Size = UDim2.new(1, -20, 1, -80)
lbList.Position = UDim2.new(0, 10, 0, 70)
lbList.BackgroundTransparency = 1
lbList.Parent = lbModal
local lbLayout = Instance.new("UIListLayout")
lbLayout.Padding = UDim.new(0, 4)
lbLayout.Parent = lbList

-- ===== TUTORIAL TOOLTIP (hidden, controller drives it) =====
local tutorial = makeFrame({
    Name = "TutorialTooltip",
    Size = UDim2.new(0, 400, 0, 90),
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 100),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    Visible = false,
    Parent = screenGui,
})
Instance.new("UICorner", tutorial).CornerRadius = UDim.new(0, 12)
local tutLabel = makeLabel({
    Name = "Text",
    Size = UDim2.new(1, -20, 1, -20),
    Position = UDim2.new(0, 10, 0, 10),
    Text = "",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Parent = tutorial,
})

print("[HUDBuilder] MainHUD constructed")

-- Expose remote-controlled refs (other client scripts find by Name)
return screenGui

]]
end

print('[KittyRaiser] chunk 3/5 loaded - 6 scripts')
