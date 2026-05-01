-- CityRebuild.server.lua  (v2 — spawn-safe)
-- Auto-runs on server boot.
-- Order matters: BUILD GROUND FIRST so destroyed-spawn cleanup never leaves the
-- player in the void. Idempotent. Place in: ServerScriptService > CityRebuild.

local Workspace = game:GetService("Workspace")
local Lighting  = game:GetService("Lighting")
local Players   = game:GetService("Players")

print("[CityRebuild v2] starting...")

------------------------------------------------------------
-- STEP 0. GROUND FIRST. Always. No matter what.
------------------------------------------------------------
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
    return g
end
ensureGround()

------------------------------------------------------------
-- STEP 1. SPAWN safely on the ground we just built.
------------------------------------------------------------
local function ensureSpawn()
    -- Wipe broken/old spawn pads
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

------------------------------------------------------------
-- STEP 2. Heal-on-spawn handler so SurvivalSystem can't insta-kill.
------------------------------------------------------------
local function healCharacter(char)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Health = hum.MaxHealth
        hum.WalkSpeed = 16
    end
end

Players.PlayerAdded:Connect(function(plr)
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        healCharacter(char)
    end)
end)
for _, plr in ipairs(Players:GetPlayers()) do
    plr.CharacterAdded:Connect(function(char) task.wait(0.1); healCharacter(char) end)
    if plr.Character then healCharacter(plr.Character) end
end

------------------------------------------------------------
-- STEP 3. Sweep magenta/pink platforms (only big ones).
------------------------------------------------------------
local function isPink(c)
    if not c then return false end
    return c.R > 0.75 and c.B > 0.55 and c.G < 0.45
end
local nukedPink = 0
for _, p in ipairs(Workspace:GetDescendants()) do
    if p:IsA("BasePart") and p ~= Workspace.KittyGround and isPink(p.Color) and (p.Size.X > 8 or p.Size.Z > 8) then
        p:Destroy(); nukedPink = nukedPink + 1
    end
end
print(("[CityRebuild v2] killed %d pink platforms"):format(nukedPink))

------------------------------------------------------------
-- STEP 4. Kill broken city / island / cartoon assets.
------------------------------------------------------------
local KILL_NAMES = {
    "ToolboxCity", "Lowpoly", "LowPoly", "CityTiles",
    "ToolboxCity_1","ToolboxCity_2","ToolboxCity_3","ToolboxCity_4",
}
local killed = 0
for _, name in ipairs(KILL_NAMES) do
    local o = Workspace:FindFirstChild(name)
    while o do o:Destroy(); killed = killed + 1; o = Workspace:FindFirstChild(name) end
end
for _, m in ipairs(Workspace:GetChildren()) do
    if m:IsA("Model") and (m.Name:lower():find("toolbox") or m.Name:lower():find("lowpoly") or m.Name:lower():find("island")) then
        m:Destroy(); killed = killed + 1
    end
end
print(("[CityRebuild v2] killed %d broken city models"):format(killed))

------------------------------------------------------------
-- STEP 5. Cartoon trees out.
------------------------------------------------------------
local nukedTree = 0
for _, m in ipairs(Workspace:GetDescendants()) do
    if (m:IsA("Model") or m:IsA("BasePart")) and m.Name:lower():find("tree") then
        m:Destroy(); nukedTree = nukedTree + 1
    end
end
print(("[CityRebuild v2] killed %d cartoon trees"):format(nukedTree))

------------------------------------------------------------
-- STEP 6. Build the city in a clean folder.
------------------------------------------------------------
local cityFolder = Workspace:FindFirstChild("KittyCity") or Instance.new("Folder", Workspace)
cityFolder.Name = "KittyCity"
cityFolder:ClearAllChildren()

------------------------------------------------------------
-- STEP 7. Asphalt road grid.
------------------------------------------------------------
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
local SP = 200
for i = -4, 4 do
    mkRoad(Vector3.new(i*SP, 0.5, 0), Vector3.new(40, 0.6, 3000))
    mkRoad(Vector3.new(0, 0.5, i*SP), Vector3.new(3000, 0.6, 40))
