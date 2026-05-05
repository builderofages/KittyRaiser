-- HUDFix.client.lua  v3.68 — comprehensive layout + wiring fix
-- 1. REMOVE SummonButton entirely (clicks auto-summon now via skill click)
-- 2. Reposition ACH + PASS into a top-right ICON column (under TopBar, above MAP) so they don't cut off
-- 3. Reliably re-wire INV/TOP/REBIRTH/SHOP and every prank slot using WaitForChild
-- 4. Hide the duplicate "LV X" fallback label that was overlapping with prank ASCII
-- 5. Custom HealthBar
-- 6. Hotkey 1-8 redundantly wired
-- 7. Console prints for every wiring step + click event

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

print("[HUDFix v3.68] starting — full HUD layout + click wiring fix")

-- ============================================================
-- NEAREST NPC (scans both PrankNPCs AND AmbientCrowd)
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

local function firePrank(prankName)
    print("[HUDFix] firePrank called: " .. prankName)
    local prank = PrankConfig.Pranks[prankName]
    if not prank then warn("[HUDFix]   no PrankConfig entry for " .. prankName); return end
    local npc = nearestNPC((prank.rangeStuds or 24) * 1.5)
    if not npc then
        print("[HUDFix]   no NPC in range, auto-summoning")
        Remotes.RequestSummonHuman:FireServer()
        task.wait(0.7)
        npc = nearestNPC((prank.rangeStuds or 24) * 2.5)
    end
    if npc then
        print("[HUDFix]   firing " .. prankName .. " on " .. tostring(npc.Name))
        Remotes.RequestPrank:FireServer(prankName, npc)
    else
        print("[HUDFix]   STILL no NPC after summon")
    end
end

-- ============================================================
-- 1. REMOVE SUMMON BUTTON ENTIRELY
-- ============================================================
local summonBtn = hud:WaitForChild("SummonButton", 15)
if summonBtn then
    summonBtn.Visible = false
    summonBtn:Destroy()
    print("[HUDFix] SummonButton destroyed (per user request)")
end

-- ============================================================
-- 2. RE-WIRE SKILL BAR SLOTS — THIS IS THE CRITICAL FIX
-- ============================================================
local prankCol = hud:WaitForChild("PrankColumn", 15)
if prankCol then
    print("[HUDFix] PrankColumn found, wiring " .. #PrankConfig.Order .. " slots")
    for slot, prankName in ipairs(PrankConfig.Order) do
        local btn = prankCol:WaitForChild("Prank_" .. prankName, 5)
        if btn then
            -- Hide the duplicate FallbackLabel since LockOverlay shows "LV X"
            local fallback = btn:FindFirstChild("FallbackLabel")
            if fallback then
                if btn:GetAttribute("Locked") then
                    fallback.Visible = false  -- hide ASCII; show only "LV X"
                else
                    fallback.Visible = true
                end
            end
            -- Wire click
            btn.MouseButton1Click:Connect(function()
                print("[HUDFix] SKILL CLICKED slot " .. slot .. ": " .. prankName)
                if btn:GetAttribute("Locked") then
                    print("[HUDFix]   slot is locked")
                    return
                end
                firePrank(prankName)
            end)
            print("[HUDFix]   wired slot " .. slot .. " (" .. prankName .. ") locked=" .. tostring(btn:GetAttribute("Locked")))
        end
    end
else
    warn("[HUDFix] PrankColumn never appeared")
end

-- ============================================================
-- 3. HOTKEYS 1-8
-- ============================================================
local NUM_KC = {
    [Enum.KeyCode.One]=1, [Enum.KeyCode.Two]=2, [Enum.KeyCode.Three]=3, [Enum.KeyCode.Four]=4,
    [Enum.KeyCode.Five]=5, [Enum.KeyCode.Six]=6, [Enum.KeyCode.Seven]=7, [Enum.KeyCode.Eight]=8,
}
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local slot = NUM_KC[input.KeyCode]
    if slot then
        local prankName = PrankConfig.Order[slot]
        if not prankName then return end
        print("[HUDFix] HOTKEY " .. slot .. " pressed → " .. prankName)
        local btn = prankCol and prankCol:FindFirstChild("Prank_" .. prankName)
        if btn and btn:GetAttribute("Locked") then
            print("[HUDFix]   locked")
            return
        end
        firePrank(prankName)
    end
end)

