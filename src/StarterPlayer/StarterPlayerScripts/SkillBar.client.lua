--[[
  SkillBar.client.lua  v3.95
  Diablo-style bottom skill bar wrapping the 8 existing pranks from PrankConfig.
  Replaces/hides the old PrankColumn. Works on PC (1-8 keys) and mobile (tap).
  Wires to existing Remotes.RequestPrank + Remotes.PrankRegistered.
--]]
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local PrankConfig  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PrankConfig"))

-- Order from PrankConfig: CatScratch, Pie, Hairball, Anvil, FartCloud, LaserEyes, Whip, Purrgatory
local ORDER = PrankConfig.Order   -- 8 entries

-- Icon map (emoji fallback — replace with ImageLabel asset IDs when art is ready)
local ICONS = {
  CatScratch = "🐾", Pie       = "🥧", Hairball = "🎱",
  Anvil      = "⚒️",  FartCloud = "💨", LaserEyes = "👁️",
  Whip       = "🌀",  Purrgatory = "💀",
}
local SLOT_W, SLOT_H = 70, 70
local PADDING        = 6
local BAR_W          = (#ORDER * (SLOT_W + PADDING)) + PADDING

-- ── Player level (read from leaderstats) ─────────────────────────────────────
local function getLevel()
  local ls = player:FindFirstChild("leaderstats")
  if ls then
    local lv = ls:FindFirstChild("Level") or ls:FindFirstChild("Lvl")
    if lv then return lv.Value end
  end
  return 1
end

-- ── Build GUI ────────────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "DiabloSkillBar"
screenGui.ResetOnSpawn    = false
screenGui.IgnoreGuiInset  = true
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.Parent          = playerGui

-- Outer container — bottom center, floats 6px above bottom edge
local bar = Instance.new("Frame")
bar.Name                  = "SkillBar"
bar.Size                  = UDim2.fromOffset(BAR_W, SLOT_H + PADDING * 2)
bar.Position              = UDim2.new(0.5, -BAR_W/2, 1, -(SLOT_H + PADDING * 2 + 8))
bar.BackgroundColor3      = Color3.fromRGB(12, 10, 16)
bar.BackgroundTransparency = 0.18
bar.BorderSizePixel       = 0
bar.Parent                = screenGui
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 12)

-- Tooltip strip above bar
local tip = Instance.new("TextLabel")
tip.Size                  = UDim2.fromOffset(500, 26)
tip.Position              = UDim2.new(0.5, -250, 1, -(SLOT_H + PADDING*2 + 8 + 30))
tip.BackgroundTransparency = 1
tip.TextColor3            = Color3.fromRGB(255, 230, 160)
tip.TextStrokeTransparency = 0.35
tip.Font                  = Enum.Font.GothamBold
tip.TextSize              = 14
tip.Text                  = ""
tip.Parent                = screenGui

-- ── Slot data ─────────────────────────────────────────────────────────────────
local slots = {}        -- [i] = { prankName, frame, cdOverlay, cdText, lockOverlay }
local clientCDs = {}    -- [prankName] = lastFiredTime (visual only; server is authoritative)

