-- PreSpawnLobby v3 — Grok's fix: use direct ReplicatedStorage:WaitForChild for RemoteEvent
-- All other features same as v2 (3D rotating cat, cyberpunk skyline, 12 fur tiers, premium SPAWN button)
-- Place in: StarterPlayer > StarterPlayerScripts > PreSpawnLobby (LocalScript)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Get RemoteEvent the SAFE way
local requestSpawn = ReplicatedStorage:WaitForChild("RequestSpawnCustomization", 10)
if not requestSpawn then
  warn("[PreSpawnLobby] RequestSpawnCustomization RemoteEvent missing after 10s")
end

local FUR_OPTIONS = {
  {name = "Orange Tabby",  color = Color3.fromRGB(220, 130, 50),  rarity = "common"},
  {name = "Brown",          color = Color3.fromRGB(80, 60, 50),    rarity = "common"},
  {name = "Black",          color = Color3.fromRGB(40, 40, 40),    rarity = "common"},
  {name = "White",          color = Color3.fromRGB(220, 220, 215), rarity = "common"},
  {name = "Grey Tabby",     color = Color3.fromRGB(140, 130, 120), rarity = "common"},
  {name = "Cream",          color = Color3.fromRGB(255, 200, 180), rarity = "common"},
  {name = "Demon Pink",     color = Color3.fromRGB(255, 80, 180),  rarity = "rare"},
  {name = "Cyber Cyan",     color = Color3.fromRGB(80, 220, 255),  rarity = "rare"},
  {name = "Neon Lime",      color = Color3.fromRGB(150, 255, 80),  rarity = "rare"},
  {name = "Hellfire Red",   color = Color3.fromRGB(255, 60, 40),   rarity = "epic"},
  {name = "Void Purple",    color = Color3.fromRGB(140, 40, 220),  rarity = "epic"},
  {name = "Gold (Robux)",   color = Color3.fromRGB(255, 215, 0),   rarity = "robux"},
}
local RARITY_COLOR = {
  common = Color3.fromRGB(150, 150, 150),
  rare   = Color3.fromRGB(50, 200, 100),
  epic   = Color3.fromRGB(180, 80, 220),
  robux  = Color3.fromRGB(255, 215, 0),
}

local selectedIndex = 1
local catModel

local lobby = Instance.new("ScreenGui")
lobby.Name = "PreSpawnLobby"
lobby.IgnoreGuiInset = true
lobby.ResetOnSpawn = false
lobby.DisplayOrder = 50
lobby.Parent = playerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(10, 5, 25)
bg.Parent = lobby
local bgGrad = Instance.new("UIGradient", bg)
bgGrad.Color = ColorSequence.new{
  ColorSequenceKeypoint.new(0,   Color3.fromRGB(80, 30, 130)),
  ColorSequenceKeypoint.new(0.4, Color3.fromRGB(45, 20, 90)),
  ColorSequenceKeypoint.new(1,   Color3.fromRGB(8, 4, 20)),
}
bgGrad.Rotation = 90

