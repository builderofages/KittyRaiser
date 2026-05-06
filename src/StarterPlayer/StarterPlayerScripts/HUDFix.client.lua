-- HUDFix.client.lua  v3.69 — clean HUD overhaul per user feedback
-- 1. DESTROY SummonButton entirely
-- 2. HIDE BottomBar (INV/TOP/REBIRTH/SHOP all gone — clutter)
-- 3. KEEP only top-right chaos counter, hide top-left coin + top-center gem duplicates
-- 4. HIDE ACH + PASS (clutter, were cut off anyway)
-- 5. Move PrankColumn skill bar DOWN to where bottom bar was (more screen space)
-- 6. Custom HP / HUNGER / THIRST bars stacked top-left under TopBar
-- 7. Reliable click + hotkey wiring for all 8 skill slots
-- 8. Auto-summon fallback when no NPC in range

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

print("[HUDFix v3.69] starting — clean HUD overhaul")

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
                        if d < dist and d <= maxRange then dist = d; closest = m end
                    end
                end
            end
        end
    end
    return closest
end

-- v3.78: widened attack hitbox per playtest. Was 1.5x rangeStuds (~36 studs
-- for default 24); now 3x (~72 studs). Pranks land on whatever's near the
-- cat in the screen view, not just point-blank.
local HITBOX_MULT = 3.0
local function firePrank(prankName)
    print("[HUDFix] firePrank " .. prankName)
    local prank = PrankConfig.Pranks[prankName]
    if not prank then return end
    local range = (prank.rangeStuds or 24) * HITBOX_MULT
    local npc = nearestNPC(range)
    if not npc then
        Remotes.RequestSummonHuman:FireServer()
        task.wait(0.7)
        npc = nearestNPC(range * 1.4)
    end
    if npc then
        Remotes.RequestPrank:FireServer(prankName, npc)
        print("[HUDFix]   fired on " .. tostring(npc.Name))
    else
        print("[HUDFix]   no NPC found")
    end
end

-- v3.78: also expose a direct mouse/touch click-to-attack handler that
-- always picks the strongest unlocked skill. Robust fallback in case the
-- per-button MouseButton1Click handlers don't fire.
local function strongestUnlockedPrank()
    local prankCol = hud:FindFirstChild("PrankColumn")
    if not prankCol then return nil end
    for i = #PrankConfig.Order, 1, -1 do
        local name = PrankConfig.Order[i]
        local b = prankCol:FindFirstChild("Prank_" .. name)
        if b and not b:GetAttribute("Locked") then return name end
    end
    return nil
end
local lastClickAttackT = 0
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        local now = os.clock()
        if now - lastClickAttackT < 0.35 then return end
        lastClickAttackT = now
        local name = strongestUnlockedPrank()
        if name then firePrank(name) end
    end
end)

-- ============ 1. DESTROY SummonButton ============

-- v290 HOTFIX: PERMANENT_SUMMON_KILLER — anything ever named SummonButton dies on sight
hud.ChildAdded:Connect(function(child)
    if child.Name == 'SummonButton' or child.Name == 'SummonButton_REMOVED' then
        child:Destroy()
        print('[HUDFix] killed late-spawned SummonButton')
    end
end)
for _, c in ipairs(hud:GetChildren()) do
    if c.Name == 'SummonButton' or c.Name == 'SummonButton_REMOVED' then c:Destroy() end
end

local summonBtn = hud:WaitForChild("SummonButton", 2)
if summonBtn then summonBtn:Destroy(); print("[HUDFix] SummonButton destroyed") end

