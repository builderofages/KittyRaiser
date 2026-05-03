-- RagdollOnPrank.server.lua
-- When a registered NPC's Pranked attribute flips, ragdoll it + add knockback +
-- spawn coin loot. Place in ServerScriptService.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local function ragdoll(npc, fromPos)
    if not npc or not npc.Parent then return end
    local hum = npc:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.PlatformStand = true
        hum.WalkSpeed = 0
    end
    for _, p in ipairs(npc:GetDescendants()) do
        if p:IsA("BasePart") and not p.Anchored then
            local diff = p.Position - fromPos
            local dir
            if diff.Magnitude < 1e-3 then
                dir = Vector3.new(0, 1, 0)
            else
                dir = diff.Unit
            end
            p.AssemblyLinearVelocity = dir * 60 + Vector3.new(0, 40, 0)
            p.AssemblyAngularVelocity = Vector3.new(
                math.random() * 8 - 4,
                math.random() * 8 - 4,
                math.random() * 8 - 4
            )
        end
    end
    Debris:AddItem(npc, 3)
end

local function spawnCoinLoot(pos, count)
    for _ = 1, count do
        local c = Instance.new("Part")
        c.Shape = Enum.PartType.Cylinder
        c.Size = Vector3.new(0.4, 1.2, 1.2)
        c.Material = Enum.Material.Neon
        c.Color = Color3.fromRGB(255, 215, 0)
        c.CFrame = CFrame.new(
            pos + Vector3.new(math.random()*4-2, 4 + math.random()*2, math.random()*4-2)
        ) * CFrame.Angles(0, 0, math.rad(90))
        c.AssemblyLinearVelocity = Vector3.new(
            (math.random()-0.5)*30,
            math.random()*20+10,
            (math.random()-0.5)*30
        )
        c.CanCollide = true   -- coins now bounce on the ground instead of sinking
        c.Parent = Workspace
        Debris:AddItem(c, 4)
    end
end

local function spawnChaosNumber(pos, amount)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Size = Vector3.new(1, 1, 1)
    part.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
    part.Parent = Workspace
    local g = Instance.new("BillboardGui")
    g.Size = UDim2.new(0, 200, 0, 80)
    g.AlwaysOnTop = true
    g.Parent = part
    local l = Instance.new("TextLabel")
    l.Size = UDim2.fromScale(1, 1)
    l.BackgroundTransparency = 1
    l.Text = "+" .. amount
    l.Font = Enum.Font.GothamBlack
    l.TextScaled = true
    l.TextSize = 36
    l.TextColor3 = Color3.fromRGB(0, 255, 100)
    l.TextStrokeTransparency = 0
    l.TextStrokeColor3 = Color3.new(0, 0, 0)
    l.Parent = g
    task.spawn(function()
        for i = 1, 30 do
            if not part.Parent then return end
            part.CFrame = part.CFrame + Vector3.new(0, 0.15, 0)
            l.TextTransparency = i/30
            l.TextStrokeTransparency = i/30 * 0.7
            task.wait(0.05)
        end
        if part.Parent then part:Destroy() end
    end)
end

-- Listen on the dedicated PrankNPCs / AmbientCrowd folders only (was hooked
-- on Workspace.DescendantAdded which fired for terrain, particle effects, etc.)
local NPC_FOLDERS = {"PrankNPCs", "AmbientCrowd"}

local function watchNpc(npc)
    if not npc:IsA("Model") then return end
    if not npc:GetAttribute("KittyRaiserNPC") then return end
    npc:GetAttributeChangedSignal("Pranked"):Connect(function()
        if not npc:GetAttribute("Pranked") then return end
        local prim = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
        if not prim then return end
        local pos = prim.Position
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
end

for _, folderName in ipairs(NPC_FOLDERS) do
    local folder = Workspace:FindFirstChild(folderName)
    if folder then
        for _, child in ipairs(folder:GetChildren()) do watchNpc(child) end
        folder.ChildAdded:Connect(watchNpc)
    end
end

-- If the folders are created later, attach when they appear.
Workspace.ChildAdded:Connect(function(child)
    if not child:IsA("Folder") then return end
    if not table.find(NPC_FOLDERS, child.Name) then return end
    for _, c in ipairs(child:GetChildren()) do watchNpc(c) end
    child.ChildAdded:Connect(watchNpc)
end)

print("[RagdollOnPrank] ready - NPCs ragdoll + drop coins on prank")
