-- TerritoryHUD.client.lua  v1 — top-of-screen banner shows current zone
-- and which clan owns it. Updates 1Hz from workspace attributes set by
-- the server's TerritorySystem.

local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local RunService       = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIUtil = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIUtil"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local ZONES = {
    {name="PLAZA",        center=Vector3.new(0, 5, 0),         radius=140},
    {name="DOWNTOWN",     center=Vector3.new(800, 5, 800),     radius=200},
    {name="CHINATOWN",    center=Vector3.new(-1200, 5, 1200),  radius=200},
    {name="BROOKLYN",     center=Vector3.new(1200, 5, -1200),  radius=200},
    {name="CENTRAL_PARK", center=Vector3.new(-1200, 5, -1200), radius=200},
    {name="WATERFRONT",   center=Vector3.new(0, 5, -1500),     radius=200},
}

local sg = Instance.new("ScreenGui", playerGui)
sg.Name = "TerritoryHUD"
sg.IgnoreGuiInset = false
sg.ResetOnSpawn = false
sg.DisplayOrder = (UIUtil.DisplayOrder.HUD or 10) + 2

local strip = Instance.new("Frame", sg)
strip.AnchorPoint = Vector2.new(0.5, 0)
strip.Position = UDim2.new(0.5, 0, 0, 130)
strip.Size = UDim2.fromOffset(280, 24)
strip.BackgroundColor3 = Color3.fromRGB(50, 35, 20)
strip.BackgroundTransparency = 0.2
strip.Visible = false
Instance.new("UICorner", strip).CornerRadius = UDim.new(0, 8)
local stroke = Instance.new("UIStroke", strip)
stroke.Thickness = 2; stroke.Color = Color3.fromRGB(110, 75, 40)

local lbl = Instance.new("TextLabel", strip)
lbl.Size = UDim2.fromScale(1, 1)
lbl.BackgroundTransparency = 1
lbl.Text = ""
lbl.Font = Enum.Font.GothamBold
lbl.TextColor3 = Color3.fromRGB(255, 240, 200)
lbl.TextStrokeTransparency = 0.4
lbl.TextScaled = true
local lc = Instance.new("UITextSizeConstraint", lbl); lc.MinTextSize = 10; lc.MaxTextSize = 14

local lastT = 0
RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastT < 1 then return end
    lastT = now
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then strip.Visible = false; return end
    local pos = hrp.Position
    local inZone
    for _, z in ipairs(ZONES) do
        if (pos - z.center).Magnitude < z.radius then inZone = z; break end
    end
    if not inZone then strip.Visible = false; return end
    strip.Visible = true
    local ownerTag = Workspace:GetAttribute("Zone_" .. inZone.name .. "_OwnerTag")
    if ownerTag and ownerTag ~= "" then
        lbl.Text = inZone.name .. "  -  owned by [" .. ownerTag .. "]"
    else
        lbl.Text = inZone.name .. "  -  unclaimed (capture the pad)"
    end
end)

print("[TerritoryHUD v1] online")
