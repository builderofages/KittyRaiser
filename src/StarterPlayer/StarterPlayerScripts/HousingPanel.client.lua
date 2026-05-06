-- HousingPanel.client.lua  v1 — UI for HousingSystem.
-- Trigger: HOME button anchored top-right (under CLAN pill).
-- Modal shows furniture catalog + "ENTER YOUR APARTMENT" button.
-- Click a furniture chip to place it at the player's current position
-- (server clamps to room interior).

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIUtil = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIUtil"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RequestEnterHome, RequestPlaceFurniture, RequestExitHome, RequestSetHomePublic, RequestRemoveFurniture
task.spawn(function()
    local f = ReplicatedStorage:WaitForChild("RemoteEventsFolder", 30)
    RequestEnterHome    = f:WaitForChild("RequestEnterHome", 30)
    RequestPlaceFurniture = f:WaitForChild("RequestPlaceFurniture", 30)
    RequestExitHome     = f:WaitForChild("RequestExitHome", 30)
    RequestSetHomePublic = f:WaitForChild("RequestSetHomePublic", 30)
    RequestRemoveFurniture = f:WaitForChild("RequestRemoveFurniture", 30)
end)

local FURNITURE_KINDS = {
    "cat_bed", "scratch_post", "food_bowl", "water_bowl", "cat_tower",
    "hammock", "fish_tank", "treat_jar", "window_perch", "yarn_ball",
}

local triggerSG = Instance.new("ScreenGui", playerGui)
triggerSG.Name = "HomeTrigger"
triggerSG.ResetOnSpawn = false
triggerSG.DisplayOrder = (UIUtil.DisplayOrder.HUD or 10) + 7

local btn = Instance.new("TextButton", triggerSG)
btn.AnchorPoint = Vector2.new(1, 0)
btn.Size = UDim2.fromOffset(80, 32)
btn.Position = UDim2.new(1, -16, 0, 410)
btn.BackgroundColor3 = Color3.fromRGB(180, 130, 90)
btn.Text = "HOME"
btn.Font = Enum.Font.LuckiestGuy
btn.TextScaled = true
btn.TextColor3 = Color3.fromRGB(255, 240, 200)
btn.TextStrokeTransparency = 0.3
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
local bs = Instance.new("UIStroke", btn); bs.Thickness = 2; bs.Color = Color3.fromRGB(80, 50, 30)
local bc = Instance.new("UITextSizeConstraint", btn); bc.MinTextSize = 12; bc.MaxTextSize = 18

local modalSG = Instance.new("ScreenGui", playerGui)
modalSG.IgnoreGuiInset = true
modalSG.ResetOnSpawn = false
modalSG.DisplayOrder = (UIUtil.DisplayOrder.Modal or 60) + 5
modalSG.Enabled = false
local backdrop = Instance.new("Frame", modalSG)
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0); backdrop.BackgroundTransparency = 0.5

local modal = Instance.new("Frame", modalSG)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.Size = UDim2.fromOffset(560, 480)
modal.BackgroundColor3 = Color3.fromRGB(245, 230, 200)
Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 14)
local ms = Instance.new("UIStroke", modal); ms.Thickness = 4; ms.Color = Color3.fromRGB(110, 75, 45)

local title = Instance.new("TextLabel", modal)
title.Size = UDim2.new(1, -56, 0, 44)
title.Position = UDim2.fromOffset(16, 12)
title.BackgroundTransparency = 1
title.Text = "YOUR APARTMENT"
title.Font = Enum.Font.LuckiestGuy
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(80, 40, 20)
title.TextXAlignment = Enum.TextXAlignment.Left
local tc = Instance.new("UITextSizeConstraint", title); tc.MinTextSize = 18; tc.MaxTextSize = 28

local close = Instance.new("TextButton", modal)
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -12, 0, 12)
close.Size = UDim2.fromOffset(36, 36)
close.BackgroundColor3 = Color3.fromRGB(220, 100, 80)
close.Text = "X"
close.Font = Enum.Font.GothamBlack
close.TextColor3 = Color3.fromRGB(255, 248, 230)
close.TextScaled = true
Instance.new("UICorner", close).CornerRadius = UDim.new(1, 0)

