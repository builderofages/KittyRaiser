-- SettingsMenu.client.lua  v1
-- Adds a MENU button to the HUD bottom bar that opens a settings + pause modal.
-- Settings stored in player attributes so other scripts can read them:
--   * MasterVolume (0-1)
--   * GraphicsQuality ("low" | "med" | "high")
--   * MotionShake (bool — disables CombatFeel FOV pulse + EffectsController shake)
--
-- Place in: StarterPlayer > StarterPlayerScripts > SettingsMenu (LocalScript)

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIUtil   = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIUtil"))
local AssetIds = require(ReplicatedStorage.Modules.AssetIds)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud       = playerGui:WaitForChild("MainHUD", 30)
if not hud then return end

-- Defaults
player:SetAttribute("MasterVolume",    player:GetAttribute("MasterVolume")    or 0.7)
player:SetAttribute("GraphicsQuality", player:GetAttribute("GraphicsQuality") or "med")
player:SetAttribute("MotionShake",     player:GetAttribute("MotionShake")     ~= false)  -- default true

local function applyVolume()
    SoundService.Volume = player:GetAttribute("MasterVolume") or 0.7
end
local function applyGraphics()
    local q = player:GetAttribute("GraphicsQuality") or "med"
    local atm = Lighting:FindFirstChildOfClass("Atmosphere")
    local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
    local sun = Lighting:FindFirstChildOfClass("SunRaysEffect")
    if q == "low" then
        if atm then atm.Density = 0.05; atm.Haze = 0.1 end
        if bloom then bloom.Intensity = 0.0 end
        if sun then sun.Intensity = 0.0 end
    elseif q == "med" then
        if atm then atm.Density = 0.12; atm.Haze = 0.5 end
        if bloom then bloom.Intensity = 0.3 end
        if sun then sun.Intensity = 0.10 end
    else  -- high
        if atm then atm.Density = 0.20; atm.Haze = 1.0 end
        if bloom then bloom.Intensity = 0.5 end
        if sun then sun.Intensity = 0.15 end
    end
end

applyVolume()
applyGraphics()

player:GetAttributeChangedSignal("MasterVolume"):Connect(applyVolume)
player:GetAttributeChangedSignal("GraphicsQuality"):Connect(applyGraphics)

-- ============================================================
-- MODAL
-- ============================================================
local modal = Instance.new("Frame")
modal.Name = "SettingsModal"
modal.Size = UIUtil.modalSize(420, 460, 24)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.new(0.5, 0, 0.5, 0)
modal.BackgroundColor3 = UIUtil.Palette.bgMid
modal.BorderSizePixel = 0
modal.Visible = false
modal.ZIndex = 60
Instance.new("UICorner", modal).CornerRadius = UIUtil.Token.cornerLg
local mStroke = Instance.new("UIStroke", modal)
mStroke.Thickness = UIUtil.Token.strokeBold; mStroke.Color = UIUtil.Palette.primary
modal.Parent = hud

local cam = workspace.CurrentCamera
if cam then
    cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        modal.Size = UIUtil.modalSize(420, 460, 24)
    end)
end

-- Title
local title = Instance.new("TextLabel", modal)
title.Size = UDim2.new(1, -80, 0, 50)
title.Position = UDim2.new(0, 16, 0, 12)
title.BackgroundTransparency = 1
title.Text = "SETTINGS"
title.TextColor3 = UIUtil.Palette.primary
title.Font = UIUtil.Token.fontHeader
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
UIUtil.TextSize.header(title)

-- Close
local close = Instance.new("TextButton", modal)
close.Size = UDim2.new(0, 48, 0, 48)
close.Position = UDim2.new(1, -56, 0, 8)
close.BackgroundColor3 = UIUtil.Palette.danger
close.AutoButtonColor = true
close.Text = "X"
close.TextColor3 = UIUtil.Palette.textHi
close.Font = UIUtil.Token.fontHeader
close.TextScaled = true
Instance.new("UICorner", close).CornerRadius = UIUtil.Token.cornerSm
local cs = Instance.new("UIStroke", close); cs.Thickness = UIUtil.Token.strokeReg; cs.Color = UIUtil.Palette.stroke
UIUtil.boundText(close, 18, 26)
close.MouseButton1Click:Connect(function() modal.Visible = false end)