-- Skyline
local skyline = Instance.new("Frame")
skyline.Size = UDim2.new(1, 0, 0.55, 0)
skyline.Position = UDim2.new(0, 0, 0.45, 0)
skyline.BackgroundTransparency = 1
skyline.Parent = lobby
local rng = Random.new(7)
for i = 1, 18 do
  local b = Instance.new("Frame")
  local h = rng:NextInteger(40, 95)
  local w = rng:NextInteger(40, 110)
  local x = (i - 0.5) / 18
  b.Size = UDim2.new(0, w, 0, h * 5)
  b.Position = UDim2.new(x, -w/2, 1, -h * 5 + 30)
  b.BackgroundColor3 = Color3.fromRGB(rng:NextInteger(15, 35), rng:NextInteger(8, 25), rng:NextInteger(35, 70))
  b.BorderSizePixel = 0
  b.Parent = skyline
  for w_y = 1, math.floor(h / 8) do
    for w_x = 1, math.floor(w / 12) do
      if rng:NextNumber() < 0.35 then
        local win = Instance.new("Frame", b)
        win.Size = UDim2.new(0, 4, 0, 6)
        win.Position = UDim2.new(0, w_x * 12, 0, w_y * 8 + 5)
        win.BackgroundColor3 = (rng:NextNumber() < 0.5) and Color3.fromRGB(255, 220, 120) or Color3.fromRGB(180, 220, 255)
        win.BorderSizePixel = 0
      end
    end
  end
  if rng:NextNumber() < 0.25 then
    local neon = Instance.new("Frame", b)
    neon.Size = UDim2.new(0, w * 0.7, 0, 4)
    neon.Position = UDim2.new(0.15, 0, 0, -2)
    local neonColors = {Color3.fromRGB(255,80,200), Color3.fromRGB(80,200,255), Color3.fromRGB(255,200,80)}
    neon.BackgroundColor3 = neonColors[rng:NextInteger(1, #neonColors)]
    neon.BorderSizePixel = 0
    Instance.new("UICorner", neon).CornerRadius = UDim.new(0, 2)
  end
end

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 130)
title.Position = UDim2.new(0, 0, 0.04, 0)
title.BackgroundTransparency = 1
title.Text = "KITTYRAISER"
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 100, 200)
title.TextStrokeTransparency = 0
title.TextStrokeColor3 = Color3.fromRGB(80, 0, 60)
title.Parent = lobby
local titleGrad = Instance.new("UIGradient", title)
titleGrad.Color = ColorSequence.new{
  ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 220)),
  ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 220, 255)),
}
titleGrad.Rotation = 90

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, 0, 0, 30)
subtitle.Position = UDim2.new(0, 0, 0.16, 0)
subtitle.BackgroundTransparency = 1
subtitle.Text = "▸ CHAOS CITY ◂"
subtitle.Font = Enum.Font.GothamBold
subtitle.TextScaled = true
subtitle.TextColor3 = Color3.fromRGB(180, 150, 220)
subtitle.Parent = lobby

-- 3D viewport
local previewFrame = Instance.new("Frame")
previewFrame.Size = UDim2.new(0, 320, 0, 320)
previewFrame.Position = UDim2.new(0.5, -160, 0.24, 0)
previewFrame.BackgroundColor3 = Color3.fromRGB(15, 10, 30)
previewFrame.BorderSizePixel = 0
previewFrame.Parent = lobby
Instance.new("UICorner", previewFrame).CornerRadius = UDim.new(1, 0)
local previewStroke = Instance.new("UIStroke", previewFrame)
previewStroke.Thickness = 4; previewStroke.Color = Color3.fromRGB(255, 100, 220)

local viewport = Instance.new("ViewportFrame")
viewport.Size = UDim2.fromScale(1, 1)
viewport.BackgroundTransparency = 1
viewport.Parent = previewFrame
Instance.new("UICorner", viewport).CornerRadius = UDim.new(1, 0)

