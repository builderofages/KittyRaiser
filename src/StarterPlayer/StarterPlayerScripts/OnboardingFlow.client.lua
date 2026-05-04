-- OnboardingFlow.client.lua — Grok's #1 priority: 15-sec guided first-prank tutorial with massive payoff
-- Place in: StarterPlayer > StarterPlayerScripts > OnboardingFlow (LocalScript)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local UIUtil = require(ReplicatedStorage.Modules:WaitForChild("UIUtil"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Skip if already onboarded
if player:GetAttribute("OnboardingDone") then return end

-- Wait for spawn
task.wait(4)
local hud = playerGui:WaitForChild("MainHUD", 30)
if not hud then return end

local PALETTE = {
  bgDark    = Color3.fromRGB(26, 20, 40),
  neonPink  = Color3.fromRGB(192, 38, 211),
  cyan      = Color3.fromRGB(34, 211, 238),
  gold      = Color3.fromRGB(250, 204, 21),
  green     = Color3.fromRGB(34, 197, 94),
  white     = Color3.fromRGB(245, 240, 250),
}

local overlay = Instance.new("ScreenGui")
overlay.Name = "OnboardingOverlay"
overlay.IgnoreGuiInset = true
overlay.ResetOnSpawn = false
overlay.DisplayOrder = UIUtil.DisplayOrder.Onboarding
overlay.Parent = playerGui

local function showStep(text, anchorRect)
  local box = Instance.new("Frame")
  box.Size = UDim2.new(0, 380, 0, 110)
  box.BackgroundColor3 = PALETTE.bgDark
  box.BorderSizePixel = 0
  box.Parent = overlay
  Instance.new("UICorner", box).CornerRadius = UDim.new(0, 14)
  local stroke = Instance.new("UIStroke", box)
  stroke.Thickness = 3; stroke.Color = PALETTE.neonPink
  local grad = Instance.new("UIGradient", box)
  grad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(48, 30, 90)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 14, 32)),
  }
  grad.Rotation = 90

  local label = Instance.new("TextLabel", box)
  label.Size = UDim2.new(1, -24, 1, -24)
  label.Position = UDim2.fromOffset(12, 12)
  label.BackgroundTransparency = 1
  label.Text = text
  label.Font = Enum.Font.GothamBold
  label.TextScaled = true
  label.TextColor3 = PALETTE.white
  label.TextXAlignment = Enum.TextXAlignment.Center
  UIUtil.boundText(label, 16, 24)

  if anchorRect then
    box.Position = UDim2.fromOffset(anchorRect.X + anchorRect.Width/2 - 190, anchorRect.Y - 130)
  else
    box.Position = UDim2.new(0.5, -190, 0.4, 0)
  end

  -- Pulse
  task.spawn(function()
    while box.Parent do
      TweenService:Create(box, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Size = UDim2.new(0, 400, 0, 116)}):Play()
      task.wait(1)
    end
  end)
  return box
end

local function findHudButton(textPattern)
  for _, d in ipairs(hud:GetDescendants()) do
    if d:IsA("TextButton") and d.Text and d.Text:find(textPattern) then return d end
  end
  for _, d in ipairs(hud:GetDescendants()) do
    if d:IsA("ImageButton") and d.Name:find(textPattern) then return d end
  end
  return nil
end

local function spotlight(targetGui)
  if not targetGui then return nil end
  local r = targetGui.AbsolutePosition
  local s = targetGui.AbsoluteSize
  local ring = Instance.new("Frame")
  ring.Size = UDim2.fromOffset(s.X + 30, s.Y + 30)
  ring.Position = UDim2.fromOffset(r.X - 15, r.Y - 15)
  ring.BackgroundTransparency = 1
  ring.Parent = overlay
  local stroke = Instance.new("UIStroke", ring)
  stroke.Thickness = 4
  stroke.Color = PALETTE.gold
  task.spawn(function()
    while ring.Parent do
      TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Size = UDim2.fromOffset(s.X + 50, s.Y + 50), Position = UDim2.fromOffset(r.X - 25, r.Y - 25)}):Play()
      task.wait(1)
    end
  end)
  return ring
