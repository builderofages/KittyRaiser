-- CityRebuild.server.lua  v3 — full implementation
-- Auto-runs on server boot. Builds the city, swaps cat to mesh, applies
-- uploaded textures to buildings, dumps asset IDs to Output, sets up safe spawn.
-- Idempotent. Place in: ServerScriptService > CityRebuild (Script).

local Workspace          = game:GetService("Workspace")
local Lighting           = game:GetService("Lighting")
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local StarterPlayer      = game:GetService("StarterPlayer")
local AssetManagerService

print("[CityRebuild v3] booting...")

----------------------------------------------------------------------
-- 0. Try to load AssetIds module (placeholder fallback if missing)
----------------------------------------------------------------------
local AssetIds
do
    local modulesFolder = ReplicatedStorage:FindFirstChild("Modules")
    local assetIdsModule = modulesFolder and modulesFolder:FindFirstChild("AssetIds")
    if assetIdsModule then
        local ok, mod = pcall(require, assetIdsModule)
        if ok then AssetIds = mod end
    end
    if not AssetIds then
        AssetIds = setmetatable({}, {__index = function() return "rbxassetid://0" end})
        AssetIds.has = function() return false end
        AssetIds.get = function() return nil end
    end
end

----------------------------------------------------------------------
-- 1. GROUND FIRST (always, no matter what)
----------------------------------------------------------------------
local function ensureGround()
    local g = Workspace:FindFirstChild("KittyGround")
    if not g then
        g = Instance.new("Part")
        g.Name = "KittyGround"
        g.Anchored = true
        g.CanCollide = true
        g.Size = Vector3.new(4000, 4, 4000)
        g.Position = Vector3.new(0, -2, 0)
        g.Material = Enum.Material.Concrete
        g.Color = Color3.fromRGB(48, 48, 54)
        g.TopSurface = Enum.SurfaceType.Smooth
        g.Parent = Workspace
    end
    -- Apply asphalt texture to ground if available
    if AssetIds.has("asphalt") then
        local existing = g:FindFirstChildOfClass("Texture")
        if existing then existing:Destroy() end
        local tex = Instance.new("Texture")
        tex.Texture = AssetIds.asphalt
        tex.StudsPerTileU = 32; tex.StudsPerTileV = 32
        tex.Face = Enum.NormalId.Top
        tex.Parent = g
    end
    return g
end
local groundPart = ensureGround()

----------------------------------------------------------------------
-- 2. SAFE SPAWN
----------------------------------------------------------------------
local function ensureSpawn()
    for _, sp in ipairs(Workspace:GetDescendants()) do
        if sp:IsA("SpawnLocation") then sp:Destroy() end
    end
    local s = Instance.new("SpawnLocation")
    s.Name = "MainSpawn"
    s.Anchored = true
    s.CanCollide = true
    s.Size = Vector3.new(8, 1, 8)
    s.CFrame = CFrame.new(0, 5, 24)
    s.Material = Enum.Material.SmoothPlastic
    s.Transparency = 1
    s.TopSurface = Enum.SurfaceType.Smooth
    s.Parent = Workspace
    return s
end
ensureSpawn()

----------------------------------------------------------------------
-- 3. HEAL-ON-SPAWN HANDLER (overrides SurvivalSystem instakill)
----------------------------------------------------------------------
local function healAndSetup(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Health = hum.MaxHealth
        hum.WalkSpeed = 16
        hum.JumpPower = 50
    end
    -- Apply mesh-cat if cat_body mesh available
    if AssetIds.has("mesh_cat_body") then
        applyMeshCat(char)
    end
end

-- Forward declaration so healAndSetup compiles
function applyMeshCat(_) end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.15)
        healAndSetup(char)
    end)
end)
for _, plr in ipairs(Players:GetPlayers()) do
    plr.CharacterAdded:Connect(function(char) task.wait(0.15); healAndSetup(char) end)
    if plr.Character then healAndSetup(plr.Character) end
end

----------------------------------------------------------------------
-- 4. NUKE BROKEN ASSETS (pink platforms, ToolboxCity, cartoon trees, islands)
----------------------------------------------------------------------
local function isPink(c)
    if not c then return false end
    return c.R > 0.75 and c.B > 0.55 and c.G < 0.45
end

local nukedPink, killedToolbox, nukedTree, nukedIsland = 0, 0, 0, 0
for _, p in ipairs(Workspace:GetDescendants()) do
    if p:IsA("BasePart") and p ~= groundPart and isPink(p.Color) and (p.Size.X > 6 or p.Size.Z > 6) then
        p:Destroy(); nukedPink = nukedPink + 1
    end
