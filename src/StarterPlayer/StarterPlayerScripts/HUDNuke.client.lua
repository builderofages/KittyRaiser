-- HUDNuke.client.lua  v3.99.6 (hardened total takeover)
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local Workspace     = game:GetService("Workspace")
local TweenService  = game:GetService("TweenService")
local UIS           = game:GetService("UserInputService")
local RS            = game:GetService("ReplicatedStorage")
local player        = Players.LocalPlayer
local playerGui     = player:WaitForChild("PlayerGui")
local hud           = playerGui:WaitForChild("MainHUD", 30)
if not hud then return end

print("[HUDNuke v3.99.6] starting")
local Remotes = require(RS:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local PrankConfig = require(RS:WaitForChild("Modules"):WaitForChild("PrankConfig"))

-- ===== PrankFailed listener with red toast =====
if Remotes.PrankFailed then
    Remotes.PrankFailed.OnClientEvent:Connect(function(reason)
        warn("[HUDNuke] PRANK FAILED: " .. tostring(reason))
        local toast = Instance.new("TextLabel")
        toast.Size = UDim2.new(0, 320, 0, 44)
        toast.AnchorPoint = Vector2.new(0.5, 0)
        toast.Position = UDim2.new(0.5, 0, 0, 200)
        toast.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
        toast.Text = "PRANK FAILED: " .. tostring(reason)
        toast.Font = Enum.Font.GothamBlack
        toast.TextColor3 = Color3.fromRGB(255, 255, 255)
        toast.TextScaled = true
        toast.ZIndex = 99999
        Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 8)
        toast.Parent = hud
        task.delay(3, function() toast:Destroy() end)
    end)
end

-- ===== Vitals at ZIndex 99999 =====
local vitals = Instance.new("Frame", hud)
vitals.Name = "NukeVitals"
vitals.Size = UDim2.new(0, 220, 0, 96)
vitals.Position = UDim2.new(0, 16, 0, 160)
vitals.BackgroundTransparency = 1
vitals.ZIndex = 99999
local vL = Instance.new("UIListLayout", vitals); vL.Padding = UDim.new(0, 4)
local function bar(name, color, order)
    local row = Instance.new("Frame", vitals)
    row.Size = UDim2.new(1, 0, 0, 26); row.BackgroundColor3 = Color3.fromRGB(20,14,10); row.BorderSizePixel = 0; row.LayoutOrder = order; row.ZIndex = 99999
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    local f = Instance.new("Frame", row); f.Size = UDim2.new(1,0,1,0); f.BackgroundColor3 = color; f.BorderSizePixel = 0; f.ZIndex = 100000
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local l = Instance.new("TextLabel", row); l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1; l.Text = name; l.Font = Enum.Font.GothamBlack; l.TextColor3 = Color3.new(1,1,1); l.TextStrokeTransparency = 0.2; l.TextScaled = true; l.ZIndex = 100001
    return f, l
end
local hpF, hpL = bar("HP",     Color3.fromRGB(220,70,60), 1)
local hgF, hgL = bar("HUNGER", Color3.fromRGB(230,140,60), 2)
local thF, thL = bar("THIRST", Color3.fromRGB(80,160,220), 3)

local function trackHealth(char)
    local h = char:WaitForChild("Humanoid", 5); if not h then return end
    local function u()
        local r = math.max(0, h.Health) / math.max(1, h.MaxHealth)
        TweenService:Create(hpF, TweenInfo.new(0.2), {Size = UDim2.new(r,0,1,0)}):Play()
        hpL.Text = string.format("HP  %d/%d", h.Health, h.MaxHealth)
    end
    u(); h.HealthChanged:Connect(u)
end
if player.Character then trackHealth(player.Character) end
player.CharacterAdded:Connect(trackHealth)

-- ===== Build OUR OWN top-right chip stack — independent of any other script =====
local CHIPS = {
    {n="ACHIEVEMENTS", lbl="ACH", y=290, color=Color3.fromRGB(160,110,60), modal="AchievementsModal"},
    {n="BATTLEPASS",   lbl="PASS", y=330, color=Color3.fromRGB(220,140,50), modal="BattlePassModal"},
    {n="CLAN",         lbl="CLAN", y=370, color=Color3.fromRGB(140,90,200), modal="ClanModal"},
    {n="HOME",         lbl="HOME", y=410, color=Color3.fromRGB(180,130,80), modal="HomeModal"},
    {n="INV",          lbl="INV",  y=460, color=Color3.fromRGB(160,110,60), modal="InventoryModal"},
    {n="TOP",          lbl="TOP",  y=500, color=Color3.fromRGB(60,120,180), modal="LeaderboardModal"},
    {n="RBT",          lbl="RBT",  y=540, color=Color3.fromRGB(220,140,50), modal="RebirthModal"},
    {n="SHP",          lbl="SHP",  y=580, color=Color3.fromRGB(80,170,80),  modal="ShopModal"},
}
-- Note: ACH/PASS/CLAN/HOME already created by their own panels; we leave those alone.
-- We only build the missing INV/TOP/RBT/SHP chips and HIDE the BottomBar.

