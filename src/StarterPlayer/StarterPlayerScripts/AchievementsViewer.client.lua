-- AchievementsViewer.client.lua  v1 — browseable achievement list.
-- Adds a small ACH button to the top bar and a modal showing all 8
-- achievements from AchievementConfig with their unlock state derived from
-- the player's persisted data (totalPranks / level / rebirths / attribute
-- flags BossDefeated, Ticketed).
-- Place in: StarterPlayer > StarterPlayerScripts > AchievementsViewer (LocalScript)

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")

local UIUtil   = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIUtil"))
local Remotes  = require(ReplicatedStorage.Modules.RemoteEvents)
local AssetIds = require(ReplicatedStorage.Modules.AssetIds)
local AchievementConfig = require(ReplicatedStorage.Modules:WaitForChild("AchievementConfig"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud       = playerGui:WaitForChild("MainHUD", 30)
if not hud then return end

-- Latest replicated player data (DataHandler fires UpdatePlayerData).
local cachedData = {}
Remotes.UpdatePlayerData.OnClientEvent:Connect(function(d)
    if typeof(d) == "table" then cachedData = d end
end)

-- =====================================================================
-- TRIGGER BUTTON — small ACH pill anchored top-right under minimap
-- =====================================================================
local triggerSG = Instance.new("ScreenGui", playerGui)
triggerSG.Name = "AchievementsTrigger"
triggerSG.IgnoreGuiInset = false
triggerSG.ResetOnSpawn = false
triggerSG.DisplayOrder = UIUtil.DisplayOrder.HUD or 50

local btn = Instance.new("TextButton", triggerSG)
btn.AnchorPoint = Vector2.new(1, 0)
btn.Size = UDim2.new(0, 80, 0, 32)
btn.Position = UDim2.new(1, -16, 0, 290)  -- under minimap (180 + ~110 buffer)
btn.BackgroundColor3 = Color3.fromRGB(110, 75, 45)
btn.AutoButtonColor = true
btn.Text = "ACH"
btn.Font = Enum.Font.LuckiestGuy
btn.TextScaled = true
btn.TextColor3 = Color3.fromRGB(255, 240, 200)
btn.TextStrokeTransparency = 0.3
btn.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
local btnStroke = Instance.new("UIStroke", btn)
btnStroke.Thickness = 2; btnStroke.Color = Color3.fromRGB(60, 35, 18)
local bc = Instance.new("UITextSizeConstraint", btn); bc.MinTextSize = 12; bc.MaxTextSize = 18

-- =====================================================================
-- MODAL
-- =====================================================================
local modalSG = Instance.new("ScreenGui", playerGui)
modalSG.Name = "AchievementsModal"
modalSG.IgnoreGuiInset = true
modalSG.ResetOnSpawn = false
modalSG.DisplayOrder = (UIUtil.DisplayOrder.Modal or 100) + 5
modalSG.Enabled = false

local backdrop = Instance.new("Frame", modalSG)
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.45
backdrop.BorderSizePixel = 0

local modal = Instance.new("Frame", modalSG)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.Size = UDim2.fromOffset(560, 540)
modal.BackgroundColor3 = Color3.fromRGB(245, 230, 200)
modal.BorderSizePixel = 0
Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 14)
local mStroke = Instance.new("UIStroke", modal)
mStroke.Thickness = 4; mStroke.Color = Color3.fromRGB(110, 75, 45)

local title = Instance.new("TextLabel", modal)
title.Size = UDim2.new(1, -56, 0, 44)
title.Position = UDim2.new(0, 16, 0, 12)
title.BackgroundTransparency = 1
title.Text = "ACHIEVEMENTS"
title.Font = Enum.Font.LuckiestGuy
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(80, 40, 20)
title.TextXAlignment = Enum.TextXAlignment.Left
local tc = Instance.new("UITextSizeConstraint", title); tc.MinTextSize = 18; tc.MaxTextSize = 32

local close = Instance.new("TextButton", modal)
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -12, 0, 12)
close.Size = UDim2.fromOffset(36, 36)
close.BackgroundColor3 = Color3.fromRGB(220, 100, 80)
close.Text = "X"
close.Font = Enum.Font.GothamBlack
close.TextColor3 = Color3.fromRGB(255, 248, 230)
close.TextScaled = true
Instance.new("UICorner", close).CornerRadius = UDim.new(1, 0)

local scroll = Instance.new("ScrollingFrame", modal)
scroll.Size = UDim2.new(1, -32, 1, -76)
scroll.Position = UDim2.new(0, 16, 0, 64)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = Color3.fromRGB(110, 75, 45)
local layout = Instance.new("UIListLayout", scroll)
layout.Padding = UDim.new(0, 8)

local function isUnlocked(entry, data)
    if entry.trigger == "first_prank" then return (data.totalPranks or 0) > 0 end
    if entry.trigger == "level"       then return (data.level or 1) >= (entry.threshold or 1) end
    if entry.trigger == "rebirth"     then return (data.rebirths or 0) >= (entry.threshold or 1) end
    if entry.trigger == "boss_defeat" then return (data.bossesDefeated or 0) > 0 end
    if entry.trigger == "ticketed"    then return (data.timesTicketed or 0) > 0 end
    return false
end