end
for _, m in ipairs(Workspace:GetChildren()) do
    if m:IsA("Model") then
        local ln = m.Name:lower()
        if ln:find("toolbox") or ln:find("lowpoly") or ln:find("island") then
            m:Destroy(); killedToolbox = killedToolbox + 1
        end
    end
end
for _, m in ipairs(Workspace:GetDescendants()) do
    if (m:IsA("Model") or m:IsA("BasePart")) and m.Name:lower():find("tree") then
        m:Destroy(); nukedTree = nukedTree + 1
    end
end
print(("[CityRebuild v3] cleanup: %d pink, %d toolbox/island, %d trees"):format(nukedPink, killedToolbox, nukedTree))

----------------------------------------------------------------------
-- 5. BUILD THE CITY
----------------------------------------------------------------------
local cityFolder = Workspace:FindFirstChild("KittyCity") or Instance.new("Folder", Workspace)
cityFolder.Name = "KittyCity"
cityFolder:ClearAllChildren()

local SP = 200

-- 5a. Asphalt road grid
local roads = Instance.new("Folder", cityFolder); roads.Name = "Roads"
local function mkRoad(pos, sz)
    local r = Instance.new("Part")
    r.Anchored = true; r.CanCollide = true
    r.Material = Enum.Material.Asphalt
    r.Color = Color3.fromRGB(28, 28, 32)
    r.Size = sz; r.Position = pos
    r.TopSurface = Enum.SurfaceType.Smooth
    r.Parent = roads
end
for i = -4, 4 do
    mkRoad(Vector3.new(i*SP, 0.5, 0), Vector3.new(40, 0.6, 3000))
    mkRoad(Vector3.new(0, 0.5, i*SP), Vector3.new(3000, 0.6, 40))
end

-- 5b. Yellow lane lines
local lanes = Instance.new("Folder", cityFolder); lanes.Name = "Lanes"
for i = -4, 4 do
    for z = -1400, 1400, 80 do
        local d = Instance.new("Part")
        d.Anchored = true; d.CanCollide = false
        d.Material = Enum.Material.Neon
        d.Color = Color3.fromRGB(255, 220, 50)
        d.Size = Vector3.new(1.5, 0.65, 30)
        d.Position = Vector3.new(i*SP, 0.85, z)
        d.Parent = lanes
    end
    for x = -1400, 1400, 80 do
        local d = Instance.new("Part")
        d.Anchored = true; d.CanCollide = false
        d.Material = Enum.Material.Neon
        d.Color = Color3.fromRGB(255, 220, 50)
        d.Size = Vector3.new(30, 0.65, 1.5)
        d.Position = Vector3.new(x, 0.85, i*SP)
        d.Parent = lanes
    end
end

-- 5c. Sidewalks
local walks = Instance.new("Folder", cityFolder); walks.Name = "Sidewalks"
local function mkWalk(pos, sz)
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = true
    p.Material = Enum.Material.Concrete
    p.Color = Color3.fromRGB(135, 135, 138)
    p.Size = sz; p.Position = pos
    p.TopSurface = Enum.SurfaceType.Smooth
    p.Parent = walks
    -- Apply concrete texture
    if AssetIds.has("concrete") then
        local tex = Instance.new("Texture")
        tex.Texture = AssetIds.concrete
        tex.StudsPerTileU = 8; tex.StudsPerTileV = 8
        tex.Face = Enum.NormalId.Top
        tex.Parent = p
    end
end
for i = -4, 4 do
    mkWalk(Vector3.new(i*SP - 26, 1, 0), Vector3.new(12, 1.6, 3000))
    mkWalk(Vector3.new(i*SP + 26, 1, 0), Vector3.new(12, 1.6, 3000))
    mkWalk(Vector3.new(0, 1, i*SP - 26), Vector3.new(3000, 1.6, 12))
    mkWalk(Vector3.new(0, 1, i*SP + 26), Vector3.new(3000, 1.6, 12))
end

-- 5d. 80 buildings with material + texture variety
local bldgs = Instance.new("Folder", cityFolder); bldgs.Name = "Buildings"
local rng = Random.new(42)

local function applyBldgTexture(b, kind)
    local texId
    if kind == "brick" and AssetIds.has("brick") then texId = AssetIds.brick
    elseif kind == "concrete" and AssetIds.has("concrete") then texId = AssetIds.concrete
    elseif kind == "metal" and AssetIds.has("skyscraper_windows") then texId = AssetIds.skyscraper_windows
    end
    if not texId then return end
    for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
        local t = Instance.new("Texture")
        t.Texture = texId
        t.StudsPerTileU = 8; t.StudsPerTileV = 12
        t.Face = face
        t.Parent = b
    end
