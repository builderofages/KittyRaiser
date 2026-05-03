-- DailyRewardPopup.client.lua
-- Grok #3 retention killer fix: show daily streak + today's reward immediately on spawn
-- Place in: StarterPlayer > StarterPlayerScripts > DailyRewardPopup (LocalScript)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local UIUtil  = require(ReplicatedStorage.Modules:WaitForChild("UIUtil"))

local function bound(lbl, mn, mx)
  UIUtil.boundText(lbl, mn, mx); return lbl
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for spawn
task.wait(5)

local DAY_REWARDS = {
  {day=1, chaos=500,  hellTokens=0, label="500 Chaos"},
  {day=2, chaos=1000, hellTokens=0, label="1,000 Chaos"},
  {day=3, chaos=2500, hellTokens=5, label="2,500 Chaos + 5 Hell Tokens"},
  {day=4, chaos=5000, hellTokens=10, label="5,000 Chaos + 10 Hell Tokens"},
  {day=5, chaos=10000, hellTokens=25, label="10K Chaos + 25 HT"},
  {day=6, chaos=25000, hellTokens=50, label="25K Chaos + 50 HT"},
  {day=7, chaos=100000, hellTokens=200, label="🎁 100K Chaos + 200 HT + EPIC SKIN"},
}

local streak = (player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("DailyStreak") and player.leaderstats.DailyStreak.Value) or 1
local dayIndex = ((streak - 1) % 7) + 1
local reward = DAY_REWARDS[dayIndex]

local popup = Instance.new("ScreenGui")
popup.Name = "DailyRewardPopup"
popup.IgnoreGuiInset = true
popup.ResetOnSpawn = false
popup.DisplayOrder = UIUtil.DisplayOrder.DailyReward
popup.Parent = playerGui

local dim = Instance.new("Frame")
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dim.BackgroundTransparency = 0.5
dim.Parent = popup

local card = Instance.new("Frame")
card.Size = UDim2.new(0, 480, 0, 380)
card.Position = UDim2.new(0.5, -240, 0.5, -190)
card.BackgroundColor3 = Color3.fromRGB(40, 20, 70)
card.BorderSizePixel = 0
card.Parent = popup
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 16)
local cardStroke = Instance.new("UIStroke", card)
cardStroke.Thickness = 3
cardStroke.Color = Color3.fromRGB(255, 215, 0)
local cardGrad = Instance.new("UIGradient", card)
cardGrad.Color = ColorSequence.new{
  ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 30, 130)),
  ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 10, 50)),
}
cardGrad.Rotation = 90

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 40)
title.Position = UDim2.new(0, 20, 0, 14)
title.BackgroundTransparency = 1
title.Text = "🎁 DAILY REWARD"
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.Parent = card
bound(title, 20, 36)

-- Streak display
local streakLabel = Instance.new("TextLabel")
streakLabel.Size = UDim2.new(1, -40, 0, 30)
streakLabel.Position = UDim2.new(0, 20, 0, 60)
streakLabel.BackgroundTransparency = 1
streakLabel.Text = "STREAK: " .. streak .. " day" .. (streak == 1 and "" or "s") .. " 🔥"
streakLabel.Font = Enum.Font.GothamBold
streakLabel.TextScaled = true
streakLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
streakLabel.Parent = card
bound(streakLabel, 14, 22)

-- 7-day strip
local strip = Instance.new("Frame")
strip.Size = UDim2.new(1, -40, 0, 90)
strip.Position = UDim2.new(0, 20, 0, 100)
strip.BackgroundTransparency = 1
strip.Parent = card
local stripLayout = Instance.new("UIListLayout", strip)
stripLayout.FillDirection = Enum.FillDirection.Horizontal
stripLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
stripLayout.Padding = UDim.new(0, 4)

