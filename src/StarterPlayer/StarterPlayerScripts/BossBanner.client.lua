-- BossBanner.client.lua
-- When a boss NPC exists in PrankNPCs, show a top-of-screen banner
-- "BOSS NEARBY" with an arrow pointing toward the closest boss. Banner
-- fades out when no bosses remain. Updates direction continuously.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIUtil = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIUtil"))

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
if not hud then return end

local sg = Instance.new("ScreenGui")
sg.Name = "BossBannerGui"
sg.IgnoreGuiInset = true
sg.ResetOnSpawn = false
sg.DisplayOrder = UIUtil.DisplayOrder.Combo + 1
sg.Parent = player.PlayerGui

local banner = Instance.new("Frame", sg)
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Size = UDim2.new(0, 300, 0, 38)
banner.Position = UDim2.new(0.5, 0, 0, 152)  -- below TopBar + Survival + a bit
banner.BackgroundColor3 = UIUtil.Palette.bgMid
banner.BackgroundTransparency = 1  -- start hidden
banner.BorderSizePixel = 0
Instance.new("UICorner", banner).CornerRadius = UIUtil.Token.cornerSm
local bs = Instance.new("UIStroke", banner)
bs.Thickness = UIUtil.Token.strokeBold
bs.Color = UIUtil.Palette.gold
bs.Transparency = 1

local arrow = Instance.new("TextLabel", banner)
arrow.AnchorPoint = Vector2.new(0, 0.5)
arrow.Size = UDim2.new(0, 24, 1, 0)
arrow.Position = UDim2.new(0, 8, 0.5, 0)
arrow.BackgroundTransparency = 1
arrow.Text = ">"
arrow.TextColor3 = UIUtil.Palette.gold
arrow.Font = UIUtil.Token.fontHeader
arrow.TextScaled = true
arrow.TextTransparency = 1
UIUtil.boundText(arrow, 18, 28)

local label = Instance.new("TextLabel", banner)
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.Size = UDim2.new(1, -40, 1, -8)
label.Position = UDim2.new(0.5, 0, 0.5, 0)
label.BackgroundTransparency = 1
label.Text = "BOSS NEARBY"
label.TextColor3 = UIUtil.Palette.textHi
label.TextStrokeTransparency = 0.4
label.TextStrokeColor3 = UIUtil.Palette.stroke
label.Font = UIUtil.Token.fontHeader
label.TextScaled = true
label.TextTransparency = 1
UIUtil.boundText(label, 14, 22)

local visible = false
local function setVisible(v)
    if v == visible then return end
    visible = v
    local target = v and 0.1 or 1
    local labelTarget = v and 0 or 1
    TweenService:Create(banner, UIUtil.Token.easeOut, {BackgroundTransparency = target}):Play()
    TweenService:Create(bs,     UIUtil.Token.easeOut, {Transparency = labelTarget}):Play()
    TweenService:Create(label,  UIUtil.Token.easeOut, {TextTransparency = labelTarget}):Play()
    TweenService:Create(arrow,  UIUtil.Token.easeOut, {TextTransparency = labelTarget}):Play()
end

-- Find nearest boss + its 2D screen direction
RunService.RenderStepped:Connect(function()
    local pnpcs = Workspace:FindFirstChild("PrankNPCs")
    if not pnpcs then setVisible(false); return end
    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then setVisible(false); return end

    local closest, closestDist = nil, math.huge
    for _, npc in ipairs(pnpcs:GetChildren()) do
        if npc:IsA("Model") and npc:GetAttribute("Boss") and not npc:GetAttribute("BossDefeated") and npc.PrimaryPart then
            local d = (npc.PrimaryPart.Position - hrp.Position).Magnitude
            if d < closestDist then
                closestDist = d
                closest = npc
            end
        end
    end
    if not closest then setVisible(false); return end
    setVisible(true)

    -- Compute angle from player look-direction to boss in XZ plane
    local toBoss = closest.PrimaryPart.Position - hrp.Position
    toBoss = Vector3.new(toBoss.X, 0, toBoss.Z)
    local lookXZ = hrp.CFrame.LookVector
    lookXZ = Vector3.new(lookXZ.X, 0, lookXZ.Z)
    if toBoss.Magnitude < 0.1 or lookXZ.Magnitude < 0.1 then return end
    toBoss = toBoss.Unit; lookXZ = lookXZ.Unit
    -- Signed angle: cross.Y > 0 => boss is to the LEFT
    local cross = lookXZ:Cross(toBoss)
    local dot = lookXZ:Dot(toBoss)
    local ang = math.atan2(cross.Y, dot)  -- radians, positive = right? actually depends
    -- Normalize to choose arrow + label
    local degrees = math.deg(ang)
    if math.abs(degrees) < 30 then
        arrow.Text = "^"
        label.Text = "BOSS AHEAD  ·  " .. math.floor(closestDist) .. "m"
    elseif degrees > 0 then
        arrow.Text = ">"
        label.Text = "BOSS RIGHT  ·  " .. math.floor(closestDist) .. "m"
    else
        arrow.Text = "<"
        label.Text = "BOSS LEFT  ·  " .. math.floor(closestDist) .. "m"
    end
end)

print("[BossBanner v1] online")