end

local function mkBldg(cx, cz)
    local h = rng:NextInteger(60, 200)
    local w = rng:NextInteger(40, 80)
    local d = rng:NextInteger(40, 80)
    local b = Instance.new("Part")
    b.Anchored = true; b.CanCollide = true
    b.Size = Vector3.new(w, h, d)
    b.Position = Vector3.new(cx, h/2 + 1, cz)
    local roll = rng:NextNumber()
    local kind
    if roll < 0.35 then
        b.Material = Enum.Material.Concrete
        b.Color = Color3.fromRGB(rng:NextInteger(120,170), rng:NextInteger(115,165), rng:NextInteger(110,160))
        kind = "concrete"
    elseif roll < 0.7 then
        b.Material = Enum.Material.Brick
        b.Color = Color3.fromRGB(rng:NextInteger(140,200), rng:NextInteger(70,110), rng:NextInteger(55,90))
        kind = "brick"
    else
        b.Material = Enum.Material.Metal
        b.Color = Color3.fromRGB(rng:NextInteger(70,130), rng:NextInteger(80,135), rng:NextInteger(95,150))
        kind = "metal"
    end
    b.TopSurface = Enum.SurfaceType.Smooth
    b.Parent = bldgs
    applyBldgTexture(b, kind)

    -- Lit window glow
    local sl = Instance.new("SurfaceLight")
    sl.Face = Enum.NormalId.Front
    sl.Range = 18; sl.Brightness = 0.6
    sl.Color = Color3.fromRGB(255, 230, 160)
    sl.Parent = b

    -- Rooftop neon sign on tall buildings
    if h > 130 and AssetIds.has("neon_sign") then
        local roof = Instance.new("Part")
        roof.Anchored = true; roof.CanCollide = false
        roof.Size = Vector3.new(w * 0.7, 18, 1)
        roof.Position = Vector3.new(cx, h + 11, cz - d/2 + 0.5)
        roof.Material = Enum.Material.Neon
        roof.Color = Color3.fromRGB(rng:NextInteger(180,255), rng:NextInteger(50,150), rng:NextInteger(100,255))
        roof.Parent = bldgs
        local sg = Instance.new("SurfaceGui", roof); sg.Face = Enum.NormalId.Front
        local tl = Instance.new("TextLabel", sg)
        tl.Size = UDim2.fromScale(1, 1); tl.BackgroundTransparency = 1
        tl.Text = ({"PURRZA","WHISKERS","KITCO","FELINE","MEOW","CATKIND","HISS","ALLEY","PROWL","NIGHT9","BODEGA","CATFI","TAILZ","9LIVES"})[rng:NextInteger(1,14)]
        tl.Font = Enum.Font.GothamBlack
        tl.TextScaled = true
        tl.TextColor3 = Color3.fromRGB(255, 240, 220)
    end
end

for gx = -3, 3 do
    for gz = -3, 3 do
        if math.abs(gx) > 0 or math.abs(gz) > 0 then
            local cx = gx * SP + rng:NextInteger(-50, 50)
            local cz = gz * SP + rng:NextInteger(-50, 50)
            mkBldg(cx, cz)
        end
    end
end
-- Outer ring
for theta = 0, 2*math.pi - 0.01, math.pi/8 do
    mkBldg(math.cos(theta) * 1100, math.sin(theta) * 1100)
end
-- Even outer ring of skyscrapers
for theta = math.pi/16, 2*math.pi - 0.01, math.pi/8 do
    mkBldg(math.cos(theta) * 1400, math.sin(theta) * 1400)
end

----------------------------------------------------------------------
-- 6. SPAWN PLAZA (concrete + fountain + welcome neon + lamps)
----------------------------------------------------------------------
local plaza = Instance.new("Folder", cityFolder); plaza.Name = "Plaza"

local pf = Instance.new("Part")
pf.Name = "PlazaFloor"
pf.Anchored = true; pf.CanCollide = true
pf.Size = Vector3.new(140, 2, 140)
pf.Position = Vector3.new(0, 1.5, 0)
pf.Material = Enum.Material.Concrete
pf.Color = Color3.fromRGB(180, 175, 165)
pf.TopSurface = Enum.SurfaceType.Smooth
pf.Parent = plaza
if AssetIds.has("concrete") then
    local t = Instance.new("Texture")
    t.Texture = AssetIds.concrete; t.StudsPerTileU = 16; t.StudsPerTileV = 16; t.Face = Enum.NormalId.Top
    t.Parent = pf
end