local function progressText(entry, data)
    if entry.trigger == "first_prank" then
        return tostring(math.min(1, data.totalPranks or 0)) .. "/1"
    elseif entry.trigger == "level" then
        return tostring(math.min(entry.threshold or 1, data.level or 1)) .. "/" .. (entry.threshold or 1)
    elseif entry.trigger == "rebirth" then
        return tostring(math.min(entry.threshold or 1, data.rebirths or 0)) .. "/" .. (entry.threshold or 1)
    elseif entry.trigger == "boss_defeat" then
        return tostring(math.min(1, data.bossesDefeated or 0)) .. "/1"
    elseif entry.trigger == "ticketed" then
        return tostring(math.min(1, data.timesTicketed or 0)) .. "/1"
    end
    return "-"
end

local function rebuild()
    for _, c in ipairs(scroll:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    -- Lifetime totals header row
    local totalsRow = Instance.new("Frame", scroll)
    totalsRow.Size = UDim2.new(1, -8, 0, 60)
    totalsRow.BackgroundColor3 = Color3.fromRGB(255, 220, 170)
    totalsRow.BorderSizePixel = 0
    Instance.new("UICorner", totalsRow).CornerRadius = UDim.new(0, 8)
    local tStroke = Instance.new("UIStroke", totalsRow)
    tStroke.Thickness = 2; tStroke.Color = Color3.fromRGB(180, 140, 90)
    local tlbl = Instance.new("TextLabel", totalsRow)
    tlbl.Size = UDim2.new(1, -16, 1, 0)
    tlbl.Position = UDim2.fromOffset(8, 0)
    tlbl.BackgroundTransparency = 1
    tlbl.TextColor3 = Color3.fromRGB(80, 40, 20)
    tlbl.Font = Enum.Font.GothamBold
    tlbl.TextScaled = true
    tlbl.TextXAlignment = Enum.TextXAlignment.Left
    tlbl.Text = string.format(
        "LIFETIME  ·  Pranks: %d  ·  Bosses: %d  ·  Rebirths: %d  ·  Tickets: %d",
        cachedData.totalPranks or 0,
        cachedData.bossesDefeated or 0,
        cachedData.rebirths or 0,
        cachedData.timesTicketed or 0)
    local tlc = Instance.new("UITextSizeConstraint", tlbl); tlc.MinTextSize = 11; tlc.MaxTextSize = 16

    -- Achievement rows
    for _, entry in ipairs(AchievementConfig.List) do
        local unlocked = isUnlocked(entry, cachedData)
        local row = Instance.new("Frame", scroll)
        row.Size = UDim2.new(1, -8, 0, 64)
        row.BackgroundColor3 = unlocked
            and Color3.fromRGB(255, 245, 215)
            or Color3.fromRGB(225, 215, 195)
        row.BackgroundTransparency = 0.05
        row.BorderSizePixel = 0
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
        local stroke = Instance.new("UIStroke", row)
        stroke.Thickness = 2
        stroke.Color = unlocked
            and Color3.fromRGB(220, 175, 80)
            or Color3.fromRGB(140, 120, 100)
        -- Status pill
        local status = Instance.new("TextLabel", row)
        status.AnchorPoint = Vector2.new(1, 0.5)
        status.Position = UDim2.new(1, -10, 0.5, 0)
        status.Size = UDim2.fromOffset(80, 24)
        status.BackgroundColor3 = unlocked
            and Color3.fromRGB(110, 165, 95)
            or Color3.fromRGB(140, 120, 100)
        status.Text = unlocked and "UNLOCKED" or progressText(entry, cachedData)
        status.TextColor3 = Color3.fromRGB(255, 248, 230)
        status.Font = Enum.Font.GothamBold
        status.TextScaled = true
        Instance.new("UICorner", status).CornerRadius = UDim.new(0, 6)
        local sc = Instance.new("UITextSizeConstraint", status); sc.MinTextSize = 9; sc.MaxTextSize = 12
        -- Name + description
        local name = Instance.new("TextLabel", row)
        name.Size = UDim2.new(1, -110, 0, 26)
        name.Position = UDim2.fromOffset(12, 8)
        name.BackgroundTransparency = 1
        name.Text = entry.name
        name.TextColor3 = Color3.fromRGB(80, 40, 20)
        name.Font = Enum.Font.LuckiestGuy
        name.TextScaled = true
        name.TextXAlignment = Enum.TextXAlignment.Left
        local nc = Instance.new("UITextSizeConstraint", name); nc.MinTextSize = 12; nc.MaxTextSize = 18
        local desc = Instance.new("TextLabel", row)
        desc.Size = UDim2.new(1, -110, 0, 22)
        desc.Position = UDim2.fromOffset(12, 36)
        desc.BackgroundTransparency = 1
        desc.Text = entry.description
        desc.TextColor3 = Color3.fromRGB(120, 70, 40)
        desc.Font = Enum.Font.GothamMedium
        desc.TextScaled = true
        desc.TextXAlignment = Enum.TextXAlignment.Left
        local dc = Instance.new("UITextSizeConstraint", desc); dc.MinTextSize = 9; dc.MaxTextSize = 13
    end
end

btn.MouseButton1Click:Connect(function()
    rebuild()
    modalSG.Enabled = true
end)
close.MouseButton1Click:Connect(function() modalSG.Enabled = false end)
backdrop.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        modalSG.Enabled = false
    end
end)

print("[AchievementsViewer v1] online")
