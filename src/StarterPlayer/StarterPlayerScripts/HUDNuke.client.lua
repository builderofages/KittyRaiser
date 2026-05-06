-- HUDNuke.client.lua  v3.99.3
-- Brute-force HUD cleanup that runs every Heartbeat. No name guessing.
-- Hides duplicates, force-shows vitals, kills nameplates, dedupes prompts.
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local Workspace     = game:GetService("Workspace")
local TweenService  = game:GetService("TweenService")
local player        = Players.LocalPlayer
local playerGui     = player:WaitForChild("PlayerGui")

-- ===== 1. Build always-on-top HP/HUNGER/THIRST bars at ZIndex 9999 =====
local hud = playerGui:WaitForChild("MainHUD", 30)
if not hud then return end

local nukeContainer = Instance.new("Frame")
nukeContainer.Name = "HUDNuke_Vitals"
nukeContainer.Size = UDim2.new(0, 220, 0, 96)
nukeContainer.Position = UDim2.new(0, 16, 0, 160)
nukeContainer.BackgroundTransparency = 1
nukeContainer.ZIndex = 9999
nukeContainer.Parent = hud

local layout = Instance.new("UIListLayout", nukeContainer)
layout.FillDirection = Enum.FillDirection.Vertical
layout.Padding = UDim.new(0, 4)

local function makeBar(name, color, order)
    local row = Instance.new("Frame", nukeContainer)
    row.Name = name
    row.Size = UDim2.new(1, 0, 0, 26)
    row.BackgroundColor3 = Color3.fromRGB(20, 14, 10)
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.ZIndex = 9999
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
    local fill = Instance.new("Frame", row)
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = color
    fill.BorderSizePixel = 0
    fill.ZIndex = 10000
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeTransparency = 0.2
    lbl.TextScaled = true
    lbl.ZIndex = 10001
    return fill, lbl
end

local hpFill, hpLbl     = makeBar("HP",     Color3.fromRGB(220, 70, 60), 1)
local hungerFill, hLbl  = makeBar("HUNGER", Color3.fromRGB(230, 140, 60), 2)
local thirstFill, tLbl  = makeBar("THIRST", Color3.fromRGB(80, 160, 220), 3)

local function trackHealth(char)
    local hum = char:WaitForChild("Humanoid", 5); if not hum then return end
    local function update()
        local r = math.max(0, hum.Health) / math.max(1, hum.MaxHealth)
        TweenService:Create(hpFill, TweenInfo.new(0.2), {Size = UDim2.new(r, 0, 1, 0)}):Play()
        hpLbl.Text = string.format("HP  %d/%d", hum.Health, hum.MaxHealth)
    end
    update()
    hum.HealthChanged:Connect(update)
end
if player.Character then trackHealth(player.Character) end
player.CharacterAdded:Connect(trackHealth)

-- ===== 2. Heartbeat sweep: hide left+center TopBar children, kill nameplates, dedupe prompts =====
local TOP_BAR_KEEP_NAME_HINTS = {"level", "xp", "rebirth"}  -- keep level + rebirth
local nameplatesKilled = {}  -- humanoid -> true
local promptsClipped = {}    -- BillboardGui -> true

RunService.Heartbeat:Connect(function()
    -- A) TopBar duplicate currency hide
    local topBar = hud:FindFirstChild("TopBar")
    if topBar then
        for _, c in ipairs(topBar:GetChildren()) do
            if c:IsA("GuiObject") then
                local lname = c.Name:lower()
                local keep = false
                for _, hint in ipairs(TOP_BAR_KEEP_NAME_HINTS) do
                    if lname:find(hint) then keep = true; break end
                end
                -- Right-side anchored = primary count, keep
                if c.Position.X.Scale > 0.5 or c.AnchorPoint.X > 0.5 then keep = true end
                -- Hide left+center currency wraps
                if not keep and (lname:find("chaos") or lname:find("hell") or lname:find("wrap") or lname:find("coin") or lname:find("gem")) then
                    c.Visible = false
                end
            end
        end
    end

    -- B) Force-disable Roblox auto-nameplate on every player character
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and not nameplatesKilled[hum] then
                hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
                hum.NameDisplayDistance = 0
                hum.HealthDisplayDistance = 0
                nameplatesKilled[hum] = true
            end
        end
    end

    -- C) BillboardGui prompt dedupe — clamp MaxDistance on every world BillboardGui
    for _, bb in ipairs(Workspace:GetDescendants()) do
        if bb:IsA("BillboardGui") and not promptsClipped[bb] then
            if bb.MaxDistance == 0 or bb.MaxDistance > 18 then
                bb.MaxDistance = 12
            end
            promptsClipped[bb] = true
        end
    end
end)

print("[HUDNuke v3.99.3] online — vitals top-left ZIndex 9999, currency dedupe, nameplate kill, prompt dedupe")
-- ===== 3. PrankFailed listener — show why prank rejected =====
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("RemoteEvents"))
if Remotes and Remotes.PrankFailed then
    Remotes.PrankFailed.OnClientEvent:Connect(function(reason)
        warn("[HUDNuke] prank rejected: " .. tostring(reason))
        -- Show a toast at top-center
        local toast = Instance.new("TextLabel")
        toast.Name = "PrankFailToast"
        toast.Size = UDim2.new(0, 280, 0, 40)
        toast.AnchorPoint = Vector2.new(0.5, 0)
        toast.Position = UDim2.new(0.5, 0, 0, 200)
        toast.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
        toast.BackgroundTransparency = 0.1
        toast.Text = "PRANK FAILED: " .. tostring(reason)
        toast.Font = Enum.Font.GothamBlack
        toast.TextColor3 = Color3.fromRGB(255, 255, 255)
        toast.TextScaled = true
        toast.ZIndex = 99999
        Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 8)
        toast.Parent = hud
        task.delay(2.5, function() toast:Destroy() end)
    end)
    print("[HUDNuke] PrankFailed listener wired")
end