local fountain = Instance.new("Part")
fountain.Name = "Fountain"
fountain.Anchored = true; fountain.CanCollide = true
fountain.Shape = Enum.PartType.Cylinder
fountain.Size = Vector3.new(6, 16, 16)
fountain.CFrame = CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90))
fountain.Material = Enum.Material.Marble
fountain.Color = Color3.fromRGB(220, 215, 210)
fountain.Parent = plaza

local water = Instance.new("Part")
water.Name = "FountainWater"
water.Anchored = true; water.CanCollide = false
water.Shape = Enum.PartType.Cylinder
water.Size = Vector3.new(0.5, 14, 14)
water.CFrame = CFrame.new(0, 12, 0) * CFrame.Angles(0, 0, math.rad(90))
water.Material = Enum.Material.Glass
water.Color = Color3.fromRGB(120, 180, 255)
water.Transparency = 0.3
water:SetAttribute("WaterSource", true)  -- player can drink
water.Parent = plaza

local sign = Instance.new("Part")
sign.Name = "Welcome"
sign.Anchored = true; sign.CanCollide = false
sign.Size = Vector3.new(80, 18, 1)
sign.Position = Vector3.new(0, 17, -64)
sign.Material = Enum.Material.Neon
sign.Color = Color3.fromRGB(255, 80, 60)
sign.Parent = plaza
local sgui = Instance.new("SurfaceGui", sign); sgui.Face = Enum.NormalId.Front
local stl = Instance.new("TextLabel", sgui)
stl.Size = UDim2.fromScale(1,1); stl.BackgroundTransparency = 1
stl.Text = "WELCOME TO KITTYRAISER"
stl.Font = Enum.Font.GothamBlack
stl.TextScaled = true
stl.TextColor3 = Color3.fromRGB(255, 230, 200)

for _, lp in ipairs({Vector3.new(-50,0,-50), Vector3.new(50,0,-50), Vector3.new(-50,0,50), Vector3.new(50,0,50)}) do
    local post = Instance.new("Part")
    post.Anchored = true; post.CanCollide = true
    post.Size = Vector3.new(1, 16, 1); post.Position = lp + Vector3.new(0, 10, 0)
    post.Material = Enum.Material.Metal
    post.Color = Color3.fromRGB(40, 40, 50)
    post.Parent = plaza
    local lamp = Instance.new("Part")
    lamp.Anchored = true; lamp.CanCollide = true; lamp.Shape = Enum.PartType.Ball
    lamp.Size = Vector3.new(2, 2, 2)
    lamp.Position = lp + Vector3.new(0, 18, 0)
    lamp.Material = Enum.Material.Neon
    lamp.Color = Color3.fromRGB(255, 230, 160)
    lamp.Parent = plaza
    local pl = Instance.new("PointLight", lamp)
    pl.Brightness = 2; pl.Range = 30; pl.Color = Color3.fromRGB(255, 230, 160)
end

-- Trash cans (food source) on plaza corners
for _, tp in ipairs({Vector3.new(-30,2,-30), Vector3.new(30,2,-30), Vector3.new(-30,2,30), Vector3.new(30,2,30)}) do
    local can = Instance.new("Part")
    can.Anchored = true; can.CanCollide = true
    can.Shape = Enum.PartType.Cylinder
    can.Size = Vector3.new(5, 4, 4)
    can.CFrame = CFrame.new(tp) * CFrame.Angles(0, 0, math.rad(90))
    can.Material = Enum.Material.Metal
    can.Color = Color3.fromRGB(60, 70, 60)
    can:SetAttribute("FoodSource", true)
    can.Parent = plaza
end

----------------------------------------------------------------------
-- 7. ATMOSPHERE + CINEMATIC LIGHTING
----------------------------------------------------------------------
Lighting.Technology = Enum.Technology.Future
Lighting.ClockTime = 18.5
Lighting.GeographicLatitude = 41.5
Lighting.Brightness = 2
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.6
Lighting.GlobalShadows = true
Lighting.Ambient = Color3.fromRGB(75, 60, 95)
Lighting.OutdoorAmbient = Color3.fromRGB(110, 100, 140)
Lighting.FogEnd = 1800
Lighting.FogStart = 600
Lighting.FogColor = Color3.fromRGB(70, 50, 90)

local function ensureFx(cls, props)
    local fx = Lighting:FindFirstChildOfClass(cls)
    if not fx then fx = Instance.new(cls); fx.Parent = Lighting end
    for k, v in pairs(props) do pcall(function() fx[k] = v end) end
