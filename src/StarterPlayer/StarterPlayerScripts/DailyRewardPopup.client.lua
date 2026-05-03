-- DailyRewardPopup.client.lua
-- Shows the daily streak + claim button when the server announces availability
-- via DailyAvailable. (Old version polled leaderstats on a 5s timer; that was
-- racy and also only fired once even when not actually available.)
-- Place in: StarterPlayer > StarterPlayerScripts > DailyRewardPopup (LocalScript)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DAY_REWARDS = {
  {day=1, label="500 Chaos"},
  {day=2, label="1.5K Chaos"},
  {day=3, label="3K Chaos + 1 Hell Token"},
  {day=4, label="5K Chaos"},
  {day=5, label="7.5K Chaos + 2 Hell Tokens"},
  {day=6, label="10K Chaos"},
  {day=7, label="25K Chaos + 5 Hell Tokens"},
}

local pulseLoops = {}  -- track pulse loops so we can stop them on close
local function stopPulses()
    for _, t in ipairs(pulseLoops) do
        pcall(function() t:Cancel() end)
    end
    pulseLoops = {}
end

local function showPopup(streakDay, serverReward)
    local existing = playerGui:FindFirstChild("DailyRewardPopup")
    if existing then existing:Destroy() end

    local popup = Instance.new("ScreenGui")
    popup.Name = "DailyRewardPopup"
    popup.IgnoreGuiInset = true
    popup.ResetOnSpawn = false
    popup.DisplayOrder = 80
    popup.Parent = playerGui

    local dim = Instance.new("Frame", popup)
    dim.Size = UDim2.fromScale(1, 1)
    dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    dim.BackgroundTransparency = 0.5

    local card = Instance.new("Frame", popup)
    card.Size = UDim2.new(0, 480, 0, 380)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.BackgroundColor3 = Color3.fromRGB(40, 20, 70)
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 16)
    local cs = Instance.new("UIStroke", card); cs.Thickness = 3; cs.Color = Color3.fromRGB(255, 215, 0)

    local title = Instance.new("TextLabel", card)
    title.Size = UDim2.new(1, -40, 0, 40)
    title.Position = UDim2.new(0, 20, 0, 14)
    title.BackgroundTransparency = 1
    title.Text = "DAILY REWARD"
    title.Font = Enum.Font.GothamBlack
    title.TextScaled = true
    title.TextColor3 = Color3.fromRGB(255, 215, 0)

    local streakLabel = Instance.new("TextLabel", card)
    streakLabel.Size = UDim2.new(1, -40, 0, 30)
    streakLabel.Position = UDim2.new(0, 20, 0, 60)
    streakLabel.BackgroundTransparency = 1
    streakLabel.Text = "STREAK DAY " .. streakDay
    streakLabel.Font = Enum.Font.GothamBold
    streakLabel.TextScaled = true
    streakLabel.TextColor3 = Color3.fromRGB(255, 100, 100)

    local strip = Instance.new("Frame", card)
    strip.Size = UDim2.new(1, -40, 0, 90)
    strip.Position = UDim2.new(0, 20, 0, 100)
    strip.BackgroundTransparency = 1
    local layout = Instance.new("UIListLayout", strip)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Padding = UDim.new(0, 4)

    for i = 1, 7 do
        local box = Instance.new("Frame", strip)
        box.Size = UDim2.new(0, 56, 0, 80)
        box.BackgroundColor3 = (i <= streakDay) and Color3.fromRGB(50, 200, 100) or Color3.fromRGB(60, 30, 90)
        box.BorderSizePixel = 0
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
        if i == streakDay then
            local s = Instance.new("UIStroke", box); s.Thickness = 3; s.Color = Color3.fromRGB(255, 215, 0)
            local pulse = TweenService:Create(box,
                TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                {Size = UDim2.new(0, 60, 0, 84)})
            pulse:Play()
            table.insert(pulseLoops, pulse)
        end
        local dl = Instance.new("TextLabel", box)
        dl.Size = UDim2.fromScale(1, 0.4); dl.BackgroundTransparency = 1
        dl.Text = "D" .. i; dl.Font = Enum.Font.GothamBold; dl.TextScaled = true
        dl.TextColor3 = Color3.fromRGB(255, 255, 255)
        local rl = Instance.new("TextLabel", box)
        rl.Size = UDim2.fromScale(1, 0.6); rl.Position = UDim2.fromScale(0, 0.4); rl.BackgroundTransparency = 1
        local r = DAY_REWARDS[i]
        rl.Text = r and r.label:sub(1, 12) or ""
        rl.Font = Enum.Font.Gotham; rl.TextScaled = true
        rl.TextColor3 = Color3.fromRGB(255, 230, 200)
    end

    local rewardText = Instance.new("TextLabel", card)
    rewardText.Size = UDim2.new(1, -40, 0, 60)
    rewardText.Position = UDim2.new(0, 20, 0, 200)
    rewardText.BackgroundTransparency = 1
    rewardText.Text = "TODAY: " .. ((serverReward and serverReward.msg) or DAY_REWARDS[streakDay].label)
    rewardText.Font = Enum.Font.GothamBlack
    rewardText.TextScaled = true
    rewardText.TextColor3 = Color3.fromRGB(255, 230, 100)

    local claimBtn = Instance.new("TextButton", card)
    claimBtn.Size = UDim2.new(0, 280, 0, 60)
    claimBtn.Position = UDim2.new(0.5, -140, 0, 280)
    claimBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
    claimBtn.Text = "CLAIM"
    claimBtn.Font = Enum.Font.GothamBlack; claimBtn.TextScaled = true
    claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    Instance.new("UICorner", claimBtn).CornerRadius = UDim.new(0, 12)

    local function close()
        stopPulses()
        TweenService:Create(card, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        TweenService:Create(dim, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        task.wait(0.5)
        if popup then popup:Destroy() end
    end

    claimBtn.MouseButton1Click:Connect(function()
        claimBtn.Active = false
        if Remotes.RequestClaimDaily then
            task.spawn(function()
                pcall(function() Remotes.RequestClaimDaily:InvokeServer() end)
            end)
        end
        close()
    end)

    local x = Instance.new("TextButton", card)
    x.Size = UDim2.new(0, 36, 0, 36)
    x.Position = UDim2.new(1, -42, 0, 6)
    x.BackgroundTransparency = 1
    x.Text = "X"
    x.Font = Enum.Font.GothamBold; x.TextScaled = true
    x.TextColor3 = Color3.fromRGB(255, 200, 200)
    x.MouseButton1Click:Connect(close)
end

if Remotes.DailyAvailable then
    Remotes.DailyAvailable.OnClientEvent:Connect(function(streakDay, reward)
        showPopup(streakDay, reward)
    end)
end
