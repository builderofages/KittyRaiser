-- CombatFeel.client.lua  — Grok-tuned hit-stop, screen flash, FOV pulse, damage numbers
-- Listens to PrankRegistered events and plays satisfying feedback.
-- Place in: StarterPlayer > StarterPlayerScripts > CombatFeel (LocalScript)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local AssetIds = require(ReplicatedStorage.Modules:WaitForChild("AssetIds"))
local PrankConfig = require(ReplicatedStorage.Modules.PrankConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

-- Combo tracking
local combo = 0
local lastComboTime = 0
local COMBO_TIMEOUT = 3  -- sec

local comboGui = Instance.new("ScreenGui")
comboGui.Name = "ComboGui"
comboGui.IgnoreGuiInset = false
comboGui.ResetOnSpawn = false
comboGui.Parent = playerGui

local comboLabel = Instance.new("TextLabel")
comboLabel.Size = UDim2.new(0, 320, 0, 80)
comboLabel.Position = UDim2.new(0.5, -160, 0.18, 0)
comboLabel.BackgroundTransparency = 1
comboLabel.Text = ""
comboLabel.Font = Enum.Font.GothamBlack
comboLabel.TextScaled = true
comboLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
comboLabel.TextStrokeTransparency = 0
comboLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
comboLabel.Visible = false
comboLabel.Parent = comboGui

-- Screen flash overlay
local flashGui = Instance.new("ScreenGui")
flashGui.Name = "ScreenFlash"
flashGui.IgnoreGuiInset = true
flashGui.ResetOnSpawn = false
flashGui.DisplayOrder = 60
flashGui.Parent = playerGui
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = flashGui

local function comboColorFor(c)
  if c >= 20 then return Color3.fromRGB(255, 100, 255) end  -- rainbow-ish
  if c >= 10 then return Color3.fromRGB(255, 80, 80) end    -- red
  if c >= 5  then return Color3.fromRGB(255, 165, 0) end    -- orange
  return Color3.fromRGB(255, 220, 50)                       -- yellow
end

local function bumpCombo()
  local now = os.clock()
  if (now - lastComboTime) < COMBO_TIMEOUT then
    combo = combo + 1
  else
    combo = 1
  end
  lastComboTime = now
  if combo >= 2 then
    comboLabel.Text = "x" .. combo .. " COMBO"
    comboLabel.TextColor3 = comboColorFor(combo)
    comboLabel.Visible = true
    -- Pulse
    comboLabel.Size = UDim2.new(0, 320, 0, 80)
    TweenService:Create(comboLabel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 360, 0, 90)}):Play()
    task.delay(0.3, function()
      TweenService:Create(comboLabel, TweenInfo.new(0.15), {Size = UDim2.new(0, 320, 0, 80)}):Play()
    end)
    -- Auto fade
    task.delay(COMBO_TIMEOUT, function()
      if (os.clock() - lastComboTime) >= COMBO_TIMEOUT then
        TweenService:Create(comboLabel, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
        task.wait(0.5)
        comboLabel.Visible = false
        comboLabel.TextTransparency = 0
        combo = 0
      end
    end)
  end
end

-- Use Tween.Completed instead of task.wait so we don't block the caller and
-- so subsequent pranks don't stack waits and stutter the camera.
local function hitStop(durationMS)
  local origFov = camera.FieldOfView
  local up = TweenService:Create(camera,
    TweenInfo.new((durationMS or 80) / 1000 * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    {FieldOfView = origFov + 8})
  up:Play()
  up.Completed:Once(function()
    TweenService:Create(camera,
      TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
      {FieldOfView = origFov}
    ):Play()
  end)
end

local function screenFlash(color, intensity)
  flash.BackgroundColor3 = color
  flash.BackgroundTransparency = 1 - intensity
  TweenService:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
end

local function spawnDamageNumber(worldCFrame, amount)
  local part = Instance.new("Part")
  part.Anchored = true; part.CanCollide = false; part.Transparency = 1
  part.Size = Vector3.new(1, 1, 1)
  part.CFrame = worldCFrame + Vector3.new(math.random()*4-2, 4, math.random()*4-2)
  part.Parent = Workspace
  local g = Instance.new("BillboardGui")
  g.Size = UDim2.new(0, 200, 0, 80)
  g.AlwaysOnTop = true
  g.Parent = part
  local l = Instance.new("TextLabel")
  l.Size = UDim2.fromScale(1, 1)
  l.BackgroundTransparency = 1
  l.Text = "+" .. amount
  l.Font = Enum.Font.GothamBlack
  l.TextScaled = true
  l.TextColor3 = comboColorFor(combo)
  l.TextStrokeTransparency = 0
  l.TextStrokeColor3 = Color3.new(0, 0, 0)
  l.Parent = g
  task.spawn(function()
    for i = 1, 30 do
      part.CFrame = part.CFrame + Vector3.new(0, 0.18, 0)
      l.TextTransparency = i/30
      l.TextStrokeTransparency = i/30 * 0.7
      task.wait(0.04)
    end
    part:Destroy()
  end)
end

local function playPrankSound(prankName)
  local soundIdMap = {
    CatScratch  = AssetIds.cat_scratch,
    Pie         = AssetIds.pie_splat,
    Hairball    = AssetIds.fish_slap,
    Anvil       = AssetIds.anvil_clang,
    FartCloud   = AssetIds.tp_unroll,
    LaserEyes   = AssetIds.flight_whoosh,
    Whip        = AssetIds.cat_scratch,
    Purrgatory  = AssetIds.purrgatory,
  }
  local id = soundIdMap[prankName]
  if id and id ~= "rbxassetid://0" then
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = 1.0
    s.Parent = SoundService
    s:Play()
    Debris:AddItem(s, 4)
  end
end

if Remotes.PrankRegistered then
  Remotes.PrankRegistered.OnClientEvent:Connect(function(prankName, targetModel, chaos, fxPayload)
    local prank = PrankConfig.Pranks[prankName]
    bumpCombo()
    if prank and prank.screenShake and prank.screenShake > 0 then
      hitStop(80)
    end
    -- Screen flash color per prank
    local flashColor = Color3.fromRGB(255, 255, 200)
    if prankName == "Anvil" then flashColor = Color3.fromRGB(255, 200, 100)
    elseif prankName == "Pie" then flashColor = Color3.fromRGB(255, 240, 200)
    elseif prankName == "LaserEyes" then flashColor = Color3.fromRGB(255, 80, 80)
    elseif prankName == "Purrgatory" then flashColor = Color3.fromRGB(180, 80, 220)
    end
    screenFlash(flashColor, 0.35)
    -- Damage number
    if targetModel and targetModel.PrimaryPart and chaos and chaos > 0 then
      spawnDamageNumber(targetModel.PrimaryPart.CFrame, chaos)
    end
    -- Sound
    playPrankSound(prankName)
  end)
end

print("[CombatFeel] hit-stop, flash, combo, damage numbers, sounds wired")
