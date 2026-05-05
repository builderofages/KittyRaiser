-- PreSpawnLobby v4 — compact UI revamp.
-- v3 was too big: 320x320 preview + 65x65 cards + 360x80 spawn button took
-- up the whole screen and clipped the picker. v4 reduces preview to 220px,
-- cards to 50px (60px hover), spawn 260x60. All 24 skins fit in 2 rows on
-- desktop, wrap to 3-4 on phone. Title smaller too.
-- Place in: StarterPlayer > StarterPlayerScripts > PreSpawnLobby (LocalScript)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIUtil = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIUtil"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Get the RemoteEvent the way the SERVER expects: via the RemoteEvents module
-- under ReplicatedStorage.Modules. RemotesBootstrap also creates a copy at
-- ReplicatedStorage root, but the server's CatCharacterBuilder connects to
-- the module copy, so we MUST use the module to make the round-trip work.
-- (Fur color was previously not persisting from lobby because the lobby
-- fired the root copy while the server listened on the folder copy.)
local Remotes
do
  local mods = ReplicatedStorage:WaitForChild("Modules", 10)
  local re = mods and mods:WaitForChild("RemoteEvents", 5)
  if re then
    local ok, mod = pcall(require, re)
    if ok then Remotes = mod end
  end
end
local requestSpawn = Remotes and Remotes.RequestSpawnCustomization
-- Belt-and-suspenders: also fall back to the root copy so we don't break
-- if the module path fails. RemotesBootstrap creates the root copy.
if not requestSpawn then
  requestSpawn = ReplicatedStorage:WaitForChild("RequestSpawnCustomization", 5)
end
if not requestSpawn then
  warn("[PreSpawnLobby] RequestSpawnCustomization not found via module OR root after 15s")
end

local FUR_OPTIONS = {
  -- COMMON (8)
  {name = "Orange Tabby",   color = Color3.fromRGB(220, 130, 50),  rarity = "common"},
  {name = "Brown",          color = Color3.fromRGB(105, 75, 55),   rarity = "common"},
  {name = "Black",          color = Color3.fromRGB(45, 40, 40),    rarity = "common"},
  {name = "White",          color = Color3.fromRGB(225, 220, 210), rarity = "common"},
  {name = "Grey Tabby",     color = Color3.fromRGB(150, 140, 130), rarity = "common"},
  {name = "Cream",          color = Color3.fromRGB(245, 215, 175), rarity = "common"},
  {name = "Charcoal",       color = Color3.fromRGB(70, 65, 65),    rarity = "common"},
  {name = "Caramel",        color = Color3.fromRGB(195, 130, 80),  rarity = "common"},
  -- RARE (8)
  {name = "Calico",         color = Color3.fromRGB(225, 165, 95),  rarity = "rare"},
  {name = "Russian Blue",   color = Color3.fromRGB(140, 160, 175), rarity = "rare"},
  {name = "Tortoiseshell",  color = Color3.fromRGB(95, 65, 40),    rarity = "rare"},
  {name = "Maine Coon",     color = Color3.fromRGB(165, 115, 75),  rarity = "rare"},
  {name = "Persian",        color = Color3.fromRGB(235, 220, 200), rarity = "rare"},
  {name = "Lilac Point",    color = Color3.fromRGB(200, 185, 195), rarity = "rare"},
  {name = "Cinnamon",       color = Color3.fromRGB(180, 110, 75),  rarity = "rare"},
  {name = "Smoke Grey",     color = Color3.fromRGB(125, 120, 130), rarity = "rare"},
  -- EPIC (5)
  {name = "Sunset Ginger",  color = Color3.fromRGB(235, 110, 55),  rarity = "epic"},
  {name = "Snow Bengal",    color = Color3.fromRGB(245, 230, 195), rarity = "epic"},
  {name = "Midnight Velvet",color = Color3.fromRGB(35, 30, 50),    rarity = "epic"},
  {name = "Sapphire",       color = Color3.fromRGB(80, 130, 195),  rarity = "epic"},
  {name = "Rose Champagne", color = Color3.fromRGB(230, 175, 165), rarity = "epic"},
  -- ROBUX (3) — gated below by ownership check; promptPurchase if not owned.
  {name = "Gold",           color = Color3.fromRGB(225, 175, 75),  rarity = "robux", gamepassKey = "GOLD_SKIN"},
  {name = "Pearl",          color = Color3.fromRGB(235, 230, 240), rarity = "robux", gamepassKey = "PEARL_SKIN"},
  {name = "Ember",          color = Color3.fromRGB(220, 95, 50),   rarity = "robux", gamepassKey = "EMBER_SKIN"},
}
local RARITY_COLOR = {
  common = Color3.fromRGB(150, 145, 135),
  rare   = Color3.fromRGB(110, 165, 95),
  epic   = Color3.fromRGB(195, 130, 75),
  robux  = Color3.fromRGB(225, 175, 75),
}