local function buildCat(color)
  if catModel then catModel:Destroy() end
  local model = Instance.new("Model")
  local body = Instance.new("Part", model)
  body.Size = Vector3.new(2, 1.5, 3); body.Color = color; body.Material = Enum.Material.SmoothPlastic; body.Anchored = true
  body.CFrame = CFrame.new(0, 0, 0)
  local head = Instance.new("Part", model)
  head.Shape = Enum.PartType.Ball; head.Size = Vector3.new(1.6, 1.6, 1.6); head.Color = color
  head.Material = Enum.Material.SmoothPlastic; head.Anchored = true
  head.CFrame = body.CFrame * CFrame.new(0, 0.4, -1.8)
  for _, off in ipairs({Vector3.new(-0.4, 0.2, -0.7), Vector3.new(0.4, 0.2, -0.7)}) do
    local eye = Instance.new("Part", model)
    eye.Shape = Enum.PartType.Ball; eye.Size = Vector3.new(0.35, 0.35, 0.35)
    eye.Color = Color3.fromRGB(255, 255, 255); eye.Material = Enum.Material.Neon; eye.Anchored = true
    eye.CFrame = head.CFrame * CFrame.new(off)
    local pupil = Instance.new("Part", model)
    pupil.Shape = Enum.PartType.Ball; pupil.Size = Vector3.new(0.2, 0.32, 0.2)
    pupil.Color = Color3.fromRGB(50, 220, 100); pupil.Material = Enum.Material.Neon; pupil.Anchored = true
    pupil.CFrame = eye.CFrame * CFrame.new(0, 0, -0.12)
  end
  for _, off in ipairs({Vector3.new(-0.55, 0.85, -0.05), Vector3.new(0.55, 0.85, -0.05)}) do
    local ear = Instance.new("Part", model)
    ear.Size = Vector3.new(0.5, 0.7, 0.4); ear.Color = color
    ear.Material = Enum.Material.SmoothPlastic; ear.Anchored = true
    ear.CFrame = head.CFrame * CFrame.new(off) * CFrame.Angles(math.rad(-15), 0, 0)
  end
  for _, lp in ipairs({Vector3.new(-0.7, -1.0, -1.0), Vector3.new(0.7, -1.0, -1.0), Vector3.new(-0.7, -1.0, 1.0), Vector3.new(0.7, -1.0, 1.0)}) do
    local leg = Instance.new("Part", model)
    leg.Size = Vector3.new(0.55, 1.4, 0.55); leg.Color = color
    leg.Material = Enum.Material.SmoothPlastic; leg.Anchored = true
    leg.CFrame = body.CFrame * CFrame.new(lp)
  end
  for i = 1, 5 do
    local seg = Instance.new("Part", model)
    seg.Size = Vector3.new(0.45 - i*0.06, 0.45 - i*0.06, 0.7); seg.Color = color
    seg.Material = Enum.Material.SmoothPlastic; seg.Anchored = true
    local angle = math.rad(20 + i*5)
    seg.CFrame = body.CFrame * CFrame.new(0, 0.2 + i*0.25, 1.4 + i*0.55) * CFrame.Angles(angle, 0, 0)
  end
  model.Parent = viewport
  catModel = model
end

local catCamera = Instance.new("Camera")
catCamera.CFrame = CFrame.new(Vector3.new(0, 1.5, -7), Vector3.new(0, 0, 0))
catCamera.FieldOfView = 50
catCamera.Parent = viewport
viewport.CurrentCamera = catCamera

buildCat(FUR_OPTIONS[1].color)

local rotAngle = 0
RunService.RenderStepped:Connect(function(dt)
  rotAngle = rotAngle + dt * 0.7
  if catModel then
    catModel:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, rotAngle, 0))
  end
end)

-- Name + rarity
local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(0, 360, 0, 32)
nameLabel.Position = UDim2.new(0.5, -180, 0.61, 0)
nameLabel.BackgroundTransparency = 1
nameLabel.Text = FUR_OPTIONS[1].name
nameLabel.Font = Enum.Font.GothamBlack
nameLabel.TextScaled = true
nameLabel.TextColor3 = Color3.fromRGB(255, 240, 220)
nameLabel.TextStrokeTransparency = 0
nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
nameLabel.Parent = lobby

local rarityBadge = Instance.new("TextLabel")
rarityBadge.Size = UDim2.new(0, 120, 0, 22)
rarityBadge.Position = UDim2.new(0.5, -60, 0.65, 0)
rarityBadge.BackgroundColor3 = RARITY_COLOR.common
rarityBadge.Text = "COMMON"
rarityBadge.Font = Enum.Font.GothamBold
rarityBadge.TextScaled = true
rarityBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
rarityBadge.Parent = lobby
Instance.new("UICorner", rarityBadge).CornerRadius = UDim.new(0, 6)

-- Color picker
local pickerRow = Instance.new("Frame")
pickerRow.Size = UDim2.new(0, 920, 0, 80)
pickerRow.Position = UDim2.new(0.5, -460, 0.74, 0)
pickerRow.BackgroundTransparency = 1
pickerRow.Parent = lobby
local layout = Instance.new("UIListLayout", pickerRow)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 8)

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

