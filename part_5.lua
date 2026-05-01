local function getOrMake(parent, className, name)
    local existing = parent:FindFirstChild(name)
    if existing and existing.ClassName == className then return existing end
    if existing then existing:Destroy() end
    local obj = Instance.new(className)
    obj.Name = name
    obj.Parent = parent
    return obj
end
local modulesFolder = getOrMake(game.ReplicatedStorage, 'Folder', 'Modules')
do
    local s = getOrMake(game.StarterPlayer:WaitForChild('StarterPlayerScripts'), 'LocalScript', 'SurvivalUI')
    s.Source = [[
-- SurvivalUI.client.lua
-- Hunger + thirst bars on HUD. Listens to SurvivalUpdate events.
-- Place in: StarterPlayer > StarterPlayerScripts > SurvivalUI (LocalScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
if not hud then return end

local function makeBar(name, color, posY)
    local container = Instance.new("Frame")
    container.Name = name .. "BarContainer"
    container.Size = UDim2.new(0, 220, 0, 22)
    container.Position = UDim2.new(0, 12, 0, posY)
    container.BackgroundTransparency = 1
    container.Parent = hud

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 60, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = color
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextStrokeTransparency = 0
    lbl.Parent = container

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 150, 0.7, 0)
    bg.Position = UDim2.new(0, 65, 0.15, 0)
    bg.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
    bg.BorderSizePixel = 0
    bg.Parent = container
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = color
    fill.BorderSizePixel = 0
    fill.Parent = bg
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    return fill
end

local hungerFill = makeBar("HUNGER", Color3.fromRGB(255, 150, 60), 90)
local thirstFill = makeBar("THIRST", Color3.fromRGB(60, 180, 255), 116)

Remotes.SurvivalUpdate.OnClientEvent:Connect(function(hunger, thirst)
    TweenService:Create(hungerFill, TweenInfo.new(0.4), {Size = UDim2.new(math.clamp(hunger/100,0,1), 0, 1, 0)}):Play()
    TweenService:Create(thirstFill, TweenInfo.new(0.4), {Size = UDim2.new(math.clamp(thirst/100,0,1), 0, 1, 0)}):Play()
end)

Remotes.UpdatePlayerData.OnClientEvent:Connect(function(d)
    TweenService:Create(hungerFill, TweenInfo.new(0.4), {Size = UDim2.new(math.clamp((d.hunger or 100)/100,0,1), 0, 1, 0)}):Play()
    TweenService:Create(thirstFill, TweenInfo.new(0.4), {Size = UDim2.new(math.clamp((d.thirst or 100)/100,0,1), 0, 1, 0)}):Play()
end)

return true

]]
end

do
    local s = getOrMake(game.StarterPlayer:WaitForChild('StarterPlayerScripts'), 'LocalScript', 'EmoteWheel')
    s.Source = [[
-- EmoteWheel.client.lua
-- B key opens emote wheel. Click an emote to play.
-- Place in: StarterPlayer > StarterPlayerScripts > EmoteWheel (LocalScript)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
if not hud then return end

local wheel = Instance.new("Frame")
wheel.Name = "EmoteWheel"
wheel.Size = UDim2.new(0, 360, 0, 360)
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.Position = UDim2.new(0.5, 0, 0.5, 0)
wheel.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
wheel.BackgroundTransparency = 0.2
wheel.BorderSizePixel = 0
wheel.Visible = false
wheel.Parent = hud
Instance.new("UICorner", wheel).CornerRadius = UDim.new(1, 0)
local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.Color = Color3.fromRGB(150, 50, 200)
stroke.Parent = wheel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.Position = UDim2.new(0, 0, 0, 10)
title.BackgroundTransparency = 1
title.Text = "EMOTES"
title.TextColor3 = Color3.fromRGB(150, 50, 200)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.Parent = wheel

local center = Vector2.new(180, 180)
for i, emoteName in ipairs(GameConfig.EMOTES) do
    local angle = (i - 1) * (2 * math.pi / #GameConfig.EMOTES) - math.pi / 2
    local r = 130
    local x = center.X + math.cos(angle) * r - 35
    local y = center.Y + math.sin(angle) * r - 25
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 70, 0, 50)
    btn.Position = UDim2.new(0, x, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(60, 30, 90)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBlack
    btn.Text = emoteName
    btn.TextScaled = true
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.Parent = wheel
    btn.MouseButton1Click:Connect(function()
        Remotes.RequestEmote:FireServer(emoteName)
        wheel.Visible = false
    end)
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.B then
        wheel.Visible = not wheel.Visible
    elseif input.KeyCode == Enum.KeyCode.Escape and wheel.Visible then
        wheel.Visible = false
    end
end)

-- Listen to other players' emotes -> show floating tag above their head
Remotes.EmoteBroadcast.OnClientEvent:Connect(function(userId, emoteName)
    local target = Players:GetPlayerByUserId(userId)
    if not target or not target.Character then return end
    local head = target.Character:FindFirstChild("Head")
    if not head then return end
    local b = Instance.new("BillboardGui")
    b.Size = UDim2.new(0, 100, 0, 36)
    b.StudsOffset = Vector3.new(0, 3, 0)
    b.AlwaysOnTop = true
    b.Parent = head
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
    lbl.BackgroundTransparency = 0.3
    lbl.Text = "*" .. emoteName .. "*"
    lbl.TextColor3 = Color3.fromRGB(255, 200, 0)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 8)
    lbl.Parent = b
    task.delay(2, function() b:Destroy() end)
end)

return true

]]
end

