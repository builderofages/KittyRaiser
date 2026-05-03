-- SurvivalUI.client.lua
-- Hunger + thirst bars on HUD. Listens to SurvivalUpdate events.
-- Place in: StarterPlayer > StarterPlayerScripts > SurvivalUI (LocalScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

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

local function setBars(hunger, thirst)
    local hPct = math.clamp((hunger or 100) / 100, 0, 1)
    local tPct = math.clamp((thirst or 100) / 100, 0, 1)
    TweenService:Create(hungerFill, TweenInfo.new(0.4), {Size = UDim2.new(hPct, 0, 1, 0)}):Play()
    TweenService:Create(thirstFill, TweenInfo.new(0.4), {Size = UDim2.new(tPct, 0, 1, 0)}):Play()
end

Remotes.SurvivalUpdate.OnClientEvent:Connect(setBars)
Remotes.UpdatePlayerData.OnClientEvent:Connect(function(d)
    setBars(d.hunger, d.thirst)
end)

return true
