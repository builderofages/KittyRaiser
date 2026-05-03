-- SkinPreviewer.client.lua
-- Listens for a BindableEvent fired by the shop UI ("PreviewSkin") with a
-- skin id; tints the local cat to that skin for 5s so the player sees what
-- they're buying. Original colors restore automatically.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("CosmeticConfig"))

local player = Players.LocalPlayer

-- BindableEvent under PlayerGui so HUDController can fire it.
local pg = player:WaitForChild("PlayerGui")
local previewEv = pg:FindFirstChild("PreviewSkinEvent")
if not previewEv then
    previewEv = Instance.new("BindableEvent")
    previewEv.Name = "PreviewSkinEvent"
    previewEv.Parent = pg
end

local PREVIEW_DURATION = 5

local function tint(skinId)
    local char = player.Character
    if not char then return end
    local skin = CosmeticConfig.getSkin(skinId)
    if not skin or not skin.bodyColors then return end

    local TINT_SKIP = {Pupil=true, Eye=true, Nose=true, Mouth=true,
                       Tongue=true, Whisker=true, Tooth=true}

    local prevColors = {}  -- restore on timeout
    for _, p in ipairs(char:GetDescendants()) do
        if (p:IsA("BasePart") or p:IsA("MeshPart")) and not TINT_SKIP[p.Name]
            and not p:GetAttribute("NoTint")
        then
            prevColors[p] = p.Color
            -- Use TorsoColor as the primary preview tint
            local target = skin.bodyColors.TorsoColor
            if typeof(target) == "Color3" then p.Color = target end
        end
    end

    -- Show small banner
    local banner = Instance.new("ScreenGui", pg)
    banner.Name = "PreviewBanner"
    banner.IgnoreGuiInset = true
    banner.DisplayOrder = 70
    local lbl = Instance.new("TextLabel", banner)
    lbl.AnchorPoint = Vector2.new(0.5, 0)
    lbl.Position = UDim2.new(0.5, 0, 0, 70)
    lbl.Size = UDim2.new(0, 280, 0, 40)
    lbl.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
    lbl.BackgroundTransparency = 0.2
    lbl.TextColor3 = Color3.fromRGB(255, 215, 0)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    lbl.Text = "Previewing: " .. (skin.displayName or skinId)
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 8)

    task.delay(PREVIEW_DURATION, function()
        for p, c in pairs(prevColors) do
            if p.Parent then p.Color = c end
        end
        if banner.Parent then banner:Destroy() end
    end)
end

previewEv.Event:Connect(function(skinId) tint(skinId) end)
