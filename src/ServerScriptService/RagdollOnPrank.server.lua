-- RagdollOnPrank.server.lua
-- When PrankRegistered fires, ragdoll the target NPC + add knockback + spawn coin loot
-- so each prank feels satisfying and rewarding. Place in ServerScriptService.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local AssetIds = require(ReplicatedStorage.Modules.AssetIds)

local function ragdoll(npc, fromPos)
    if not npc or not npc.Parent then return end
    local hum = npc:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = true
        hum.WalkSpeed = 0
    end
    -- Apply knockback to all parts
    for _, p in ipairs(npc:GetDescendants()) do
        if p:IsA("BasePart") then
            local dir = (p.Position - fromPos).Unit
            if dir.Magnitude == math.huge or dir ~= dir then
                dir = Vector3.new(0, 1, 0)
            end
            p.AssemblyLinearVelocity = dir * 60 + Vector3.new(0, 40, 0)
            p.AssemblyAngularVelocity = Vector3.new(math.random()*8, math.random()*8, math.random()*8)
        end
    end
    -- Despawn after 3 seconds
    Debris:AddItem(npc, 3)
end

local AudioGroups
do
    local m = ReplicatedStorage.Modules:WaitForChild("AudioGroups", 5)
    if m then local ok, mod = pcall(require, m); if ok then AudioGroups = mod end end
end

local function spawnCoinLoot(pos, count)
    -- One coin pickup chime per cluster (not per coin — would be deafening).
    if AssetIds.has("coin_pickup") then
        local s = Instance.new("Sound")
        s.SoundId = AssetIds.coin_pickup
        s.Volume = 0.7
        if AudioGroups then AudioGroups.assign(s, "SFX") end
        local p = Instance.new("Part")
        p.Anchored = true; p.CanCollide = false; p.Transparency = 1
        p.Size = Vector3.new(0.1, 0.1, 0.1); p.Position = pos
        p.Parent = Workspace
        s.Parent = p
        s:Play()
        Debris:AddItem(p, 3)
    end
    for i = 1, count do
        -- Cylinder long-axis is X; rotating 90° around Z makes it stand vertically
        -- with flat faces front/back — that's our "coin face the camera" look.
        local c = Instance.new("Part")
        c.Shape = Enum.PartType.Cylinder
        c.Size = Vector3.new(0.18, 1.0, 1.0)  -- thin disc, 1 stud diameter
        c.Material = Enum.Material.Neon
        c.Color = Color3.fromRGB(255, 215, 0)
        c.Reflectance = 0.15
        c.CanCollide = false
        c.CFrame = CFrame.new(pos + Vector3.new(math.random()*4-2, 4, math.random()*4-2))
            * CFrame.Angles(0, 0, math.rad(90))
        c.AssemblyLinearVelocity = Vector3.new((math.random()-0.5)*22, math.random()*16+12, (math.random()-0.5)*22)
        -- Spin around Y axis (vertical) so the coin tumbles like a real coin
        c.AssemblyAngularVelocity = Vector3.new(0, math.random(8, 14), 0)
        c.Parent = Workspace

        -- Outline — second cylinder slightly larger and dark
        local outline = Instance.new("Part")
        outline.Shape = Enum.PartType.Cylinder
        outline.Size = Vector3.new(0.16, 1.05, 1.05)
        outline.Material = Enum.Material.SmoothPlastic
        outline.Color = Color3.fromRGB(180, 130, 0)
        outline.CanCollide = false
        outline.Massless = true
        outline.CFrame = c.CFrame
        outline.Parent = Workspace
        local w = Instance.new("WeldConstraint"); w.Part0 = c; w.Part1 = outline; w.Parent = outline

        -- Glow trail for shine
        local light = Instance.new("PointLight", c)
        light.Color = Color3.fromRGB(255, 230, 130)
        light.Range = 6; light.Brightness = 1.5

        Debris:AddItem(c, 4)
        Debris:AddItem(outline, 4)
    end
end

local function spawnChaosNumber(pos, amount)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Size = Vector3.new(1, 1, 1)
    part.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))  -- closer to head
    part.Parent = Workspace
    local g = Instance.new("BillboardGui")
    g.Size = UDim2.new(0, 180, 0, 60)
    g.AlwaysOnTop = true
    g.Parent = part
    -- Coin icon on the left, +amount text on the right
    if AssetIds.has("coin") then
        local ic = Instance.new("ImageLabel", g)
        ic.Size = UDim2.new(0, 40, 0, 40)
        ic.Position = UDim2.new(0, 4, 0.5, -20)
        ic.BackgroundTransparency = 1
        ic.Image = AssetIds.coin
    end
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -50, 1, 0)
    l.Position = UDim2.new(0, 50, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = "+" .. amount
    l.Font = Enum.Font.GothamBlack
    l.TextScaled = true
    l.TextColor3 = Color3.fromRGB(255, 220, 80)
    l.TextStrokeTransparency = 0
    l.TextStrokeColor3 = Color3.new(0, 0, 0)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = g
    local c = Instance.new("UITextSizeConstraint", l)
    c.MinTextSize = 14; c.MaxTextSize = 32
    -- Float up + fade
    task.spawn(function()
        for i = 1, 30 do
            part.CFrame = part.CFrame + Vector3.new(0, 0.15, 0)
            l.TextTransparency = i/30
            l.TextStrokeTransparency = i/30 * 0.7
            task.wait(0.05)
        end
        part:Destroy()
    end)
end

Remotes.PrankRegistered.OnServerEvent:Connect(function() end) -- safety

-- We hook server-side too: when a prank is registered, server fires PrankRegistered to client.
-- Add a separate hook here that listens to PrankSystem broadcast attribute. Simpler:
-- Listen for any NPC getting Pranked attribute set to true.

Workspace.DescendantAdded:Connect(function(npc)
    if not npc:IsA("Model") or not npc:GetAttribute("KittyRaiserNPC") then return end
    npc:GetAttributeChangedSignal("Pranked"):Connect(function()
        if not npc:GetAttribute("Pranked") then return end
        local prim = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
        if not prim then return end
        local pos = prim.Position
        -- Pick a random "pranker" position offset for knockback direction
        local closestPlayerPos = pos + Vector3.new(0, 0, 5)
        local closestDist = math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character and p.Character.PrimaryPart then
                local d = (p.Character.PrimaryPart.Position - pos).Magnitude
                if d < closestDist then
                    closestDist = d
                    closestPlayerPos = p.Character.PrimaryPart.Position
                end
            end
        end
        ragdoll(npc, closestPlayerPos)
        spawnCoinLoot(pos, math.random(3, 6))
        spawnChaosNumber(pos, math.random(20, 80))
    end)
end)

print("[RagdollOnPrank] ready - NPCs ragdoll + drop coins on prank")
