-- BattlePassPanel.client.lua  v1 — browseable battle-pass tier list.
-- BP button anchored top-right under the AchievementsViewer ACH pill;
-- modal lists 10 tiers each with progress bar + free/premium claim buttons.
-- Persists last-known data via Remotes.UpdatePlayerData.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIUtil  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIUtil"))
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local BattlePassConfig = require(ReplicatedStorage.Modules:WaitForChild("BattlePassConfig"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud       = playerGui:WaitForChild("MainHUD", 30)
if not hud then return end

local cachedData = {}
Remotes.UpdatePlayerData.OnClientEvent:Connect(function(d)
    if typeof(d) == "table" then cachedData = d end
end)

-- Wait for the lazy-created RequestClaimBattlePass RemoteFunction.
local RequestClaimBP
task.spawn(function()
    local f = ReplicatedStorage:WaitForChild("RemoteEventsFolder", 30)
    if f then RequestClaimBP = f:WaitForChild("RequestClaimBattlePass", 30) end
end)

-- =====================================================================
-- TRIGGER BUTTON
-- =====================================================================
local triggerSG = Instance.new("ScreenGui", playerGui)
triggerSG.Name = "BattlePassTrigger"
triggerSG.IgnoreGuiInset = false
triggerSG.ResetOnSpawn = false
triggerSG.DisplayOrder = (UIUtil.DisplayOrder.HUD or 10) + 5

local btn = Instance.new("TextButton", triggerSG)
btn.AnchorPoint = Vector2.new(1, 0)
btn.Size = UDim2.new(0, 80, 0, 32)
btn.Position = UDim2.new(1, -16, 0, 330)  -- below ACH button (which sits at 290)
btn.BackgroundColor3 = Color3.fromRGB(220, 150, 60)
btn.AutoButtonColor = true
btn.Text = "PASS"
btn.Font = Enum.Font.LuckiestGuy
btn.TextScaled = true
btn.TextColor3 = Color3.fromRGB(255, 240, 200)
btn.TextStrokeTransparency = 0.3
btn.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
local bs = Instance.new("UIStroke", btn); bs.Thickness = 2; bs.Color = Color3.fromRGB(110, 75, 40)
local bc = Instance.new("UITextSizeConstraint", btn); bc.MinTextSize = 12; bc.MaxTextSize = 18

-- =====================================================================
-- MODAL
-- =====================================================================
local modalSG = Instance.new("ScreenGui", playerGui)
modalSG.Name = "BattlePassModal"
modalSG.IgnoreGuiInset = true
modalSG.ResetOnSpawn = false
modalSG.DisplayOrder = (UIUtil.DisplayOrder.Modal or 60) + 5
modalSG.Enabled = false

local backdrop = Instance.new("Frame", modalSG)
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.45

local modal = Instance.new("Frame", modalSG)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.Size = UDim2.fromOffset(680, 580)
modal.BackgroundColor3 = Color3.fromRGB(245, 230, 200)
Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 14)
local mStr = Instance.new("UIStroke", modal); mStr.Thickness = 4; mStr.Color = Color3.fromRGB(110, 75, 45)

local title = Instance.new("TextLabel", modal)
title.Size = UDim2.new(1, -56, 0, 44)
title.Position = UDim2.new(0, 16, 0, 12)
title.BackgroundTransparency = 1
title.Text = "BATTLE PASS"
title.Font = Enum.Font.LuckiestGuy
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(80, 40, 20)
title.TextXAlignment = Enum.TextXAlignment.Left
local tc = Instance.new("UITextSizeConstraint", title); tc.MinTextSize = 18; tc.MaxTextSize = 32

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

local scroll = Instance.new("ScrollingFrame", modal)
scroll.Size = UDim2.new(1, -32, 1, -76)
scroll.Position = UDim2.new(0, 16, 0, 64)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = Color3.fromRGB(110, 75, 45)
local layout = Instance.new("UIListLayout", scroll)
layout.Padding = UDim.new(0, 6)

local function rewardSummary(r)
    local pieces = {}
    if r.chaos and r.chaos > 0 then
        if r.chaos >= 1000000 then table.insert(pieces, math.floor(r.chaos/1000000) .. "M chaos")
        elseif r.chaos >= 1000 then table.insert(pieces, math.floor(r.chaos/1000) .. "K chaos")
        else table.insert(pieces, r.chaos .. " chaos") end
    end
    if r.hellTokens and r.hellTokens > 0 then table.insert(pieces, r.hellTokens .. " HT") end
    if r.skinId then table.insert(pieces, "SKIN: " .. r.skinId) end
    return table.concat(pieces, "  ·  ")
end

local function rebuild()
    for _, c in ipairs(scroll:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    local totalPranks = cachedData.totalPranks or 0
    local claimed = cachedData.bpClaimed or {free={},premium={}}

    -- Header progress
    local header = Instance.new("Frame", scroll)
    header.Size = UDim2.new(1, -8, 0, 50)
    header.BackgroundColor3 = Color3.fromRGB(255, 220, 170)
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 8)
    local hStr = Instance.new("UIStroke", header); hStr.Thickness = 2; hStr.Color = Color3.fromRGB(180, 140, 90)
    local hl = Instance.new("TextLabel", header)
    hl.Size = UDim2.new(1, -16, 1, 0)
    hl.Position = UDim2.fromOffset(8, 0)
    hl.BackgroundTransparency = 1
    hl.Text = "TOTAL PRANKS: " .. totalPranks .. "  -  earn pranks to unlock tiers"
    hl.Font = Enum.Font.GothamBold
    hl.TextScaled = true
    hl.TextColor3 = Color3.fromRGB(80, 40, 20)
    hl.TextXAlignment = Enum.TextXAlignment.Left
    local hc = Instance.new("UITextSizeConstraint", hl); hc.MinTextSize = 11; hc.MaxTextSize = 16

    for _, entry in ipairs(BattlePassConfig.Tiers) do
        local unlocked = totalPranks >= entry.threshold
        local row = Instance.new("Frame", scroll)
        row.Size = UDim2.new(1, -8, 0, 64)
        row.BackgroundColor3 = unlocked and Color3.fromRGB(255, 245, 215) or Color3.fromRGB(225, 215, 195)
        row.BackgroundTransparency = 0.05
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
        local rStr = Instance.new("UIStroke", row)
        rStr.Thickness = 2
        rStr.Color = unlocked and Color3.fromRGB(220, 175, 80) or Color3.fromRGB(140, 120, 100)

        -- Tier label
        local tierLbl = Instance.new("TextLabel", row)
        tierLbl.Size = UDim2.fromOffset(60, 60)
        tierLbl.Position = UDim2.fromOffset(8, 2)
        tierLbl.BackgroundTransparency = 1
        tierLbl.Text = "T" .. entry.tier
        tierLbl.Font = Enum.Font.LuckiestGuy
        tierLbl.TextScaled = true
        tierLbl.TextColor3 = Color3.fromRGB(80, 40, 20)
        local ttc = Instance.new("UITextSizeConstraint", tierLbl); ttc.MinTextSize = 16; ttc.MaxTextSize = 28

        -- Threshold
        local thr = Instance.new("TextLabel", row)
        thr.Size = UDim2.fromOffset(80, 16)
        thr.Position = UDim2.fromOffset(72, 4)
        thr.BackgroundTransparency = 1
        thr.Text = entry.threshold .. " pranks"
        thr.Font = Enum.Font.GothamMedium
        thr.TextScaled = true
        thr.TextColor3 = Color3.fromRGB(120, 70, 40)
        thr.TextXAlignment = Enum.TextXAlignment.Left
        local thc = Instance.new("UITextSizeConstraint", thr); thc.MinTextSize = 9; thc.MaxTextSize = 12

        -- Free reward + claim
        local freeLbl = Instance.new("TextLabel", row)
        freeLbl.Size = UDim2.fromOffset(220, 22)
        freeLbl.Position = UDim2.fromOffset(72, 22)
        freeLbl.BackgroundTransparency = 1
        freeLbl.Text = "FREE: " .. rewardSummary(entry.free)
        freeLbl.Font = Enum.Font.GothamBold
        freeLbl.TextScaled = true
        freeLbl.TextColor3 = Color3.fromRGB(80, 40, 20)
        freeLbl.TextXAlignment = Enum.TextXAlignment.Left
        local flc = Instance.new("UITextSizeConstraint", freeLbl); flc.MinTextSize = 10; flc.MaxTextSize = 13

        local prmLbl = Instance.new("TextLabel", row)
        prmLbl.Size = UDim2.fromOffset(220, 22)
        prmLbl.Position = UDim2.fromOffset(72, 42)
        prmLbl.BackgroundTransparency = 1
        prmLbl.Text = "PREMIUM: " .. rewardSummary(entry.premium)
        prmLbl.Font = Enum.Font.GothamBold
        prmLbl.TextScaled = true
        prmLbl.TextColor3 = Color3.fromRGB(150, 90, 30)
        prmLbl.TextXAlignment = Enum.TextXAlignment.Left
        local plc = Instance.new("UITextSizeConstraint", prmLbl); plc.MinTextSize = 10; plc.MaxTextSize = 13

        local function makeClaim(track, x, y, color)
            local b = Instance.new("TextButton", row)
            b.AnchorPoint = Vector2.new(1, 0)
            b.Position = UDim2.new(1, x, 0, y)
            b.Size = UDim2.fromOffset(110, 26)
            b.BackgroundColor3 = color
            b.AutoButtonColor = unlocked
            local key = tostring(entry.tier)
            local already = claimed[track] and claimed[track][key]
            if not unlocked then
                b.Text = "LOCKED"; b.BackgroundColor3 = Color3.fromRGB(140, 120, 100)
            elseif already then
                b.Text = "CLAIMED"; b.BackgroundColor3 = Color3.fromRGB(140, 120, 100)
            else
                b.Text = "CLAIM"
            end
            b.Font = Enum.Font.GothamBold
            b.TextScaled = true
            b.TextColor3 = Color3.fromRGB(255, 248, 230)
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
            local sc2 = Instance.new("UITextSizeConstraint", b); sc2.MinTextSize = 9; sc2.MaxTextSize = 14
            if unlocked and not already then
                b.MouseButton1Click:Connect(function()
                    if not RequestClaimBP then return end
                    b.Active = false; b.Text = "..."
                    task.spawn(function()
                        pcall(function() RequestClaimBP:InvokeServer(entry.tier, track) end)
                        task.wait(0.3); rebuild()
                    end)
                end)
            end
        end
        makeClaim("free",    -132, 6,  Color3.fromRGB(110, 165, 95))
        makeClaim("premium", -10,  32, Color3.fromRGB(220, 150, 60))
    end
end

btn.MouseButton1Click:Connect(function()
    rebuild()
    modalSG.Enabled = true
end)
close.MouseButton1Click:Connect(function() modalSG.Enabled = false end)
backdrop.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        modalSG.Enabled = false
    end
end)

print("[BattlePassPanel v1] online")
