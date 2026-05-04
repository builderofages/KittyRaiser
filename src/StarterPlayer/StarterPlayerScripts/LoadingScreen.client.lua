-- LoadingScreen.client.lua  v1
-- Shows a sunny loading screen the moment the player joins, until either:
--   * the MainHUD finishes building (HUDBuilder prints success),
--   * a 12-second timeout passes (so the player isn't stuck).
-- Place in: StarterPlayer > StarterPlayerScripts > LoadingScreen (LocalScript)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIUtil = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIUtil"))
local AssetIds

pcall(function()
    AssetIds = require(ReplicatedStorage.Modules.AssetIds)
end)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local sg = Instance.new("ScreenGui")
sg.Name = "LoadingScreen"
sg.IgnoreGuiInset = true
sg.ResetOnSpawn = false
sg.DisplayOrder = 200  -- above everything
sg.Parent = playerGui

-- Sky-gradient background
local bg = Instance.new("Frame", sg)
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(170, 215, 240)
bg.BorderSizePixel = 0
local g = Instance.new("UIGradient", bg)
g.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(220, 240, 255)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(150, 200, 235)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(255, 220, 170)),
}
g.Rotation = 90

-- Center column: title + subtitle + spinner + tip
local center = Instance.new("Frame", sg)
center.AnchorPoint = Vector2.new(0.5, 0.5)
center.Position = UDim2.new(0.5, 0, 0.5, 0)
center.Size = UDim2.new(0.8, 0, 0, 320)
center.BackgroundTransparency = 1

local title = Instance.new("TextLabel", center)
title.Size = UDim2.new(1, 0, 0, 110)
title.BackgroundTransparency = 1
title.Text = "KITTYRAISER"
title.Font = UIUtil.Token.fontTitle
title.TextScaled = true
title.TextColor3 = UIUtil.Palette.textLo
title.TextStrokeTransparency = 0.3
title.TextStrokeColor3 = Color3.fromRGB(255, 240, 200)
local titleC = Instance.new("UITextSizeConstraint", title)
titleC.MinTextSize = 50; titleC.MaxTextSize = 110

local subtitle = Instance.new("TextLabel", center)
subtitle.Size = UDim2.new(1, 0, 0, 28)
subtitle.Position = UDim2.new(0, 0, 0, 110)
subtitle.BackgroundTransparency = 1
subtitle.Text = "loading the city..."
subtitle.Font = UIUtil.Token.fontTitle
subtitle.TextScaled = true
subtitle.TextColor3 = Color3.fromRGB(120, 70, 40)
local sC = Instance.new("UITextSizeConstraint", subtitle)
sC.MinTextSize = 14; sC.MaxTextSize = 26

-- Animated spinner ring
local spinner = Instance.new("Frame", center)
spinner.AnchorPoint = Vector2.new(0.5, 0)
spinner.Size = UDim2.new(0, 80, 0, 80)
spinner.Position = UDim2.new(0.5, 0, 0, 160)
spinner.BackgroundTransparency = 1
local spinIcon = Instance.new("ImageLabel", spinner)
spinIcon.Size = UDim2.fromScale(1, 1)
spinIcon.BackgroundTransparency = 1
if AssetIds and AssetIds.has and AssetIds.has("paw") then
    spinIcon.Image = AssetIds.paw
    spinIcon.ImageColor3 = Color3.fromRGB(110, 75, 40)
else
    -- Fallback: a circle with a notch
    spinIcon.Image = ""
    local c = Instance.new("Frame", spinner)
    c.Size = UDim2.new(1, 0, 1, 0)
    c.BackgroundColor3 = UIUtil.Palette.primary
    c.BackgroundTransparency = 0.5
    Instance.new("UICorner", c).CornerRadius = UDim.new(1, 0)
end

-- Spin
task.spawn(function()
    while sg.Parent do
        spinner.Rotation = (spinner.Rotation + 4) % 360
        task.wait(0.025)
    end
end)

-- Tip rotation
local TIPS = {
    "Bigger combos = bigger payouts.",
    "Press B to emote.",
    "Anvils unlock at level 8.",
    "Daily streaks unlock the EPIC SKIN on day 7.",
    "Hold a chain of pranks for combo multipliers.",
    "Rebirth at higher levels for permanent score multipliers.",
}
local tip = Instance.new("TextLabel", sg)
tip.AnchorPoint = Vector2.new(0.5, 1)
tip.Position = UDim2.new(0.5, 0, 1, -28)
tip.Size = UDim2.new(0.9, 0, 0, 24)
tip.BackgroundTransparency = 1
tip.Font = UIUtil.Token.fontBody
tip.TextScaled = true
tip.TextColor3 = Color3.fromRGB(80, 50, 30)
tip.Text = "TIP  ·  " .. TIPS[math.random(1, #TIPS)]
local tC = Instance.new("UITextSizeConstraint", tip)
tC.MinTextSize = 12; tC.MaxTextSize = 20

task.spawn(function()
    while sg.Parent do
        task.wait(3)
        if not sg.Parent then break end
        local newTip = "TIP  ·  " .. TIPS[math.random(1, #TIPS)]
        TweenService:Create(tip, UIUtil.Token.easeFade, {TextTransparency = 1}):Play()
        task.wait(0.4)
        tip.Text = newTip
        TweenService:Create(tip, UIUtil.Token.easeFade, {TextTransparency = 0}):Play()
    end
end)

-- Wait until either the HUD exists OR 12 seconds elapse, then fade out.
task.spawn(function()
    local started = os.clock()
    while os.clock() - started < 12 do
        if playerGui:FindFirstChild("MainHUD") then break end
        task.wait(0.2)
    end
    -- Slight grace so the HUD has time to populate
    task.wait(0.6)
    TweenService:Create(bg, TweenInfo.new(0.6), {BackgroundTransparency = 1}):Play()
    TweenService:Create(title, TweenInfo.new(0.4), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    TweenService:Create(subtitle, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
    TweenService:Create(tip, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
    TweenService:Create(spinIcon, TweenInfo.new(0.4), {ImageTransparency = 1}):Play()
    task.wait(0.7)
    sg:Destroy()
end)

-- Preload high-priority assets in the background
task.spawn(function()
    if AssetIds then
        local toPreload = {}
        for k, v in pairs(AssetIds) do
            if type(v) == "string" and v:match("^rbxassetid://%d+") then
                table.insert(toPreload, v)
            end
        end
        pcall(function() ContentProvider:PreloadAsync(toPreload) end)
    end
end)

print("[LoadingScreen v1] showing while HUD spins up")
