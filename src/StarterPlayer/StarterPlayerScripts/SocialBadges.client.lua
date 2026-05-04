-- SocialBadges.client.lua
-- Two small UX touches anchored to the bottom-left:
--   1. Friends-in-server pill: shows "FRIENDS  ·  N" when at least one of
--      your Roblox friends is in the same server. Updates on join/leave.
--   2. Solo-server hint: when you're the only player, show a single toast
--      "Empty server. Invite friends to play together!" once per session.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIUtil = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIUtil"))

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
if not hud then return end

-- Pill anchored bottom-left, above the bottom bar
local pill = Instance.new("Frame")
pill.Name = "FriendsPill"
pill.AnchorPoint = Vector2.new(0, 1)
pill.Size = UDim2.new(0, 132, 0, 30)
pill.Position = UDim2.new(0, 12, 1, -86)
pill.BackgroundColor3 = UIUtil.Palette.bgMid
pill.BackgroundTransparency = 0.05
pill.Visible = false
pill.Parent = hud
Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
local pillStroke = Instance.new("UIStroke", pill)
pillStroke.Thickness = UIUtil.Token.strokeReg
pillStroke.Color = UIUtil.Palette.hairline

local pillLabel = Instance.new("TextLabel", pill)
pillLabel.Size = UDim2.new(1, -16, 1, 0)
pillLabel.Position = UDim2.fromOffset(8, 0)
pillLabel.BackgroundTransparency = 1
pillLabel.TextColor3 = UIUtil.Palette.textHi
pillLabel.TextStrokeTransparency = 0.4
pillLabel.TextStrokeColor3 = UIUtil.Palette.stroke
pillLabel.Font = UIUtil.Token.fontHeader
pillLabel.TextScaled = true
pillLabel.TextXAlignment = Enum.TextXAlignment.Center
pillLabel.Text = "FRIENDS"
UIUtil.boundText(pillLabel, 12, 18)

-- Friend detection via Roblox Friends API
local function isFriend(otherUserId)
    if otherUserId == player.UserId then return false end
    local ok, result = pcall(function()
        return player:IsFriendsWith(otherUserId)
    end)
    return ok and result
end

local function refresh()
    local friendCount = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isFriend(p.UserId) then
            friendCount = friendCount + 1
        end
    end
    if friendCount > 0 then
        pillLabel.Text = "FRIENDS  ·  " .. friendCount
        pill.Visible = true
    else
        pill.Visible = false
    end
end

Players.PlayerAdded:Connect(function() task.wait(1); refresh() end)
Players.PlayerRemoving:Connect(refresh)
task.spawn(function() task.wait(3); refresh() end)

-- Solo-server hint (once per session)
task.spawn(function()
    task.wait(20)  -- give other players a chance to load
    if #Players:GetPlayers() <= 1 and not player:GetAttribute("SeenSoloHint") then
        player:SetAttribute("SeenSoloHint", true)
        local toastFrame = hud:FindFirstChild("ToastFrame")
        if toastFrame then
            UIUtil.makeToast(toastFrame,
                "Quiet server. Invite friends to play together.",
                UIUtil.Palette.gold, 5.0)
        end
    end
end)

print("[SocialBadges v1] online")