local selectedIndex = 1
local catModel

local lobby = Instance.new("ScreenGui")
lobby.Name = "PreSpawnLobby"
lobby.IgnoreGuiInset = true
lobby.ResetOnSpawn = false
lobby.DisplayOrder = UIUtil.DisplayOrder.PreSpawnLobby
lobby.Parent = playerGui

-- Sunny daytime sky background (gradient)
local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(170, 215, 240)
bg.Parent = lobby
local bgGrad = Instance.new("UIGradient", bg)
bgGrad.Color = ColorSequence.new{
  ColorSequenceKeypoint.new(0,   Color3.fromRGB(220, 240, 255)),  -- pale top
  ColorSequenceKeypoint.new(0.55, Color3.fromRGB(150, 200, 235)), -- mid sky
  ColorSequenceKeypoint.new(1,   Color3.fromRGB(255, 220, 170)),  -- warm horizon
}
bgGrad.Rotation = 90

-- Cartoon clouds drifting across
local cloudLayer = Instance.new("Frame")
cloudLayer.Size = UDim2.fromScale(1, 0.6)
cloudLayer.BackgroundTransparency = 1
cloudLayer.Parent = lobby
local rng = Random.new(13)
for i = 1, 8 do
  local cloud = Instance.new("Frame", cloudLayer)
  local cw = rng:NextInteger(120, 220)
  local ch = rng:NextInteger(40, 60)
  cloud.Size = UDim2.fromOffset(cw, ch)
  cloud.Position = UDim2.new(rng:NextNumber(), 0, rng:NextNumber() * 0.7, 0)
  cloud.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
  cloud.BackgroundTransparency = 0.15
  cloud.BorderSizePixel = 0
  Instance.new("UICorner", cloud).CornerRadius = UDim.new(1, 0)
end

-- Cartoon city silhouette at the bottom (warm browns + ochres, NOT cyberpunk)
local skyline = Instance.new("Frame")
skyline.Size = UDim2.new(1, 0, 0.32, 0)
skyline.Position = UDim2.new(0, 0, 0.68, 0)
skyline.BackgroundTransparency = 1
skyline.Parent = lobby
for i = 1, 14 do
  local b = Instance.new("Frame")
  local h = rng:NextInteger(60, 140)
  local w = rng:NextInteger(50, 120)
  local x = (i - 0.5) / 14
  b.Size = UDim2.new(0, w, 0, h * 2)
  b.Position = UDim2.new(x, -w/2, 1, -h * 2 + 20)
  -- Warm brick / sandstone palette
  local palette = {
    Color3.fromRGB(170, 110, 80),
    Color3.fromRGB(190, 175, 150),
    Color3.fromRGB(140, 100, 75),
    Color3.fromRGB(210, 195, 175),
  }
  b.BackgroundColor3 = palette[rng:NextInteger(1, #palette)]
  b.BorderSizePixel = 0
  b.Parent = skyline
  -- Window grid (warm yellow, no neon)
  for w_y = 1, math.floor(h / 10) do
    for w_x = 1, math.floor(w / 14) do
      if rng:NextNumber() < 0.65 then
        local win = Instance.new("Frame", b)
        win.Size = UDim2.new(0, 6, 0, 8)
        win.Position = UDim2.new(0, w_x * 14, 0, w_y * 12 + 5)
        win.BackgroundColor3 = Color3.fromRGB(255, 220, 140)
        win.BorderSizePixel = 0
      end
    end
  end
end

-- Title — compact wood-stained "KITTYRAISER" sign
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 80)
title.Position = UDim2.new(0, 0, 0.02, 0)
title.BackgroundTransparency = 1
title.Text = "KITTYRAISER"
title.Font = Enum.Font.LuckiestGuy
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(80, 40, 20)
title.TextStrokeTransparency = 0.3
title.TextStrokeColor3 = Color3.fromRGB(255, 240, 200)
title.Parent = lobby
local titleC = Instance.new("UITextSizeConstraint", title)
titleC.MinTextSize = 36; titleC.MaxTextSize = 70

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, 0, 0, 22)
subtitle.Position = UDim2.new(0, 0, 0.13, 0)
subtitle.BackgroundTransparency = 1
subtitle.Text = "pick your cat"
subtitle.Font = Enum.Font.LuckiestGuy
subtitle.TextScaled = true
subtitle.TextColor3 = Color3.fromRGB(120, 70, 40)
subtitle.Parent = lobby
local subC = Instance.new("UITextSizeConstraint", subtitle)
subC.MinTextSize = 12; subC.MaxTextSize = 18