local function buildSlot(i, prankName)
  local prank  = PrankConfig.Pranks[prankName]
  local xOff   = PADDING + (i-1) * (SLOT_W + PADDING)
  local yOff   = PADDING

  -- Base colour from tier (higher unlock level = more intense colour)
  local lv     = prank.unlockLevel
  local hue    = (lv / 40)   -- 0..1
  local baseCol = Color3.fromHSV(hue * 0.85, 0.7, 0.85)

  local slot = Instance.new("Frame")
  slot.Name             = "Slot" .. i
  slot.Size             = UDim2.fromOffset(SLOT_W, SLOT_H)
  slot.Position         = UDim2.fromOffset(xOff, yOff)
  slot.BackgroundColor3 = baseCol
  slot.BackgroundTransparency = 0.25
  slot.BorderSizePixel  = 0
  slot.Parent           = bar
  Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 8)

  -- Key number badge (top-left)
  local badge = Instance.new("TextLabel")
  badge.Size              = UDim2.fromOffset(20, 20)
  badge.Position          = UDim2.fromOffset(3, 3)
  badge.BackgroundColor3  = Color3.fromRGB(0,0,0)
  badge.BackgroundTransparency = 0.45
  badge.BorderSizePixel   = 0
  badge.Text              = tostring(i)
  badge.TextColor3        = Color3.fromRGB(255,255,255)
  badge.Font              = Enum.Font.GothamBold
  badge.TextSize          = 11
  badge.ZIndex            = 3
  badge.Parent            = slot
  Instance.new("UICorner", badge).CornerRadius = UDim.new(0,4)

  -- Icon (emoji)
  local icon = Instance.new("TextLabel")
  icon.Size               = UDim2.new(1,0,0,36)
  icon.Position           = UDim2.fromOffset(0, 8)
  icon.BackgroundTransparency = 1
  icon.Text               = ICONS[prankName] or "❓"
  icon.TextSize           = 28
  icon.Font               = Enum.Font.GothamBold
  icon.ZIndex             = 2
  icon.Parent             = slot

  -- Display name (bottom)
  local label = Instance.new("TextLabel")
  label.Size              = UDim2.new(1,-4,0,16)
  label.Position          = UDim2.new(0,2,1,-18)
  label.BackgroundTransparency = 1
  label.Text              = prank.displayName
  label.TextColor3        = Color3.fromRGB(255,255,255)
  label.Font              = Enum.Font.GothamBold
  label.TextSize          = 8
  label.TextScaled        = true
  label.ZIndex            = 2
  label.Parent            = slot

  -- Cooldown overlay
  local cdOverlay = Instance.new("Frame")
  cdOverlay.Name              = "CDOverlay"
  cdOverlay.Size              = UDim2.new(1,0,1,0)
  cdOverlay.BackgroundColor3  = Color3.fromRGB(0,0,0)
  cdOverlay.BackgroundTransparency = 1
  cdOverlay.BorderSizePixel   = 0
  cdOverlay.ZIndex            = 4
  cdOverlay.Parent            = slot
  Instance.new("UICorner", cdOverlay).CornerRadius = UDim.new(0,8)

  local cdText = Instance.new("TextLabel")
  cdText.Size                 = UDim2.new(1,0,1,0)
  cdText.BackgroundTransparency = 1
  cdText.TextColor3           = Color3.fromRGB(255,255,255)
  cdText.Font                 = Enum.Font.GothamBold
  cdText.TextSize             = 20
  cdText.ZIndex               = 5
  cdText.Text                 = ""
  cdText.Parent               = cdOverlay

  -- Lock overlay (shown when skill not yet unlocked)
  local lockOverlay = Instance.new("Frame")
  lockOverlay.Name            = "LockOverlay"
  lockOverlay.Size            = UDim2.new(1,0,1,0)
  lockOverlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
  lockOverlay.BackgroundTransparency = 0.5
  lockOverlay.BorderSizePixel = 0
  lockOverlay.ZIndex          = 6
  lockOverlay.Parent          = slot
  Instance.new("UICorner", lockOverlay).CornerRadius = UDim.new(0,8)

  local lockLabel = Instance.new("TextLabel")
  lockLabel.Size              = UDim2.new(1,0,1,0)
  lockLabel.BackgroundTransparency = 1
  lockLabel.Text              = "🔒\nLv " .. prank.unlockLevel
  lockLabel.TextColor3        = Color3.fromRGB(200,200,200)
  lockLabel.Font              = Enum.Font.GothamBold
  lockLabel.TextSize          = 11
  lockLabel.ZIndex            = 7
  lockLabel.Parent            = lockOverlay

  -- Tap button (covers slot, mobile + mouse)
  local tapBtn = Instance.new("TextButton")
  tapBtn.Size                 = UDim2.new(1,0,1,0)
  tapBtn.BackgroundTransparency = 1
  tapBtn.Text                 = ""
  tapBtn.ZIndex               = 8
  tapBtn.Parent               = slot
  tapBtn.MouseButton1Click:Connect(function() fireSkill(i) end)
  tapBtn.MouseEnter:Connect(function()
    tip.Text = string.format("[%d] %s  •  +%d chaos  •  CD: %.1fs  •  Unlocks Lv%d",
      i, prank.displayName, prank.baseChaos, prank.cooldown, prank.unlockLevel)
  end)
  tapBtn.MouseLeave:Connect(function() tip.Text = "" end)

  slots[i] = { prankName=prankName, frame=slot, baseCol=baseCol,
               cdOverlay=cdOverlay, cdText=cdText, lockOverlay=lockOverlay }
end

for i, name in ipairs(ORDER) do buildSlot(i, name) end

