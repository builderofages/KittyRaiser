-- FirstSpawnTutorial.client.lua  v1 — 3-step welcome popup that surfaces
-- the core loop on first spawn. Skips if data.seenTutorial already set.
-- Marks complete via Remotes.RequestMarkTutorialDone so it never repeats.

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Skip if persisted seenTutorial flag is set (DataHandler mirrors it to
-- the OnboardingDone player attribute on join).
if player:GetAttribute("OnboardingDone") then return end

-- Wait for HUD + cat to settle
task.wait(3)

local STEPS = {
    {title="WELCOME, CAT!", body="You're in the city. Your job: cause chaos.\nClick or tap any civilian to prank them.", color=Color3.fromRGB(220, 150, 60)},
    {title="STEP 1 - PRANK", body="Your cat lands a CatScratch by default.\nEvery prank earns CHAOS + XP. Level up to unlock 7 more skills.", color=Color3.fromRGB(110, 165, 95)},
    {title="STEP 2 - WATCH OUT", body="After 5 quick pranks, COPS spawn and chase you.\nLose them or pay the ticket. Have fun.", color=Color3.fromRGB(85, 130, 175)},
}

local sg = Instance.new("ScreenGui", playerGui)
sg.Name = "FirstSpawnTutorial"
sg.IgnoreGuiInset = true
sg.ResetOnSpawn = false
sg.DisplayOrder = 200

local backdrop = Instance.new("Frame", sg)
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.55

local card = Instance.new("Frame", sg)
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromOffset(440, 220)
card.BackgroundColor3 = Color3.fromRGB(245, 230, 200)
Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
local cs = Instance.new("UIStroke", card)
cs.Thickness = 4; cs.Color = Color3.fromRGB(110, 75, 45)

local title = Instance.new("TextLabel", card)
title.Size = UDim2.new(1, -32, 0, 50)
title.Position = UDim2.new(0, 16, 0, 12)
title.BackgroundTransparency = 1
title.Text = ""
title.Font = Enum.Font.LuckiestGuy
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(80, 40, 20)
title.TextXAlignment = Enum.TextXAlignment.Left
local tc = Instance.new("UITextSizeConstraint", title); tc.MinTextSize = 22; tc.MaxTextSize = 36

local body = Instance.new("TextLabel", card)
body.Size = UDim2.new(1, -32, 0, 90)
body.Position = UDim2.new(0, 16, 0, 64)
body.BackgroundTransparency = 1
body.Text = ""
body.Font = Enum.Font.GothamMedium
body.TextScaled = true
body.TextColor3 = Color3.fromRGB(80, 40, 20)
body.TextXAlignment = Enum.TextXAlignment.Left
body.TextYAlignment = Enum.TextYAlignment.Top
body.TextWrapped = true
local bc = Instance.new("UITextSizeConstraint", body); bc.MinTextSize = 12; bc.MaxTextSize = 18

local nextBtn = Instance.new("TextButton", card)
nextBtn.AnchorPoint = Vector2.new(1, 1)
nextBtn.Position = UDim2.new(1, -16, 1, -12)
nextBtn.Size = UDim2.fromOffset(140, 44)
nextBtn.BackgroundColor3 = Color3.fromRGB(220, 150, 60)
nextBtn.Text = "NEXT"
nextBtn.Font = Enum.Font.LuckiestGuy
nextBtn.TextScaled = true
nextBtn.TextColor3 = Color3.fromRGB(255, 250, 235)
Instance.new("UICorner", nextBtn).CornerRadius = UDim.new(0, 10)
local ns = Instance.new("UIStroke", nextBtn); ns.Thickness = 3; ns.Color = Color3.fromRGB(110, 75, 40)
local nbc = Instance.new("UITextSizeConstraint", nextBtn); nbc.MinTextSize = 14; nbc.MaxTextSize = 22

local skipBtn = Instance.new("TextButton", card)
skipBtn.AnchorPoint = Vector2.new(0, 1)
skipBtn.Position = UDim2.new(0, 16, 1, -12)
skipBtn.Size = UDim2.fromOffset(80, 32)
skipBtn.BackgroundColor3 = Color3.fromRGB(140, 120, 100)
skipBtn.Text = "SKIP"
skipBtn.Font = Enum.Font.GothamBold
skipBtn.TextScaled = true
skipBtn.TextColor3 = Color3.fromRGB(255, 248, 230)
Instance.new("UICorner", skipBtn).CornerRadius = UDim.new(0, 8)
local sks = Instance.new("UITextSizeConstraint", skipBtn); sks.MinTextSize = 10; sks.MaxTextSize = 14

local idx = 1
local function render()
    local step = STEPS[idx]
    title.Text = step.title
    body.Text = step.body
    nextBtn.BackgroundColor3 = step.color
    nextBtn.Text = (idx == #STEPS) and "PLAY" or "NEXT"
    -- Pop animation
    card.Size = UDim2.fromOffset(380, 200)
    TweenService:Create(card, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.fromOffset(440, 220)}):Play()
end

local function dismiss()
    sg:Destroy()
    if Remotes.RequestMarkTutorialDone then
        pcall(function() Remotes.RequestMarkTutorialDone:FireServer() end)
    end
    player:SetAttribute("OnboardingDone", true)
end

nextBtn.MouseButton1Click:Connect(function()
    if idx < #STEPS then
        idx = idx + 1
        render()
    else
        dismiss()
    end
end)
skipBtn.MouseButton1Click:Connect(dismiss)

render()
print("[FirstSpawnTutorial v1] online")
