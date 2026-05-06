-- VersionDisplay.client.lua  v1 — small chip bottom-right showing what
-- version of the source is actually running in the player's session.
-- Reads VersionInfo.lua. If the chip says 'v3.62' but the branch on git
-- is at v3.99, that means the live build is stale and Cowork needs to
-- pull + republish. The chip lets the player + Alex verify at a glance.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VersionInfo
do
    local m = ReplicatedStorage:WaitForChild("Modules", 10)
    local v = m and m:WaitForChild("VersionInfo", 5)
    if v then local ok, mod = pcall(require, v); if ok then VersionInfo = mod end end
end
if not VersionInfo then VersionInfo = {tag="?", commitHash="?", buildDate="?"} end

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local sg = Instance.new("ScreenGui", playerGui)
sg.Name = "VersionDisplay"
sg.IgnoreGuiInset = true
sg.ResetOnSpawn = false
sg.DisplayOrder = 5

local chip = Instance.new("TextButton", sg)
chip.AnchorPoint = Vector2.new(1, 1)
chip.Position = UDim2.new(1, -8, 1, -8)
chip.Size = UDim2.fromOffset(140, 20)
chip.BackgroundColor3 = Color3.fromRGB(40, 25, 12)
chip.BackgroundTransparency = 0.3
chip.Text = VersionInfo.tag .. "  " .. VersionInfo.buildDate
chip.Font = Enum.Font.GothamBold
chip.TextColor3 = Color3.fromRGB(245, 235, 200)
chip.TextStrokeTransparency = 0.4
chip.TextScaled = true
chip.AutoButtonColor = false
Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 4)
local stroke = Instance.new("UIStroke", chip); stroke.Thickness = 1; stroke.Color = Color3.fromRGB(110, 75, 40)
local sc = Instance.new("UITextSizeConstraint", chip); sc.MinTextSize = 9; sc.MaxTextSize = 12

-- Click chip -> expand to show full info for 4s
local expanded = false
chip.MouseButton1Click:Connect(function()
    if expanded then return end
    expanded = true
    chip.Size = UDim2.fromOffset(380, 60)
    chip.Text = string.format("%s  -  built %s\n%s",
        VersionInfo.tag, VersionInfo.buildDate, VersionInfo.commitHash)
    task.delay(4, function()
        chip.Size = UDim2.fromOffset(140, 20)
        chip.Text = VersionInfo.tag .. "  " .. VersionInfo.buildDate
        expanded = false
    end)
end)

print("[VersionDisplay] running " .. VersionInfo.tag .. " (" .. VersionInfo.commitHash .. ")")