-- 3D viewport — compact 220x220
local previewFrame = Instance.new("Frame")
previewFrame.Size = UDim2.new(0, 220, 0, 220)
previewFrame.Position = UDim2.new(0.5, -110, 0.18, 0)
previewFrame.BackgroundColor3 = Color3.fromRGB(245, 230, 200)
previewFrame.BorderSizePixel = 0
previewFrame.Parent = lobby
Instance.new("UICorner", previewFrame).CornerRadius = UDim.new(1, 0)
local previewStroke = Instance.new("UIStroke", previewFrame)
previewStroke.Thickness = 5; previewStroke.Color = Color3.fromRGB(110, 75, 40)  -- wood frame

local viewport = Instance.new("ViewportFrame")
viewport.Size = UDim2.fromScale(1, 1)
viewport.BackgroundTransparency = 1
viewport.Parent = previewFrame
Instance.new("UICorner", viewport).CornerRadius = UDim.new(1, 0)

local function buildCat(color)
  if catModel then catModel:Destroy() end
  local model = Instance.new("Model")

  local function part(props)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Material = Enum.Material.SmoothPlastic
    for k, v in pairs(props) do p[k] = v end
    p.Parent = model
    return p
  end

  -- Body — sleek oblong, slightly tapered
  local body = part{
    Size = Vector3.new(1.6, 1.2, 2.4),
    Color = color,
    CFrame = CFrame.new(0, 0, 0),
  }

  -- Chest (slightly forward bulge)
  part{
    Shape = Enum.PartType.Ball,
    Size = Vector3.new(1.5, 1.3, 1.5),
    Color = color,
    CFrame = body.CFrame * CFrame.new(0, 0, -0.8),
  }

  -- Head — proportional, sits forward
  local head = part{
    Shape = Enum.PartType.Ball,
    Size = Vector3.new(1.35, 1.3, 1.3),
    Color = color,
    CFrame = body.CFrame * CFrame.new(0, 0.45, -1.55),
  }

  -- Cheeks (subtle bulge for cat face)
  for _, side in ipairs({-0.45, 0.45}) do
    part{
      Shape = Enum.PartType.Ball,
      Size = Vector3.new(0.6, 0.55, 0.55),
      Color = color,
      CFrame = head.CFrame * CFrame.new(side, -0.15, -0.2),
    }
  end

  -- Eyes (sclera + slit pupil)
  for _, off in ipairs({Vector3.new(-0.32, 0.1, -0.55), Vector3.new(0.32, 0.1, -0.55)}) do
    part{
      Shape = Enum.PartType.Ball,
      Size = Vector3.new(0.32, 0.32, 0.32),
      Color = Color3.fromRGB(255, 255, 255),
      Material = Enum.Material.SmoothPlastic,
      CFrame = head.CFrame * CFrame.new(off),
    }
    part{
      Shape = Enum.PartType.Ball,
      Size = Vector3.new(0.12, 0.26, 0.12),
      Color = Color3.fromRGB(60, 220, 110),
      Material = Enum.Material.Neon,
      CFrame = head.CFrame * CFrame.new(off + Vector3.new(0, 0, -0.1)),
    }
  end

  -- Nose
  part{
    Shape = Enum.PartType.Ball,
    Size = Vector3.new(0.18, 0.14, 0.14),
    Color = Color3.fromRGB(255, 130, 150),
    CFrame = head.CFrame * CFrame.new(0, -0.18, -0.6),
  }

  -- Ears (outer + pink inner)
  for _, side in ipairs({-1, 1}) do
    local off = Vector3.new(side * 0.4, 0.7, -0.05)
    local angle = side * math.rad(8)
    local ear = part{
      Size = Vector3.new(0.4, 0.6, 0.15),
      Color = color,
      CFrame = head.CFrame * CFrame.new(off) * CFrame.Angles(math.rad(-5), angle, 0),
    }
    part{
      Size = Vector3.new(0.22, 0.38, 0.05),
      Color = Color3.fromRGB(255, 180, 200),
      CFrame = ear.CFrame * CFrame.new(0, 0, -0.08),
    }
  end

  -- Whiskers (thin black lines via stretched parts)
  for _, side in ipairs({-1, 1}) do
    for _, yOff in ipairs({-0.05, -0.18, -0.31}) do
      part{
        Size = Vector3.new(0.55, 0.025, 0.025),
        Color = Color3.fromRGB(40, 40, 40),
        CFrame = head.CFrame * CFrame.new(side * 0.65, yOff, -0.45),
      }
    end
  end

  -- Legs (slim cat legs)
  for _, lp in ipairs({
    Vector3.new(-0.45, -0.85, -0.7),
    Vector3.new( 0.45, -0.85, -0.7),
    Vector3.new(-0.45, -0.85,  0.85),
    Vector3.new( 0.45, -0.85,  0.85),
  }) do
    part{
      Size = Vector3.new(0.4, 1.0, 0.4),
      Color = color,
      CFrame = body.CFrame * CFrame.new(lp),
    }
    -- White paw tip (cute detail)
    part{
      Size = Vector3.new(0.45, 0.2, 0.5),
      Color = Color3.fromRGB(245, 240, 230),
      CFrame = body.CFrame * CFrame.new(lp + Vector3.new(0, -0.55, 0.05)),
    }
  end

  -- Tail (curved arc using small segments, but offsets relative to body so it's behind cat)
  local tailColors = {color, color, color, color, color}
  local startCF = body.CFrame * CFrame.new(0, 0.2, 1.2)
  local prevCF = startCF
  local prevSize = 0.42
  for i = 1, 6 do
    local size = math.max(0.22, prevSize - 0.03)
    local pitch = math.rad(-18 - i * 4)  -- arc the tail upward and back
    local seg = part{
      Size = Vector3.new(size, size, 0.6),
      Color = tailColors[((i-1) % #tailColors) + 1],
      CFrame = prevCF * CFrame.Angles(pitch, 0, 0) * CFrame.new(0, 0, 0.4),
    }
    prevCF = seg.CFrame
    prevSize = size
  end

  model.PrimaryPart = body
  model.Parent = viewport
  catModel = model
end

local catCamera = Instance.new("Camera")
catCamera.CFrame = CFrame.new(Vector3.new(0, 1.2, -6.5), Vector3.new(0, 0, 0))
catCamera.FieldOfView = 50
catCamera.Parent = viewport
viewport.CurrentCamera = catCamera

-- Pleasant viewport lighting (pink + cyan rim light vibe)
pcall(function()
  viewport.Ambient = Color3.fromRGB(120, 100, 160)
  viewport.LightColor = Color3.fromRGB(255, 220, 240)
  viewport.LightDirection = Vector3.new(-0.3, -0.8, 0.4).Unit
end)

buildCat(FUR_OPTIONS[1].color)

local rotAngle = 0
RunService.RenderStepped:Connect(function(dt)
  rotAngle = rotAngle + dt * 0.7
  if catModel then
    catModel:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, rotAngle, 0))
  end
end)

-- Name + rarity (compact, side-by-side under preview)
local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(0, 280, 0, 26)
nameLabel.Position = UDim2.new(0.5, -140, 0.49, 0)
nameLabel.BackgroundTransparency = 1
nameLabel.Text = FUR_OPTIONS[1].name
nameLabel.Font = Enum.Font.LuckiestGuy
nameLabel.TextScaled = true
nameLabel.TextColor3 = Color3.fromRGB(80, 40, 20)
nameLabel.TextStrokeTransparency = 0.4
nameLabel.TextStrokeColor3 = Color3.fromRGB(255, 240, 200)
nameLabel.Parent = lobby
local nameC = Instance.new("UITextSizeConstraint", nameLabel)
nameC.MinTextSize = 14; nameC.MaxTextSize = 22

local rarityBadge = Instance.new("TextLabel")
rarityBadge.Size = UDim2.new(0, 90, 0, 18)
rarityBadge.Position = UDim2.new(0.5, -45, 0.535, 0)
rarityBadge.BackgroundColor3 = RARITY_COLOR.common
rarityBadge.Text = "COMMON"
rarityBadge.Font = Enum.Font.GothamBold
rarityBadge.TextScaled = true
rarityBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
rarityBadge.Parent = lobby
Instance.new("UICorner", rarityBadge).CornerRadius = UDim.new(0, 5)
local rbC = Instance.new("UITextSizeConstraint", rarityBadge)
rbC.MinTextSize = 9; rbC.MaxTextSize = 12

-- Color picker — compact 50x50 cards, two rows of 12 wraps cleanly on all
-- screens; ScreenGui width-flex still lets phone fall to 3+ rows.
local pickerRow = Instance.new("Frame")
pickerRow.Size = UDim2.new(0.96, 0, 0, 116)  -- 96% width, 2 rows @ 50px + 6px gap + slack
pickerRow.AnchorPoint = Vector2.new(0.5, 0)
pickerRow.Position = UDim2.new(0.5, 0, 0.59, 0)
pickerRow.BackgroundTransparency = 1
pickerRow.Parent = lobby
local layout = Instance.new("UIListLayout", pickerRow)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Top
layout.Padding = UDim.new(0, 6)
layout.Wraps = true

local function setSelected(i)
  selectedIndex = i
  local opt = FUR_OPTIONS[i]
  buildCat(opt.color)
  nameLabel.Text = opt.name
  rarityBadge.Text = opt.rarity:upper()
  rarityBadge.BackgroundColor3 = RARITY_COLOR[opt.rarity] or RARITY_COLOR.common
  for j, btn in ipairs(pickerRow:GetChildren()) do
    if btn:IsA("Frame") then
      local s = btn:FindFirstChildOfClass("UIStroke")
      if s then
        s.Thickness = (j-1 == i) and 5 or 1
        s.Color = (j-1 == i) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(80, 80, 100)
      end
    end
  end
end

-- v3.74 LOBBY POLISH: arrow ◄ ► cycle replaces 24-circle grid
-- Container holds left arrow + big preview swatch + right arrow + dot indicator + name+rarity
pickerRow.Size = UDim2.new(0.96, 0, 0, 132)

local function makeArrow(text, position)
    local a = Instance.new("TextButton", pickerRow)
    a.Size = UDim2.new(0, 56, 0, 56)
    a.AnchorPoint = Vector2.new(position == "left" and 0 or 1, 0.5)
    a.Position = (position == "left") and UDim2.new(0, 60, 0.5, 0) or UDim2.new(1, -60, 0.5, 0)
    a.BackgroundColor3 = Color3.fromRGB(220, 150, 60)
    a.Text = text
    a.Font = Enum.Font.LuckiestGuy
    a.TextScaled = true
    a.TextColor3 = Color3.fromRGB(255, 250, 235)
    a.TextStrokeTransparency = 0.3
    a.TextStrokeColor3 = Color3.fromRGB(80, 40, 20)
    Instance.new("UICorner", a).CornerRadius = UDim.new(1, 0)
    local s = Instance.new("UIStroke", a)
    s.Thickness = 3; s.Color = Color3.fromRGB(110, 75, 40)
    return a
end

local prevBtn = makeArrow("<", "left")
local nextBtn = makeArrow(">", "right")

-- Big center swatch preview
local centerSwatch = Instance.new("Frame", pickerRow)
centerSwatch.Size = UDim2.new(0, 90, 0, 90)
centerSwatch.AnchorPoint = Vector2.new(0.5, 0.5)
centerSwatch.Position = UDim2.new(0.5, 0, 0.5, 0)
centerSwatch.BackgroundColor3 = FUR_OPTIONS[1].color
centerSwatch.BorderSizePixel = 0
Instance.new("UICorner", centerSwatch).CornerRadius = UDim.new(1, 0)
local swStroke = Instance.new("UIStroke", centerSwatch)
swStroke.Thickness = 5; swStroke.Color = Color3.fromRGB(255, 255, 255)
local rarityRing = Instance.new("UIStroke", centerSwatch)
rarityRing.Thickness = 3; rarityRing.Color = RARITY_COLOR[FUR_OPTIONS[1].rarity] or RARITY_COLOR.common
rarityRing.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Optional R$ badge for paid skins
local robuxBadge = Instance.new("TextLabel", centerSwatch)
robuxBadge.Size = UDim2.new(0, 28, 0, 28)
robuxBadge.AnchorPoint = Vector2.new(1, 0)
robuxBadge.Position = UDim2.new(1, -2, 0, -2)
robuxBadge.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
robuxBadge.Text = "R$"
robuxBadge.Font = Enum.Font.GothamBold
robuxBadge.TextScaled = true
robuxBadge.TextColor3 = Color3.fromRGB(0, 0, 0)
robuxBadge.Visible = false
Instance.new("UICorner", robuxBadge).CornerRadius = UDim.new(1, 0)

-- Dot indicator strip showing position in list
local dotsContainer = Instance.new("Frame", pickerRow)
dotsContainer.Size = UDim2.new(1, -200, 0, 12)
dotsContainer.AnchorPoint = Vector2.new(0.5, 1)
dotsContainer.Position = UDim2.new(0.5, 0, 1, -8)
dotsContainer.BackgroundTransparency = 1
local dotsLayout = Instance.new("UIListLayout", dotsContainer)
dotsLayout.FillDirection = Enum.FillDirection.Horizontal
dotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
dotsLayout.Padding = UDim.new(0, 3)
local dots = {}
for i = 1, #FUR_OPTIONS do
    local d = Instance.new("Frame", dotsContainer)
    d.Size = UDim2.new(0, 8, 0, 8)
    d.BorderSizePixel = 0
    d.BackgroundColor3 = (i == 1) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 110, 100)
    Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
    dots[i] = d
