-- PatchNotesUI.client.lua
-- Show "What's New" modal on first join after a deploy. Compares the current
-- GAME_VERSION against the player's saved lastSeenPatchVersion.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Patch notes content. Bump GAME_VERSION + add a new entry on each release.
local PATCH_NOTES = {
    {
        version = "v1.0",
        title = "Launch!",
        items = {
            "8 pranks: Pie, Anvil, Fart, Laser, and more",
            "5 cat skins to start, 25 total to collect",
            "Daily quests + achievements + 7-day login streak",
            "Settings: music, SFX, camera, codes",
            "Cyberpunk Cat Alley with weather + day/night",
        },
    },
}

local CURRENT_VERSION = GameConfig.GAME_VERSION or "v1.0"

local subscribed = false
Remotes.UpdatePlayerData.OnClientEvent:Connect(function(d)
    if subscribed then return end
    subscribed = true
    if d.lastSeenPatchVersion == CURRENT_VERSION then return end
    -- Only show if user has played before; brand-new players get the IntroSplash instead.
    if not d.seenIntro then return end

    local gui = Instance.new("ScreenGui")
    gui.Name = "PatchNotes"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 75
    gui.Parent = playerGui

    local dim = Instance.new("Frame", gui)
    dim.Size = UDim2.fromScale(1, 1)
    dim.BackgroundColor3 = Color3.new(0, 0, 0)
    dim.BackgroundTransparency = 0.4

    local card = Instance.new("Frame", gui)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.Size = UDim2.new(0, 480, 0, 480)
    card.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
    card.BorderSizePixel = 0
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 16)
    local stroke = Instance.new("UIStroke", card); stroke.Thickness = 3; stroke.Color = Color3.fromRGB(80, 220, 255)

    local title = Instance.new("TextLabel", card)
    title.Size = UDim2.new(1, -20, 0, 50)
    title.Position = UDim2.new(0, 10, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "WHAT'S NEW — " .. CURRENT_VERSION
    title.TextColor3 = Color3.fromRGB(80, 220, 255)
    title.Font = Enum.Font.GothamBlack
    title.TextScaled = true

    local list = Instance.new("ScrollingFrame", card)
    list.Size = UDim2.new(1, -40, 1, -130)
    list.Position = UDim2.new(0, 20, 0, 70)
    list.BackgroundTransparency = 1
    list.BorderSizePixel = 0
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.CanvasSize = UDim2.new()
    list.ScrollBarThickness = 6

    local layout = Instance.new("UIListLayout", list); layout.Padding = UDim.new(0, 10)

    for _, patch in ipairs(PATCH_NOTES) do
        local h = Instance.new("TextLabel", list)
        h.Size = UDim2.new(1, 0, 0, 28)
        h.BackgroundTransparency = 1
        h.Text = patch.version .. ": " .. patch.title
        h.TextColor3 = Color3.fromRGB(255, 215, 0)
        h.Font = Enum.Font.GothamBlack
        h.TextScaled = true
        h.TextXAlignment = Enum.TextXAlignment.Left

        for _, item in ipairs(patch.items) do
            local li = Instance.new("TextLabel", list)
            li.Size = UDim2.new(1, 0, 0, 28)
            li.BackgroundTransparency = 1
            li.Text = "• " .. item
            li.TextColor3 = Color3.fromRGB(220, 220, 220)
            li.Font = Enum.Font.Gotham
            li.TextScaled = true
            li.TextXAlignment = Enum.TextXAlignment.Left
        end
    end

    local close = Instance.new("TextButton", card)
    close.AnchorPoint = Vector2.new(0.5, 0)
    close.Position = UDim2.new(0.5, 0, 1, -56)
    close.Size = UDim2.new(0, 200, 0, 44)
    close.BackgroundColor3 = Color3.fromRGB(80, 220, 255)
    close.TextColor3 = Color3.new(0, 0, 0)
    close.Font = Enum.Font.GothamBlack
    close.TextScaled = true
    close.Text = "GOT IT"
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
    close.MouseButton1Click:Connect(function()
        Remotes.RequestSettingChange:InvokeServer("lastSeenPatchVersion", CURRENT_VERSION)
        TweenService:Create(card, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        TweenService:Create(dim, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
        task.wait(0.4); gui:Destroy()
    end)
end)