-- ============================================================
-- 4. WIRE BOTTOM BAR (INV/TOP/REBIRTH/SHOP)
-- ============================================================
local bottomBar = hud:WaitForChild("BottomBar", 15)
if bottomBar then
    print("[HUDFix] BottomBar found")
    local function toggleModal(modalName)
        local m = hud:FindFirstChild(modalName)
        if m then m.Visible = not m.Visible; print("[HUDFix]   " .. modalName .. " toggled to " .. tostring(m.Visible)) end
    end

    local shopBtn = bottomBar:FindFirstChild("ShopButton")
    if shopBtn then shopBtn.MouseButton1Click:Connect(function() print("[HUDFix] SHOP clicked"); toggleModal("ShopModal") end); print("[HUDFix]   SHOP wired") end

    local invBtn = bottomBar:FindFirstChild("InventoryButton")
    if invBtn then invBtn.MouseButton1Click:Connect(function() print("[HUDFix] INV clicked"); toggleModal("ShopModal") end); print("[HUDFix]   INV wired") end

    local rebBtn = bottomBar:FindFirstChild("RebirthButton")
    if rebBtn then
        rebBtn.MouseButton1Click:Connect(function()
            print("[HUDFix] REBIRTH clicked")
            local ok, err = pcall(function() return Remotes.RequestRebirth:InvokeServer() end)
            if not ok then warn("[HUDFix]   rebirth failed: " .. tostring(err)) end
        end)
        print("[HUDFix]   REBIRTH wired")
    end

    local topBtn = bottomBar:FindFirstChild("LeaderboardButton")
    if topBtn then topBtn.MouseButton1Click:Connect(function() print("[HUDFix] TOP clicked"); toggleModal("LeaderboardModal") end); print("[HUDFix]   TOP wired") end
end

-- ============================================================
-- 5. REPOSITION ACH + PASS so they don't cut off
-- ============================================================
local achPanel = hud:FindFirstChild("AchButton") or hud:FindFirstChild("AchievementsButton") or hud:FindFirstChild("ACH")
local passPanel = hud:FindFirstChild("PassButton") or hud:FindFirstChild("BattlePassButton") or hud:FindFirstChild("PASS")
-- Search descendants for any frame named ACH or PASS
for _, child in ipairs(hud:GetDescendants()) do
    if child:IsA("GuiObject") then
        if (not achPanel) and (child.Name == "ACH" or child.Name:find("Achievement") or child.Name:find("ACH")) then achPanel = child end
        if (not passPanel) and (child.Name == "PASS" or child.Name:find("BattlePass") or child.Name:find("PASS")) then passPanel = child end
    end
end

-- Move ACH and PASS to a safe top-right column at x=-72 (so they fit on-screen with margin)
if achPanel and achPanel:IsA("GuiObject") then
    achPanel.AnchorPoint = Vector2.new(1, 0)
    achPanel.Position = UDim2.new(1, -16, 0, 200)
    achPanel.Size = UDim2.new(0, 56, 0, 40)
    print("[HUDFix] ACH repositioned top-right at y=200")
end
if passPanel and passPanel:IsA("GuiObject") then
    passPanel.AnchorPoint = Vector2.new(1, 0)
    passPanel.Position = UDim2.new(1, -16, 0, 248)
    passPanel.Size = UDim2.new(0, 56, 0, 40)
    print("[HUDFix] PASS repositioned top-right at y=248")
end

-- ============================================================
-- 6. CUSTOM HEALTH BAR (top-left below survival)
-- ============================================================
local healthFrame = Instance.new("Frame")
healthFrame.Name = "HealthBar"
healthFrame.Size = UDim2.new(0, 232, 0, 18)
healthFrame.Position = UDim2.new(0, 12, 0, 196)
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
    hum.HealthDisplayDistance = 100
    hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
end
if player.Character then trackHealth(player.Character) end
player.CharacterAdded:Connect(trackHealth)
print("[HUDFix] HealthBar created at y=196")

print("[HUDFix v3.68] all wiring + layout fixes applied")