end

-- Override setSelected to update arrow-cycle UI (keep original cat preview + name/rarity update behavior)
local _prevSetSelected = setSelected
setSelected = function(i)
    if i < 0 then i = #FUR_OPTIONS - 1 end
    if i >= #FUR_OPTIONS then i = 0 end
    selectedIndex = i
    local opt = FUR_OPTIONS[i + 1]
    buildCat(opt.color)
    nameLabel.Text = opt.name
    rarityBadge.Text = opt.rarity:upper()
    rarityBadge.BackgroundColor3 = RARITY_COLOR[opt.rarity] or RARITY_COLOR.common
    centerSwatch.BackgroundColor3 = opt.color
    rarityRing.Color = RARITY_COLOR[opt.rarity] or RARITY_COLOR.common
    robuxBadge.Visible = (opt.rarity == "robux")
    for j, d in ipairs(dots) do
        d.BackgroundColor3 = (j - 1 == i) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 110, 100)
    end
end

prevBtn.MouseButton1Click:Connect(function() setSelected(selectedIndex - 1) end)
nextBtn.MouseButton1Click:Connect(function() setSelected(selectedIndex + 1) end)

-- DUMMY closure to swallow the original loop body's `end`s — original loop is replaced
-- Keep the iteration variable scope clean by using a no-op for loop guard
for _, _ in ipairs({}) do

