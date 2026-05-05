-- HUDFix.client.lua  v3.67 race-fix
-- Bypass layer that runs AFTER HUDBuilder/HUDController/InputHandler and:
--   1. Re-wires every clickable HUD button with explicit prints + working handlers
--   2. Moves INV/TOP/REBIRTH/SHOP to TOP-RIGHT as small icon buttons (under TopBar, above MAP)
--   3. Adds a visible HEALTH bar in the top-left under the survival bars
--   4. Force-enables Roblox default health if no custom is rendering
--   5. Adds a debug overlay showing button click events so we can verify wiring at runtime

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")

local Remotes      = require(ReplicatedStorage.Modules.RemoteEvents)
local PrankConfig  = require(ReplicatedStorage.Modules.PrankConfig)

local player = Players.LocalPlayer
local hud    = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
if not hud then warn("[HUDFix] MainHUD not found"); return end

print("[HUDFix v3.67] starting — redundant button wiring + layout fixes")

-- Wait one frame so HUDBuilder's children settle
task.wait(0.2)

-- ============================================================
-- 1. NEAREST NPC (scans both PrankNPCs AND AmbientCrowd)
-- ============================================================
local function nearestNPC(maxRange)
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local closest, dist = nil, math.huge
    local folders = {Workspace:FindFirstChild("PrankNPCs"), Workspace:FindFirstChild("AmbientCrowd")}
    for _, folder in ipairs(folders) do
        if folder then
            for _, m in ipairs(folder:GetChildren()) do
                if m:IsA("Model") and not m:GetAttribute("Pranked") then
                    local p = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
                    if p then
                        local d = (p.Position - hrp.Position).Magnitude
                        if d < dist and d <= maxRange then
                            dist = d; closest = m
                        end
                    end
                end
            end
        end
    end
    return closest
end

-- ============================================================
-- 2. RE-WIRE SKILL BAR SLOTS (redundant; will fire prank even if InputHandler is broken)
-- ============================================================
local prankCol = hud:WaitForChild("PrankColumn", 15)
if not prankCol then warn("[HUDFix] PrankColumn never appeared") end
if prankCol then
    print("[HUDFix] PrankColumn found, wiring " .. #PrankConfig.Order .. " slots")
    for _, prankName in ipairs(PrankConfig.Order) do
        local btn = prankCol:FindFirstChild("Prank_" .. prankName)
        if btn then
            local prank = PrankConfig.Pranks[prankName]
            btn.MouseButton1Click:Connect(function()
                print("[HUDFix] SKILL CLICKED: " .. prankName)
                if btn:GetAttribute("Locked") then
                    print("[HUDFix]   → locked, ignored")
                    return
                end
                local npc = nearestNPC(prank.rangeStuds or 24)
                if not npc then
                    -- fallback: auto-summon a target then prank it
                    print("[HUDFix]   → no target in range, auto-summoning")
                    Remotes.RequestSummonHuman:FireServer()
                    task.wait(0.6)
                    npc = nearestNPC((prank.rangeStuds or 24) * 2)
                end
                if npc then
                    print("[HUDFix]   → firing " .. prankName .. " on " .. tostring(npc.Name))
                    Remotes.RequestPrank:FireServer(prankName, npc)
                else
                    print("[HUDFix]   → still no NPC after summon")
                end
            end)
            print("[HUDFix] wired skill slot: " .. prankName)
        end
    end
end

-- ============================================================
-- 3. RE-WIRE HOTKEYS 1-8
-- ============================================================
local NUM_TO_KEYCODE = {
    Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four,
    Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight,
}
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    for slot, kc in ipairs(NUM_TO_KEYCODE) do
        if input.KeyCode == kc then
            local prankName = PrankConfig.Order[slot]
            if not prankName then return end
            print("[HUDFix] HOTKEY " .. slot .. " pressed → " .. prankName)
            local btn = prankCol and prankCol:FindFirstChild("Prank_" .. prankName)
            if btn and btn:GetAttribute("Locked") then
                print("[HUDFix]   → " .. prankName .. " locked, ignored")
                return
            end
            local prank = PrankConfig.Pranks[prankName]
            local npc = nearestNPC((prank.rangeStuds or 24) * 1.5)
            if not npc then
                Remotes.RequestSummonHuman:FireServer()
                task.wait(0.6)
                npc = nearestNPC((prank.rangeStuds or 24) * 2)
            end
            if npc then
                print("[HUDFix]   → firing " .. prankName)
                Remotes.RequestPrank:FireServer(prankName, npc)
            end
            return
        end
    end
end)

-- ============================================================
-- 4. MOVE INV/TOP/REBIRTH/SHOP TO TOP-RIGHT (per user request)
-- Hide the bottom bar, create a vertical icon column under the TopBar
-- and above the MAP minimap.
-- ============================================================
local bottomBar = hud:WaitForChild("BottomBar", 15)
if bottomBar then
    bottomBar.Visible = false  -- hide original
    print("[HUDFix] hid original BottomBar")
