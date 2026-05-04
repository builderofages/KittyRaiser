-- EventBanner.client.lua  v1 — server-wide event broadcast banner.
-- Listens to Remotes.EventBroadcast 'event' kind from EventScheduler.
-- Renders a top-of-screen banner that slides in, holds, then slides out.
-- Stack-safe: multiple events queue and play in sequence.

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local UIUtil  = require(ReplicatedStorage.Modules.UIUtil)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local sg = Instance.new("ScreenGui", playerGui)
sg.Name = "EventBanner"
sg.IgnoreGuiInset = true
sg.ResetOnSpawn = false
sg.DisplayOrder = (UIUtil.DisplayOrder.Combo or 90) + 5

local banner = Instance.new("Frame", sg)
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, -100)  -- start hidden above screen
banner.Size = UDim2.fromOffset(520, 80)
banner.BackgroundColor3 = Color3.fromRGB(220, 150, 60)
banner.BorderSizePixel = 0
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke", banner)
stroke.Thickness = 4; stroke.Color = Color3.fromRGB(110, 75, 40)
local grad = Instance.new("UIGradient", banner)
grad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 195, 100)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 125, 50)),
}
grad.Rotation = 90

local title = Instance.new("TextLabel", banner)
title.Size = UDim2.new(1, -16, 0, 36)
title.Position = UDim2.new(0, 8, 0, 6)
title.BackgroundTransparency = 1
title.Text = ""
title.Font = Enum.Font.LuckiestGuy
title.TextColor3 = Color3.fromRGB(80, 40, 20)
title.TextStrokeTransparency = 0.3
title.TextStrokeColor3 = Color3.fromRGB(255, 240, 200)
title.TextScaled = true
local tc = Instance.new("UITextSizeConstraint", title); tc.MinTextSize = 18; tc.MaxTextSize = 32

local subtitle = Instance.new("TextLabel", banner)
subtitle.Size = UDim2.new(1, -16, 0, 26)
subtitle.Position = UDim2.new(0, 8, 0, 44)
subtitle.BackgroundTransparency = 1
subtitle.Text = ""
subtitle.Font = Enum.Font.GothamBold
subtitle.TextColor3 = Color3.fromRGB(60, 35, 18)
subtitle.TextScaled = true
local sc = Instance.new("UITextSizeConstraint", subtitle); sc.MinTextSize = 11; sc.MaxTextSize = 16

local queue = {}
local playing = false
local function playNext()
    if playing or #queue == 0 then return end
    playing = true
    local p = table.remove(queue, 1)
    title.Text = p.title or "EVENT"
    subtitle.Text = p.message or ""
    -- Slide in
    TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, 0, 0, 88)}):Play()
    task.wait(4.5)
    -- Slide out
    TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {Position = UDim2.new(0.5, 0, 0, -100)}):Play()
    task.wait(0.4)
    playing = false
    if #queue > 0 then task.spawn(playNext) end
end

Remotes.EventBroadcast.OnClientEvent:Connect(function(kind, payload)
    if kind ~= "event" then return end
    if typeof(payload) ~= "table" then return end
    table.insert(queue, payload)
    if not playing then task.spawn(playNext) end
end)

print("[EventBanner v1] online")
