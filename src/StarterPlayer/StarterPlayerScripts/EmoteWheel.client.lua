-- EmoteWheel.client.lua
-- B key opens emote wheel. Click an emote to play.
-- Place in: StarterPlayer > StarterPlayerScripts > EmoteWheel (LocalScript)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
if not hud then return end

local wheel = Instance.new("Frame")
wheel.Name = "EmoteWheel"
wheel.Size = UDim2.new(0, 360, 0, 360)
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.Position = UDim2.new(0.5, 0, 0.5, 0)
wheel.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
wheel.BackgroundTransparency = 0.2
wheel.BorderSizePixel = 0
wheel.Visible = false
wheel.Parent = hud
Instance.new("UICorner", wheel).CornerRadius = UDim.new(1, 0)
local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.Color = Color3.fromRGB(150, 50, 200)
stroke.Parent = wheel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.Position = UDim2.new(0, 0, 0, 10)
title.BackgroundTransparency = 1
title.Text = "EMOTES"
title.TextColor3 = Color3.fromRGB(150, 50, 200)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.Parent = wheel

local center = Vector2.new(180, 180)
for i, emoteName in ipairs(GameConfig.EMOTES) do
    local angle = (i - 1) * (2 * math.pi / #GameConfig.EMOTES) - math.pi / 2
    local r = 130
    local x = center.X + math.cos(angle) * r - 35
    local y = center.Y + math.sin(angle) * r - 25
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 70, 0, 50)
    btn.Position = UDim2.new(0, x, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(60, 30, 90)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBlack
    btn.Text = emoteName
    btn.TextScaled = true
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.Parent = wheel
    btn.MouseButton1Click:Connect(function()
        Remotes.RequestEmote:FireServer(emoteName)
        wheel.Visible = false
    end)
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.B then
        wheel.Visible = not wheel.Visible
    elseif input.KeyCode == Enum.KeyCode.Escape and wheel.Visible then
        wheel.Visible = false
    end
end)

-- Listen to other players' emotes -> show floating tag above their head
Remotes.EmoteBroadcast.OnClientEvent:Connect(function(userId, emoteName)
    local target = Players:GetPlayerByUserId(userId)
    if not target or not target.Character then return end
    local head = target.Character:FindFirstChild("Head")
    if not head then return end
    local b = Instance.new("BillboardGui")
    b.Size = UDim2.new(0, 100, 0, 36)
    b.StudsOffset = Vector3.new(0, 3, 0)
    b.AlwaysOnTop = true
    b.Parent = head
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
    lbl.BackgroundTransparency = 0.3
    lbl.Text = "*" .. emoteName .. "*"
    lbl.TextColor3 = Color3.fromRGB(255, 200, 0)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 8)
    lbl.Parent = b
    task.delay(2, function() b:Destroy() end)
end)

return true
