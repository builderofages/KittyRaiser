-- WeatherClient.client.lua
-- Reacts to weather changes: spawns rain/fog/red mist particles, shows banner.
-- Place in: StarterPlayer > StarterPlayerScripts > WeatherClient (LocalScript)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 60)
if not hud then return end

local banner = Instance.new("TextLabel")
banner.Size = UDim2.new(0, 300, 0, 50)
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 90)
banner.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
banner.BackgroundTransparency = 0.2
banner.TextColor3 = Color3.fromRGB(255, 200, 0)
banner.Font = Enum.Font.GothamBlack
banner.TextScaled = true
banner.Visible = false
banner.Text = ""
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 12)
banner.Parent = hud

local activeFX, activeConn

local function clearFX()
    if activeConn then
        pcall(function() activeConn:Disconnect() end)
        activeConn = nil
    end
    if activeFX then
        pcall(function() activeFX:Destroy() end)
        activeFX = nil
    end
end

local function rainFX()
    local model = Instance.new("Model")
    model.Name = "RainFX"
    model.Parent = Workspace
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = false; p.Transparency = 1
    p.Size = Vector3.new(60, 1, 60)
    p.Parent = model
    local cam = Workspace.CurrentCamera
    activeConn = RunService.Heartbeat:Connect(function()
        if not p.Parent or not cam then
            if activeConn then activeConn:Disconnect(); activeConn = nil end
            return
        end
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
    local frame = Instance.new("Frame")
    frame.Name = "RedMistOverlay"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    frame.BackgroundTransparency = 0.92
    frame.BorderSizePixel = 0
    frame.ZIndex = 0
    frame.Parent = hud
    return frame
end

Remotes.WeatherChanged.OnClientEvent:Connect(function(weather, multBonus)
    clearFX()
    banner.Text = string.format("%s%s", weather:upper(),
        (multBonus and multBonus > 1) and (" (x" .. multBonus .. ")") or "")
    banner.TextColor3 = ({
        Sunny = Color3.fromRGB(255, 220, 80),
        Rainy = Color3.fromRGB(120, 180, 255),
        Foggy = Color3.fromRGB(220, 220, 220),
        RedMist = Color3.fromRGB(255, 50, 50),
    })[weather] or Color3.fromRGB(255, 200, 0)
    banner.Visible = true
    task.delay(4, function() if banner then banner.Visible = false end end)

    if weather == "Rainy" then activeFX = rainFX()
    elseif weather == "Foggy" then activeFX = fogFX()
    elseif weather == "RedMist" then activeFX = redMistFX() end
end)

Remotes.EventBroadcast.OnClientEvent:Connect(function(message)
    banner.Text = message
    banner.Visible = true
    task.delay(5, function() if banner then banner.Visible = false end end)
end)

return true
