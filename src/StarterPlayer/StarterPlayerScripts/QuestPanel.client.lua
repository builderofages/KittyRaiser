-- QuestPanel.client.lua  v1
-- Compact daily-quest panel pinned to the left side of the screen.
-- Shows each quest, progress bar, current/target. Auto-collapses on phone
-- to a single button that expands when tapped.
-- Listens to Remotes.QuestUpdate from QuestSystem.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes  = require(ReplicatedStorage.Modules.RemoteEvents)
local UIUtil   = require(ReplicatedStorage.Modules:WaitForChild("UIUtil"))
local AssetIds = require(ReplicatedStorage.Modules.AssetIds)

local player = Players.LocalPlayer
local hud    = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
if not hud then return end

local PHONE = UIUtil.isPhone()
local PANEL_W = PHONE and 220 or 280

-- Container
local container = Instance.new("Frame")
container.Name = "QuestPanel"
container.Size = UDim2.new(0, PANEL_W, 0, 220)
-- Sit below SurvivalContainer (y=88) + bars (60) + 12 gap
container.Position = UDim2.new(0, 12, 0, 162)
container.BackgroundColor3 = UIUtil.Palette.bgMid
container.BackgroundTransparency = 0.1
container.BorderSizePixel = 0
container.Parent = hud
Instance.new("UICorner", container).CornerRadius = UIUtil.Token.cornerMd
local cStroke = Instance.new("UIStroke", container)
cStroke.Thickness = UIUtil.Token.strokeReg
cStroke.Color = UIUtil.Palette.hairline

-- Title row
local titleRow = Instance.new("Frame", container)
titleRow.Size = UDim2.new(1, 0, 0, 28)
titleRow.BackgroundTransparency = 1

if AssetIds.has("star") then
    local ic = Instance.new("ImageLabel", titleRow)
    ic.BackgroundTransparency = 1
    ic.Size = UDim2.new(0, 20, 0, 20)
    ic.Position = UDim2.new(0, 8, 0.5, -10)
    ic.Image = AssetIds.star
    ic.ImageColor3 = UIUtil.Palette.primary
end

local title = Instance.new("TextLabel", titleRow)
title.Size = UDim2.new(1, -68, 1, 0)
title.Position = UDim2.fromOffset(34, 0)
title.BackgroundTransparency = 1
title.Text = "DAILY QUESTS"
title.Font = UIUtil.Token.fontHeader
title.TextColor3 = UIUtil.Palette.primary
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
UIUtil.TextSize.label(title)

-- Collapse toggle
local collapsed = false
local toggle = Instance.new("TextButton", titleRow)
toggle.AnchorPoint = Vector2.new(1, 0.5)
toggle.Size = UDim2.new(0, 28, 0, 22)
toggle.Position = UDim2.new(1, -8, 0.5, 0)
toggle.BackgroundColor3 = UIUtil.Palette.panel
toggle.AutoButtonColor = true
toggle.Text = "-"
toggle.TextColor3 = UIUtil.Palette.textHi
toggle.Font = UIUtil.Token.fontHeader
toggle.TextScaled = true
Instance.new("UICorner", toggle).CornerRadius = UIUtil.Token.cornerSm
UIUtil.boundText(toggle, 14, 22)

-- List body
local body = Instance.new("Frame", container)
body.Size = UDim2.new(1, -16, 1, -36)
body.Position = UDim2.fromOffset(8, 32)
body.BackgroundTransparency = 1
local layout = Instance.new("UIListLayout", body)
layout.FillDirection = Enum.FillDirection.Vertical
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder

local function setCollapsed(v)
    collapsed = v
    body.Visible = not v
    toggle.Text = v and "+" or "-"
    container.Size = v and UDim2.new(0, PANEL_W, 0, 36) or UDim2.new(0, PANEL_W, 0, 220)
end
toggle.MouseButton1Click:Connect(function() setCollapsed(not collapsed) end)
if PHONE then setCollapsed(true) end

-- Build / refresh quest rows from snapshot
local function rebuild(quests)
    for _, c in ipairs(body:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    for i, q in ipairs(quests) do
        local row = Instance.new("Frame", body)
        row.Size = UDim2.new(1, 0, 0, 36)
        row.LayoutOrder = i
        row.BackgroundColor3 = q.done and UIUtil.Palette.accent or UIUtil.Palette.panel
        row.BackgroundTransparency = 0.1
        row.BorderSizePixel = 0
        Instance.new("UICorner", row).CornerRadius = UIUtil.Token.cornerSm

        local label = Instance.new("TextLabel", row)
        label.Size = UDim2.new(1, -56, 0.5, 0)
        label.Position = UDim2.new(0, 8, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = q.label
        label.Font = UIUtil.Token.fontLabel
        label.TextColor3 = UIUtil.Palette.textHi
        label.TextStrokeTransparency = 0.4
        label.TextStrokeColor3 = UIUtil.Palette.stroke
        label.TextScaled = true
        label.TextXAlignment = Enum.TextXAlignment.Left
        UIUtil.TextSize.small(label)

        local count = Instance.new("TextLabel", row)
        count.AnchorPoint = Vector2.new(1, 0)
        count.Size = UDim2.new(0, 50, 0.5, 0)
        count.Position = UDim2.new(1, -6, 0, 0)
        count.BackgroundTransparency = 1
        count.Text = q.current .. "/" .. q.target
        count.Font = UIUtil.Token.fontHeader
        count.TextColor3 = q.done and UIUtil.Palette.gold or UIUtil.Palette.textHi
        count.TextStrokeTransparency = 0.4
        count.TextStrokeColor3 = UIUtil.Palette.stroke
        count.TextScaled = true
        count.TextXAlignment = Enum.TextXAlignment.Right
        UIUtil.TextSize.small(count)

        -- Progress bar
        local bg = Instance.new("Frame", row)
        bg.AnchorPoint = Vector2.new(0, 1)
        bg.Size = UDim2.new(1, -16, 0, 6)
        bg.Position = UDim2.new(0, 8, 1, -6)
        bg.BackgroundColor3 = UIUtil.Palette.bgDark
        bg.BorderSizePixel = 0
        Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame", bg)
        local pct = (q.target > 0) and (q.current / q.target) or 0
        fill.Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)
        fill.BackgroundColor3 = q.done and UIUtil.Palette.gold or UIUtil.Palette.primary
        fill.BorderSizePixel = 0
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    end
end

if Remotes.QuestUpdate then
    Remotes.QuestUpdate.OnClientEvent:Connect(rebuild)
end

-- Completion toast
if Remotes.QuestCompleted then
    Remotes.QuestCompleted.OnClientEvent:Connect(function(q)
        local toastFrame = hud:FindFirstChild("ToastFrame")
        if not toastFrame then return end
        local txt = "QUEST COMPLETE  ·  " .. q.label .. "  ·  +" .. (q.rewardChaos or 0) .. " CHAOS"
        UIUtil.makeToast(toastFrame, txt, UIUtil.Palette.gold, 3.5)
    end)
end

print("[QuestPanel v1] daily quests panel ready")
