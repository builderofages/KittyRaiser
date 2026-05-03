-- TooltipSystem.client.lua
-- Generic tooltip overlay. Any GuiObject with a "Tooltip" attribute set to a
-- string will show a tooltip near it on hover (desktop) or long-press (mobile).
-- To opt into tooltips for an existing button, set:
--   button:SetAttribute("Tooltip", "Summon a human to prank")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 60)
if not hud then return end

local container = Instance.new("ScreenGui")
container.Name = "TooltipOverlay"
container.IgnoreGuiInset = true
container.ResetOnSpawn = false
container.DisplayOrder = 200
container.Parent = player.PlayerGui

local tip = Instance.new("Frame", container)
tip.Visible = false
tip.AnchorPoint = Vector2.new(0.5, 1)
tip.Size = UDim2.new(0, 220, 0, 36)
tip.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
tip.BackgroundTransparency = 0.05
tip.BorderSizePixel = 0
Instance.new("UICorner", tip).CornerRadius = UDim.new(0, 6)
local stroke = Instance.new("UIStroke", tip); stroke.Thickness = 1; stroke.Color = Color3.fromRGB(150, 50, 200)

local lbl = Instance.new("TextLabel", tip)
lbl.Size = UDim2.new(1, -10, 1, -6)
lbl.Position = UDim2.new(0, 5, 0, 3)
lbl.BackgroundTransparency = 1
lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
lbl.Font = Enum.Font.Gotham
lbl.TextScaled = true
lbl.Text = ""

local function showTooltipFor(obj, text)
    lbl.Text = text
    -- Position above the object
    local abs = obj.AbsolutePosition
    local size = obj.AbsoluteSize
    tip.Position = UDim2.fromOffset(abs.X + size.X / 2, abs.Y - 6)
    tip.Visible = true
end

local function hideTooltip() tip.Visible = false end

-- Walk all GuiObjects with "Tooltip" attr; install hover handlers.
local installed = setmetatable({}, {__mode = "k"})  -- weak so destroyed buttons don't leak
local function attach(gui)
    if installed[gui] then return end
    if not gui:IsA("GuiButton") and not gui:IsA("GuiObject") then return end
    local txt = gui:GetAttribute("Tooltip")
    if not txt then return end
    installed[gui] = true
    gui.MouseEnter:Connect(function() showTooltipFor(gui, gui:GetAttribute("Tooltip") or "") end)
    gui.MouseLeave:Connect(hideTooltip)
end

local function sweep(parent)
    for _, c in ipairs(parent:GetDescendants()) do attach(c) end
    parent.DescendantAdded:Connect(attach)
end
sweep(hud)

-- Add tooltips to known HUD buttons. Defer until they exist.
task.spawn(function()
    task.wait(2)
    local function set(name, text)
        local b = hud:FindFirstChild(name, true)
        if b then b:SetAttribute("Tooltip", text) end
    end
    set("SummonButton",      "Summon a human (E)")
    set("ShopButton",        "Browse and buy skins")
    set("InventoryButton",   "Your owned skins")
    set("RebirthButton",     "Reset progress for a chaos multiplier")
    set("LeaderboardButton", "See the top players in this server")
    set("StatsButton",       "Spend stat points")
    set("QuestsButton",      "Today's daily challenges")
    set("SocialButton",      "Discord + invite friends")
    set("SettingsGear",      "Music, camera, redeem code")
    -- Prank buttons: walk children of PrankColumn
    local col = hud:FindFirstChild("PrankColumn")
    if col then
        for _, b in ipairs(col:GetChildren()) do
            local p = b:GetAttribute("PrankName")
            if p then b:SetAttribute("Tooltip", p .. " — get close, then tap") end
        end
    end
end)