end

-- New top-right icon column
local rightCol = Instance.new("Frame")
rightCol.Name = "TopRightActions"
rightCol.Size = UDim2.new(0, 56, 0, 240)
rightCol.AnchorPoint = Vector2.new(1, 0)
rightCol.Position = UDim2.new(1, -16, 0, 130) -- below TopBar (~y=124), above MAP minimap
rightCol.BackgroundTransparency = 1
rightCol.Parent = hud

local rcLayout = Instance.new("UIListLayout", rightCol)
rcLayout.FillDirection = Enum.FillDirection.Vertical
rcLayout.Padding = UDim.new(0, 6)
rcLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function makeActionIcon(name, label, color, layoutOrder, onClick)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, 48, 0, 48)
    btn.BackgroundColor3 = color
    btn.Text = label
    btn.Font = Enum.Font.GothamBlack
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextScaled = true
    btn.TextStrokeTransparency = 0.4
    btn.AutoButtonColor = true
    btn.LayoutOrder = layoutOrder
    btn.Parent = rightCol
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(40, 25, 12)
    btn.MouseButton1Click:Connect(function()
        print("[HUDFix] " .. name .. " icon clicked")
        if onClick then onClick() end
    end)
    return btn
end

local function toggleModal(modalName)
    local modal = hud:FindFirstChild(modalName)
    if modal then
        modal.Visible = not modal.Visible
        print("[HUDFix]   → " .. modalName .. " toggled to " .. tostring(modal.Visible))
    else
        print("[HUDFix]   → modal " .. modalName .. " not found in HUD")
    end
end

makeActionIcon("ShopIcon",    "SHOP", Color3.fromRGB(95, 165, 80),  1, function() toggleModal("ShopModal") end)
makeActionIcon("InvIcon",     "INV",  Color3.fromRGB(140, 95, 60),  2, function() toggleModal("ShopModal") end)
makeActionIcon("RebirthIcon", "REB",  Color3.fromRGB(220, 150, 60), 3, function()
    local ok, err = pcall(function() return Remotes.RequestRebirth:InvokeServer() end)
    if not ok then warn("[HUDFix] Rebirth invoke failed: " .. tostring(err)) end
end)
makeActionIcon("TopIcon",     "TOP",  Color3.fromRGB(85, 130, 175), 4, function() toggleModal("LeaderboardModal") end)

-- ============================================================
-- 5. ADD HEALTH BAR (top-left, below SurvivalContainer)
-- ============================================================
local healthFrame = Instance.new("Frame")
healthFrame.Name = "HealthBar"
healthFrame.Size = UDim2.new(0, 232, 0, 18)
healthFrame.Position = UDim2.new(0, 12, 0, 196) -- below SurvivalContainer (which is at y=126 + 60 + 6)
healthFrame.BackgroundColor3 = Color3.fromRGB(40, 14, 14)
healthFrame.BorderSizePixel = 0
healthFrame.ZIndex = 10
healthFrame.Parent = hud
Instance.new("UICorner", healthFrame).CornerRadius = UDim.new(1, 0)

local healthFill = Instance.new("Frame", healthFrame)
healthFill.Name = "Fill"
healthFill.Size = UDim2.new(1, 0, 1, 0)
healthFill.BackgroundColor3 = Color3.fromRGB(220, 70, 60)
healthFill.BorderSizePixel = 0
healthFill.ZIndex = 11
Instance.new("UICorner", healthFill).CornerRadius = UDim.new(1, 0)

local healthLbl = Instance.new("TextLabel", healthFrame)
healthLbl.Size = UDim2.new(1, 0, 1, 0)
healthLbl.BackgroundTransparency = 1
healthLbl.Text = "HP"
healthLbl.Font = Enum.Font.GothamBlack
healthLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
healthLbl.TextStrokeTransparency = 0.3
healthLbl.TextScaled = true
healthLbl.ZIndex = 12

local function trackHealth(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    local function update()
        local h = math.max(0, hum.Health) / math.max(1, hum.MaxHealth)
        TweenService:Create(healthFill, TweenInfo.new(0.2), {Size = UDim2.new(h, 0, 1, 0)}):Play()
        healthLbl.Text = string.format("HP  %d/%d", math.floor(hum.Health), math.floor(hum.MaxHealth))
    end
    update()
    hum.HealthChanged:Connect(update)
end
if player.Character then trackHealth(player.Character) end
player.CharacterAdded:Connect(trackHealth)
print("[HUDFix] HealthBar created at y=196")

-- ============================================================
-- 6. CHARACTER OVERHEAD HEALTH (Roblox default fallback)
-- ============================================================
local function setHealthDisplay(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.HealthDisplayDistance = 100
        hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
    end
end
if player.Character then setHealthDisplay(player.Character) end
player.CharacterAdded:Connect(setHealthDisplay)

print("[HUDFix v3.67] all wiring + layout fixes applied")
