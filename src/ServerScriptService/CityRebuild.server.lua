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

-- 1. LIGHTING: defer to StrayLighting (single source of truth).
-- If StrayLighting hasn't run yet, give it a moment, then leave it alone.
if not Lighting:GetAttribute("KittyLightingConfigured") then
  task.wait(0.5)
end

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

-- 3. SAFE GROUND — wet asphalt feel
local g = Workspace:FindFirstChild("KittyGround")
if not g then
  g = Instance.new("Part")
  g.Name = "KittyGround"
  g.Anchored = true; g.CanCollide = true
  g.Size = Vector3.new(4000, 4, 4000)
  g.Position = Vector3.new(0, -2, 0)
  g.Material = Enum.Material.Slate
  g.Color = Color3.fromRGB(38, 36, 44)
  g.Reflectance = 0.05
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

-- 6. PROCEDURAL FALLBACK CITY — proper neon skyline with window grids + neon trim
task.spawn(function()
  task.wait(8)  -- give InsertService a chance
  if #cityFolder:GetChildren() > 0 then return end
  print("[CityRebuild v5] building procedural skyline")

  local rng = Random.new(42)
  local NEON_COLORS = {
    Color3.fromRGB(255, 80, 200),   -- hot pink
    Color3.fromRGB(80, 220, 255),   -- cyan
    Color3.fromRGB(255, 200, 80),   -- amber
    Color3.fromRGB(180, 80, 255),   -- purple
    Color3.fromRGB(120, 255, 180),  -- mint
  }
  local BUILDING_COLORS = {
    Color3.fromRGB(35, 35, 50),
    Color3.fromRGB(50, 38, 60),
    Color3.fromRGB(40, 50, 65),
    Color3.fromRGB(28, 28, 35),
  }

  local SP = 220  -- spacing between buildings
  for gx = -3, 3 do
    for gz = -3, 3 do
      if math.abs(gx) > 0 or math.abs(gz) > 0 then
        local cx = gx * SP + rng:NextInteger(-40, 40)
        local cz = gz * SP + rng:NextInteger(-40, 40)
        local h  = rng:NextInteger(80, 220)
        local w  = rng:NextInteger(45, 80)
        local d  = rng:NextInteger(45, 80)

        local b = Instance.new("Part")
        b.Anchored = true; b.CanCollide = true
        b.Size = Vector3.new(w, h, d)
        b.Position = Vector3.new(cx, h/2 + 1, cz)
        b.Material = Enum.Material.Concrete
        b.Color = BUILDING_COLORS[rng:NextInteger(1, #BUILDING_COLORS)]
        b.TopSurface = Enum.SurfaceType.Smooth
        b.Parent = cityFolder

        -- Window grid via SurfaceGui per side: chunky cells visible from distance.
        for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
          local faceW = (face == Enum.NormalId.Front or face == Enum.NormalId.Back) and w or d
          local cols = math.max(3, math.floor(faceW / 8))
          local rows = math.max(4, math.floor(h / 10))
          local sg = Instance.new("SurfaceGui")
          sg.Face = face
          sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
          sg.PixelsPerStud = 4
          sg.LightInfluence = 0
          sg.Parent = b
          local container = Instance.new("Frame")
          container.Size = UDim2.fromScale(1, 1)
          container.BackgroundTransparency = 1
          container.Parent = sg
          local pad = Instance.new("UIPadding", container)
          pad.PaddingLeft = UDim.new(0.04, 0); pad.PaddingRight = UDim.new(0.04, 0)
          pad.PaddingTop = UDim.new(0.05, 0); pad.PaddingBottom = UDim.new(0.05, 0)
          local grid = Instance.new("UIGridLayout", container)
          grid.CellSize = UDim2.new(1/cols - 0.02, 0, 1/rows - 0.02, 0)
          grid.CellPadding = UDim2.new(0.02, 0, 0.02, 0)
          grid.SortOrder = Enum.SortOrder.LayoutOrder
          for _ = 1, cols * rows do
            local win = Instance.new("Frame")
            local lit = rng:NextNumber() < 0.50
            if lit then
              win.BackgroundColor3 = (rng:NextNumber() < 0.65)
                  and Color3.fromRGB(255, 220, 140)
                  or Color3.fromRGB(120, 200, 255)
            else
              win.BackgroundColor3 = Color3.fromRGB(10, 12, 22)
            end
            win.BorderSizePixel = 0
            win.Parent = container
          end
        end

        -- Neon trim along top edge of building (a thin neon part)
        local trim = Instance.new("Part")
        trim.Anchored = true; trim.CanCollide = false
        trim.Size = Vector3.new(w + 1, 1, d + 1)
        trim.Position = Vector3.new(cx, h + 1.5, cz)
        trim.Material = Enum.Material.Neon
        trim.Color = NEON_COLORS[rng:NextInteger(1, #NEON_COLORS)]
        trim.Parent = cityFolder

        -- Random neon billboard panel on the side (one in three buildings)
        if rng:NextNumber() < 0.35 then
          local bbHeight = rng:NextInteger(15, 30)
          local bbWidth  = rng:NextInteger(20, 35)
          local bbColor  = NEON_COLORS[rng:NextInteger(1, #NEON_COLORS)]
          local side = (rng:NextNumber() < 0.5) and 1 or -1
          local axis = (rng:NextNumber() < 0.5) and "x" or "z"
          local bb = Instance.new("Part")
          bb.Anchored = true; bb.CanCollide = false
          bb.Material = Enum.Material.Neon
          bb.Color = bbColor
          if axis == "x" then
            bb.Size = Vector3.new(0.5, bbHeight, bbWidth)
            bb.Position = Vector3.new(cx + side * (w/2 + 0.4), h - bbHeight/2 - 5, cz)
          else
            bb.Size = Vector3.new(bbWidth, bbHeight, 0.5)
            bb.Position = Vector3.new(cx, h - bbHeight/2 - 5, cz + side * (d/2 + 0.4))
          end
          bb.Parent = cityFolder
        end
      end
    end
  end
  print("[CityRebuild v5] procedural skyline ready: 48 buildings + neon")
end)

-- 7. PLAZA — neon-strip plaza with proper materials
local plaza = Workspace:FindFirstChild("Plaza") or Instance.new("Folder", Workspace)
plaza.Name = "Plaza"
plaza:ClearAllChildren()

-- Floor: pavement
local pf = Instance.new("Part", plaza)
pf.Name = "PlazaFloor"
pf.Anchored = true; pf.CanCollide = true
pf.Size = Vector3.new(140, 2, 140)
pf.Position = Vector3.new(0, 1.5, 0)
pf.Material = Enum.Material.Pavement
pf.Color = Color3.fromRGB(70, 70, 78)
pf.TopSurface = Enum.SurfaceType.Smooth

-- Cyan glow strip running along plaza edge for that neon-noir vibe
for _, edge in ipairs({
  {pos = Vector3.new(0, 2.6, -69),  size = Vector3.new(140, 0.2, 1)},
  {pos = Vector3.new(0, 2.6,  69),  size = Vector3.new(140, 0.2, 1)},
  {pos = Vector3.new(-69, 2.6, 0),  size = Vector3.new(1, 0.2, 140)},
  {pos = Vector3.new( 69, 2.6, 0),  size = Vector3.new(1, 0.2, 140)},
}) do
  local strip = Instance.new("Part", plaza)
  strip.Anchored = true; strip.CanCollide = false
  strip.Size = edge.size
  strip.Position = edge.pos
  strip.Material = Enum.Material.Neon
  strip.Color = Color3.fromRGB(80, 220, 255)
  strip.TopSurface = Enum.SurfaceType.Smooth
end

-- Welcome sign — pink neon, framed
local frame = Instance.new("Part", plaza)
frame.Anchored = true; frame.CanCollide = false
frame.Size = Vector3.new(86, 22, 1)
frame.Position = Vector3.new(0, 17, -65)
frame.Material = Enum.Material.Metal
frame.Color = Color3.fromRGB(28, 28, 36)

local sign = Instance.new("Part", plaza)
sign.Anchored = true; sign.CanCollide = false
sign.Size = Vector3.new(80, 18, 0.5)
sign.Position = Vector3.new(0, 17, -64.5)
sign.Material = Enum.Material.Neon
sign.Color = Color3.fromRGB(255, 80, 200)
local sg = Instance.new("SurfaceGui", sign); sg.Face = Enum.NormalId.Front
sg.LightInfluence = 0
sg.PixelsPerStud = 20
sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
local stl = Instance.new("TextLabel", sg)
stl.AnchorPoint = Vector2.new(0.5, 0.5)
stl.Position = UDim2.fromScale(0.5, 0.5)
stl.Size = UDim2.new(0.94, 0, 0.7, 0)  -- give margin so text doesn't crash sign edges
stl.BackgroundTransparency = 1
stl.Text = "WELCOME TO KITTYRAISER"
stl.Font = Enum.Font.GothamBlack
stl.TextScaled = true
stl.TextColor3 = Color3.fromRGB(255, 240, 250)
stl.TextStrokeTransparency = 0.4
stl.TextStrokeColor3 = Color3.fromRGB(120, 30, 90)
local stc = Instance.new("UITextSizeConstraint", stl)
stc.MinTextSize = 60; stc.MaxTextSize = 220

-- Pink + cyan flood lights on the sign
for _, side in ipairs({-30, 30}) do
  local floodbox = Instance.new("Part", plaza)
  floodbox.Anchored = true; floodbox.CanCollide = false
  floodbox.Size = Vector3.new(2, 2, 2)
  floodbox.Position = Vector3.new(side, 26, -64)
  floodbox.Material = Enum.Material.Metal
  floodbox.Color = Color3.fromRGB(40, 40, 50)
  local sl = Instance.new("SpotLight", floodbox)
  sl.Range = 60
  sl.Brightness = 6
  sl.Angle = 90
  sl.Face = Enum.NormalId.Bottom
  sl.Color = (side < 0) and Color3.fromRGB(255, 120, 220) or Color3.fromRGB(120, 220, 255)
end

-- 8. PARTICLE POOL FOR PRANKS
local pool = Workspace:FindFirstChild("PrankParticlePool") or Instance.new("Folder", Workspace)
pool.Name = "PrankParticlePool"

print("[CityRebuild v4] DONE — city + lighting + plaza + particle pool ready")
