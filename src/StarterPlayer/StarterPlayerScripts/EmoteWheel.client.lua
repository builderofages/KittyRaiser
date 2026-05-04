-- EmoteWheel.client.lua  v2 — radial emote wheel, responsive, warm theme.
-- B key (PC) or always-visible toggle button (mobile) opens the wheel.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes    = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local UIUtil     = require(ReplicatedStorage.Modules:WaitForChild("UIUtil"))

local player = Players.LocalPlayer
local hud    = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
if not hud then return end

-- Pick wheel diameter responsively
local function pickWheelSize()
    local p = UIUtil.platform()
    if p == "phone"  then return 280 end
    if p == "tablet" then return 340 end
    return 380
end

local WHEEL_SIZE = pickWheelSize()

local wheel = Instance.new("Frame")
wheel.Name = "EmoteWheel"
wheel.Size = UDim2.new(0, WHEEL_SIZE, 0, WHEEL_SIZE)
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.Position = UDim2.new(0.5, 0, 0.5, 0)
wheel.BackgroundColor3 = UIUtil.Palette.bgMid
wheel.BackgroundTransparency = 0.15
wheel.BorderSizePixel = 0
wheel.Visible = false
wheel.Parent = hud
Instance.new("UICorner", wheel).CornerRadius = UDim.new(1, 0)
local stroke = Instance.new("UIStroke", wheel)
stroke.Thickness = UIUtil.Token.strokeBold
stroke.Color = UIUtil.Palette.hairline

-- Title in the center
local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Size = UDim2.new(0, 120, 0, 30)
title.Position = UDim2.new(0.5, 0, 0.5, 0)
title.BackgroundTransparency = 1
title.Text = "EMOTES"
title.TextColor3 = UIUtil.Palette.primary
title.TextStrokeTransparency = 0.4
title.TextStrokeColor3 = UIUtil.Palette.stroke
title.Font = UIUtil.Token.fontHeader
title.TextScaled = true
title.Parent = wheel
UIUtil.TextSize.label(title)

-- Build emote buttons in a circle. We use AnchorPoint(0.5, 0.5) +
-- scale-based position so the wheel resizes cleanly.
local function rebuildButtons(diameter)
    for _, c in ipairs(wheel:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local btnSize = math.floor(diameter * 0.20)
    local radius  = (diameter * 0.5) - btnSize * 0.7
    local n = #GameConfig.EMOTES
    for i, emoteName in ipairs(GameConfig.EMOTES) do
        local angle = (i - 1) * (2 * math.pi / n) - math.pi / 2
        local px = math.cos(angle) * radius
        local py = math.sin(angle) * radius
        local btn = Instance.new("TextButton")
        btn.AnchorPoint = Vector2.new(0.5, 0.5)
        btn.Size = UDim2.new(0, btnSize, 0, btnSize * 0.7)
        btn.Position = UDim2.new(0.5, px, 0.5, py)
        btn.BackgroundColor3 = UIUtil.Palette.panel
        btn.AutoButtonColor = true
        btn.TextColor3 = UIUtil.Palette.textHi
        btn.Font = UIUtil.Token.fontHeader
        btn.Text = emoteName
        btn.TextScaled = true
        btn.TextStrokeTransparency = 0.4
        btn.TextStrokeColor3 = UIUtil.Palette.stroke
        Instance.new("UICorner", btn).CornerRadius = UIUtil.Token.cornerSm
        local s = Instance.new("UIStroke", btn)
        s.Thickness = UIUtil.Token.strokeReg; s.Color = UIUtil.Palette.hairline
        btn.Parent = wheel
        UIUtil.boundText(btn, 12, 18)
        btn.MouseButton1Click:Connect(function()
            Remotes.RequestEmote:FireServer(emoteName)
            wheel.Visible = false
        end)
    end
end
rebuildButtons(WHEEL_SIZE)

-- Re-pick wheel size on viewport resize
local cam = workspace.CurrentCamera
if cam then
    cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        local s = pickWheelSize()
        if s ~= WHEEL_SIZE then
            WHEEL_SIZE = s
            wheel.Size = UDim2.new(0, s, 0, s)
            rebuildButtons(s)
        end
    end)
end

-- Toggle: B key (PC) or always show a small button on mobile
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.B then
        wheel.Visible = not wheel.Visible
    elseif input.KeyCode == Enum.KeyCode.Escape and wheel.Visible then
        wheel.Visible = false
    end
end)

-- Mobile/touch: small toggle button on left side, just under SurvivalContainer
if UIUtil.isMobile() then
    local toggle = Instance.new("TextButton")
    toggle.Name = "EmoteToggle"
    toggle.Size = UDim2.new(0, 56, 0, 56)
    toggle.Position = UDim2.new(0, 12, 0, 160)
    toggle.AnchorPoint = Vector2.new(0, 0)
    toggle.BackgroundColor3 = UIUtil.Palette.panel
    toggle.AutoButtonColor = true
    toggle.Text = "EMO"
    toggle.TextColor3 = UIUtil.Palette.textHi
    toggle.Font = UIUtil.Token.fontHeader
    toggle.TextScaled = true
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)
    local ts = Instance.new("UIStroke", toggle)
    ts.Thickness = UIUtil.Token.strokeReg; ts.Color = UIUtil.Palette.hairline
    UIUtil.boundText(toggle, 14, 20)
    toggle.Parent = hud
    toggle.MouseButton1Click:Connect(function()
        wheel.Visible = not wheel.Visible
    end)
end

-- Floating "*emote*" tag above other players' heads
Remotes.EmoteBroadcast.OnClientEvent:Connect(function(userId, emoteName)
    local target = Players:GetPlayerByUserId(userId)
    if not target or not target.Character then return end
    local head = target.Character:FindFirstChild("Head")
    if not head then return end
    local b = Instance.new("BillboardGui")
    b.Size = UDim2.new(0, 110, 0, 30)
    b.StudsOffset = Vector3.new(0, 1.6, 0)
    b.AlwaysOnTop = true
    b.Parent = head
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundColor3 = UIUtil.Palette.bgMid
    lbl.BackgroundTransparency = 0.25
    lbl.Text = emoteName
    lbl.TextColor3 = UIUtil.Palette.primary
    lbl.Font = UIUtil.Token.fontHeader
    lbl.TextScaled = true
    Instance.new("UICorner", lbl).CornerRadius = UIUtil.Token.cornerSm
    lbl.Parent = b
    UIUtil.boundText(lbl, 12, 18)
    task.delay(2, function() b:Destroy() end)
end)

print("[EmoteWheel v2] responsive + warm theme")
return true
