-- NpcReactions.server.lua
-- Adds variety to how NPCs behave around the player and react to nearby chaos:
--   * Civilians within 30 studs of a triggered prank PANIC and run away from
--     the prank epicenter for a few seconds.
--   * Some civilians (random 1 in 6) are "skittish" and flee from the player
--     whenever the player is within 14 studs.
--   * Speech bubbles (BillboardGui) over NPC heads when they react.
--
-- Place in: ServerScriptService > NpcReactions (Script). Auto-runs.

local Players   = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local PANIC_RADIUS = 30
local PANIC_DURATION = 4
local FLEE_SPEED = 22

local function bubble(npc, text)
    local head = npc:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then return end
    if head:FindFirstChild("ReactionBubble") then return end
    local g = Instance.new("BillboardGui")
    g.Name = "ReactionBubble"
    g.Size = UDim2.new(0, 110, 0, 30)
    g.StudsOffset = Vector3.new(0, 1.6, 0)
    g.AlwaysOnTop = true
    g.Parent = head
    local lbl = Instance.new("TextLabel", g)
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundColor3 = Color3.fromRGB(56, 40, 28)
    lbl.BackgroundTransparency = 0.2
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(255, 250, 240)
    lbl.TextStrokeTransparency = 0.4
    lbl.TextStrokeColor3 = Color3.fromRGB(40, 25, 15)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 8)
    local c = Instance.new("UITextSizeConstraint", lbl)
    c.MinTextSize = 12; c.MaxTextSize = 18
    task.delay(2.5, function() g:Destroy() end)
end

local function panicAway(npc, fromPos)
    local hum = npc:FindFirstChildOfClass("Humanoid")
    local hrp = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
    if not (hum and hrp) then return end
    if npc:GetAttribute("Pranked") then return end
    if npc:GetAttribute("Panicking") then return end

    npc:SetAttribute("Panicking", true)
    local prevSpeed = hum.WalkSpeed
    hum.WalkSpeed = FLEE_SPEED

    local dir = (hrp.Position - fromPos)
    if dir.Magnitude < 0.1 then
        dir = Vector3.new(math.random()-0.5, 0, math.random()-0.5)
    end
    dir = Vector3.new(dir.X, 0, dir.Z).Unit
    local dest = hrp.Position + dir * 60

    bubble(npc, "AAH!")
    hum:MoveTo(dest)

    task.delay(PANIC_DURATION, function()
        if npc.Parent and not npc:GetAttribute("Pranked") then
            hum.WalkSpeed = prevSpeed
            npc:SetAttribute("Panicking", false)
        end
    end)
end

-- =====================================================================
-- WHEN AN NPC GETS THE Pranked ATTRIBUTE, NEARBY NPCS PANIC
-- =====================================================================
local function onPrank(prankedNpc)
    local hrp = prankedNpc.PrimaryPart or prankedNpc:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local epicenter = hrp.Position
    -- Find nearby ambient/prank NPCs
    local crowd = Workspace:FindFirstChild("AmbientCrowd")
    if crowd then
        for _, npc in ipairs(crowd:GetChildren()) do
            if npc:IsA("Model") and npc ~= prankedNpc and npc.PrimaryPart then
                local d = (npc.PrimaryPart.Position - epicenter).Magnitude
                if d < PANIC_RADIUS then
                    task.spawn(panicAway, npc, epicenter)
                end
            end
        end
    end
    local prankNpcs = Workspace:FindFirstChild("PrankNPCs")
    if prankNpcs then
        for _, npc in ipairs(prankNpcs:GetChildren()) do
            if npc:IsA("Model") and npc ~= prankedNpc and npc.PrimaryPart then
                local d = (npc.PrimaryPart.Position - epicenter).Magnitude
                if d < PANIC_RADIUS then
                    task.spawn(panicAway, npc, epicenter)
                end
            end
        end
    end
end

local function watch(npc)
    if not npc:IsA("Model") then return end
    if not npc:GetAttribute("KittyRaiserNPC") then return end
    -- Mark some skittish NPCs (run from player when close)
    if math.random(1, 6) == 1 then
        npc:SetAttribute("Skittish", true)
    end
    npc:GetAttributeChangedSignal("Pranked"):Connect(function()
        if npc:GetAttribute("Pranked") then
            onPrank(npc)
        end
    end)
end

-- Watch existing + future NPCs
for _, folderName in ipairs({"AmbientCrowd", "PrankNPCs"}) do
    local f = Workspace:FindFirstChild(folderName)
    if f then
        for _, c in ipairs(f:GetChildren()) do watch(c) end
        f.ChildAdded:Connect(function(c) task.wait(0.1); watch(c) end)
    end
end
Workspace.ChildAdded:Connect(function(c)
    if c.Name == "AmbientCrowd" or c.Name == "PrankNPCs" then
        for _, n in ipairs(c:GetChildren()) do watch(n) end
        c.ChildAdded:Connect(function(n) task.wait(0.1); watch(n) end)
    end
end)

-- =====================================================================
-- SKITTISH NPCs flee when player approaches
-- =====================================================================
task.spawn(function()
    while true do
        task.wait(0.8)
        local players = Players:GetPlayers()
        for _, folderName in ipairs({"AmbientCrowd", "PrankNPCs"}) do
            local f = Workspace:FindFirstChild(folderName)
            if not f then continue end
            for _, npc in ipairs(f:GetChildren()) do
                if not (npc:IsA("Model") and npc:GetAttribute("Skittish") and npc.PrimaryPart) then continue end
                if npc:GetAttribute("Pranked") or npc:GetAttribute("Panicking") then continue end
                for _, p in ipairs(players) do
                    if p.Character and p.Character.PrimaryPart then
                        local d = (p.Character.PrimaryPart.Position - npc.PrimaryPart.Position).Magnitude
                        if d < 14 then
                            panicAway(npc, p.Character.PrimaryPart.Position)
                            break
                        end
                    end
                end
            end
        end
    end
end)

print("[NpcReactions v1] online — civilians panic on nearby pranks; skittish NPCs flee")