-- ============ 2. RELOCATE BottomBar to top-right vertical icon column ============
-- v3.78: instead of hiding BottomBar, MOVE it. HUDController already wired
-- MouseButton1Click on InventoryButton/LeaderboardButton/RebirthButton/
-- ShopButton — keeping the same buttons preserves all that modal wiring.
-- We just resize the container vertically and shrink each child button to
-- a 40x38 icon-style chip.
local bottomBar = hud:WaitForChild("BottomBar", 15)
if bottomBar then
    bottomBar.AnchorPoint = Vector2.new(1, 0)
    bottomBar.Position = UDim2.new(1, -16, 0, 320)  -- below minimap + PASS pill
    bottomBar.Size = UDim2.fromOffset(48, 4 * 42 + 8)
    bottomBar.Visible = true
    bottomBar.BackgroundTransparency = 1
    -- Flip layout to vertical
    for _, layout in ipairs(bottomBar:GetChildren()) do
        if layout:IsA("UIListLayout") then
            layout.FillDirection = Enum.FillDirection.Vertical
            layout.Padding = UDim.new(0, 4)
            layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        end
    end
    -- Resize each child button + replace label with short text
    local SHORT = {InventoryButton="INV", LeaderboardButton="TOP",
                   RebirthButton="RBT", ShopButton="SHP",
                   StatsButton="STA", MenuButton="MNU"}
    for _, btn in ipairs(bottomBar:GetChildren()) do
        if btn:IsA("TextButton") or btn:IsA("ImageButton") then
            btn.Size = UDim2.fromOffset(40, 38)
            -- Hide internal Icon ImageLabel + use a short text label instead
            -- (icons render too small at 18x18 inside a 40x38 chip).
            for _, c in ipairs(btn:GetChildren()) do
                if c:IsA("ImageLabel") then c.Visible = false end
                if c:IsA("TextLabel") then
                    c.Size = UDim2.fromScale(1, 1)
                    c.Position = UDim2.fromOffset(0, 0)
                    c.Text = SHORT[btn.Name] or btn.Name:sub(1, 3)
                    c.Font = Enum.Font.GothamBold
                    c.TextScaled = true
                    c.TextColor3 = Color3.fromRGB(255, 248, 230)
                    c.TextStrokeTransparency = 0.3
                    c.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)
                end
            end
        end
    end
    print("[HUDFix v3.78] BottomBar relocated to top-right vertical icon column")

    -- v3.79: REDUNDANT modal click wiring. HUDController already wires
    -- MouseButton1Click on these buttons — but if HUDFix runs first, or if
    -- there's any race condition, the wiring may miss. Re-wire as belt-and-
    -- suspenders so clicks ALWAYS open something.
    local function wireModalToggle(btn, modalName, opts)
        if not btn then return end
        btn.MouseButton1Click:Connect(function()
            print("[HUDFix v3.79] " .. (btn.Name or "?") .. " clicked")
            local modal = hud:FindFirstChild(modalName)
            if modal then
                modal.Visible = not modal.Visible
                print("[HUDFix v3.79]   toggled " .. modalName .. " to " .. tostring(modal.Visible))
            else
                print("[HUDFix v3.79]   WARN: " .. modalName .. " not found in HUD")
            end
        end)
    end
    wireModalToggle(bottomBar:FindFirstChild("ShopButton"), "ShopModal")
    wireModalToggle(bottomBar:FindFirstChild("InventoryButton"), "ShopModal")
    wireModalToggle(bottomBar:FindFirstChild("LeaderboardButton"), "LeaderboardModal")
    -- REBIRTH stays as-is (it calls a remote, not a modal). We don't double-fire.
end

-- ============ 3. HIDE duplicate currency cells (keep only top-right) ============
-- TopBar has chaosWrap (top-left), hellWrap (gem, top-center), and the right-side count.
-- Per user: keep only top-right yellow chaos counter.
local topBar = hud:WaitForChild("TopBar", 15)
if topBar then
    -- v3.99.1: hide ALL currency wraps EXCEPT the right-side primary chaos label.
    -- Defensive: don't trust any specific child names. Walk children and hide
    -- any Frame whose name contains 'Wrap' or matches known currency keywords,
    -- KEEP one that's anchored top-right (RightCount / ChaosLabel host).
    for _, child in ipairs(topBar:GetChildren()) do
        if child:IsA("GuiObject") then
            local n = child.Name:lower()
            local isLeftSide = (child.AnchorPoint.X < 0.5) or (child.Position.X.Scale < 0.4)
            local isCurrency = n:find("wrap") or n:find("chaos") or n:find("hell") or n:find("gem") or n:find("coin")
            if isCurrency and isLeftSide then
                child.Visible = false
                print("[HUDFix] hid duplicate currency " .. child.Name)
            end
        end
    end
end

-- ============ 4. ACH/PASS PILLS RETAINED ============
-- v3.99.2: ACH (AchievementsViewer:43) + PASS (BattlePassPanel:45) are
-- LEGITIMATE buttons that open functional modals. Do NOT hide them.
-- They sit at top-right Y=290, 330 above CLAN (370) + HOME (410) — clean stack.

