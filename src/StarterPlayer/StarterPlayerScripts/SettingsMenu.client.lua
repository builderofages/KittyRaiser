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
local AudioGroups = require(ReplicatedStorage.Modules:WaitForChild("AudioGroups"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud       = playerGui:WaitForChild("MainHUD", 30)
if not hud then return end

-- Defaults
player:SetAttribute("MasterVolume",    player:GetAttribute("MasterVolume")    or 0.8)
player:SetAttribute("MusicVolume",     player:GetAttribute("MusicVolume")     or 0.6)
player:SetAttribute("SFXVolume",       player:GetAttribute("SFXVolume")       or 0.9)
player:SetAttribute("UIVolume",        player:GetAttribute("UIVolume")        or 0.8)
player:SetAttribute("GraphicsQuality", player:GetAttribute("GraphicsQuality") or "med")
player:SetAttribute("MotionShake",     player:GetAttribute("MotionShake")     ~= false)  -- default true

local function applyVolume()
    -- Master scales SoundService; per-channel sliders scale the SoundGroup volumes.
    SoundService.Volume = player:GetAttribute("MasterVolume") or 0.8
    AudioGroups.setChannelVolume("Music", player:GetAttribute("MusicVolume") or 0.6)
    AudioGroups.setChannelVolume("SFX",   player:GetAttribute("SFXVolume")   or 0.9)
    AudioGroups.setChannelVolume("UI",    player:GetAttribute("UIVolume")    or 0.8)
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
player:GetAttributeChangedSignal("MusicVolume"):Connect(applyVolume)
player:GetAttributeChangedSignal("SFXVolume"):Connect(applyVolume)
player:GetAttributeChangedSignal("UIVolume"):Connect(applyVolume)
player:GetAttributeChangedSignal("GraphicsQuality"):Connect(applyGraphics)

-- ============================================================
-- MODAL
-- ============================================================
local modal = Instance.new("Frame")
modal.Name = "SettingsModal"
modal.Size = UIUtil.modalSize(440, 660, 24)
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
        modal.Size = UIUtil.modalSize(440, 660, 24)
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
-- Pause player movement while menu is open (single source of truth)
local pausedSpeed = nil
local pausedJump = nil
local function setMenuVisible(v)
    modal.Visible = v
    local char = player.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if v then
        pausedSpeed = pausedSpeed or hum.WalkSpeed
        pausedJump  = pausedJump  or hum.JumpPower
        hum.WalkSpeed = 0
        hum.JumpPower = 0
    else
        if pausedSpeed then hum.WalkSpeed = pausedSpeed end
        if pausedJump  then hum.JumpPower = pausedJump  end
        pausedSpeed = nil; pausedJump = nil
    end
end

close.MouseButton1Click:Connect(function() setMenuVisible(false) end)

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

-- ----- VOLUME SLIDERS (master + 3 channels) -----
local UserInputService = game:GetService("UserInputService")
local activeSlider = nil  -- track which slider is being dragged

local function makeVolumeSlider(label, attrName, layoutOrder)
    local row = makeRow(label, layoutOrder, 50)
    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(0.55, -12, 0, 10)
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -12, 0.5, 0)
    track.BackgroundColor3 = UIUtil.Palette.bgDark
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame", track)
    local val = player:GetAttribute(attrName) or 0.7
    fill.Size = UDim2.new(val, 0, 1, 0)
    fill.BackgroundColor3 = UIUtil.Palette.primary
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("TextButton", track)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Size = UDim2.new(0, 22, 0, 22)
    knob.Position = UDim2.new(val, 0, 0.5, 0)
    knob.BackgroundColor3 = UIUtil.Palette.gold
    knob.AutoButtonColor = true
    knob.Text = ""
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local ks = Instance.new("UIStroke", knob); ks.Color = UIUtil.Palette.stroke; ks.Thickness = UIUtil.Token.strokeReg

    local function setRel(rel)
        rel = math.clamp(rel, 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        player:SetAttribute(attrName, rel)
    end

    knob.MouseButton1Down:Connect(function() activeSlider = track end)
    knob.TouchTap:Connect(function() activeSlider = track end)

    -- Tap-to-set anywhere on the track
    local trackBtn = Instance.new("TextButton", track)
    trackBtn.Size = UDim2.fromScale(1, 1)
    trackBtn.BackgroundTransparency = 1
    trackBtn.Text = ""
    trackBtn.MouseButton1Click:Connect(function()
        local m = player:GetMouse()
        setRel((m.X - track.AbsolutePosition.X) / track.AbsoluteSize.X)
    end)

    -- React to external setAttribute (e.g. from server)
    player:GetAttributeChangedSignal(attrName):Connect(function()
        local v = player:GetAttribute(attrName) or 0
        if math.abs(v - (fill.Size.X.Scale or 0)) > 0.001 then
            fill.Size = UDim2.new(v, 0, 1, 0)
            knob.Position = UDim2.new(v, 0, 0.5, 0)
        end
    end)

    return track, setRel
end

-- Single global drag listener so all sliders share one input pipeline
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        activeSlider = nil
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if not activeSlider then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
       and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local rel = math.clamp((input.Position.X - activeSlider.AbsolutePosition.X) / activeSlider.AbsoluteSize.X, 0, 1)
    -- find the slider's owning row by walking up
    local fill = activeSlider:FindFirstChildOfClass("Frame")
    local knob = activeSlider:FindFirstChildOfClass("TextButton")
    if fill then fill.Size = UDim2.new(rel, 0, 1, 0) end
    if knob then knob.Position = UDim2.new(rel, 0, 0.5, 0) end
    -- Walk: track -> row -> body, the row's first child label tells us the attr.
    -- Simpler: store the attr on the track via attribute.
    local attr = activeSlider:GetAttribute("VolumeAttr")
    if attr then player:SetAttribute(attr, rel) end
end)

-- Build the 4 sliders. Tag each track with VolumeAttr so the global listener
-- knows which attribute to update.
local masterTrack = makeVolumeSlider("MASTER", "MasterVolume", 1)
masterTrack:SetAttribute("VolumeAttr", "MasterVolume")
local musicTrack  = makeVolumeSlider("MUSIC",  "MusicVolume",  2)
musicTrack:SetAttribute("VolumeAttr", "MusicVolume")
local sfxTrack    = makeVolumeSlider("SFX",    "SFXVolume",    3)
sfxTrack:SetAttribute("VolumeAttr", "SFXVolume")
local uiTrack     = makeVolumeSlider("UI",     "UIVolume",     4)
uiTrack:SetAttribute("VolumeAttr", "UIVolume")

-- ----- GRAPHICS QUALITY SEGMENTED -----
local gfxRow = makeRow("GRAPHICS", 5, 56)
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
local shakeRow = makeRow("MOTION FX", 6, 56)
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
-- ----- RESET DEFAULTS -----
local resetRow = makeRow("RESET", 7, 56)
local resetBtn = Instance.new("TextButton", resetRow)
resetBtn.AnchorPoint = Vector2.new(1, 0.5)
resetBtn.Size = UDim2.new(0, 140, 0, 36)
resetBtn.Position = UDim2.new(1, -12, 0.5, 0)
resetBtn.BackgroundColor3 = UIUtil.Palette.danger
resetBtn.AutoButtonColor = true
resetBtn.Text = "RESET ALL"
resetBtn.TextColor3 = UIUtil.Palette.textHi
resetBtn.Font = UIUtil.Token.fontHeader
resetBtn.TextScaled = true
Instance.new("UICorner", resetBtn).CornerRadius = UIUtil.Token.cornerSm
local rs = Instance.new("UIStroke", resetBtn); rs.Thickness = UIUtil.Token.strokeReg; rs.Color = UIUtil.Palette.stroke
UIUtil.boundText(resetBtn, 12, 18)
resetBtn.MouseButton1Click:Connect(function()
    player:SetAttribute("MasterVolume",    0.8)
    player:SetAttribute("MusicVolume",     0.6)
    player:SetAttribute("SFXVolume",       0.9)
    player:SetAttribute("UIVolume",        0.8)
    player:SetAttribute("GraphicsQuality", "med")
    player:SetAttribute("MotionShake",     true)
end)

local controls = makeRow("CONTROLS", 8, 100)
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
        setMenuVisible(not modal.Visible)
    end)
end

hookMenuButton()
hud.ChildAdded:Connect(function() task.wait(0.5); hookMenuButton() end)

-- Also bind Escape (PC) to open
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.M then
        setMenuVisible(not modal.Visible)
    end
end)

print("[SettingsMenu v1] menu + volume + graphics + motion + controls help ready")