for i, opt in ipairs(FUR_OPTIONS) do
  local card = Instance.new("Frame", pickerRow)
  card.Size = UDim2.new(0, 65, 0, 65)
  card.BackgroundColor3 = opt.color
  card.BorderSizePixel = 0
  Instance.new("UICorner", card).CornerRadius = UDim.new(1, 0)
  local sStroke = Instance.new("UIStroke", card)
  sStroke.Thickness = (i == 1) and 5 or 1
  sStroke.Color = (i == 1) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(80, 80, 100)
  local rRing = Instance.new("UIStroke", card)
  rRing.Thickness = 2; rRing.Color = RARITY_COLOR[opt.rarity] or RARITY_COLOR.common
  rRing.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
  if opt.rarity == "robux" then
    local robux = Instance.new("TextLabel", card)
    robux.Size = UDim2.new(0, 24, 0, 24); robux.Position = UDim2.new(1, -22, 0, -2)
    robux.BackgroundColor3 = Color3.fromRGB(255, 215, 0); robux.Text = "R$"
    robux.Font = Enum.Font.GothamBold; robux.TextScaled = true; robux.TextColor3 = Color3.fromRGB(0, 0, 0)
    Instance.new("UICorner", robux).CornerRadius = UDim.new(1, 0)
  end
  local btn = Instance.new("TextButton", card)
  btn.Size = UDim2.fromScale(1, 1); btn.BackgroundTransparency = 1; btn.Text = ""
  btn.MouseButton1Click:Connect(function() setSelected(i) end)
  btn.MouseEnter:Connect(function()
    TweenService:Create(card, TweenInfo.new(0.15), {Size = UDim2.new(0, 75, 0, 75)}):Play()
  end)
  btn.MouseLeave:Connect(function()
    TweenService:Create(card, TweenInfo.new(0.15), {Size = UDim2.new(0, 65, 0, 65)}):Play()
  end)
end

-- SPAWN button
local spawnBtn = Instance.new("TextButton")
spawnBtn.Size = UDim2.new(0, 360, 0, 80)
spawnBtn.Position = UDim2.new(0.5, -180, 0.86, 0)
spawnBtn.BackgroundColor3 = Color3.fromRGB(50, 220, 110)
spawnBtn.Text = "▶ SPAWN INTO CHAOS"
spawnBtn.Font = Enum.Font.GothamBlack
spawnBtn.TextScaled = true
spawnBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
spawnBtn.TextStrokeTransparency = 0
spawnBtn.TextStrokeColor3 = Color3.fromRGB(0, 60, 30)
spawnBtn.Parent = lobby
Instance.new("UICorner", spawnBtn).CornerRadius = UDim.new(0, 14)
local btnStroke = Instance.new("UIStroke", spawnBtn)
btnStroke.Thickness = 3; btnStroke.Color = Color3.fromRGB(255, 255, 255)
local spawnGrad = Instance.new("UIGradient", spawnBtn)
spawnGrad.Color = ColorSequence.new{
  ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 255, 160)),
  ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 180, 90)),
}
spawnGrad.Rotation = 90

task.spawn(function()
  while spawnBtn.Parent do
    TweenService:Create(spawnBtn, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Size = UDim2.new(0, 380, 0, 86)}):Play()
    task.wait(1.6)
  end
end)

spawnBtn.MouseButton1Click:Connect(function()
  spawnBtn.Active = false
  spawnBtn.Text = "SPAWNING..."
  print("[PreSpawnLobby] SPAWN clicked, sending RequestSpawnCustomization")
  local opt = FUR_OPTIONS[selectedIndex]
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
hint.Size = UDim2.new(1, 0, 0, 30)
hint.Position = UDim2.new(0, 0, 0.96, -30)
hint.BackgroundTransparency = 1
hint.Text = "✦ Cat RP   ✦ 8 Pranks   ✦ Gangs   ✦ 100 Levels   ✦ 75 Skins   ✦ Real Cat Physics ✦"
hint.Font = Enum.Font.GothamBold
hint.TextScaled = true
hint.TextColor3 = Color3.fromRGB(180, 150, 220)
hint.Parent = lobby

print("[PreSpawnLobby v3 grokfix] ready, requestSpawn = " .. tostring(requestSpawn))