local function makeChip(info)
    if hud:FindFirstChild("NukeChip_"..info.lbl) then return end
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
    b.MouseButton1Click:Connect(function()
        warn("[HUDNuke] chip clicked: " .. info.lbl)
        -- Try to open matching modal that was built by HUDBuilder
        local modal = hud:FindFirstChild(info.modal)
        if modal and modal:IsA("Frame") then
            modal.Visible = not modal.Visible
        else
            print("[HUDNuke] no modal named " .. info.modal)
        end
    end)
end
makeChip(CHIPS[5]); makeChip(CHIPS[6]); makeChip(CHIPS[7]); makeChip(CHIPS[8])

-- ===== Heartbeat sweep =====
local nameKilled = {}
local bbClipped = {}
RunService.Heartbeat:Connect(function()
    -- Hide BottomBar entirely — we have our own chips
    local bb = hud:FindFirstChild("BottomBar")
    if bb then bb.Visible = false end
    -- Also kill SummonButton if it ever spawns
    local sb = hud:FindFirstChild("SummonButton")
    if sb then sb:Destroy() end
    -- Hide left/center currency wraps in TopBar
    local tb = hud:FindFirstChild("TopBar")
    if tb then
        for _, c in ipairs(tb:GetChildren()) do
            if c:IsA("GuiObject") then
                local lname = c.Name:lower()
                local rightSide = c.Position.X.Scale > 0.5 or c.AnchorPoint.X > 0.5
                local isCurrency = lname:find("chaos") or lname:find("hell") or lname:find("wrap") or lname:find("coin") or lname:find("gem")
                if isCurrency and not rightSide then c.Visible = false end
            end
        end
    end
    -- Force-disable Roblox auto-nameplate on every player Humanoid
    for _, p in ipairs(Players:GetPlayers()) do
        local ch = p.Character
        if ch then
            local h = ch:FindFirstChildOfClass("Humanoid")
            if h and not nameKilled[h] then
                h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                h.NameDisplayDistance = 0
                h.HealthDisplayDistance = 0
                nameKilled[h] = true
            end
        end
    end
    -- Clamp every world BillboardGui to MaxDistance so duplicate prompts don't show
    for _, b2 in ipairs(Workspace:GetDescendants()) do
        if b2:IsA("BillboardGui") and not bbClipped[b2] then
            if b2.MaxDistance == 0 or b2.MaxDistance > 18 then
                b2.MaxDistance = 12
            end
            bbClipped[b2] = true
        end
    end
end)

-- ===== Direct keypress 1-8 fallback for prank slots =====
-- If HUDFix click handlers fail, this catches the keystroke independently.
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

local NUM_KC = {[Enum.KeyCode.One]=1, [Enum.KeyCode.Two]=2, [Enum.KeyCode.Three]=3, [Enum.KeyCode.Four]=4,
                [Enum.KeyCode.Five]=5, [Enum.KeyCode.Six]=6, [Enum.KeyCode.Seven]=7, [Enum.KeyCode.Eight]=8}
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    local slot = NUM_KC[input.KeyCode]
    if not slot then return end
    local prankName = PrankConfig.Order[slot]
    if not prankName then return end
    print("[HUDNuke] HOTKEY " .. slot .. " -> " .. prankName)
    local prank = PrankConfig.Pranks[prankName]
    if not prank then return end
    local npc = nearestNPC((prank.rangeStuds or 24) * 3)
    if npc then
        Remotes.RequestPrank:FireServer(prankName, npc)
        print("[HUDNuke]   fired prank on " .. npc.Name)
    else
        print("[HUDNuke]   no NPC in range")
        Remotes.RequestSummonHuman:FireServer()
    end
end)

print("[HUDNuke v3.99.6] online — chips, vitals, prank-fallback, dedupe all active")
