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
    buildSpawnLocation(mapModel)

    print("[MapBuilder] Cat Alley built.")
    return mapModel
end

build()
return true