for i = 1, 7 do
  local box = Instance.new("Frame")
  box.Size = UDim2.new(0, 56, 0, 80)
  box.BackgroundColor3 = (i <= dayIndex) and Color3.fromRGB(50, 200, 100) or Color3.fromRGB(60, 30, 90)
  box.BorderSizePixel = 0
  box.Parent = strip
  Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
  if i == dayIndex then
    local s = Instance.new("UIStroke", box)
    s.Thickness = 3
    s.Color = Color3.fromRGB(255, 215, 0)
    -- Pulse
    task.spawn(function()
      while box.Parent do
        TweenService:Create(box, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Size = UDim2.new(0, 60, 0, 84)}):Play()
        task.wait(1.2)
      end
    end)
  end
  local dl = Instance.new("TextLabel", box)
  dl.Size = UDim2.fromScale(1, 0.4)
  dl.Position = UDim2.fromScale(0, 0)
  dl.BackgroundTransparency = 1
  dl.Text = "D" .. i
  dl.Font = Enum.Font.GothamBold
  dl.TextScaled = true
  dl.TextColor3 = Color3.fromRGB(255, 255, 255)
  bound(dl, 12, 18)
  local rl = Instance.new("TextLabel", box)
  rl.Size = UDim2.fromScale(1, 0.6)
  rl.Position = UDim2.fromScale(0, 0.4)
  rl.BackgroundTransparency = 1
  rl.Text = (DAY_REWARDS[i].chaos >= 1000) and (math.floor(DAY_REWARDS[i].chaos/1000) .. "K") or tostring(DAY_REWARDS[i].chaos)
  rl.Font = Enum.Font.Gotham
  rl.TextScaled = true
  rl.TextColor3 = Color3.fromRGB(255, 230, 200)
  bound(rl, 11, 16)
end

-- Today's reward big text
local rewardText = Instance.new("TextLabel")
rewardText.Size = UDim2.new(1, -40, 0, 60)
rewardText.Position = UDim2.new(0, 20, 0, 200)
rewardText.BackgroundTransparency = 1
rewardText.Text = "TODAY: " .. reward.label
rewardText.Font = Enum.Font.GothamBlack
rewardText.TextScaled = true
rewardText.TextColor3 = Color3.fromRGB(255, 230, 100)
rewardText.Parent = card
bound(rewardText, 14, 28)

-- CLAIM button
local claimBtn = Instance.new("TextButton")
claimBtn.Size = UDim2.new(0, 280, 0, 60)
claimBtn.Position = UDim2.new(0.5, -140, 0, 280)
claimBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
claimBtn.Text = "✨ CLAIM ✨"
claimBtn.Font = Enum.Font.GothamBlack
claimBtn.TextScaled = true
claimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
claimBtn.Parent = card
bound(claimBtn, 18, 28)
Instance.new("UICorner", claimBtn).CornerRadius = UDim.new(0, 12)
local cs = Instance.new("UIStroke", claimBtn); cs.Thickness = 3; cs.Color = Color3.fromRGB(0, 80, 40)

claimBtn.MouseButton1Click:Connect(function()
  claimBtn.Active = false
  if Remotes.RequestClaimDaily then
    pcall(function() Remotes.RequestClaimDaily:InvokeServer() end)
  end
  TweenService:Create(card, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
  TweenService:Create(dim, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
  task.wait(0.5)
  popup:Destroy()
end)

-- X dismiss
local x = Instance.new("TextButton")
x.Size = UDim2.new(0, 36, 0, 36)
x.Position = UDim2.new(1, -42, 0, 6)
x.BackgroundTransparency = 1
x.Text = "✕"
x.Font = Enum.Font.GothamBold
x.TextScaled = true
x.TextColor3 = Color3.fromRGB(255, 200, 200)
x.Parent = card
x.MouseButton1Click:Connect(function() popup:Destroy() end)

print("[DailyRewardPopup] showed daily reward streak " .. streak .. ", day " .. dayIndex)