-- ── Fire skill (shared by key + tap) ─────────────────────────────────────────
-- NOTE: actual NPC targeting is handled by InputHandler's nearestNPC / raycast.
-- SkillBar just fires the same RequestPrank remote that InputHandler uses.
-- We share _G.KR_LastTarget so both systems can share the clicked NPC.
function fireSkill(i)
  local s = slots[i]
  if not s then return end
  local prankName = s.prankName
  local prank     = PrankConfig.Pranks[prankName]
  local lv        = getLevel()

  if not PrankConfig.isUnlocked(prankName, lv) then
    -- Flash red + shake lock icon
    TweenService:Create(s.frame, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(180,30,30)}):Play()
    task.delay(0.15, function()
      TweenService:Create(s.frame, TweenInfo.new(0.15), {BackgroundColor3 = s.baseCol}):Play()
    end)
    return
  end

  local now  = tick()
  local last = clientCDs[prankName] or 0
  if now - last < prank.cooldown then
    -- Still cooling — flash red
    TweenService:Create(s.frame, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(180,30,30)}):Play()
    task.delay(0.15, function()
      TweenService:Create(s.frame, TweenInfo.new(0.15), {BackgroundColor3 = s.baseCol}):Play()
    end)
    return
  end

  -- Find target — prefer raycast target from InputHandler shared global
  local npc = _G.KR_LastTarget
  if not npc or not npc.Parent then
    -- Fall back to proximity
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
      local best, bestDist = nil, prank.rangeStuds
      for _, folder in ipairs({workspace:FindFirstChild("PrankNPCs"), workspace:FindFirstChild("AmbientCrowd")}) do
        if folder then
          for _, m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") and (m:GetAttribute("KittyRaiserNPC") or m:GetAttribute("AmbientNPC"))
              and not m:GetAttribute("Pranked") then
              local r = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
              if r then
                local d = (r.Position - root.Position).Magnitude
                if d < bestDist then bestDist = d; best = m end
              end
            end
          end
        end
      end
      npc = best
    end
  end

  clientCDs[prankName] = now
  -- Gold flash on fire
  TweenService:Create(s.frame, TweenInfo.new(0.07), {BackgroundColor3 = Color3.fromRGB(255,220,50)}):Play()
  task.delay(0.1, function()
    TweenService:Create(s.frame, TweenInfo.new(0.2), {BackgroundColor3 = s.baseCol}):Play()
  end)

  Remotes.RequestPrank:FireServer(prankName, npc)
end

-- ── Cooldown + lock ticker ────────────────────────────────────────────────────
RunService.RenderStepped:Connect(function()
  local now = tick()
  local lv  = getLevel()
  for i, s in ipairs(slots) do
    local prank   = PrankConfig.Pranks[s.prankName]
    local unlocked = PrankConfig.isUnlocked(s.prankName, lv)

    -- Lock overlay visibility
    s.lockOverlay.BackgroundTransparency = unlocked and 1 or 0.5

    -- Cooldown
    if unlocked then
      local elapsed  = now - (clientCDs[s.prankName] or 0)
      local remain   = prank.cooldown - elapsed
      if remain > 0 then
        s.cdOverlay.BackgroundTransparency = 0.5
        s.cdText.Text = string.format("%.1f", remain)
      else
        s.cdOverlay.BackgroundTransparency = 1
        s.cdText.Text = ""
      end
    else
      s.cdOverlay.BackgroundTransparency = 1
      s.cdText.Text = ""
    end
  end
end)

-- ── Keyboard 1-8 ─────────────────────────────────────────────────────────────
local KEY_MAP = {
  [Enum.KeyCode.One]=1, [Enum.KeyCode.Two]=2, [Enum.KeyCode.Three]=3,
  [Enum.KeyCode.Four]=4,[Enum.KeyCode.Five]=5, [Enum.KeyCode.Six]=6,
  [Enum.KeyCode.Seven]=7,[Enum.KeyCode.Eight]=8,
}
UserInputService.InputBegan:Connect(function(input, gp)
  if gp then return end
  local idx = KEY_MAP[input.KeyCode]
  if idx then fireSkill(idx) end
end)

-- ── Hide old PrankColumn if it exists ────────────────────────────────────────
task.spawn(function()
  local hud = playerGui:WaitForChild("MainHUD", 10)
  if not hud then return end
  local col = hud:FindFirstChild("PrankColumn")
  if col then col.Visible = false end
end)

print("[SkillBar] Loaded — Diablo-style 8-prank bar active (1-8 keys + tap)")
