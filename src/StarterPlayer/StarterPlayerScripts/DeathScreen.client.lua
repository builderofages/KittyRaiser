-- DeathScreen.client.lua  v1
-- Shows a "you died" overlay when the player's Humanoid dies, with a
-- countdown timer, big RESPAWN button, and a "what killed you" line.
-- Place in: StarterPlayer > StarterPlayerScripts > DeathScreen (LocalScript)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIUtil = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIUtil"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RESPAWN_DELAY = 5  -- seconds

local function buildOverlay(killReason)
    -- Reuse if it exists
    local existing = playerGui:FindFirstChild("DeathScreen")
    if existing then existing:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name = "DeathScreen"
    sg.IgnoreGuiInset = true
    sg.ResetOnSpawn = false
    sg.DisplayOrder = UIUtil.DisplayOrder.DeathScreen
    sg.Parent = playerGui

    local dim = Instance.new("Frame", sg)
    dim.Size = UDim2.fromScale(1, 1)
    dim.BackgroundColor3 = Color3.fromRGB(20, 8, 8)
    dim.BackgroundTransparency = 1
    dim.BorderSizePixel = 0
    TweenService:Create(dim, UIUtil.Token.easeOut, {BackgroundTransparency = 0.4}):Play()

    local card = Instance.new("Frame", sg)
    card.Size = UIUtil.modalSize(420, 300, 24)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.BackgroundColor3 = UIUtil.Palette.bgMid
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UIUtil.Token.cornerLg
    local cs = Instance.new("UIStroke", card)
    cs.Thickness = UIUtil.Token.strokeBold; cs.Color = UIUtil.Palette.danger
    local cg = Instance.new("UIGradient", card)
    cg.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, UIUtil.Palette.panel),
        ColorSequenceKeypoint.new(1, UIUtil.Palette.bgDark),
    }
    cg.Rotation = 90

    -- Big "YOU DIED" headline
    local headline = Instance.new("TextLabel", card)
    headline.Size = UDim2.new(1, -32, 0, 70)
    headline.Position = UDim2.new(0, 16, 0, 16)
    headline.BackgroundTransparency = 1
    headline.Text = "YOU DIED"
    headline.Font = UIUtil.Token.fontTitle
    headline.TextColor3 = UIUtil.Palette.danger
    headline.TextStrokeTransparency = 0.4
    headline.TextStrokeColor3 = UIUtil.Palette.stroke
    headline.TextScaled = true
    UIUtil.TextSize.hero(headline)

    -- Cause-of-death sub-line
    local reason = Instance.new("TextLabel", card)
    reason.Size = UDim2.new(1, -32, 0, 28)
    reason.Position = UDim2.new(0, 16, 0, 96)
    reason.BackgroundTransparency = 1
    reason.Text = killReason or "your nine lives didn't help"
    reason.Font = UIUtil.Token.fontBody
    reason.TextColor3 = UIUtil.Palette.textMuted
    reason.TextScaled = true
    UIUtil.TextSize.body(reason)

    -- Countdown
    local countdown = Instance.new("TextLabel", card)
    countdown.AnchorPoint = Vector2.new(0.5, 0)
    countdown.Size = UDim2.new(1, -32, 0, 40)
    countdown.Position = UDim2.new(0.5, 0, 0, 138)
    countdown.BackgroundTransparency = 1
    countdown.Text = "Respawning in " .. RESPAWN_DELAY .. "s"
    countdown.Font = UIUtil.Token.fontHeader
    countdown.TextColor3 = UIUtil.Palette.primary
    countdown.TextScaled = true
    UIUtil.TextSize.label(countdown)

    -- Respawn button
    local btn = Instance.new("TextButton", card)
    btn.AnchorPoint = Vector2.new(0.5, 1)
    btn.Size = UDim2.new(1, -32, 0, 56)
    btn.Position = UDim2.new(0.5, 0, 1, -16)
    btn.BackgroundColor3 = UIUtil.Palette.danger
    btn.AutoButtonColor = true
    btn.Text = "RESPAWN NOW"
    btn.Font = UIUtil.Token.fontHeader
    btn.TextColor3 = UIUtil.Palette.textHi
    btn.TextStrokeTransparency = 0.3
    btn.TextStrokeColor3 = UIUtil.Palette.stroke
    btn.TextScaled = true
    Instance.new("UICorner", btn).CornerRadius = UIUtil.Token.cornerMd
    local bs = Instance.new("UIStroke", btn)
    bs.Thickness = UIUtil.Token.strokeBold; bs.Color = UIUtil.Palette.stroke
    UIUtil.boundText(btn, 18, 28)

    -- Slide in
    card.Position = UDim2.new(0.5, 0, 0.5, -40)
    card.BackgroundTransparency = 1
    TweenService:Create(card, UIUtil.Token.easeBack,
        {Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundTransparency = 0}):Play()

    -- Re-clamp on viewport resize
    local cam = workspace.CurrentCamera
    if cam then
        cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            card.Size = UIUtil.modalSize(420, 300, 24)
        end)
    end

    return sg, btn, countdown
end

local function tryRespawn()
    pcall(function() player:LoadCharacter() end)
end

local function onCharacterAdded(char)
    -- Hide overlay if it exists
    local sg = playerGui:FindFirstChild("DeathScreen")
    if sg then
        TweenService:Create(sg.Frame or sg, UIUtil.Token.easeFade, {}):Play()
        sg:Destroy()
    end
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    hum.Died:Connect(function()
        local cause = "your nine lives didn't help"
        -- Try to figure out cause
        if hum:GetState() == Enum.HumanoidStateType.PlatformStanding then
            cause = "ragdolled to death"
        elseif char:FindFirstChild("HumanoidRootPart")
            and char.HumanoidRootPart.Position.Y < -50 then
            cause = "fell out of the world"
        end

        local sg, btn, countdown = buildOverlay(cause)
        local timeLeft = RESPAWN_DELAY
        local respawned = false
        btn.MouseButton1Click:Connect(function()
            if respawned then return end
            respawned = true
            tryRespawn()
        end)
        task.spawn(function()
            while timeLeft > 0 and not respawned and sg.Parent do
                countdown.Text = "Respawning in " .. timeLeft .. "s"
                task.wait(1)
                timeLeft = timeLeft - 1
            end
            if not respawned and sg.Parent then
                tryRespawn()
            end
        end)
    end)
end

if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)

print("[DeathScreen v1] death overlay + respawn ready")