end
ensureFx("BloomEffect",         {Intensity = 0.7, Size = 32, Threshold = 1.4})
ensureFx("SunRaysEffect",       {Intensity = 0.18, Spread = 0.7})
ensureFx("ColorCorrectionEffect", {Saturation = 0.18, Contrast = 0.12, TintColor = Color3.fromRGB(255, 232, 220)})
ensureFx("DepthOfFieldEffect",  {FarIntensity = 0.05, FocusDistance = 80, InFocusRadius = 100, NearIntensity = 0})

local atm = Lighting:FindFirstChildOfClass("Atmosphere")
if not atm then atm = Instance.new("Atmosphere"); atm.Parent = Lighting end
atm.Density = 0.45; atm.Offset = 0.25
atm.Color = Color3.fromRGB(180, 150, 200)
atm.Decay = Color3.fromRGB(80, 60, 110)
atm.Glare = 0.4; atm.Haze = 1.5

----------------------------------------------------------------------
-- 8. APPLY MESH-CAT (define after AssetIds is loaded)
----------------------------------------------------------------------
function applyMeshCat(char)
    -- Replace primitive parts with mesh body if assets exist
    if not (AssetIds.has("mesh_cat_body") and AssetIds.has("mesh_cat_head")) then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    -- Find existing body / head
    local torso = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    local head  = char:FindFirstChild("Head")
    if torso and torso:IsA("BasePart") and not torso:FindFirstChildOfClass("SpecialMesh") then
        local sm = Instance.new("SpecialMesh", torso)
        sm.MeshType = Enum.MeshType.FileMesh
        sm.MeshId = AssetIds.mesh_cat_body
        sm.Scale = Vector3.new(2, 2, 2.5)
        if AssetIds.has("fur_orange") then
            sm.TextureId = AssetIds.fur_orange
        end
    end
    if head and head:IsA("BasePart") and not head:FindFirstChildOfClass("SpecialMesh") then
        local sm = Instance.new("SpecialMesh", head)
        sm.MeshType = Enum.MeshType.FileMesh
        sm.MeshId = AssetIds.mesh_cat_head
        sm.Scale = Vector3.new(1.5, 1.5, 1.5)
        if AssetIds.has("fur_orange") then
            sm.TextureId = AssetIds.fur_orange
        end
    end
end

----------------------------------------------------------------------
-- 9. ASSET-ID DUMPER (so user can copy IDs into AssetIds.lua)
----------------------------------------------------------------------
print("=== KITTYRAISER_ASSET_DUMP_BEGIN ===")
local ams_ok, AMS = pcall(function() return game:GetService("AssetManagerService") end)
if ams_ok and AMS then
    local function tryGet(method, name)
        local ok, id = pcall(function() return AMS[method](AMS, name) end)
        if ok and id and id ~= 0 then return tostring(id) end
        return nil
    end

    local ICONS = {"coin","gem","robux","paw","scratch","pie","fish","slushie","tp","anvil","skull","wings","shop","bag","bars","gift","slot","star","trophy"}
    local TEXTURES = {"asphalt","brick","concrete","fur_orange","grass","neon_sign","skyscraper_windows"}
    local SOUNDS = {"anvil_clang","cat_scratch","coin_pickup","fish_slap","flight_whoosh","ko_sound","level_up","meow_1","meow_2","meow_3","pie_splat","purrgatory","slushie_freeze","spawn_chime","tp_unroll"}
    local MESHES = {"anvil","brownstone","cat_body","cat_ear","cat_head","cat_leg","cat_tail_segment","hydrant","mailbox","pie","skyscraper","taxi","trashcan"}

    for _, n in ipairs(ICONS) do
        local id = tryGet("GetImage", n) or tryGet("GetImageAssetIdByAlias", n)
        if id then print(("ICON: %s = rbxassetid://%s"):format(n, id)) end
    end
    for _, n in ipairs(TEXTURES) do
        local id = tryGet("GetImage", n) or tryGet("GetImageAssetIdByAlias", n)
        if id then print(("TEXTURE: %s = rbxassetid://%s"):format(n, id)) end
    end
    for _, n in ipairs(SOUNDS) do
        local id = tryGet("GetAudio", n) or tryGet("GetAudioAssetIdByAlias", n)
        if id then print(("SOUND: %s = rbxassetid://%s"):format(n, id)) end
    end
    for _, n in ipairs(MESHES) do
        local id = tryGet("GetMesh", n) or tryGet("GetMeshAssetIdByAlias", n)
        if id then print(("MESH: %s = rbxassetid://%s"):format(n, id)) end
    end
end
print("=== KITTYRAISER_ASSET_DUMP_END ===")

print("[CityRebuild v3] DONE — city built, spawn safe, textures applied if IDs wired, mesh cat ready, asset IDs dumped to Output")
