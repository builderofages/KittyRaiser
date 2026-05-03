-- CityRebuild.server.lua  v5 — geometry only. Lighting lives in StrayLighting.
-- Boots the world: ground, spawn, city kit insertion (with duplicate guard),
-- procedural fallback, plaza, particle pool.

local Workspace = game:GetService("Workspace")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[CityRebuild v5] booting (geometry only)...")

-- 0. AssetIds (graceful fallback)
local AssetIds
do
    local mods = ReplicatedStorage:FindFirstChild("Modules")
    local m = mods and mods:FindFirstChild("AssetIds")
    if m then
        local ok, mod = pcall(require, m)
        if ok then AssetIds = mod end
    end
    if not AssetIds then
        AssetIds = setmetatable({}, {__index = function() return "rbxassetid://0" end})
        AssetIds.has = function() return false end
    end
end

-- 1. NUKE BROKEN ASSETS
-- Be conservative: only delete clearly-broken pink stuff that came in via the
-- toolbox kit. Whitelist: skip parts under named decorative folders we own.
local function isPlaceholderPink(part)
    if not part:IsA("BasePart") then return false end
    local c = part.Color
    if not (c.R > 0.85 and c.B > 0.65 and c.G < 0.35) then return false end
    -- only big "decoration" parts; spare small props (tongues, accents, etc.)
    if part.Size.X < 12 and part.Size.Z < 12 then return false end
    -- spare anything inside Plaza, KittyGround, or our explicit folders
    local ancestor = part.Parent
    while ancestor and ancestor ~= Workspace do
        if ancestor.Name == "Plaza" or ancestor.Name == "KittyGround"
            or ancestor:GetAttribute("KittyRaiserKeep") then
            return false
        end
        ancestor = ancestor.Parent
    end
    return true
end
local nukedPink = 0
for _, p in ipairs(Workspace:GetDescendants()) do
    if isPlaceholderPink(p) then p:Destroy(); nukedPink = nukedPink + 1 end
end

local KILL_NAMES = {"ToolboxCity", "Lowpoly", "LowPoly", "CityTiles"}
for _, n in ipairs(KILL_NAMES) do
    local guard = 0
    local o = Workspace:FindFirstChild(n)
    while o and guard < 100 do
        warn("[CityRebuild] removing legacy node: " .. n)
        o:Destroy()
        o = Workspace:FindFirstChild(n)
        guard = guard + 1
    end
end

-- 2. SAFE GROUND
local g = Workspace:FindFirstChild("KittyGround")
if not g then
    g = Instance.new("Part")
    g.Name = "KittyGround"
    g.Anchored = true; g.CanCollide = true
    g.Size = Vector3.new(4000, 4, 4000)
    g.Position = Vector3.new(0, -2, 0)
    g.Material = Enum.Material.Concrete
    g.Color = Color3.fromRGB(45, 45, 50)
    g.TopSurface = Enum.SurfaceType.Smooth
    g.Parent = Workspace
end
if AssetIds.has and AssetIds.has("asphalt") then
    if not g:FindFirstChildOfClass("Decal") then
        local d = Instance.new("Decal", g)
        d.Texture = AssetIds.asphalt
        d.Face = Enum.NormalId.Top
    end
end

-- 3. SAFE SPAWN
for _, sp in ipairs(Workspace:GetDescendants()) do
    if sp:IsA("SpawnLocation") and sp.Name ~= "MainSpawn" then sp:Destroy() end
end
local mainSpawn = Workspace:FindFirstChild("MainSpawn")
if not mainSpawn then
    mainSpawn = Instance.new("SpawnLocation")
    mainSpawn.Name = "MainSpawn"
    mainSpawn.Anchored = true; mainSpawn.CanCollide = true
    mainSpawn.Size = Vector3.new(8, 1, 8)
    mainSpawn.CFrame = CFrame.new(0, 5, 24)
    mainSpawn.Material = Enum.Material.SmoothPlastic
    mainSpawn.Transparency = 1
    mainSpawn.Parent = Workspace
end

-- 4. INSERT CYBERPUNK CITY KIT (asset 139781692633505) WITH DUPLICATE GUARD
local CITY_KIT_ID = 139781692633505
local cityFolder = Workspace:FindFirstChild("CyberpunkCity")
if not cityFolder then
    cityFolder = Instance.new("Folder")
    cityFolder.Name = "CyberpunkCity"
    cityFolder.Parent = Workspace
end
cityFolder:SetAttribute("KittyRaiserKeep", true)