-- ============ 5. MOVE PrankColumn DOWN ============
local prankCol = hud:WaitForChild("PrankColumn", 15)
if prankCol then
    -- Move skill bar down to ~y=1, -32 (just above bottom edge) since BottomBar is gone
    prankCol.AnchorPoint = Vector2.new(0.5, 1)
    prankCol.Position = UDim2.new(0.5, 0, 1, -16)
    print("[HUDFix] PrankColumn moved to bottom-center")

    print("[HUDFix] wiring " .. #PrankConfig.Order .. " skill slots")
    for slot, prankName in ipairs(PrankConfig.Order) do
        local btn = prankCol:WaitForChild("Prank_" .. prankName, 5)
        if btn then
            -- Hide duplicate FallbackLabel on locked slots so LV X reads cleanly
            local fallback = btn:FindFirstChild("FallbackLabel")
            if fallback and btn:GetAttribute("Locked") then fallback.Visible = false end
            btn.MouseButton1Click:Connect(function()
                print("[HUDFix] SKILL " .. slot .. " clicked: " .. prankName)
                if btn:GetAttribute("Locked") then return end
                firePrank(prankName)
            end)
            print("[HUDFix]   slot " .. slot .. " (" .. prankName .. ") locked=" .. tostring(btn:GetAttribute("Locked")))
        end
    end
end

-- ============ 6. HOTKEYS 1-8 ============
local NUM_KC = {[Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3,[Enum.KeyCode.Four]=4,
                [Enum.KeyCode.Five]=5,[Enum.KeyCode.Six]=6,[Enum.KeyCode.Seven]=7,[Enum.KeyCode.Eight]=8}
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local slot = NUM_KC[input.KeyCode]
    if slot then
        local prankName = PrankConfig.Order[slot]
        if not prankName then return end
        print("[HUDFix] HOTKEY " .. slot)
        local btn = prankCol and prankCol:FindFirstChild("Prank_" .. prankName)
        if btn and btn:GetAttribute("Locked") then return end
        firePrank(prankName)
    end
end)

-- ============ 7. CUSTOM HP / HUNGER / THIRST BARS (top-left stacked) ============
local barsContainer = Instance.new("Frame")
barsContainer.Name = "VitalsContainer"
barsContainer.Size = UDim2.new(0, 232, 0, 96)
-- v3.78: pushed further down + slightly right (12 -> 220 left offset)
-- so the vitals column doesn't sit directly under the Roblox top-left
-- icons (Roblox menu, hamburger, headphones). 130 -> 80 vertical so they
-- sit under the TopBar bottom edge cleanly.
barsContainer.Position = UDim2.new(0, 16, 0, 140)  -- v3.99.1: was y=80 hiding behind TopBar; now y=140 just below it
barsContainer.BackgroundTransparency = 1
barsContainer.ZIndex = 15
barsContainer.Parent = hud

local barLayout = Instance.new("UIListLayout", barsContainer)
barLayout.FillDirection = Enum.FillDirection.Vertical
barLayout.Padding = UDim.new(0, 4)
barLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function makeVital(name, color, layoutOrder, getValue)
    local row = Instance.new("Frame")
    row.Name = name .. "Bar"
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundColor3 = Color3.fromRGB(30, 18, 12)
    row.BorderSizePixel = 0
    row.LayoutOrder = layoutOrder
    row.ZIndex = 16
    row.Parent = barsContainer
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    local fill = Instance.new("Frame", row)
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = color
    fill.BorderSizePixel = 0
    fill.ZIndex = 17
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeTransparency = 0.3
    lbl.TextScaled = true
    lbl.ZIndex = 18
    return fill, lbl
end

local hpFill, hpLbl = makeVital("HP", Color3.fromRGB(220, 70, 60), 1)
local hungerFill, hungerLbl = makeVital("HUNGER", Color3.fromRGB(230, 140, 60), 2)
local thirstFill, thirstLbl = makeVital("THIRST", Color3.fromRGB(80, 160, 220), 3)

-- HP tracking
local function trackHealth(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    local function update()
        local h = math.max(0, hum.Health) / math.max(1, hum.MaxHealth)
        TweenService:Create(hpFill, TweenInfo.new(0.2), {Size = UDim2.new(h, 0, 1, 0)}):Play()
        hpLbl.Text = string.format("HP  %d/%d", math.floor(hum.Health), math.floor(hum.MaxHealth))
    end
    update()
    hum.HealthChanged:Connect(update)
end
if player.Character then trackHealth(player.Character) end
player.CharacterAdded:Connect(trackHealth)

-- Hunger/Thirst tracking via SurvivalUpdate remote (if exists)
if Remotes.SurvivalUpdate then
    Remotes.SurvivalUpdate.OnClientEvent:Connect(function(hunger, thirst)
        local h = math.clamp((hunger or 100) / 100, 0, 1)
        local th = math.clamp((thirst or 100) / 100, 0, 1)
        TweenService:Create(hungerFill, TweenInfo.new(0.2), {Size = UDim2.new(h, 0, 1, 0)}):Play()
        TweenService:Create(thirstFill, TweenInfo.new(0.2), {Size = UDim2.new(th, 0, 1, 0)}):Play()
        hungerLbl.Text = string.format("HUNGER  %d", math.floor(hunger or 0))
        thirstLbl.Text = string.format("THIRST  %d", math.floor(thirst or 0))
    end)
end

-- Hide the original SurvivalContainer to avoid duplicate bars
local oldSurv = hud:FindFirstChild("SurvivalContainer")
if oldSurv then oldSurv.Visible = false; print("[HUDFix] hid old SurvivalContainer") end

print("[HUDFix v3.69] DONE — destroyed SUMMON, hid BottomBar+ACH+PASS+duplicate currencies, moved skill bar down, added HP/HUNGER/THIRST bars")