end

local function massivePayoff()
  -- Big "+500 CHAOS!" with confetti
  local burst = Instance.new("Frame")
  burst.Size = UDim2.fromScale(1, 1)
  burst.BackgroundColor3 = PALETTE.gold
  burst.BackgroundTransparency = 0.7
  burst.BorderSizePixel = 0
  burst.Parent = overlay
  TweenService:Create(burst, TweenInfo.new(0.8), {BackgroundTransparency = 1}):Play()

  local big = Instance.new("TextLabel", overlay)
  big.Size = UDim2.new(0.7, 0, 0.25, 0)
  big.AnchorPoint = Vector2.new(0.5, 0.5)
  big.Position = UDim2.new(0.5, 0, 0.4, 0)
  big.BackgroundTransparency = 1
  big.Text = "+500 CHAOS\nLEVEL 2"
  big.Font = Enum.Font.GothamBlack
  big.TextScaled = true
  big.TextColor3 = PALETTE.gold
  big.TextStrokeTransparency = 0
  big.TextStrokeColor3 = Color3.new(0, 0, 0)
  big.Rotation = -8
  UIUtil.boundText(big, 28, 80)

  TweenService:Create(big, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    {Rotation = 0, Size = UDim2.new(0.85, 0, 0.32, 0)}):Play()

  -- Confetti particles (frame dots)
  for i = 1, 60 do
    local dot = Instance.new("Frame", overlay)
    dot.Size = UDim2.fromOffset(8, 8)
    dot.Position = UDim2.new(math.random(), 0, 0, -10)
    dot.BackgroundColor3 = ({PALETTE.gold, PALETTE.neonPink, PALETTE.cyan, PALETTE.green})[math.random(1, 4)]
    dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    task.spawn(function()
      TweenService:Create(dot, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(dot.Position.X.Scale, 0, 1.1, 0),
        Rotation = math.random(-360, 360),
      }):Play()
      task.wait(2.2)
      dot:Destroy()
    end)
  end

  task.delay(3, function()
    TweenService:Create(big, TweenInfo.new(0.6), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    task.wait(0.8)
    big:Destroy(); burst:Destroy()
  end)
end

----------------------------------------------------------------
-- Step 1: Welcome + spotlight on SUMMON HUMAN button
----------------------------------------------------------------
local welcome = showStep("Welcome.  Tap SUMMON HUMAN\nto spawn your first victim.")
local summonBtn = findHudButton("SUMMON") or findHudButton("Summon")
local ring1
if summonBtn then
  ring1 = spotlight(summonBtn)
  -- Wait for click
  local conn
  conn = summonBtn.MouseButton1Click:Connect(function()
    if conn then conn:Disconnect() end
    welcome:Destroy()
    if ring1 then ring1:Destroy() end
    -- Step 2 after delay
    task.wait(1.5)
    local step2 = showStep("NOW PRANK THEM\nTap a glowing prank")
    -- Find prank column
    local prankBtn
    local col = hud:FindFirstChild("PrankColumn", true)
    if col then prankBtn = col:FindFirstChildWhichIsA("TextButton", true) end
    local ring2
    if prankBtn then
      ring2 = spotlight(prankBtn)
      local conn2
      conn2 = prankBtn.MouseButton1Click:Connect(function()
        if conn2 then conn2:Disconnect() end
        step2:Destroy()
        if ring2 then ring2:Destroy() end
        -- Step 3: massive payoff
        task.wait(0.6)
        massivePayoff()
        player:SetAttribute("OnboardingDone", true)
        task.wait(4)
        overlay:Destroy()
      end)
    end
  end)
else
  -- Fallback: just show generic message and end
  task.wait(8)
  welcome:Destroy()
  if ring1 then ring1:Destroy() end
  player:SetAttribute("OnboardingDone", true)
  overlay:Destroy()
end

print("[OnboardingFlow] cinematic 2-step + massive payoff active")
