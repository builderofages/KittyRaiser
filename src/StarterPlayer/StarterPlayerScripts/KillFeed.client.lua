-- KillFeed.client.lua — top-right scrolling feed of recent prank events
-- Place in: StarterPlayer > StarterPlayerScripts > KillFeed (LocalScript)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local UIUtil = require(ReplicatedStorage.Modules:WaitForChild("UIUtil"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local feed = Instance.new("ScreenGui")
feed.Name = "KillFeed"
feed.IgnoreGuiInset = false
feed.ResetOnSpawn = false
feed.DisplayOrder = UIUtil.DisplayOrder.KillFeed
feed.Parent = playerGui

-- Container is right-anchored and clamped to fit narrow phones.
-- Uses Scale anchor on X so it always sits at right edge with a fixed margin.
local function computeContainerWidth()
  local vp = UIUtil.viewportSize()
  -- Cap at 320 on desktop; on phones leave room for prank column on right side
  -- of the screen (which is ~80px wide). So feed sits to the LEFT of prank column.
  return math.max(220, math.min(320, vp.X - 120))
end

local container = Instance.new("Frame")
container.AnchorPoint = Vector2.new(1, 0)
container.Size = UDim2.new(0, computeContainerWidth(), 0, 240)
container.Position = UDim2.new(1, -100, 0, 110)  -- left of prank column, below TopBar
container.BackgroundTransparency = 1
container.Parent = feed
local layout = Instance.new("UIListLayout", container)
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder

-- Re-clamp on viewport resize (window dragged, mobile rotation, etc.)
local cam = workspace.CurrentCamera
if cam then
  cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    container.Size = UDim2.new(0, computeContainerWidth(), 0, 240)
  end)
end

local entries = {}
local nextOrder = 0

local function addEntry(text, color)
  nextOrder = nextOrder - 1
  local row = Instance.new("Frame")
  -- Fill the container width so rows reflow when viewport changes
  row.Size = UDim2.new(1, 0, 0, 30)
  row.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
  row.BackgroundTransparency = 0.4
  row.BorderSizePixel = 0
  row.LayoutOrder = nextOrder
  row.Parent = container
  Instance.new("UICorner", row).CornerRadius = UIUtil.Token.cornerSm
  local bar = Instance.new("Frame", row)
  bar.Size = UDim2.new(0, 4, 1, 0)
  bar.BackgroundColor3 = color or Color3.fromRGB(255, 100, 200)
  bar.BorderSizePixel = 0
  Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)
  local label = Instance.new("TextLabel", row)
  label.Size = UDim2.new(1, -16, 1, 0)
  label.Position = UDim2.new(0, 12, 0, 0)
  label.BackgroundTransparency = 1
  label.Text = text
  label.Font = Enum.Font.GothamBold
  label.TextScaled = true
  label.TextColor3 = Color3.fromRGB(255, 255, 255)
  label.TextStrokeTransparency = 0
  label.TextStrokeColor3 = Color3.new(0, 0, 0)
  label.TextXAlignment = Enum.TextXAlignment.Left
  UIUtil.boundText(label, 13, 18)
  -- Slide in
  row.Position = UDim2.new(0, 350, 0, row.Position.Y.Offset)
  TweenService:Create(row, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
  table.insert(entries, row)
  -- Limit 6 entries
  while #entries > 6 do
    local old = table.remove(entries, 1)
    if old then old:Destroy() end
  end
  -- Auto fade after 8s
  task.delay(8, function()
    if not row.Parent then return end
    TweenService:Create(row, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
    TweenService:Create(label, TweenInfo.new(0.5), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    task.wait(0.6)
    row:Destroy()
    for i, r in ipairs(entries) do
      if r == row then table.remove(entries, i); break end
    end
  end)
end

if Remotes.PrankRegistered then
  Remotes.PrankRegistered.OnClientEvent:Connect(function(prankName, targetModel, chaos, fxPayload)
    if not chaos or chaos <= 0 then return end  -- only show for prankers, not nearby viewers
    local color = Color3.fromRGB(255, 100, 200)
    if prankName == "Anvil" then color = Color3.fromRGB(255, 180, 80)
    elseif prankName == "LaserEyes" then color = Color3.fromRGB(255, 80, 80)
    elseif prankName == "Purrgatory" then color = Color3.fromRGB(180, 80, 220)
    end
    addEntry(player.DisplayName .. "  ·  " .. prankName .. "  ·  +" .. chaos, color)
  end)
end

if Remotes.LevelUp then
  Remotes.LevelUp.OnClientEvent:Connect(function(newLevel, unlocked)
    addEntry("LEVEL UP  >  " .. newLevel, Color3.fromRGB(50, 220, 100))
    if unlocked then
      for _, name in ipairs(unlocked) do
        addEntry("NEW PRANK  >  " .. name, Color3.fromRGB(255, 215, 0))
      end
    end
  end)
end

print("[KillFeed] right-side prank/level feed ready")