end

-- SPAWN button — compact wooden plank style
local spawnBtn = Instance.new("TextButton")
spawnBtn.Size = UDim2.new(0, 260, 0, 60)
spawnBtn.Position = UDim2.new(0.5, -130, 0.85, 0)
spawnBtn.BackgroundColor3 = Color3.fromRGB(220, 150, 60)
spawnBtn.Text = "SPAWN"
spawnBtn.Font = Enum.Font.LuckiestGuy
spawnBtn.TextScaled = true
spawnBtn.TextColor3 = Color3.fromRGB(255, 250, 235)
spawnBtn.TextStrokeTransparency = 0.3
spawnBtn.TextStrokeColor3 = Color3.fromRGB(80, 40, 20)
spawnBtn.Parent = lobby
local spawnC = Instance.new("UITextSizeConstraint", spawnBtn)
spawnC.MinTextSize = 20; spawnC.MaxTextSize = 34
Instance.new("UICorner", spawnBtn).CornerRadius = UDim.new(0, 12)
local btnStroke = Instance.new("UIStroke", spawnBtn)
btnStroke.Thickness = 3; btnStroke.Color = Color3.fromRGB(110, 75, 40)
local spawnGrad = Instance.new("UIGradient", spawnBtn)
spawnGrad.Color = ColorSequence.new{
  ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 195, 100)),
  ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 125, 50)),
}
spawnGrad.Rotation = 90

