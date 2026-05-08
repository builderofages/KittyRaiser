-- HUDNuke v3.99.10
print("========== HUDNuke v3.99.10 DEFINITIVELY LOADED ==========")
warn("HUDNuke v3.99.10 entered — if you see this, client scripts run")
-- HUDNuke.client.lua  v3.99.8 (destroy-not-hide + verbose)
local Players, RunService, Workspace, TweenService, UIS, RS = game:GetService("Players"), game:GetService("RunService"), game:GetService("Workspace"), game:GetService("TweenService"), game:GetService("UserInputService"), game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
print("[HUDNuke v3.99.8] script entered")

local ok, err = pcall(function()
    local playerGui = player:WaitForChild("PlayerGui")
    local hud = playerGui:WaitForChild("MainHUD", 60)
    if not hud then warn("[HUDNuke] MainHUD never appeared"); return end
    print("[HUDNuke] MainHUD found, applying takeover")

    local Remotes, PrankConfig
    pcall(function() Remotes = require(RS:WaitForChild("Modules"):WaitForChild("RemoteEvents")) end)
    pcall(function() PrankConfig = require(RS.Modules.PrankConfig) end)

    -- 1. KILL BottomBar PERMANENTLY (destroy, not hide)
    local function killBB()
        local bb = hud:FindFirstChild("BottomBar")
        if bb then
            -- Reparent INV/TOP/REBIRTH/SHOP children to small chips in hud first
            local CHIPS = {
                {n="InventoryButton",   lbl="INV", y=460, color=Color3.fromRGB(160,110,60)},
                {n="LeaderboardButton", lbl="TOP", y=500, color=Color3.fromRGB(60,120,180)},
                {n="RebirthButton",     lbl="RBT", y=540, color=Color3.fromRGB(220,140,50)},
                {n="ShopButton",        lbl="SHP", y=580, color=Color3.fromRGB(80,170,80)},
            }
            for _, info in ipairs(CHIPS) do
                local existing = hud:FindFirstChild("NukeChip_"..info.lbl)
                if not existing then
                    local origBtn = bb:FindFirstChild(info.n)
                    if origBtn and origBtn:IsA("GuiObject") then
                        local b = Instance.new("TextButton", hud)
                        b.Name = "NukeChip_"..info.lbl
                        b.AnchorPoint = Vector2.new(1, 0)
                        b.Position = UDim2.new(1, -16, 0, info.y)
                        b.Size = UDim2.new(0, 76, 0, 32)
                        b.BackgroundColor3 = info.color
                        b.Text = info.lbl
                        b.Font = Enum.Font.GothamBlack
                        b.TextColor3 = Color3.fromRGB(255,250,240)
                        b.TextScaled = true
                        b.ZIndex = 99999
                        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
                        local origConnect = origBtn.MouseButton1Click
                        b.MouseButton1Click:Connect(function()
                            -- Forward click to original (preserves existing modal handlers)
                            origBtn.Visible = true
                            for _, sig in ipairs({origBtn.MouseButton1Click}) do
                                sig:Wait(0)  -- not great
                            end
                        end)
                        -- Better: just open the matching modal directly
                        local modalNames = {InventoryButton="InventoryModal", LeaderboardButton="LeaderboardModal", RebirthButton="RebirthModal", ShopButton="ShopModal"}
                        b.MouseButton1Click:Connect(function()
                            local m = hud:FindFirstChild(modalNames[info.n])
                            if m then m.Visible = not m.Visible; print("[HUDNuke] toggled " .. modalNames[info.n]) end
                        end)
                    end
                end
            end
            bb:Destroy()
            print("[HUDNuke] BottomBar DESTROYED + chips relocated")
        end
    end
    pcall(killBB)
    -- Run again on character respawn in case BottomBar gets recreated
    player.CharacterAdded:Connect(function() task.wait(2); pcall(killBB) end)

    -- 2. Vitals top-left at ZIndex 99999
    local vitals = Instance.new("Frame", hud)
    vitals.Size = UDim2.new(0, 220, 0, 96); vitals.Position = UDim2.new(0, 16, 0, 160); vitals.BackgroundTransparency = 1; vitals.ZIndex = 99999
    local vL = Instance.new("UIListLayout", vitals); vL.Padding = UDim.new(0, 4)
    local function bar(name, color, order)
        local row = Instance.new("Frame", vitals); row.Size = UDim2.new(1,0,0,26); row.BackgroundColor3 = Color3.fromRGB(20,14,10); row.LayoutOrder = order; row.ZIndex = 99999
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
        local f = Instance.new("Frame", row); f.Size = UDim2.new(1,0,1,0); f.BackgroundColor3 = color; f.ZIndex = 100000
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
        local l = Instance.new("TextLabel", row); l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1; l.Text = name; l.Font = Enum.Font.GothamBlack; l.TextColor3 = Color3.new(1,1,1); l.TextScaled = true; l.ZIndex = 100001
        return f, l
    end
    local hpF, hpL = bar("HP",     Color3.fromRGB(220,70,60), 1)
    local hgF      = bar("HUNGER", Color3.fromRGB(230,140,60), 2)
    local thF      = bar("THIRST", Color3.fromRGB(80,160,220), 3)
    local function trackHealth(char)
        local h = char:WaitForChild("Humanoid", 5); if not h then return end
        h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        h.NameDisplayDistance = 0; h.HealthDisplayDistance = 0
        local function u()
            local r = math.max(0, h.Health) / math.max(1, h.MaxHealth)
            TweenService:Create(hpF, TweenInfo.new(0.2), {Size = UDim2.new(r,0,1,0)}):Play()
            hpL.Text = string.format("HP  %d/%d", h.Health, h.MaxHealth)
        end
        u(); h.HealthChanged:Connect(u)
    end
    if player.Character then trackHealth(player.Character) end
    player.CharacterAdded:Connect(trackHealth)
    print("[HUDNuke] vitals built")

    -- 3. Hide left+center currency in TopBar
    local function pruneCurrency()
        local tb = hud:FindFirstChild("TopBar")
        if not tb then return end
        for _, c in ipairs(tb:GetChildren()) do
            if c:IsA("GuiObject") then
                local lname = c.Name:lower()
                local rightSide = c.Position.X.Scale > 0.5 or c.AnchorPoint.X > 0.5
                local isCurrency = lname:find("chaos") or lname:find("hell") or lname:find("wrap") or lname:find("coin") or lname:find("gem")
                if isCurrency and not rightSide then
                    c.Visible = false
                end
            end
        end
    end
    pruneCurrency()
    RunService.Heartbeat:Connect(pruneCurrency)
    print("[HUDNuke] currency prune wired")

    -- 4. PrankFailed listener with red toast
    if Remotes and Remotes.PrankFailed then
        Remotes.PrankFailed.OnClientEvent:Connect(function(reason)
            warn("[HUDNuke] PRANK FAILED: " .. tostring(reason))
            local toast = Instance.new("TextLabel", hud)
            toast.Size = UDim2.new(0, 320, 0, 44); toast.AnchorPoint = Vector2.new(0.5, 0); toast.Position = UDim2.new(0.5, 0, 0, 200)
            toast.BackgroundColor3 = Color3.fromRGB(220, 60, 60); toast.Text = "PRANK FAILED: " .. tostring(reason)
            toast.Font = Enum.Font.GothamBlack; toast.TextColor3 = Color3.fromRGB(255,255,255); toast.TextScaled = true; toast.ZIndex = 99999
            Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 8)
            task.delay(3, function() if toast and toast.Parent then toast:Destroy() end end)
        end)
        print("[HUDNuke] PrankFailed listener wired")
    end

    -- 5. Direct keypress 1-8 prank fire fallback
    if PrankConfig and Remotes then
        local function nearestNPC(maxR)
            local ch = player.Character; if not ch then return end
            local hrp = ch:FindFirstChild("HumanoidRootPart"); if not hrp then return end
            local closest, dist = nil, math.huge
            for _, folder in ipairs({Workspace:FindFirstChild("PrankNPCs"), Workspace:FindFirstChild("AmbientCrowd")}) do
                if folder then
                    for _, m in ipairs(folder:GetChildren()) do
                        if m:IsA("Model") and (m:GetAttribute("KittyRaiserNPC") or m:GetAttribute("AmbientNPC")) and not m:GetAttribute("Pranked") then
                            local p = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
                            if p then
                                local d = (p.Position - hrp.Position).Magnitude
                                if d < dist and d < maxR then dist = d; closest = m end
                            end
                        end
                    end
                end
            end
            return closest
        end
        local NUM_KC = {[Enum.KeyCode.One]=1,[Enum.KeyCode.Two]=2,[Enum.KeyCode.Three]=3,[Enum.KeyCode.Four]=4,[Enum.KeyCode.Five]=5,[Enum.KeyCode.Six]=6,[Enum.KeyCode.Seven]=7,[Enum.KeyCode.Eight]=8}
        UIS.InputBegan:Connect(function(input, gp)
            if gp then return end
            local slot = NUM_KC[input.KeyCode]
            if not slot then return end
            local prankName = PrankConfig.Order[slot]
            if not prankName then return end
            print("[HUDNuke] HOTKEY " .. slot .. " -> " .. prankName)
            local prank = PrankConfig.Pranks[prankName]
            local npc = nearestNPC((prank.rangeStuds or 24) * 3)
            if npc then
                Remotes.RequestPrank:FireServer(prankName, npc)
                print("[HUDNuke]   fired prank on " .. npc.Name)
            else
                print("[HUDNuke]   no NPC; summoning")
                Remotes.RequestSummonHuman:FireServer()
            end
        end)
        print("[HUDNuke] hotkey 1-8 fallback wired")
    end

    print("[HUDNuke v3.99.8] online — full takeover applied")
end)
if not ok then warn("[HUDNuke] script error: " .. tostring(err)) end
