-- SurvivalUI.client.lua  v2 — hunger + thirst bars, warm theme, responsive.
-- Sits below the TopBar on the left side. Bars use icons + smooth tweens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Remotes  = require(ReplicatedStorage.Modules.RemoteEvents)
local UIUtil   = require(ReplicatedStorage.Modules:WaitForChild("UIUtil"))
local AssetIds = require(ReplicatedStorage.Modules.AssetIds)

local player = Players.LocalPlayer
local hud    = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
if not hud then return end

-- Container holds both bars vertically just under the TopBar
local container = Instance.new("Frame")
container.Name = "SurvivalContainer"
container.Size = UDim2.new(0, 232, 0, 60)
container.Position = UDim2.new(0, 12, 0, 88)  -- below TopBar (70-80px)
container.BackgroundTransparency = 1
container.Parent = hud
local listLayout = Instance.new("UIListLayout", container)
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function makeBar(name, color, iconKey, layoutOrder)
    local row = Instance.new("Frame")
    row.Name = name .. "BarContainer"
    row.Size = UDim2.new(1, 0, 0, 26)
    row.BackgroundTransparency = 1
    row.LayoutOrder = layoutOrder
    row.Parent = container

    -- Always-visible colored circle backplate (matches the bar color) so the
    -- icon position is visible even if the asset image hasn't loaded.
    local iconWidth = 30
    local backplate = Instance.new("Frame", row)
    backplate.Name = "IconBackplate"
    backplate.AnchorPoint = Vector2.new(0, 0.5)
    backplate.Size = UDim2.new(0, 26, 0, 26)
    backplate.Position = UDim2.new(0, 0, 0.5, 0)
    backplate.BackgroundColor3 = color
    backplate.BorderSizePixel = 0
    Instance.new("UICorner", backplate).CornerRadius = UDim.new(1, 0)
    local bpStroke = Instance.new("UIStroke", backplate)
    bpStroke.Thickness = 1; bpStroke.Color = UIUtil.Palette.stroke; bpStroke.Transparency = 0.3

    if iconKey and AssetIds.has(iconKey) then
        local icon = Instance.new("ImageLabel", backplate)
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.BackgroundTransparency = 1
        icon.Size = UDim2.new(0, 18, 0, 18)
        icon.Position = UDim2.new(0.5, 0, 0.5, 0)
        icon.Image = AssetIds[iconKey]
        icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
        icon.ScaleType = Enum.ScaleType.Fit
    end

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0, 64, 1, 0)
    lbl.Position = UDim2.new(0, iconWidth, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = color
    lbl.Font = UIUtil.Token.fontHeader
    lbl.TextScaled = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextStrokeTransparency = 0.4
    lbl.TextStrokeColor3 = UIUtil.Palette.stroke
    UIUtil.TextSize.small(lbl)

    local bg = Instance.new("Frame", row)
    bg.Size = UDim2.new(1, -(iconWidth + 70), 0.65, 0)
    bg.Position = UDim2.new(0, iconWidth + 68, 0.175, 0)
    bg.BackgroundColor3 = UIUtil.Palette.bgDark
    bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)
    local bgStroke = Instance.new("UIStroke", bg)
    bgStroke.Thickness = UIUtil.Token.strokeThin
    bgStroke.Color = UIUtil.Palette.hairline

    local fill = Instance.new("Frame", bg)
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = color
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local g = Instance.new("UIGradient", fill)
    g.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255):Lerp(color, 0.5)),
        ColorSequenceKeypoint.new(1, color),
    }
    g.Rotation = 90
    return fill
end

local hungerFill = makeBar("HUNGER", Color3.fromRGB(230, 140, 60), "fish", 1)
local thirstFill = makeBar("THIRST", Color3.fromRGB(80, 160, 220), "slushie", 2)

Remotes.SurvivalUpdate.OnClientEvent:Connect(function(hunger, thirst)
    TweenService:Create(hungerFill, UIUtil.Token.easeOut,
        {Size = UDim2.new(math.clamp(hunger/100, 0, 1), 0, 1, 0)}):Play()
    TweenService:Create(thirstFill, UIUtil.Token.easeOut,
        {Size = UDim2.new(math.clamp(thirst/100, 0, 1), 0, 1, 0)}):Play()
end)

Remotes.UpdatePlayerData.OnClientEvent:Connect(function(d)
    if d.hunger then
        TweenService:Create(hungerFill, UIUtil.Token.easeOut,
            {Size = UDim2.new(math.clamp(d.hunger/100, 0, 1), 0, 1, 0)}):Play()
    end
    if d.thirst then
        TweenService:Create(thirstFill, UIUtil.Token.easeOut,
            {Size = UDim2.new(math.clamp(d.thirst/100, 0, 1), 0, 1, 0)}):Play()
    end
end)

print("[SurvivalUI v2] hunger + thirst bars, warm theme")
