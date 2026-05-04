-- PerkUI.client.lua  v2 — Perk picker + stats allocation modals.
-- Uses UIUtil tokens, warm cartoon palette, responsive modal sizing.
-- Adds a STATS button to the HUD bottom bar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes     = require(ReplicatedStorage.Modules.RemoteEvents)
local PerkConfig  = require(ReplicatedStorage.Modules.PerkConfig)
local GameConfig  = require(ReplicatedStorage.Modules.GameConfig)
local UIUtil      = require(ReplicatedStorage.Modules:WaitForChild("UIUtil"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud       = playerGui:WaitForChild("MainHUD", 30)
if not hud then return end

-- ============================================================
-- MODAL FACTORY (warm theme, responsive)
-- ============================================================
local function makeModal(displayTitle, accentColor)
    local modal = Instance.new("Frame")
    modal.Name = displayTitle .. "Modal"
    modal.Size = UIUtil.modalSize(560, 480, 24)
    modal.AnchorPoint = Vector2.new(0.5, 0.5)
    modal.Position = UDim2.new(0.5, 0, 0.5, 0)
    modal.BackgroundColor3 = UIUtil.Palette.bgMid
    modal.BorderSizePixel = 0
    modal.Visible = false
    modal.ZIndex = UIUtil.DisplayOrder.Modal
    Instance.new("UICorner", modal).CornerRadius = UIUtil.Token.cornerLg
    local stroke = Instance.new("UIStroke", modal)
    stroke.Thickness = UIUtil.Token.strokeBold
    stroke.Color = accentColor
    modal.Parent = hud

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name = "Title"
    titleLbl.Size = UDim2.new(1, -80, 0, 50)
    titleLbl.Position = UDim2.new(0, 16, 0, 12)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = displayTitle
    titleLbl.TextColor3 = accentColor
    titleLbl.Font = UIUtil.Token.fontHeader
    titleLbl.TextScaled = true
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = modal
    UIUtil.TextSize.header(titleLbl)

    local close = Instance.new("TextButton")
    close.Name = "CloseButton"
    close.Size = UDim2.new(0, 48, 0, 48)
    close.Position = UDim2.new(1, -56, 0, 8)
    close.BackgroundColor3 = UIUtil.Palette.danger
    close.AutoButtonColor = true
    close.Text = "X"
    close.TextColor3 = UIUtil.Palette.textHi
    close.Font = UIUtil.Token.fontHeader
    close.TextScaled = true
    Instance.new("UICorner", close).CornerRadius = UIUtil.Token.cornerSm
    local cs = Instance.new("UIStroke", close)
    cs.Thickness = UIUtil.Token.strokeReg; cs.Color = UIUtil.Palette.stroke
    close.Parent = modal
    UIUtil.boundText(close, 18, 26)
    close.MouseButton1Click:Connect(function() modal.Visible = false end)

    -- Re-clamp on viewport resize
    local cam = workspace.CurrentCamera
    if cam then
        cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            modal.Size = UIUtil.modalSize(560, 480, 24)
        end)
    end

    return modal
end

-- ============================================================
-- PERK PICKER
-- ============================================================
local perkModal = makeModal("PERK PICKER", UIUtil.Palette.gold)
local perkSubtitle = Instance.new("TextLabel")
perkSubtitle.Size = UDim2.new(1, -32, 0, 26)
perkSubtitle.Position = UDim2.new(0, 16, 0, 64)
perkSubtitle.BackgroundTransparency = 1
perkSubtitle.Text = "Pick 1 perk for this slot"
perkSubtitle.TextColor3 = UIUtil.Palette.textMuted
perkSubtitle.Font = UIUtil.Token.fontBody
perkSubtitle.TextScaled = true
perkSubtitle.TextXAlignment = Enum.TextXAlignment.Left
perkSubtitle.Parent = perkModal
UIUtil.TextSize.body(perkSubtitle)

local perkScroll = Instance.new("ScrollingFrame")
perkScroll.Name = "PerkList"
perkScroll.Size = UDim2.new(1, -32, 1, -110)
perkScroll.Position = UDim2.new(0, 16, 0, 96)
perkScroll.BackgroundTransparency = 1
perkScroll.BorderSizePixel = 0
perkScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
perkScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
perkScroll.ScrollBarThickness = 6
perkScroll.ScrollBarImageColor3 = UIUtil.Palette.hairline
perkScroll.Parent = perkModal
local perkLayout = Instance.new("UIListLayout", perkScroll)
perkLayout.Padding = UDim.new(0, 8)
perkLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function showPerkPicker(slot, options)
    perkSubtitle.Text = "SLOT " .. slot .. " — pick 1 perk"
    for _, c in ipairs(perkScroll:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    for _, perkId in ipairs(options) do
        local p = PerkConfig.getPerk(perkId)
        if not p then continue end
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 70)
        row.BackgroundColor3 = UIUtil.Palette.panel
        row.BorderSizePixel = 0
        Instance.new("UICorner", row).CornerRadius = UIUtil.Token.cornerSm
        row.Parent = perkScroll

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(0.55, -16, 0.5, 0)
        nameLbl.Position = UDim2.new(0, 12, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = p.name
        nameLbl.TextColor3 = UIUtil.Palette.gold
        nameLbl.Font = UIUtil.Token.fontHeader
        nameLbl.TextScaled = true
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent = row
        UIUtil.TextSize.label(nameLbl)

        local descLbl = Instance.new("TextLabel")
        descLbl.Size = UDim2.new(0.55, -16, 0.5, 0)
        descLbl.Position = UDim2.new(0, 12, 0.5, 0)
        descLbl.BackgroundTransparency = 1
        descLbl.Text = p.desc
        descLbl.TextColor3 = UIUtil.Palette.textMuted
        descLbl.Font = UIUtil.Token.fontBody
        descLbl.TextScaled = true
        descLbl.TextXAlignment = Enum.TextXAlignment.Left
        descLbl.TextWrapped = true
        descLbl.Parent = row
        UIUtil.TextSize.small(descLbl)

        local pickBtn = Instance.new("TextButton")
        pickBtn.Size = UDim2.new(0.35, 0, 0.7, 0)
        pickBtn.Position = UDim2.new(0.62, 0, 0.15, 0)
        pickBtn.BackgroundColor3 = UIUtil.Palette.gold
        pickBtn.TextColor3 = UIUtil.Palette.textLo
        pickBtn.Font = UIUtil.Token.fontHeader
        pickBtn.Text = "PICK"
        pickBtn.TextScaled = true
        pickBtn.AutoButtonColor = true
        Instance.new("UICorner", pickBtn).CornerRadius = UIUtil.Token.cornerSm
        local ps = Instance.new("UIStroke", pickBtn)
        ps.Thickness = UIUtil.Token.strokeReg; ps.Color = UIUtil.Palette.stroke
        pickBtn.Parent = row
        UIUtil.TextSize.label(pickBtn)
        pickBtn.MouseButton1Click:Connect(function()
            local ok = Remotes.RequestEquipPerk:InvokeServer(slot, perkId)
            if ok then perkModal.Visible = false end
        end)
    end
    perkModal.Visible = true
end

Remotes.PerkSlotEarned.OnClientEvent:Connect(showPerkPicker)

-- ============================================================
-- STATS SCREEN
-- ============================================================
local statsModal = makeModal("STATS", UIUtil.Palette.accent)
local statsSubtitle = Instance.new("TextLabel")
statsSubtitle.Size = UDim2.new(1, -32, 0, 26)
statsSubtitle.Position = UDim2.new(0, 16, 0, 64)
statsSubtitle.BackgroundTransparency = 1
statsSubtitle.Text = "Allocate stat points each level"
statsSubtitle.TextColor3 = UIUtil.Palette.textMuted
statsSubtitle.Font = UIUtil.Token.fontBody
statsSubtitle.TextScaled = true
statsSubtitle.TextXAlignment = Enum.TextXAlignment.Left
statsSubtitle.Parent = statsModal
UIUtil.TextSize.body(statsSubtitle)

local statsScroll = Instance.new("ScrollingFrame")
statsScroll.Name = "StatsList"
statsScroll.Size = UDim2.new(1, -32, 1, -110)
statsScroll.Position = UDim2.new(0, 16, 0, 96)
statsScroll.BackgroundTransparency = 1
statsScroll.BorderSizePixel = 0
statsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
statsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
statsScroll.ScrollBarThickness = 6
statsScroll.ScrollBarImageColor3 = UIUtil.Palette.hairline
statsScroll.Parent = statsModal
local statsLayout = Instance.new("UIListLayout", statsScroll)
statsLayout.Padding = UDim.new(0, 6)
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function rebuildStats(data)
    statsSubtitle.Text = "Unspent points: " .. (data.unspentStatPoints or 0)
    for _, c in ipairs(statsScroll:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    for _, statName in ipairs(GameConfig.STAT_NAMES) do
        local current = (data.stats and data.stats[statName]) or 0
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 56)
        row.BackgroundColor3 = UIUtil.Palette.panel
        row.BorderSizePixel = 0
        Instance.new("UICorner", row).CornerRadius = UIUtil.Token.cornerSm
        row.Parent = statsScroll

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -76, 1, 0)
        nameLbl.Position = UDim2.new(0, 12, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = statName .. "  ·  " .. current
        nameLbl.TextColor3 = UIUtil.Palette.accent
        nameLbl.Font = UIUtil.Token.fontHeader
        nameLbl.TextScaled = true
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent = row
        UIUtil.TextSize.label(nameLbl)

        local plus = Instance.new("TextButton")
        plus.Size = UDim2.new(0, 56, 0.8, 0)
        plus.Position = UDim2.new(1, -64, 0.1, 0)
        plus.Text = "+"
        plus.BackgroundColor3 = UIUtil.Palette.accent
        plus.TextColor3 = UIUtil.Palette.textHi
        plus.Font = UIUtil.Token.fontHeader
        plus.TextScaled = true
        plus.AutoButtonColor = true
        Instance.new("UICorner", plus).CornerRadius = UIUtil.Token.cornerSm
        local ps = Instance.new("UIStroke", plus)
        ps.Thickness = UIUtil.Token.strokeReg; ps.Color = UIUtil.Palette.stroke
        plus.Parent = row
        UIUtil.boundText(plus, 18, 28)
        plus.MouseButton1Click:Connect(function()
            local ok = Remotes.RequestAllocStat:InvokeServer(statName)
            if ok and cachedData then rebuildStats(cachedData) end
        end)
    end
end

local cachedData
Remotes.UpdatePlayerData.OnClientEvent:Connect(function(d)
    cachedData = d
    if statsModal.Visible then rebuildStats(d) end
end)

-- ============================================================
-- HOOK STATS BUTTON ON BOTTOM BAR
-- ============================================================
local function hookStatsButton()
    local botBar = hud:FindFirstChild("BottomBar")
    if not botBar then return end
    if botBar:FindFirstChild("StatsButton") then return end
    local statsBtn = Instance.new("TextButton")
    statsBtn.Name = "StatsButton"
    statsBtn.Size = UDim2.new(0, 84, 0, 60)
    statsBtn.BackgroundColor3 = UIUtil.Palette.accent
    statsBtn.AutoButtonColor = true
    statsBtn.Text = ""
    statsBtn.LayoutOrder = 5
    Instance.new("UICorner", statsBtn).CornerRadius = UIUtil.Token.cornerMd
    local sStr = Instance.new("UIStroke", statsBtn)
    sStr.Thickness = UIUtil.Token.strokeReg; sStr.Color = UIUtil.Palette.stroke
    statsBtn.Parent = botBar

    -- Use bars icon (we already have it uploaded)
    local AssetIds = require(ReplicatedStorage.Modules.AssetIds)
    if AssetIds.has("bars") then
        local img = Instance.new("ImageLabel", statsBtn)
        img.BackgroundTransparency = 1
        img.Size = UDim2.new(0, 26, 0, 26)
        img.Position = UDim2.new(0.5, -13, 0, 6)
        img.Image = AssetIds.bars
        img.ScaleType = Enum.ScaleType.Fit
    end
    local lbl = Instance.new("TextLabel", statsBtn)
    lbl.Size = UDim2.new(1, -8, 0, 18)
    lbl.Position = UDim2.new(0, 4, 1, -22)
    lbl.BackgroundTransparency = 1
    lbl.Text = "STATS"
    lbl.Font = UIUtil.Token.fontHeader
    lbl.TextColor3 = UIUtil.Palette.textHi
    lbl.TextStrokeTransparency = 0.4
    lbl.TextStrokeColor3 = UIUtil.Palette.stroke
    lbl.TextScaled = true
    UIUtil.boundText(lbl, 11, 16)

    statsBtn.MouseButton1Click:Connect(function()
        statsModal.Visible = not statsModal.Visible
        if statsModal.Visible and cachedData then rebuildStats(cachedData) end
    end)
end
hookStatsButton()
hud.ChildAdded:Connect(function() task.wait(0.3); hookStatsButton() end)
task.spawn(function()
    for i = 1, 30 do
        task.wait(0.5)
        local botBar = hud:FindFirstChild("BottomBar")
        if botBar and botBar:FindFirstChild("StatsButton") then return end
        hookStatsButton()
    end
end)

return true