-- Content container
local body = Instance.new("Frame", modal)
body.Size = UDim2.new(1, -32, 1, -84)
body.Position = UDim2.new(0, 16, 0, 76)
body.BackgroundTransparency = 1
local layout = Instance.new("UIListLayout", body)
layout.FillDirection = Enum.FillDirection.Vertical
layout.Padding = UDim.new(0, 12)
layout.SortOrder = Enum.SortOrder.LayoutOrder

-- Helper: row with label + content
local function makeRow(name, layoutOrder, height)
    local r = Instance.new("Frame", body)
    r.Size = UDim2.new(1, 0, 0, height or 56)
    r.BackgroundColor3 = UIUtil.Palette.panel
    r.BorderSizePixel = 0
    r.LayoutOrder = layoutOrder
    Instance.new("UICorner", r).CornerRadius = UIUtil.Token.cornerSm
    local lbl = Instance.new("TextLabel", r)
    lbl.Size = UDim2.new(0.4, 0, 1, 0)
    lbl.Position = UDim2.fromOffset(12, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = UIUtil.Palette.textHi
    lbl.Font = UIUtil.Token.fontHeader
    lbl.TextScaled = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    UIUtil.TextSize.label(lbl)
    return r
end

-- ----- VOLUME SLIDER -----
local volRow = makeRow("VOLUME", 1, 56)
local sliderTrack = Instance.new("Frame", volRow)
sliderTrack.Size = UDim2.new(0.55, -12, 0, 12)
sliderTrack.AnchorPoint = Vector2.new(1, 0.5)
sliderTrack.Position = UDim2.new(1, -12, 0.5, 0)
sliderTrack.BackgroundColor3 = UIUtil.Palette.bgDark
sliderTrack.BorderSizePixel = 0
Instance.new("UICorner", sliderTrack).CornerRadius = UDim.new(1, 0)
local sliderFill = Instance.new("Frame", sliderTrack)
sliderFill.Size = UDim2.new(player:GetAttribute("MasterVolume") or 0.7, 0, 1, 0)
sliderFill.BackgroundColor3 = UIUtil.Palette.primary
sliderFill.BorderSizePixel = 0
Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)
local sliderKnob = Instance.new("TextButton", sliderTrack)
sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
sliderKnob.Size = UDim2.new(0, 24, 0, 24)
sliderKnob.Position = UDim2.new(player:GetAttribute("MasterVolume") or 0.7, 0, 0.5, 0)
sliderKnob.BackgroundColor3 = UIUtil.Palette.gold
sliderKnob.AutoButtonColor = true
sliderKnob.Text = ""
Instance.new("UICorner", sliderKnob).CornerRadius = UDim.new(1, 0)
local sk = Instance.new("UIStroke", sliderKnob); sk.Color = UIUtil.Palette.stroke; sk.Thickness = UIUtil.Token.strokeReg

-- Drag logic for the knob
local UserInputService = game:GetService("UserInputService")
local dragging = false
sliderKnob.MouseButton1Down:Connect(function() dragging = true end)
sliderKnob.TouchTap:Connect(function() dragging = true end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
       and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local trackPos = sliderTrack.AbsolutePosition.X
    local trackW   = sliderTrack.AbsoluteSize.X
    local rel = math.clamp((input.Position.X - trackPos) / trackW, 0, 1)
    sliderFill.Size = UDim2.new(rel, 0, 1, 0)
    sliderKnob.Position = UDim2.new(rel, 0, 0.5, 0)
    player:SetAttribute("MasterVolume", rel)
end)