local enterBtn = Instance.new("TextButton", modal)
enterBtn.Position = UDim2.fromOffset(16, 64)
enterBtn.Size = UDim2.new(0.5, -24, 0, 50)
enterBtn.BackgroundColor3 = Color3.fromRGB(110, 165, 95)
enterBtn.Text = "ENTER YOUR APARTMENT"
enterBtn.Font = Enum.Font.LuckiestGuy
enterBtn.TextColor3 = Color3.fromRGB(255, 248, 230)
enterBtn.TextScaled = true
Instance.new("UICorner", enterBtn).CornerRadius = UDim.new(0, 8)
local ec = Instance.new("UITextSizeConstraint", enterBtn); ec.MinTextSize = 12; ec.MaxTextSize = 16
enterBtn.MouseButton1Click:Connect(function()
    if RequestEnterHome then
        pcall(function() RequestEnterHome:InvokeServer() end)
        modalSG.Enabled = false
    end
end)

local exitBtn = Instance.new("TextButton", modal)
exitBtn.Position = UDim2.new(0.5, 8, 0, 64)
exitBtn.Size = UDim2.new(0.5, -24, 0, 50)
exitBtn.BackgroundColor3 = Color3.fromRGB(85, 130, 175)
exitBtn.Text = "EXIT TO PLAZA"
exitBtn.Font = Enum.Font.LuckiestGuy
exitBtn.TextColor3 = Color3.fromRGB(255, 248, 230)
exitBtn.TextScaled = true
Instance.new("UICorner", exitBtn).CornerRadius = UDim.new(0, 8)
local exc = Instance.new("UITextSizeConstraint", exitBtn); exc.MinTextSize = 12; exc.MaxTextSize = 16
exitBtn.MouseButton1Click:Connect(function()
    if RequestExitHome then
        pcall(function() RequestExitHome:InvokeServer() end)
        modalSG.Enabled = false
    end
end)

local catalog = Instance.new("ScrollingFrame", modal)
catalog.Size = UDim2.new(1, -32, 1, -140)
catalog.Position = UDim2.fromOffset(16, 130)
catalog.BackgroundTransparency = 1
catalog.BorderSizePixel = 0
catalog.CanvasSize = UDim2.new(0, 0, 0, 0)
catalog.AutomaticCanvasSize = Enum.AutomaticSize.Y
catalog.ScrollBarThickness = 6

local layout = Instance.new("UIGridLayout", catalog)
layout.CellSize = UDim2.fromOffset(160, 50)
layout.CellPadding = UDim2.fromOffset(8, 8)

for _, kind in ipairs(FURNITURE_KINDS) do
    local item = Instance.new("TextButton", catalog)
    item.BackgroundColor3 = Color3.fromRGB(255, 245, 215)
    item.Text = kind:upper():gsub("_", " ")
    item.Font = Enum.Font.GothamBold
    item.TextColor3 = Color3.fromRGB(80, 40, 20)
    item.TextScaled = true
    Instance.new("UICorner", item).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", item); stroke.Thickness = 1; stroke.Color = Color3.fromRGB(140, 120, 100)
    local ic = Instance.new("UITextSizeConstraint", item); ic.MinTextSize = 10; ic.MaxTextSize = 14
    item.MouseButton1Click:Connect(function()
        if not RequestPlaceFurniture then return end
        -- Place near player's current position (server clamps to room)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local lx, ly, lz = 0, 0, 0
        if hrp then
            -- Use position relative to apartment center (we don't know it client-side
            -- so just send 0,0,0 and let the player drag later — for now this
            -- places everything at room origin. v3.97a UX improvement could add
            -- a 'place ghost' system).
            lx, ly, lz = 0, 0, 0
        end
        pcall(function() RequestPlaceFurniture:InvokeServer(kind, lx, ly, lz, 0) end)
    end)
end

btn.MouseButton1Click:Connect(function() modalSG.Enabled = true end)
close.MouseButton1Click:Connect(function() modalSG.Enabled = false end)
backdrop.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        modalSG.Enabled = false
    end
end)

print("[HousingPanel v1] online")