task.spawn(function()
  while spawnBtn.Parent do
    TweenService:Create(spawnBtn, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Size = UDim2.new(0, 276, 0, 64)}):Play()
    task.wait(1.6)
  end
end)

-- Cached gamepass ownership lookup (so the spawn click is fast).
local MarketplaceService = game:GetService("MarketplaceService")
local GameConfig
do
  local mods = ReplicatedStorage:WaitForChild("Modules", 5)
  local gc = mods and mods:WaitForChild("GameConfig", 5)
  if gc then local ok, mod = pcall(require, gc); if ok then GameConfig = mod end end
end
local function ownsGamepass(gamepassKey)
  if not GameConfig or not GameConfig.GAMEPASS_IDS then return false end
  local id = GameConfig.GAMEPASS_IDS[gamepassKey]
  if not id or id == 0 then return false end
  local ok, owns = pcall(function()
    return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
  end)
  return ok and owns
end

spawnBtn.MouseButton1Click:Connect(function()
  local opt = FUR_OPTIONS[selectedIndex]

  -- Robux-tier furs: gate behind gamepass ownership. If not owned, prompt
  -- purchase and DON'T spawn yet — the player can re-click after buying.
  if opt.rarity == "robux" and opt.gamepassKey then
    if not ownsGamepass(opt.gamepassKey) then
      local id = GameConfig and GameConfig.GAMEPASS_IDS[opt.gamepassKey]
      if id and id ~= 0 then
        pcall(function() MarketplaceService:PromptGamePassPurchase(player, id) end)
      end
      -- Reset spawn button so they can pick a different fur or buy and retry
      spawnBtn.Text = "SPAWN"
      return
    end
  end

  spawnBtn.Active = false
  spawnBtn.Text = "SPAWNING..."
  print("[PreSpawnLobby] SPAWN clicked, sending RequestSpawnCustomization")
  if requestSpawn then
    requestSpawn:FireServer({
      furColor = {math.floor(opt.color.R*255), math.floor(opt.color.G*255), math.floor(opt.color.B*255)},
      skinName = opt.name,
    })
    print("[PreSpawnLobby] FireServer sent")
  else
    warn("[PreSpawnLobby] requestSpawn is nil — RemoteEvent missing")
  end
  TweenService:Create(bg, TweenInfo.new(0.6), {BackgroundTransparency = 1}):Play()
  TweenService:Create(title, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
  TweenService:Create(spawnBtn, TweenInfo.new(0.4), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
  task.wait(0.7)
  lobby:Destroy()
end)

local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, 0, 0, 26)
hint.Position = UDim2.new(0, 0, 0.96, -28)
hint.BackgroundTransparency = 1
hint.Text = ""
hint.Font = Enum.Font.GothamBold
hint.TextScaled = true
hint.TextColor3 = Color3.fromRGB(120, 70, 40)
hint.Parent = lobby
local hintC = Instance.new("UITextSizeConstraint", hint)
hintC.MinTextSize = 12; hintC.MaxTextSize = 18

print("[PreSpawnLobby v4 compact] ready, requestSpawn = " .. tostring(requestSpawn))
