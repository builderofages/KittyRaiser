-- AmbientCrowd.server.lua v4 — single-manager, 12-15 visible NPCs, distance-based
-- Place in: ServerScriptService > AmbientCrowd. Auto-runs.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TARGET_VISIBLE = 14
local NEAR_RADIUS = 80
local FAR_RADIUS = 200
local DESPAWN_RADIUS = 350
local TICK_INTERVAL = 4
local SPAWN_MIN_SPACING = 8

local crowdFolder = Workspace:FindFirstChild("AmbientCrowd")
if not crowdFolder then
    crowdFolder = Instance.new("Folder")
    crowdFolder.Name = "AmbientCrowd"
    crowdFolder.Parent = Workspace
end

local SHIRT = {
    Color3.fromRGB(200,50,50),Color3.fromRGB(60,130,200),Color3.fromRGB(80,200,90),
    Color3.fromRGB(220,200,80),Color3.fromRGB(180,80,200),Color3.fromRGB(60,60,80),
    Color3.fromRGB(240,240,240),Color3.fromRGB(220,130,60),Color3.fromRGB(255,80,130),
    Color3.fromRGB(50,50,50),
}
local SKIN = {
    Color3.fromRGB(245,205,160),Color3.fromRGB(200,165,130),Color3.fromRGB(160,110,80),
    Color3.fromRGB(120,80,55),Color3.fromRGB(95,65,45),Color3.fromRGB(80,50,35),
}
local LEG = {
    Color3.fromRGB(40,40,80),Color3.fromRGB(80,50,30),Color3.fromRGB(50,50,50),
    Color3.fromRGB(100,100,110),Color3.fromRGB(60,80,50),
}

local function buildPed()
    local m = Instance.new("Model")
    m.Name = "Pedestrian"
    m:SetAttribute("KittyRaiserNPC", true)
    m:SetAttribute("Pranked", false)
    m:SetAttribute("AmbientNPC", true)
    m:SetAttribute("LastWanderTime", os.clock())

    local size = math.random() < 0.2 and 0.7 or 1.0

    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2*size, 2*size, 1*size)
    hrp.Transparency = 1
    hrp.CanCollide = true     -- HRP must collide for humanoid physics to work
    hrp.Massless = true
    hrp.Parent = m

    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2*size, 2*size, 1*size)
    torso.Color = SHIRT[math.random(1, #SHIRT)]
    torso.Material = Enum.Material.SmoothPlastic
    torso.CanCollide = false
    torso.Position = hrp.Position
    torso.Parent = m
    local tw = Instance.new("WeldConstraint"); tw.Part0 = hrp; tw.Part1 = torso; tw.Parent = torso

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(1.5*size, 1.5*size, 1.5*size)
    head.Color = SKIN[math.random(1, #SKIN)]
    head.Material = Enum.Material.SmoothPlastic
    head.CanCollide = false
    head.Position = torso.Position + Vector3.new(0, 1.75*size, 0)
    head.Parent = m
    local hw = Instance.new("WeldConstraint"); hw.Part0 = torso; hw.Part1 = head; hw.Parent = head

    local face = Instance.new("Decal")
    face.Texture = "rbxasset://textures/face.png"
    face.Face = Enum.NormalId.Front
    face.Parent = head

    local legs = Instance.new("Part")
    legs.Name = "Legs"
    legs.Size = Vector3.new(2*size, 2*size, 1*size)
    legs.Color = LEG[math.random(1, #LEG)]
    legs.Material = Enum.Material.SmoothPlastic
    legs.CanCollide = false
    legs.Position = torso.Position + Vector3.new(0, -2*size, 0)
    legs.Parent = m
    local lw = Instance.new("WeldConstraint"); lw.Part0 = torso; lw.Part1 = legs; lw.Parent = legs

    local hum = Instance.new("Humanoid")
    hum.MaxHealth = math.huge
    hum.Health = math.huge
    hum.WalkSpeed = math.random(8, 14)
    hum.JumpPower = 0
    hum.HealthDisplayDistance = 0
    hum.Parent = m

    m.PrimaryPart = hrp
    return m
end

local function isPositionFree(pos)
    for _, c in ipairs(crowdFolder:GetChildren()) do
        local p = c.PrimaryPart
        if p and (p.Position - pos).Magnitude < SPAWN_MIN_SPACING then
            return false
        end
    end
    return true
end

local function spawnNearPlayer(player)
    local char = player.Character
    if not char or not char.PrimaryPart then return nil end
    local origin = char.PrimaryPart.Position
    -- Try a handful of positions before giving up to avoid stacking.
    for _ = 1, 4 do
        local angle = math.random() * math.pi * 2
        local r = math.random(NEAR_RADIUS, FAR_RADIUS)
        local pos = origin + Vector3.new(math.cos(angle) * r, 5, math.sin(angle) * r)
        if isPositionFree(pos) then
            local npc = buildPed()
            npc:PivotTo(CFrame.new(pos))
            npc.Parent = crowdFolder
            return npc
        end
    end
    return nil
end

-- SINGLE MANAGER COROUTINE. Snapshot player positions ONCE per tick instead
-- of looping through Players for every NPC (was O(N*M)).
task.spawn(function()
    while true do
        task.wait(TICK_INTERVAL)
        local playerPositions = {}
        for _, p in ipairs(Players:GetPlayers()) do
            local c = p.Character
            if c and c.PrimaryPart then
                table.insert(playerPositions, c.PrimaryPart.Position)
            end
        end

        local liveCount = 0
        for _, npc in ipairs(crowdFolder:GetChildren()) do
            if npc:IsA("Model") and npc:GetAttribute("AmbientNPC") and not npc:GetAttribute("Pranked") then
                local hrp = npc.PrimaryPart
                if hrp then
                    local closest = math.huge
                    for _, pp in ipairs(playerPositions) do
                        local d = (pp - hrp.Position).Magnitude
                        if d < closest then closest = d end
                    end
                    if closest > DESPAWN_RADIUS then
                        npc:Destroy()
                    else
                        liveCount = liveCount + 1
                        local hum = npc:FindFirstChildOfClass("Humanoid")
                        if hum then
                            local d = Vector3.new(math.random(-20, 20), 0, math.random(-20, 20))
                            hum:MoveTo(hrp.Position + d)
                        end
                    end
                end
            end
        end

        local need = TARGET_VISIBLE - liveCount
        if need > 0 then
            for _, p in ipairs(Players:GetPlayers()) do
                if need <= 0 then break end
                if spawnNearPlayer(p) then need = need - 1 end
            end
        end
    end
end)

print("[AmbientCrowd v4] single-manager mode, target " .. TARGET_VISIBLE .. " NPCs visible")