-- Tap-to-set on the track itself
sliderTrack.InputBegan = nil  -- (Frames don't have InputBegan; using MouseButton via overlay button)
local trackBtn = Instance.new("TextButton", sliderTrack)
trackBtn.Size = UDim2.fromScale(1, 1)
trackBtn.BackgroundTransparency = 1
trackBtn.Text = ""
trackBtn.MouseButton1Click:Connect(function(x, y)
    -- Use mouse position
    local m = player:GetMouse()
    local rel = math.clamp((m.X - sliderTrack.AbsolutePosition.X) / sliderTrack.AbsoluteSize.X, 0, 1)
    sliderFill.Size = UDim2.new(rel, 0, 1, 0)
    sliderKnob.Position = UDim2.new(rel, 0, 0.5, 0)
    player:SetAttribute("MasterVolume", rel)
end)

-- ----- GRAPHICS QUALITY SEGMENTED -----
local gfxRow = makeRow("GRAPHICS", 2, 56)
local seg = Instance.new("Frame", gfxRow)
seg.Size = UDim2.new(0.55, -12, 0, 36)
seg.AnchorPoint = Vector2.new(1, 0.5)
seg.Position = UDim2.new(1, -12, 0.5, 0)
seg.BackgroundColor3 = UIUtil.Palette.bgDark
seg.BorderSizePixel = 0
Instance.new("UICorner", seg).CornerRadius = UIUtil.Token.cornerSm
local segLayout = Instance.new("UIListLayout", seg)
segLayout.FillDirection = Enum.FillDirection.Horizontal
segLayout.Padding = UDim.new(0, 4)
segLayout.SortOrder = Enum.SortOrder.LayoutOrder
local segPad = Instance.new("UIPadding", seg)
segPad.PaddingLeft = UDim.new(0, 4); segPad.PaddingRight = UDim.new(0, 4)
segPad.PaddingTop = UDim.new(0, 4); segPad.PaddingBottom = UDim.new(0, 4)
local QUALITIES = {"low", "med", "high"}
local segButtons = {}
for i, q in ipairs(QUALITIES) do
    local b = Instance.new("TextButton", seg)
    b.Size = UDim2.new(1/3, -4, 1, 0)
    b.LayoutOrder = i
    b.BackgroundColor3 = UIUtil.Palette.panel
    b.AutoButtonColor = true
    b.Text = q:upper()
    b.TextColor3 = UIUtil.Palette.textHi
    b.Font = UIUtil.Token.fontHeader
    b.TextScaled = true
    Instance.new("UICorner", b).CornerRadius = UIUtil.Token.cornerSm
    UIUtil.boundText(b, 12, 18)
    b.MouseButton1Click:Connect(function()
        player:SetAttribute("GraphicsQuality", q)
    end)
    segButtons[q] = b
end
local function refreshGfxSeg()
    local current = player:GetAttribute("GraphicsQuality")
    for q, b in pairs(segButtons) do
        b.BackgroundColor3 = (q == current) and UIUtil.Palette.primary or UIUtil.Palette.panel
        b.TextColor3       = (q == current) and UIUtil.Palette.textLo  or UIUtil.Palette.textHi
    end
end
refreshGfxSeg()
player:GetAttributeChangedSignal("GraphicsQuality"):Connect(refreshGfxSeg)

-- ----- MOTION SHAKE TOGGLE -----
local shakeRow = makeRow("MOTION FX", 3, 56)
local toggle = Instance.new("TextButton", shakeRow)
toggle.AnchorPoint = Vector2.new(1, 0.5)
toggle.Size = UDim2.new(0, 80, 0, 36)
toggle.Position = UDim2.new(1, -12, 0.5, 0)
toggle.BackgroundColor3 = UIUtil.Palette.accent
toggle.AutoButtonColor = true
toggle.Text = "ON"
toggle.TextColor3 = UIUtil.Palette.textHi
toggle.Font = UIUtil.Token.fontHeader
toggle.TextScaled = true
Instance.new("UICorner", toggle).CornerRadius = UIUtil.Token.cornerSm
local ts = Instance.new("UIStroke", toggle); ts.Thickness = UIUtil.Token.strokeReg; ts.Color = UIUtil.Palette.stroke
UIUtil.boundText(toggle, 14, 22)
local function refreshToggle()
    local on = player:GetAttribute("MotionShake")
    toggle.Text = on and "ON" or "OFF"
    toggle.BackgroundColor3 = on and UIUtil.Palette.accent or UIUtil.Palette.panel
end
refreshToggle()
toggle.MouseButton1Click:Connect(function()
    player:SetAttribute("MotionShake", not player:GetAttribute("MotionShake"))
    refreshToggle()
end)

-- ----- CONTROLS HELP (read-only text) -----
local controls = makeRow("CONTROLS", 4, 100)
local helpLbl = Instance.new("TextLabel", controls)
helpLbl.AnchorPoint = Vector2.new(1, 0.5)
helpLbl.Size = UDim2.new(0.55, -12, 1, -12)
helpLbl.Position = UDim2.new(1, -12, 0.5, 0)
helpLbl.BackgroundTransparency = 1
helpLbl.Text = "WASD = move\nSPACE = jump\nE = summon\n1-4 = pranks\nB = emotes"
helpLbl.Font = UIUtil.Token.fontBody
helpLbl.TextColor3 = UIUtil.Palette.textMuted
helpLbl.TextScaled = true
helpLbl.TextXAlignment = Enum.TextXAlignment.Right
helpLbl.TextYAlignment = Enum.TextYAlignment.Top
UIUtil.TextSize.small(helpLbl)

-- ============================================================
-- HOOK MENU BUTTON ON BOTTOM BAR
-- ============================================================
local function hookMenuButton()
    local botBar = hud:FindFirstChild("BottomBar")
    if not botBar then return end
    if botBar:FindFirstChild("MenuButton") then return end
    local menuBtn = Instance.new("TextButton")
    menuBtn.Name = "MenuButton"
    menuBtn.Size = UDim2.new(0, 84, 0, 60)
    menuBtn.BackgroundColor3 = UIUtil.Palette.panel
    menuBtn.AutoButtonColor = true
    menuBtn.Text = ""
    menuBtn.LayoutOrder = 6
    Instance.new("UICorner", menuBtn).CornerRadius = UIUtil.Token.cornerMd
    local sStr = Instance.new("UIStroke", menuBtn)
    sStr.Thickness = UIUtil.Token.strokeReg; sStr.Color = UIUtil.Palette.stroke
    menuBtn.Parent = botBar
    -- Use slot icon (gear-like) if available
    if AssetIds.has("slot") then
        local img = Instance.new("ImageLabel", menuBtn)
        img.BackgroundTransparency = 1
        img.Size = UDim2.new(0, 26, 0, 26)
        img.Position = UDim2.new(0.5, -13, 0, 6)
        img.Image = AssetIds.slot
        img.ScaleType = Enum.ScaleType.Fit
    end
    local lbl = Instance.new("TextLabel", menuBtn)
    lbl.Size = UDim2.new(1, -8, 0, 18)
    lbl.Position = UDim2.new(0, 4, 1, -22)
    lbl.BackgroundTransparency = 1
    lbl.Text = "MENU"
    lbl.Font = UIUtil.Token.fontHeader
    lbl.TextColor3 = UIUtil.Palette.textHi
    lbl.TextStrokeTransparency = 0.4
    lbl.TextStrokeColor3 = UIUtil.Palette.stroke
    lbl.TextScaled = true
    UIUtil.boundText(lbl, 11, 16)
    menuBtn.MouseButton1Click:Connect(function()
        modal.Visible = not modal.Visible
    end)
end

hookMenuButton()
hud.ChildAdded:Connect(function() task.wait(0.5); hookMenuButton() end)

-- Also bind Escape (PC) to open
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.M then
        modal.Visible = not modal.Visible
    end
end)

print("[SettingsMenu v1] menu + volume + graphics + motion + controls help ready")
