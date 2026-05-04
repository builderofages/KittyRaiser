-- WeatherClient.client.lua
-- Reacts to weather changes: spawns rain/fog/red mist particles, shows banner.
-- Place in: StarterPlayer > StarterPlayerScripts > WeatherClient (LocalScript)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local UIUtil  = require(ReplicatedStorage.Modules:WaitForChild("UIUtil"))

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
if not hud then return end

-- Banner with warm-cartoon palette, sits below TopBar
local banner = Instance.new("TextLabel")
banner.Name = "WeatherBanner"
banner.Size = UDim2.new(0, 320, 0, 44)
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 96)
banner.BackgroundColor3 = UIUtil.Palette.bgMid
banner.BackgroundTransparency = 0.1
banner.TextColor3 = UIUtil.Palette.textHi
banner.Font = UIUtil.Token.fontHeader
banner.TextScaled = true
banner.TextStrokeTransparency = 0.4
banner.TextStrokeColor3 = UIUtil.Palette.stroke
banner.Visible = false
banner.Text = ""
Instance.new("UICorner", banner).CornerRadius = UIUtil.Token.cornerMd
local bStroke = Instance.new("UIStroke", banner)
bStroke.Thickness = UIUtil.Token.strokeReg
bStroke.Color = UIUtil.Palette.hairline
banner.Parent = hud
UIUtil.TextSize.label(banner)

local function showBanner(text, accentColor, holdSec)
    banner.Text = text
    if accentColor then bStroke.Color = accentColor end
    banner.Visible = true
    banner.BackgroundTransparency = 1
    banner.TextTransparency = 1
    banner.TextStrokeTransparency = 1
    TweenService:Create(banner, UIUtil.Token.easeOut,
        {BackgroundTransparency = 0.1, TextTransparency = 0, TextStrokeTransparency = 0.4}):Play()
    task.delay(holdSec or 4, function()
        TweenService:Create(banner, UIUtil.Token.easeFade,
            {BackgroundTransparency = 1, TextTransparency = 1, TextStrokeTransparency = 1}):Play()
        task.wait(0.5)
        banner.Visible = false
    end)
end

local activeFX = nil

local function clearFX()
    if activeFX then activeFX:Destroy(); activeFX = nil end
end

local function rainFX()
    local model = Instance.new("Model")
    model.Name = "RainFX"
    model.Parent = Workspace
    -- Rain emitter attached to camera
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.Transparency = 1
    p.Size = Vector3.new(60, 1, 60)
    p.Parent = model
    local cam = Workspace.CurrentCamera
    -- Track camera
    local conn
    conn = game:GetService("RunService").Heartbeat:Connect(function()
        if not p.Parent then conn:Disconnect() return end
        p.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 30, 0))
    end)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
    emitter.Color = ColorSequence.new(Color3.fromRGB(150, 180, 220))
    emitter.Lifetime = NumberRange.new(0.6, 0.9)
    emitter.Rate = 200
    emitter.Speed = NumberRange.new(40, 60)
    emitter.SpreadAngle = Vector2.new(5, 5)
    emitter.Size = NumberSequence.new(0.3, 0.1)
    emitter.Acceleration = Vector3.new(0, -50, 0)
    emitter.Parent = p
    return model
end

local function fogFX()
    -- Lighting handles fog mostly; just intensify with a screen overlay
    local frame = Instance.new("Frame")
    frame.Name = "FogOverlay"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
    frame.BackgroundTransparency = 0.85
    frame.BorderSizePixel = 0
    frame.ZIndex = 0
    frame.Parent = hud
    return frame
end

local function redMistFX()
    local model = Instance.new("Model")
    model.Name = "RedMistFX"
    model.Parent = Workspace
    -- Screen tint
    local frame = Instance.new("Frame")
    frame.Name = "RedMistOverlay"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    frame.BackgroundTransparency = 0.92
    frame.BorderSizePixel = 0
    frame.ZIndex = 0
    frame.Parent = hud
    return model
end

Remotes.WeatherChanged.OnClientEvent:Connect(function(weather)
    clearFX()
    local color = ({
        Sunny   = UIUtil.Palette.primary,
        Rainy   = Color3.fromRGB(120, 180, 220),
        Foggy   = UIUtil.Palette.textMuted,
        RedMist = UIUtil.Palette.danger,
    })[weather] or UIUtil.Palette.primary
    showBanner(weather:upper(), color, 4)

    if weather == "Rainy" then activeFX = rainFX()
    elseif weather == "Foggy" then activeFX = fogFX()
    elseif weather == "RedMist" then activeFX = redMistFX() end
end)

Remotes.EventBroadcast.OnClientEvent:Connect(function(message)
    showBanner(message, UIUtil.Palette.primary, 5)
end)

return true
