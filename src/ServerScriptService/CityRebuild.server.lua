-- CityRebuild.server.lua  v4 — Grok-tuned cinematic lighting + Toolbox city kit insertion
-- Runs on server boot. No manual paste needed.

local Workspace = game:GetService("Workspace")
local Lighting  = game:GetService("Lighting")
local Players   = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[CityRebuild v4] booting...")

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

-- 1. GROK CINEMATIC LIGHTING
Lighting.Technology = Enum.Technology.Future
Lighting.Brightness = 3.8
Lighting.Ambient = Color3.fromRGB(90, 40, 140)
Lighting.OutdoorAmbient = Color3.fromRGB(120, 80, 180)
Lighting.GlobalShadows = true
Lighting.ClockTime = 19
Lighting.GeographicLatitude = 41.5
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.6

local function ensureFx(cls, props)
  local fx = Lighting:FindFirstChildOfClass(cls)
  if not fx then fx = Instance.new(cls); fx.Parent = Lighting end
  for k, v in pairs(props) do pcall(function() fx[k] = v end) end
  return fx
end
ensureFx("BloomEffect",          {Intensity = 2.9, Size = 28, Threshold = 1.65})
ensureFx("ColorCorrectionEffect",{Saturation = 0.30, Contrast = 0.18, TintColor = Color3.fromRGB(255, 230, 220)})
ensureFx("DepthOfFieldEffect",   {FocusDistance = 50, InFocusRadius = 20, FarIntensity = 0.06, NearIntensity = 0.02})
ensureFx("SunRaysEffect",        {Intensity = 0.22, Spread = 0.7})

local atm = Lighting:FindFirstChildOfClass("Atmosphere")
if not atm then atm = Instance.new("Atmosphere"); atm.Parent = Lighting end
atm.Density = 0.28; atm.Offset = 0.22
atm.Color = Color3.fromRGB(110, 30, 160)
atm.Decay = Color3.fromRGB(70, 20, 110)
atm.Glare = 0.5; atm.Haze = 1.8

-- 2. NUKE BROKEN ASSETS
local function isPink(c)
  if not c then return false end
  return c.R > 0.75 and c.B > 0.55 and c.G < 0.45
end
local nukedPink = 0
for _, p in ipairs(Workspace:GetDescendants()) do
  if p:IsA("BasePart") and isPink(p.Color) and (p.Size.X > 6 or p.Size.Z > 6) then
    p:Destroy(); nukedPink = nukedPink + 1
  end
end
local KILL_NAMES = {"ToolboxCity", "Lowpoly", "LowPoly", "CityTiles"}
for _, n in ipairs(KILL_NAMES) do
  local o = Workspace:FindFirstChild(n)
  while o do o:Destroy(); o = Workspace:FindFirstChild(n) end
end

-- 3. SAFE GROUND
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
if AssetIds.has("asphalt") then
  local existing = g:FindFirstChildOfClass("Decal")
  if not existing then
    local d = Instance.new("Decal", g)
    d.Texture = AssetIds.asphalt
    d.Face = Enum.NormalId.Top
  end
end

-- 4. SAFE SPAWN
for _, sp in ipairs(Workspace:GetDescendants()) do
  if sp:IsA("SpawnLocation") then sp:Destroy() end
end
local s = Instance.new("SpawnLocation")
s.Name = "MainSpawn"
s.Anchored = true; s.CanCollide = true
s.Size = Vector3.new(8, 1, 8)
s.CFrame = CFrame.new(0, 5, 24)
s.Material = Enum.Material.SmoothPlastic
s.Transparency = 1
s.Parent = Workspace

