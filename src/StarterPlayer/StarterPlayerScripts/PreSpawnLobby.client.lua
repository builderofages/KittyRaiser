-- PreSpawnLobby.client.lua  — Grok-recommended #1 retention fix
-- Shows pre-spawn skin/color picker + spawn button BEFORE cat appears.
-- Place in: StarterPlayer > StarterPlayerScripts > PreSpawnLobby (LocalScript)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local FUR_OPTIONS = {
  {name = "Orange Tabby", color = Color3.fromRGB(220, 130, 50)},
  {name = "Brown",         color = Color3.fromRGB(80, 60, 50)},
  {name = "Black",         color = Color3.fromRGB(40, 40, 40)},
  {name = "White",         color = Color3.fromRGB(220, 220, 215)},
  {name = "Grey Tabby",    color = Color3.fromRGB(140, 130, 120)},
  {name = "Cream",         color = Color3.fromRGB(255, 200, 180)},
  {name = "Pink (rare)",   color = Color3.fromRGB(255, 150, 180)},
  {name = "Cyan (rare)",   color = Color3.fromRGB(120, 220, 255)},
}

local selectedIndex = 1

local lobby = Instance.new("ScreenGui")
lobby.Name = "PreSpawnLobby"
lobby.IgnoreGuiInset = true
lobby.ResetOnSpawn = false
lobby.Parent = playerGui

-- Background
local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(15, 5, 30)
bg.BackgroundTransparency = 0
bg.Parent = lobby
local bgGrad = Instance.new("UIGradient")
bgGrad.Color = ColorSequence.new{
  ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 20, 110)),
  ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 5, 30)),
}
bgGrad.Rotation = 90
bgGrad.Parent = bg

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 100)
title.Position = UDim2.new(0, 0, 0.05, 0)
title.BackgroundTransparency = 1
title.Text = "KITTYRAISER"
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 100, 200)
title.TextStrokeTransparency = 0
title.TextStrokeColor3 = Color3.new(0, 0, 0)
title.Parent = lobby

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, 0, 0, 40)
subtitle.Position = UDim2.new(0, 0, 0.18, 0)
subtitle.BackgroundTransparency = 1
subtitle.Text = "PICK YOUR CHAOS CAT"
subtitle.Font = Enum.Font.GothamBold
subtitle.TextScaled = true
subtitle.TextColor3 = Color3.fromRGB(180, 100, 200)
subtitle.Parent = lobby

-- Cat preview circle
local previewFrame = Instance.new("Frame")
previewFrame.Size = UDim2.new(0, 240, 0, 240)
previewFrame.Position = UDim2.new(0.5, -120, 0.32, 0)
previewFrame.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
previewFrame.BorderSizePixel = 0
previewFrame.Parent = lobby
local previewCorner = Instance.new("UICorner", previewFrame)
previewCorner.CornerRadius = UDim.new(1, 0)
local previewStroke = Instance.new("UIStroke", previewFrame)
previewStroke.Thickness = 4
previewStroke.Color = Color3.fromRGB(255, 100, 200)

local catEmoji = Instance.new("TextLabel")
catEmoji.Size = UDim2.fromScale(1, 1)
catEmoji.BackgroundTransparency = 1
catEmoji.Text = "🐈"
catEmoji.Font = Enum.Font.GothamBlack
catEmoji.TextScaled = true
catEmoji.TextColor3 = FUR_OPTIONS[selectedIndex].color
catEmoji.Parent = previewFrame

local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(0, 300, 0, 40)
nameLabel.Position = UDim2.new(0.5, -150, 0.62, 0)
nameLabel.BackgroundTransparency = 1
nameLabel.Text = FUR_OPTIONS[selectedIndex].name
nameLabel.Font = Enum.Font.GothamBold
nameLabel.TextScaled = true
nameLabel.TextColor3 = Color3.fromRGB(255, 230, 200)
nameLabel.Parent = lobby

-- Color picker row
local pickerRow = Instance.new("Frame")
pickerRow.Size = UDim2.new(0, 600, 0, 80)
pickerRow.Position = UDim2.new(0.5, -300, 0.7, 0)
pickerRow.BackgroundTransparency = 1
pickerRow.Parent = lobby
local layout = Instance.new("UIListLayout", pickerRow)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 8)

local function setSelected(i)
  selectedIndex = i
  catEmoji.TextColor3 = FUR_OPTIONS[i].color
  nameLabel.Text = FUR_OPTIONS[i].name
  for j, btn in ipairs(pickerRow:GetChildren()) do
    if btn:IsA("Frame") then
      local s = btn:FindFirstChildOfClass("UIStroke")
      if s then s.Thickness = (j-1 == i) and 4 or 1 end
    end
  end
end

for i, opt in ipairs(FUR_OPTIONS) do
  local swatch = Instance.new("Frame")
  swatch.Size = UDim2.new(0, 60, 0, 60)
  swatch.BackgroundColor3 = opt.color
  swatch.BorderSizePixel = 0
  swatch.Parent = pickerRow
  Instance.new("UICorner", swatch).CornerRadius = UDim.new(1, 0)
  local sStroke = Instance.new("UIStroke", swatch)
  sStroke.Thickness = (i == 1) and 4 or 1
  sStroke.Color = Color3.fromRGB(255, 255, 255)
  local btn = Instance.new("TextButton")
  btn.Size = UDim2.fromScale(1, 1)
  btn.BackgroundTransparency = 1
  btn.Text = ""
  btn.Parent = swatch
  btn.MouseButton1Click:Connect(function() setSelected(i) end)
end

-- SPAWN button
local spawnBtn = Instance.new("TextButton")
spawnBtn.Size = UDim2.new(0, 280, 0, 80)
spawnBtn.Position = UDim2.new(0.5, -140, 0.86, 0)
spawnBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
spawnBtn.Text = "SPAWN ▶"
spawnBtn.Font = Enum.Font.GothamBlack
spawnBtn.TextScaled = true
spawnBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
spawnBtn.Parent = lobby
Instance.new("UICorner", spawnBtn).CornerRadius = UDim.new(0, 12)
local btnStroke = Instance.new("UIStroke", spawnBtn)
btnStroke.Thickness = 3
btnStroke.Color = Color3.fromRGB(0, 100, 50)

spawnBtn.MouseButton1Click:Connect(function()
  -- Send selected color to server
  local opt = FUR_OPTIONS[selectedIndex]
  if Remotes.RequestSpawnCustomization then
    Remotes.RequestSpawnCustomization:FireServer({
      furColor = {math.floor(opt.color.R*255), math.floor(opt.color.G*255), math.floor(opt.color.B*255)},
      skinName = opt.name,
    })
  end
  -- Tween out
  TweenService:Create(bg, TweenInfo.new(0.6), {BackgroundTransparency = 1}):Play()
  TweenService:Create(title, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
  task.wait(0.7)
  lobby:Destroy()
end)

-- Tutorial hint at bottom
local hint = Instance.new("TextLabel")
hint.Size = UDim2.new(1, 0, 0, 30)
hint.Position = UDim2.new(0, 0, 0.96, -30)
hint.BackgroundTransparency = 1
hint.Text = "Cat RP ✦ Pranks ✦ Gangs ✦ Chaos ✦ 100 levels"
hint.Font = Enum.Font.Gotham
hint.TextScaled = true
hint.TextColor3 = Color3.fromRGB(180, 150, 200)
hint.Parent = lobby

print("[PreSpawnLobby] showing skin picker")
