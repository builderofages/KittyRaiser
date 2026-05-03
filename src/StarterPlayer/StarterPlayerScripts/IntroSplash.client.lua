-- IntroSplash.client.lua
-- 10-second cinematic intro on first ever play. Uses seenIntro flag from
-- DataHandler. Skippable via Tap-to-skip or any input.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local shown = false
local function showIntro()
    if shown then return end
    shown = true

    local gui = Instance.new("ScreenGui")
    gui.Name = "IntroSplash"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 100
    gui.Parent = playerGui

    local bg = Instance.new("Frame", gui)
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.new(0, 0, 0)

    local lines = {
        {text="The city sleeps...",        color=Color3.fromRGB(180, 150, 220), font=Enum.Font.GothamBlack, hold=2.0},
        {text="But the cats don't.",       color=Color3.fromRGB(255, 80, 200),  font=Enum.Font.GothamBlack, hold=2.0},
        {text="Welcome to KITTYRAISER",    color=Color3.fromRGB(255, 215, 0),   font=Enum.Font.GothamBlack, hold=2.5},
        {text="Cause CHAOS. Be the cat.",  color=Color3.fromRGB(80, 220, 255),  font=Enum.Font.GothamBold,  hold=2.0},
    }

    local skipLbl = Instance.new("TextLabel", gui)
    skipLbl.Size = UDim2.new(1, 0, 0, 30)
    skipLbl.Position = UDim2.new(0, 0, 1, -50)
    skipLbl.BackgroundTransparency = 1
    skipLbl.Text = "Tap to skip"
    skipLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
    skipLbl.Font = Enum.Font.Gotham
    skipLbl.TextScaled = true

    local skipped = false
    local function dismiss()
        if skipped then return end
        skipped = true
        TweenService:Create(bg, TweenInfo.new(0.6), {BackgroundTransparency = 1}):Play()
        task.wait(0.7); gui:Destroy()
    end

    local skipButton = Instance.new("TextButton", gui)
    skipButton.Size = UDim2.fromScale(1, 1)
    skipButton.BackgroundTransparency = 1
    skipButton.Text = ""
    skipButton.MouseButton1Click:Connect(dismiss)

    -- Walk through lines
    task.spawn(function()
        for _, line in ipairs(lines) do
            if skipped then return end
            local lbl = Instance.new("TextLabel", gui)
            lbl.AnchorPoint = Vector2.new(0.5, 0.5)
            lbl.Position = UDim2.new(0.5, 0, 0.5, 0)
            lbl.Size = UDim2.new(0, 700, 0, 90)
            lbl.BackgroundTransparency = 1
            lbl.Text = line.text
            lbl.TextColor3 = line.color
            lbl.Font = line.font
            lbl.TextScaled = true
            lbl.TextStrokeTransparency = 0
            lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
            lbl.TextTransparency = 1
            lbl.TextStrokeTransparency = 1
            TweenService:Create(lbl, TweenInfo.new(0.5), {TextTransparency = 0, TextStrokeTransparency = 0.2}):Play()
            task.wait(line.hold)
            if skipped then return end
            TweenService:Create(lbl, TweenInfo.new(0.4), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
            task.wait(0.4)
            lbl:Destroy()
        end
        dismiss()
    end)
end

-- Wait for first data packet, then check seenIntro flag.
local subscribed = false
Remotes.UpdatePlayerData.OnClientEvent:Connect(function(d)
    if subscribed then return end
    subscribed = true
    if not d.seenIntro then
        showIntro()
        Remotes.RequestSettingChange:InvokeServer("seenIntro", true)
    end
end)