do
    local s = getOrMake(game.StarterPlayer:WaitForChild('StarterPlayerScripts'), 'LocalScript', 'DailyRewardUI')
    s.Source = [[
-- DailyRewardUI.client.lua
-- Shows daily reward popup when DailyAvailable fires.
-- Place in: StarterPlayer > StarterPlayerScripts > DailyRewardUI (LocalScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
if not hud then return end

local modal = Instance.new("Frame")
modal.Name = "DailyRewardModal"
modal.Size = UDim2.new(0, 380, 0, 280)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.new(0.5, 0, 0.5, 0)
modal.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
modal.BorderSizePixel = 0
modal.Visible = false
modal.ZIndex = 100
Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 16)
local s = Instance.new("UIStroke") s.Thickness = 3 s.Color = Color3.fromRGB(255, 200, 0) s.Parent = modal
modal.Parent = hud

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 50)
title.Position = UDim2.new(0, 10, 0, 10)
title.BackgroundTransparency = 1
title.Text = "DAILY REWARD"
title.TextColor3 = Color3.fromRGB(255, 200, 0)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.Parent = modal

local streakLbl = Instance.new("TextLabel")
streakLbl.Size = UDim2.new(1, -20, 0, 30)
streakLbl.Position = UDim2.new(0, 10, 0, 60)
streakLbl.BackgroundTransparency = 1
streakLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
streakLbl.Font = Enum.Font.Gotham
streakLbl.TextScaled = true
streakLbl.Parent = modal

local rewardLbl = Instance.new("TextLabel")
rewardLbl.Size = UDim2.new(1, -20, 0, 80)
rewardLbl.Position = UDim2.new(0, 10, 0, 95)
rewardLbl.BackgroundTransparency = 1
rewardLbl.TextColor3 = Color3.fromRGB(0, 255, 100)
rewardLbl.Font = Enum.Font.GothamBlack
rewardLbl.TextScaled = true
rewardLbl.Parent = modal

local claimBtn = Instance.new("TextButton")
claimBtn.Size = UDim2.new(0, 240, 0, 60)
claimBtn.AnchorPoint = Vector2.new(0.5, 1)
claimBtn.Position = UDim2.new(0.5, 0, 1, -16)
claimBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
claimBtn.TextColor3 = Color3.new(0,0,0)
claimBtn.Font = Enum.Font.GothamBlack
claimBtn.TextScaled = true
claimBtn.Text = "CLAIM"
Instance.new("UICorner", claimBtn).CornerRadius = UDim.new(0, 12)
claimBtn.Parent = modal

Remotes.DailyAvailable.OnClientEvent:Connect(function(streak, reward)
    streakLbl.Text = "Day " .. streak .. " of 7 streak"
    rewardLbl.Text = reward.msg
    modal.Visible = true
end)

claimBtn.MouseButton1Click:Connect(function()
    local ok = Remotes.RequestClaimDaily:InvokeServer()
    if ok then modal.Visible = false end
end)

return true

]]
end

do
    local s = getOrMake(game.StarterPlayer:WaitForChild('StarterPlayerScripts'), 'LocalScript', 'WeatherClient')
    s.Source = [[
-- WeatherClient.client.lua
-- Reacts to weather changes: spawns rain/fog/red mist particles, shows banner.
-- Place in: StarterPlayer > StarterPlayerScripts > WeatherClient (LocalScript)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
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
    banner.Text = weather:upper()
    banner.TextColor3 = ({
        Sunny = Color3.fromRGB(255, 220, 80),
        Rainy = Color3.fromRGB(120, 180, 255),
        Foggy = Color3.fromRGB(220, 220, 220),
        RedMist = Color3.fromRGB(255, 50, 50),
    })[weather] or Color3.fromRGB(255, 200, 0)
    banner.Visible = true
    task.delay(4, function() banner.Visible = false end)

    if weather == "Rainy" then activeFX = rainFX()
    elseif weather == "Foggy" then activeFX = fogFX()
    elseif weather == "RedMist" then activeFX = redMistFX() end
end)

Remotes.EventBroadcast.OnClientEvent:Connect(function(message)
    banner.Text = message
    banner.Visible = true
    task.delay(5, function() banner.Visible = false end)
end)

return true

]]
end

print('[KittyRaiser] chunk 5/5 loaded - 4 scripts')