-- 5. INSERT GROK'S CYBERPUNK CITY KIT (asset 139781692633505)
local CITY_KIT_ID = 139781692633505
local cityFolder = Workspace:FindFirstChild("CyberpunkCity") or Instance.new("Folder", Workspace)
cityFolder.Name = "CyberpunkCity"
if #cityFolder:GetChildren() == 0 then
  task.spawn(function()
    local ok, model = pcall(function() return InsertService:LoadAsset(CITY_KIT_ID) end)
    if ok and model then
      for _, c in ipairs(model:GetChildren()) do c.Parent = cityFolder end
      model:Destroy()
      print("[CityRebuild v4] Cyberpunk Neon City Kit loaded: " .. #cityFolder:GetChildren() .. " items")
    else
      warn("[CityRebuild v4] city kit load failed: " .. tostring(model))
    end
  end)
end

-- 6. PROCEDURAL FALLBACK CITY (in case kit fails)
task.spawn(function()
  task.wait(8)  -- give InsertService a chance
  if #cityFolder:GetChildren() == 0 then
    print("[CityRebuild v4] city kit didn't load — building procedural fallback")
    local rng = Random.new(42)
    -- 60 buildings on a road grid
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
          b.Position = Vector3.new(cx, h/2 + 1, cz)
          b.Material = (rng:NextNumber() < 0.5) and Enum.Material.Concrete or Enum.Material.Metal
          b.Color = Color3.fromRGB(rng:NextInteger(80,160), rng:NextInteger(70,150), rng:NextInteger(90,170))
          b.TopSurface = Enum.SurfaceType.Smooth
          b.Parent = cityFolder
          -- Apply uploaded brick/window/concrete texture as Decal per face (per Grok)
          local texId
          if AssetIds.has("brick") then texId = AssetIds.brick
          elseif AssetIds.has("concrete") then texId = AssetIds.concrete
          elseif AssetIds.has("skyscraper_windows") then texId = AssetIds.skyscraper_windows
          end
          if texId then
            for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
              local d = Instance.new("Decal", b)
              d.Face = face
              d.Texture = texId
            end
          end
          -- Lit window glow
          local sl = Instance.new("SurfaceLight", b)
          sl.Face = Enum.NormalId.Front
          sl.Range = 18; sl.Brightness = 0.6
          sl.Color = Color3.fromRGB(255, 230, 160)
        end
      end
    end
    print("[CityRebuild v4] procedural fallback: 48 buildings")
  end
end)

-- 7. PLAZA
local plaza = Workspace:FindFirstChild("Plaza") or Instance.new("Folder", Workspace)
plaza.Name = "Plaza"
plaza:ClearAllChildren()
local pf = Instance.new("Part", plaza)
pf.Name = "PlazaFloor"
pf.Anchored = true; pf.CanCollide = true
pf.Size = Vector3.new(140, 2, 140)
pf.Position = Vector3.new(0, 1.5, 0)
pf.Material = Enum.Material.Concrete
pf.Color = Color3.fromRGB(180, 175, 165)
pf.TopSurface = Enum.SurfaceType.Smooth

local sign = Instance.new("Part", plaza)
sign.Anchored = true; sign.CanCollide = false
sign.Size = Vector3.new(80, 18, 1)
sign.Position = Vector3.new(0, 17, -64)
sign.Material = Enum.Material.Neon
sign.Color = Color3.fromRGB(255, 80, 60)
local sg = Instance.new("SurfaceGui", sign); sg.Face = Enum.NormalId.Front
local stl = Instance.new("TextLabel", sg)
stl.Size = UDim2.fromScale(1, 1); stl.BackgroundTransparency = 1
stl.Text = "WELCOME TO KITTYRAISER"
stl.Font = Enum.Font.GothamBlack
stl.TextScaled = true
stl.TextColor3 = Color3.fromRGB(255, 230, 200)

-- 8. PARTICLE POOL FOR PRANKS
local pool = Workspace:FindFirstChild("PrankParticlePool") or Instance.new("Folder", Workspace)
pool.Name = "PrankParticlePool"

print("[CityRebuild v4] DONE — city + lighting + plaza + particle pool ready")
