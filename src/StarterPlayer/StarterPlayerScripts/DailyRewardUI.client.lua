-- DailyRewardUI.client.lua
-- Shows daily reward popup when DailyAvailable fires.
-- Place in: StarterPlayer > StarterPlayerScripts > DailyRewardUI (LocalScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
if not hud then return end

local modal = Instance.new("Frame")
modal.Name = "DailyRewardModal"
modal.Size = UDim2.new(0, 380, 0, 280)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.new(0.5, 0, 0.5, 0)
modal.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
modal.BorderSizePixel = 0
modal.Visible = false
modal.ZIndex = 100
Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 16)
local s = Instance.new("UIStroke") s.Thickness = 3 s.Color = Color3.fromRGB(255, 200, 0) s.Parent = modal
modal.Parent = hud

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 50)
title.Position = UDim2.new(0, 10, 0, 10)
title.BackgroundTransparency = 1
title.Text = "DAILY REWARD"
title.TextColor3 = Color3.fromRGB(255, 200, 0)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.Parent = modal

local streakLbl = Instance.new("TextLabel")
streakLbl.Size = UDim2.new(1, -20, 0, 30)
streakLbl.Position = UDim2.new(0, 10, 0, 60)
streakLbl.BackgroundTransparency = 1
streakLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
streakLbl.Font = Enum.Font.Gotham
streakLbl.TextScaled = true
streakLbl.Parent = modal

local rewardLbl = Instance.new("TextLabel")
rewardLbl.Size = UDim2.new(1, -20, 0, 80)
rewardLbl.Position = UDim2.new(0, 10, 0, 95)
rewardLbl.BackgroundTransparency = 1
rewardLbl.TextColor3 = Color3.fromRGB(0, 255, 100)
rewardLbl.Font = Enum.Font.GothamBlack
rewardLbl.TextScaled = true
rewardLbl.Parent = modal

local claimBtn = Instance.new("TextButton")
claimBtn.Size = UDim2.new(0, 240, 0, 60)
claimBtn.AnchorPoint = Vector2.new(0.5, 1)
claimBtn.Position = UDim2.new(0.5, 0, 1, -16)
claimBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
claimBtn.TextColor3 = Color3.new(0,0,0)
claimBtn.Font = Enum.Font.GothamBlack
claimBtn.TextScaled = true
claimBtn.Text = "CLAIM"
Instance.new("UICorner", claimBtn).CornerRadius = UDim.new(0, 12)
claimBtn.Parent = modal

Remotes.DailyAvailable.OnClientEvent:Connect(function(streak, reward)
    streakLbl.Text = "Day " .. streak .. " of 7 streak"
    rewardLbl.Text = reward.msg
    modal.Visible = true
end)

claimBtn.MouseButton1Click:Connect(function()
    local ok = Remotes.RequestClaimDaily:InvokeServer()
    if ok then modal.Visible = false end
end)

return true