end
-- Yellow lane lines
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
end

------------------------------------------------------------
-- STEP 8. Sidewalks.
------------------------------------------------------------
local walks = Instance.new("Folder", cityFolder); walks.Name = "Sidewalks"
local function mkWalk(pos, sz)
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = true
    p.Material = Enum.Material.Concrete
    p.Color = Color3.fromRGB(135, 135, 138)
    p.Size = sz; p.Position = pos
    p.TopSurface = Enum.SurfaceType.Smooth
    p.Parent = walks
end
for i = -4, 4 do
    mkWalk(Vector3.new(i*SP - 26, 1, 0), Vector3.new(12, 1.6, 3000))
    mkWalk(Vector3.new(i*SP + 26, 1, 0), Vector3.new(12, 1.6, 3000))
    mkWalk(Vector3.new(0, 1, i*SP - 26), Vector3.new(3000, 1.6, 12))
    mkWalk(Vector3.new(0, 1, i*SP + 26), Vector3.new(3000, 1.6, 12))
end

------------------------------------------------------------
-- STEP 9. 60 buildings, varied materials, with lit windows.
------------------------------------------------------------
local bldgs = Instance.new("Folder", cityFolder); bldgs.Name = "Buildings"
local rng = Random.new(42)

local function mkBldg(cx, cz)
    local h = rng:NextInteger(60, 180)
    local w = rng:NextInteger(40, 80)
    local d = rng:NextInteger(40, 80)
    local b = Instance.new("Part")
    b.Anchored = true; b.CanCollide = true
    b.Size = Vector3.new(w, h, d)
    b.Position = Vector3.new(cx, h/2 + 1, cz)
    local roll = rng:NextNumber()
    if roll < 0.35 then
        b.Material = Enum.Material.Concrete
        b.Color = Color3.fromRGB(rng:NextInteger(120,170), rng:NextInteger(115,165), rng:NextInteger(110,160))
    elseif roll < 0.7 then
        b.Material = Enum.Material.Brick
        b.Color = Color3.fromRGB(rng:NextInteger(140,200), rng:NextInteger(70,110), rng:NextInteger(55,90))
    else
        b.Material = Enum.Material.Metal
        b.Color = Color3.fromRGB(rng:NextInteger(70,130), rng:NextInteger(80,135), rng:NextInteger(95,150))
    end
    b.TopSurface = Enum.SurfaceType.Smooth
    b.Parent = bldgs
    -- lit window strip
    local sl = Instance.new("SurfaceLight")
    sl.Face = Enum.NormalId.Front
    sl.Range = 18; sl.Brightness = 0.6
    sl.Color = Color3.fromRGB(255, 230, 160)
    sl.Parent = b
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
for theta = 0, 2*math.pi - 0.01, math.pi/8 do
    mkBldg(math.cos(theta) * 1100, math.sin(theta) * 1100)
end

------------------------------------------------------------
-- STEP 10. Spawn plaza (clean concrete + fountain + welcome neon).
------------------------------------------------------------
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

------------------------------------------------------------
-- STEP 11. Atmosphere + cinematic lighting.
------------------------------------------------------------
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
ensureFx("BloomEffect",        {Intensity = 0.7, Size = 32, Threshold = 1.4})
ensureFx("SunRaysEffect",      {Intensity = 0.18, Spread = 0.7})
ensureFx("ColorCorrectionEffect", {Saturation = 0.18, Contrast = 0.12, TintColor = Color3.fromRGB(255, 232, 220)})
ensureFx("DepthOfFieldEffect", {FarIntensity = 0.05, FocusDistance = 60, InFocusRadius = 80, NearIntensity = 0})

local atm = Lighting:FindFirstChildOfClass("Atmosphere")
if not atm then atm = Instance.new("Atmosphere"); atm.Parent = Lighting end
atm.Density = 0.45; atm.Offset = 0.25
atm.Color = Color3.fromRGB(180, 150, 200)
atm.Decay = Color3.fromRGB(80, 60, 110)
atm.Glare = 0.4; atm.Haze = 1.5

print("[CityRebuild v2] DONE — ground built first, spawn safe, city rebuilt")
