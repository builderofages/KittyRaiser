-- SocialLink.client.lua
-- Discord/community link. Roblox blocks arbitrary URL navigation; the
-- canonical pattern is to display a copy-friendly text and use SocialService
-- to prompt-share the GAME itself with friends. Both are exposed.

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 60)
if not hud then return end

local DISCORD_HANDLE = "discord.gg/kittyraiser"  -- TODO: update with your real invite

-- Modal
local modal = Instance.new("Frame")
modal.Name = "SocialModal"
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.new(0.5, 0, 0.5, 0)
modal.Size = UDim2.new(0, 380, 0, 280)
modal.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
modal.Visible = false
modal.ZIndex = 50
modal.Parent = hud
Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 16)
local stroke = Instance.new("UIStroke", modal); stroke.Thickness = 3; stroke.Color = Color3.fromRGB(88, 101, 242)

local title = Instance.new("TextLabel", modal)
title.Size = UDim2.new(1, -20, 0, 40)
title.Position = UDim2.new(0, 10, 0, 10)
title.BackgroundTransparency = 1
title.Text = "JOIN THE COMMUNITY"
title.TextColor3 = Color3.fromRGB(88, 101, 242)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true

local close = Instance.new("TextButton", modal)
close.Size = UDim2.new(0, 36, 0, 36)
close.Position = UDim2.new(1, -42, 0, 6)
close.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
close.Text = "X"; close.Font = Enum.Font.GothamBlack; close.TextScaled = true
close.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
close.MouseButton1Click:Connect(function() modal.Visible = false end)

local discord = Instance.new("TextBox", modal)
discord.Size = UDim2.new(1, -40, 0, 50)
discord.Position = UDim2.new(0, 20, 0, 80)
discord.BackgroundColor3 = Color3.fromRGB(40, 25, 60)
discord.TextColor3 = Color3.fromRGB(255, 255, 255)
discord.Font = Enum.Font.GothamBold
discord.TextScaled = true
discord.Text = DISCORD_HANDLE
discord.TextEditable = false
discord.ClearTextOnFocus = false
Instance.new("UICorner", discord).CornerRadius = UDim.new(0, 8)

local note = Instance.new("TextLabel", modal)
note.Size = UDim2.new(1, -40, 0, 30)
note.Position = UDim2.new(0, 20, 0, 140)
note.BackgroundTransparency = 1
note.Text = "Tap the box, copy and paste in your browser"
note.Font = Enum.Font.Gotham
note.TextScaled = true
note.TextColor3 = Color3.fromRGB(180, 180, 180)

-- Invite button (uses SocialService to prompt the player to invite friends to
-- THIS game; this is allowed by Roblox without external URL navigation).
local invite = Instance.new("TextButton", modal)
invite.Size = UDim2.new(1, -40, 0, 50)
invite.Position = UDim2.new(0, 20, 0, 190)
invite.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
invite.TextColor3 = Color3.fromRGB(255, 255, 255)
invite.Font = Enum.Font.GothamBlack
invite.TextScaled = true
invite.Text = "INVITE FRIENDS"
Instance.new("UICorner", invite).CornerRadius = UDim.new(0, 8)
invite.MouseButton1Click:Connect(function()
    local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
    if ok and can then
        pcall(SocialService.PromptGameInvite, SocialService, player)
    end
end)

-- Bottom-bar button to open
local botBar = hud:FindFirstChild("BottomBar")
local function ensureBtn()
    if not botBar then return end
    if botBar:FindFirstChild("SocialButton") then return end
    local btn = Instance.new("TextButton")
    btn.Name = "SocialButton"
    btn.Size = UDim2.new(0, 70, 0, 44)
    btn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBlack
    btn.Text = "JOIN"
    btn.TextScaled = true
    btn.LayoutOrder = 7
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
    btn.Parent = botBar
    btn.MouseButton1Click:Connect(function() modal.Visible = not modal.Visible end)
end
ensureBtn()
hud.ChildAdded:Connect(function() task.wait(0.5); ensureBtn() end)