local cityLoaded = false
local function buildProceduralFallback()
    if cityLoaded or #cityFolder:GetChildren() > 0 then return end
    print("[CityRebuild v5] city kit unavailable — building procedural fallback")
    local rng = Random.new(42)
    local SP = 200
    for gx = -3, 3 do
        for gz = -3, 3 do
            if math.abs(gx) > 0 or math.abs(gz) > 0 then
                local cx = gx * SP + rng:NextInteger(-50, 50)
                local cz = gz * SP + rng:NextInteger(-50, 50)
                local h = rng:NextInteger(60, 180)
                local w = rng:NextInteger(40, 80)
                local d = rng:NextInteger(40, 80)
                local b = Instance.new("Part")
                b.Anchored = true; b.CanCollide = true
                b.Size = Vector3.new(w, h, d)
                -- Position by bottom (Y=0) instead of by center so buildings sit on the
                -- ground instead of being half-buried.
                b.Position = Vector3.new(cx, h / 2, cz)
                b.Material = (rng:NextNumber() < 0.5) and Enum.Material.Concrete or Enum.Material.Metal
                b.Color = Color3.fromRGB(rng:NextInteger(80,160), rng:NextInteger(70,150), rng:NextInteger(90,170))
                b.TopSurface = Enum.SurfaceType.Smooth
                b.Parent = cityFolder
                local texId
                if AssetIds.has and AssetIds.has("brick") then texId = AssetIds.brick
                elseif AssetIds.has and AssetIds.has("concrete") then texId = AssetIds.concrete
                elseif AssetIds.has and AssetIds.has("skyscraper_windows") then texId = AssetIds.skyscraper_windows
                end
                if texId then
                    for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
                        local dec = Instance.new("Decal", b)
                        dec.Face = face
                        dec.Texture = texId
                    end
                end
                -- Window glow on multiple faces for symmetry, dimmer per-face
                for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back}) do
                    local sl = Instance.new("SurfaceLight", b)
                    sl.Face = face
                    sl.Range = 18; sl.Brightness = 0.5
                    sl.Color = Color3.fromRGB(255, 230, 160)
                end
            end
        end
    end
    print("[CityRebuild v5] procedural fallback: 48 buildings")
end

if #cityFolder:GetChildren() == 0 then
    task.spawn(function()
        local ok, model = pcall(function() return InsertService:LoadAsset(CITY_KIT_ID) end)
        if ok and model and #cityFolder:GetChildren() == 0 then
            cityLoaded = true
            for _, c in ipairs(model:GetChildren()) do
                c.Parent = cityFolder
            end
            -- Anchor every part so loose-Model assets don't fall.
            for _, d in ipairs(cityFolder:GetDescendants()) do
                if d:IsA("BasePart") then d.Anchored = true end
            end
            model:Destroy()
            print("[CityRebuild v5] Cyberpunk Neon City Kit loaded: "
                .. #cityFolder:GetChildren() .. " items")
        else
            warn("[CityRebuild v5] city kit load failed: " .. tostring(model))
        end
    end)
end

-- Procedural fallback after timeout, gated by cityLoaded so we never produce
-- two cities (real + procedural).
task.spawn(function()
    task.wait(10)
    buildProceduralFallback()
end)

-- 5. PLAZA
local plaza = Workspace:FindFirstChild("Plaza")
if not plaza then
    plaza = Instance.new("Folder")
    plaza.Name = "Plaza"
    plaza.Parent = Workspace
end
plaza:SetAttribute("KittyRaiserKeep", true)
plaza:ClearAllChildren()

local pf = Instance.new("Part", plaza)
pf.Name = "PlazaFloor"
pf.Anchored = true; pf.CanCollide = true
pf.Size = Vector3.new(140, 2, 140)
pf.Position = Vector3.new(0, 1.0, 0)  -- top at y=2, just above KittyGround top (y=0)
pf.Material = Enum.Material.Concrete
pf.Color = Color3.fromRGB(180, 175, 165)
pf.TopSurface = Enum.SurfaceType.Smooth

-- Sign: lower brightness color since night ClockTime + Neon was blinding.
local sign = Instance.new("Part", plaza)
sign.Anchored = true; sign.CanCollide = false
sign.Size = Vector3.new(80, 18, 1)
sign.Position = Vector3.new(0, 17, -64)
sign.Material = Enum.Material.SmoothPlastic
sign.Color = Color3.fromRGB(40, 20, 20)
local sg = Instance.new("SurfaceGui", sign); sg.Face = Enum.NormalId.Front
sg.LightInfluence = 0  -- the GUI itself emits, not the part
local stl = Instance.new("TextLabel", sg)
stl.Size = UDim2.fromScale(1, 1); stl.BackgroundTransparency = 1
stl.Text = "WELCOME TO KITTYRAISER"
stl.Font = Enum.Font.GothamBlack
stl.TextScaled = true
stl.TextColor3 = Color3.fromRGB(255, 130, 110)
stl.TextStrokeTransparency = 0
stl.TextStrokeColor3 = Color3.fromRGB(40, 0, 0)

-- 6. PARTICLE POOL FOR PRANKS
local pool = Workspace:FindFirstChild("PrankParticlePool") or Instance.new("Folder", Workspace)
pool.Name = "PrankParticlePool"
pool:SetAttribute("KittyRaiserKeep", true)

if nukedPink > 0 then
    print(("[CityRebuild v5] removed %d placeholder pink parts"):format(nukedPink))
end
print("[CityRebuild v5] DONE — geometry ready (lighting handled by StrayLighting)")
