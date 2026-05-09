-- AmbientCrowd.server.lua  v5 — GTA-style civilian system.
--
-- v5 adds (Phase-12 directive — "GTA-style NPC system"):
--   * 5 ARCHETYPE outfit sets (BUSINESS / TOURIST / DELIVERY / JOGGER / CASUAL)
--     so the street has visible variety, not just random color tints.
--   * BEHAVIOR ROLES per NPC:
--       - "wander" (60%) — picks a new random destination every few seconds
--       - "stand"  (15%) — idles in place, occasionally pivots
--       - "group"  (15%) — clusters with 1-2 nearest other NPCs (chatting)
--       - "sit"    (10%) — anchored at nearest park-bench-ish landmark
--   * HEAD-TRACK: NPCs rotate the head Motor6D toward the nearest player
--     within 12 studs (simulates "noticing the cat").
--   * Display name overhead with the archetype label so the city reads as
--     populated by recognizable archetypes, not anonymous Robloxians.
--
-- Place in: ServerScriptService > AmbientCrowd. Auto-runs.

local Players    = game:GetService("Players")
local Workspace  = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local TARGET_VISIBLE = 80  -- v3.99.12: tripled for density
local NEAR_RADIUS    = 60
local FAR_RADIUS     = 240
local DESPAWN_RADIUS = 400
local TICK_INTERVAL  = 3
local HEAD_TRACK_RANGE = 14

local crowdFolder = Workspace:FindFirstChild("AmbientCrowd")
if not crowdFolder then
    crowdFolder = Instance.new("Folder")
    crowdFolder.Name = "AmbientCrowd"
    crowdFolder.Parent = Workspace
end

-- =====================================================================
-- ARCHETYPES
-- =====================================================================
-- Each archetype defines visual identity + speed + behavior weights.
local ARCHETYPES = {
    BUSINESS = {
        label = "OFFICE",
        names = {"Banker","Lawyer","Trader","Suit","Exec","CFO","Mgr","Analyst"},
        shirt = {Color3.fromRGB(40, 50, 80), Color3.fromRGB(60, 60, 70), Color3.fromRGB(80, 75, 70)},
        pants = {Color3.fromRGB(35, 35, 45), Color3.fromRGB(50, 50, 55)},
        skin  = {Color3.fromRGB(245,205,160), Color3.fromRGB(200,165,130), Color3.fromRGB(160,110,80), Color3.fromRGB(120,80,55)},
        speed = {10, 14},
        weights = {wander = 0.55, stand = 0.20, group = 0.20, sit = 0.05},
    },
    TOURIST = {
        label = "TOURIST",
        names = {"Tourist","Visitor","Backpacker","Sightseer","Camera Guy","Family"},
        shirt = {Color3.fromRGB(255, 110, 80), Color3.fromRGB(80, 200, 220), Color3.fromRGB(255, 200, 90), Color3.fromRGB(220, 130, 200)},
        pants = {Color3.fromRGB(200, 175, 120), Color3.fromRGB(170, 140, 100), Color3.fromRGB(120, 110, 95)},
        skin  = {Color3.fromRGB(245,205,160), Color3.fromRGB(220,180,150), Color3.fromRGB(170,120,90)},
        speed = {6, 10},
        weights = {wander = 0.50, stand = 0.30, group = 0.15, sit = 0.05},
    },
    DELIVERY = {
        label = "DELIVERY",
        names = {"Delivery","Courier","Driver","Postal","Worker","Loader"},
        shirt = {Color3.fromRGB(110, 75, 50), Color3.fromRGB(140, 90, 60), Color3.fromRGB(75, 100, 75)},
        pants = {Color3.fromRGB(60, 50, 35), Color3.fromRGB(80, 65, 45)},
        skin  = {Color3.fromRGB(220,180,150), Color3.fromRGB(160,110,80), Color3.fromRGB(95,65,45)},
        speed = {12, 16},
        weights = {wander = 0.80, stand = 0.10, group = 0.05, sit = 0.05},
    },
    JOGGER = {
        label = "JOGGER",
        names = {"Jogger","Runner","Cardio","Sporty","Athlete"},
        shirt = {Color3.fromRGB(220, 60, 90), Color3.fromRGB(80, 180, 120), Color3.fromRGB(60, 130, 220), Color3.fromRGB(245, 240, 230)},
        pants = {Color3.fromRGB(40, 40, 50), Color3.fromRGB(120, 120, 130), Color3.fromRGB(80, 50, 30)},
        skin  = {Color3.fromRGB(245,205,160), Color3.fromRGB(220,180,150), Color3.fromRGB(160,110,80), Color3.fromRGB(120,80,55)},
        speed = {16, 20},
        weights = {wander = 0.95, stand = 0.05, group = 0.0, sit = 0.0},
    },
    CASUAL = {
        label = "LOCAL",
        names = {"Local","Resident","Neighbor","Walker","Browser","Friend"},
        shirt = {Color3.fromRGB(180, 80, 200), Color3.fromRGB(60, 130, 200), Color3.fromRGB(80, 200, 90), Color3.fromRGB(255, 80, 130), Color3.fromRGB(50, 50, 50)},
        pants = {Color3.fromRGB(40, 40, 80), Color3.fromRGB(80, 50, 30), Color3.fromRGB(100, 100, 110)},
        skin  = {Color3.fromRGB(245,205,160), Color3.fromRGB(200,165,130), Color3.fromRGB(160,110,80), Color3.fromRGB(120,80,55), Color3.fromRGB(95,65,45), Color3.fromRGB(80,50,35)},
        speed = {8, 13},
        weights = {wander = 0.50, stand = 0.20, group = 0.20, sit = 0.10},
    },
}
local ARCH_KEYS = {"BUSINESS","TOURIST","DELIVERY","JOGGER","CASUAL"}

local SKIN_PARTS  = { Head=true, LeftHand=true, RightHand=true, LeftFoot=true, RightFoot=true }
local SHIRT_PARTS = { UpperTorso=true, LowerTorso=true, Torso=true,
                       LeftUpperArm=true, LeftLowerArm=true,
                       RightUpperArm=true, RightLowerArm=true,
                       ["Left Arm"]=true, ["Right Arm"]=true }
local PANTS_PARTS = { LeftUpperLeg=true, LeftLowerLeg=true,
                       RightUpperLeg=true, RightLowerLeg=true,
                       ["Left Leg"]=true, ["Right Leg"]=true }

local function pickWeighted(weights)
    local total = 0
    for _, v in pairs(weights) do total = total + v end
    local roll = math.random() * total
    local acc = 0
    for k, v in pairs(weights) do
        acc = acc + v
        if roll <= acc then return k end
    end
    return next(weights)
end

local function tintPed(model, archetype)
    local shirtColor = archetype.shirt[math.random(1, #archetype.shirt)]
    local skinColor  = archetype.skin[math.random(1, #archetype.skin)]
    local legColor   = archetype.pants[math.random(1, #archetype.pants)]
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            if SKIN_PARTS[p.Name] then
                p.Color = skinColor; p.Material = Enum.Material.SmoothPlastic
            elseif SHIRT_PARTS[p.Name] then
                p.Color = shirtColor; p.Material = Enum.Material.SmoothPlastic
            elseif PANTS_PARTS[p.Name] then
                p.Color = legColor; p.Material = Enum.Material.SmoothPlastic
            end
        end
    end
end

local function attachNameTag(model, archetype, displayName)
    local head = model:FindFirstChild("Head")
    if not head then return end
    -- v3.60 fix: tags were piling on top of each other in clustered groups
    -- and reading as overlapping garbage like 'DELIVERYDOJEREYJOGGERLOCAL'.
    -- Smaller tag (single line, archetype only) + MaxDistance fade-cull so
    -- distant tags don't render at all. Reduces visible clutter to near-zero.
    local g = Instance.new("BillboardGui", head)
    g.Name = "ArchTag"
    g.Size = UDim2.new(0, 80, 0, 14)
    g.StudsOffset = Vector3.new(0, 1.4, 0)
    g.AlwaysOnTop = false
    g.MaxDistance = 35
    local arch = Instance.new("TextLabel", g)
    arch.Size = UDim2.fromScale(1, 1)
    arch.BackgroundTransparency = 1
    arch.Text = archetype.label
    arch.Font = Enum.Font.GothamMedium
    arch.TextColor3 = Color3.fromRGB(255, 220, 150)
    arch.TextStrokeTransparency = 0.4
    arch.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)
    arch.TextScaled = true
    local ac = Instance.new("UITextSizeConstraint", arch); ac.MinTextSize = 7; ac.MaxTextSize = 10
end

local function buildPed(archKey)
    local archetype = ARCHETYPES[archKey] or ARCHETYPES.CASUAL
    local ok, m = pcall(function()
        local desc = Instance.new("HumanoidDescription")
        desc.HeightScale     = 1.05
        desc.WidthScale      = 1.00
        desc.DepthScale      = 1.00
        desc.HeadScale       = 1.00
        desc.BodyTypeScale   = 1.00
        desc.ProportionScale = 1.00
        return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
    end)

    if not ok or not m then
        m = Instance.new("Model")
        local hrp = Instance.new("Part")
        hrp.Name = "HumanoidRootPart"
        hrp.Size = Vector3.new(2, 2, 1); hrp.Transparency = 1; hrp.CanCollide = false
        hrp.Parent = m
        local torso = Instance.new("Part")
        torso.Name = "Torso"; torso.Size = Vector3.new(2, 2, 1)
        torso.Material = Enum.Material.SmoothPlastic; torso.Parent = m
        local tw = Instance.new("WeldConstraint"); tw.Part0 = hrp; tw.Part1 = torso; tw.Parent = torso
        local head = Instance.new("Part")
        head.Name = "Head"; head.Shape = Enum.PartType.Ball
        head.Size = Vector3.new(1.5, 1.5, 1.5); head.Material = Enum.Material.SmoothPlastic
        head.Position = torso.Position + Vector3.new(0, 1.75, 0); head.Parent = m
        local hw = Instance.new("WeldConstraint"); hw.Part0 = torso; hw.Part1 = head; hw.Parent = head
        local face = Instance.new("Decal"); face.Texture = "rbxasset://textures/face.png"
        face.Face = Enum.NormalId.Front; face.Parent = head
        Instance.new("Humanoid").Parent = m
        m.PrimaryPart = hrp
    end

    local displayName = archetype.names[math.random(1, #archetype.names)]
    m.Name = displayName
    m:SetAttribute("KittyRaiserNPC", true)
    m:SetAttribute("Pranked", false)
    m:SetAttribute("AmbientNPC", true)
    m:SetAttribute("Archetype", archKey)
    m:SetAttribute("Behavior", pickWeighted(archetype.weights))
    m:SetAttribute("LastWanderTime", os.clock())

    -- Strip default cosmetics. Also strip CharacterMesh so the underlying
    -- BasePart Color we set later actually shows (CharacterMesh overrides).
    for _, c in ipairs(m:GetDescendants()) do
        if c:IsA("Shirt") or c:IsA("Pants") or c:IsA("ShirtGraphic")
           or c:IsA("Accessory") or c:IsA("Hat") or c:IsA("CharacterMesh") then
            c:Destroy()
        end
    end

    -- Tint TWICE: once now, once after a short yield. Players reported the
    -- NPCs rendering as flat grey blobs even after the v3.46 description
    -- bake. Cause was tintPed running before all descendants finished
    -- their Roblox-side default-asset application. Belt and suspenders.
    pcall(tintPed, m, archetype)
    task.delay(0.1, function()
        if m.Parent then pcall(tintPed, m, archetype) end
    end)
    pcall(attachNameTag, m, archetype, displayName)

    local hum = m:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = math.random(archetype.speed[1], archetype.speed[2])
        hum.MaxHealth = 100; hum.Health = 100
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        for sname, sval in pairs({
            BodyDepthScale=1.00, BodyWidthScale=1.00, BodyHeightScale=1.05,
            HeadScale=1.00, BodyTypeScale=1.00, ProportionScale=1.00,
        }) do
            local nv = hum:FindFirstChild(sname)
            if nv and nv:IsA("NumberValue") then nv.Value = sval end
        end
    end

    return m
end

local function spawnNearPlayer(player)
    local char = player.Character
    if not char or not char.PrimaryPart then return nil end
    local origin = char.PrimaryPart.Position
    local angle = math.random() * math.pi * 2
    local r = math.random(NEAR_RADIUS, FAR_RADIUS)
    local pos = origin + Vector3.new(math.cos(angle) * r, 5, math.sin(angle) * r)
    local archKey = ARCH_KEYS[math.random(1, #ARCH_KEYS)]
    local npc = buildPed(archKey)
    npc:PivotTo(CFrame.new(pos))
    npc.Parent = crowdFolder
    return npc
end

-- =====================================================================
-- HEAD-TRACK + BEHAVIOR TICK (Heartbeat-driven, throttled per NPC)
-- =====================================================================
local lastHeadTrack = 0
RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastHeadTrack < 0.2 then return end  -- 5Hz is plenty
    lastHeadTrack = now

    for _, npc in ipairs(crowdFolder:GetChildren()) do
        if npc:IsA("Model") and npc:GetAttribute("AmbientNPC") and not npc:GetAttribute("Pranked") then
            local hrp = npc.PrimaryPart
            local head = npc:FindFirstChild("Head")
            if hrp and head then
                -- Find nearest player within head-track range
                local closest, closestDist = nil, HEAD_TRACK_RANGE
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character and p.Character.PrimaryPart then
                        local d = (p.Character.PrimaryPart.Position - hrp.Position).Magnitude
                        if d < closestDist then closest = p.Character.PrimaryPart; closestDist = d end
                    end
                end
                local neckMotor = npc:FindFirstChild("UpperTorso") and npc.UpperTorso:FindFirstChild("Neck")
                if neckMotor and neckMotor:IsA("Motor6D") then
                    if closest then
                        -- Turn head a bit toward the player. Keep pitch small.
                        local targetDir = (closest.Position - head.Position).Unit
                        local localDir = hrp.CFrame:VectorToObjectSpace(targetDir)
                        local yaw = math.clamp(math.atan2(localDir.X, -localDir.Z), -1.0, 1.0)
                        local pitch = math.clamp(-localDir.Y * 0.5, -0.4, 0.4)
                        neckMotor.C0 = CFrame.new(neckMotor.C0.Position) * CFrame.Angles(pitch, yaw, 0)
                    else
                        -- Neutral: ease back to identity orientation
                        neckMotor.C0 = CFrame.new(neckMotor.C0.Position)
                    end
                end
            end
        end
    end
end)

-- =====================================================================
-- BEHAVIOR-AWARE WANDER (per-tick, single manager)
-- =====================================================================
local function applyBehavior(npc)
    local hum = npc:FindFirstChildOfClass("Humanoid")
    local hrp = npc.PrimaryPart
    if not hum or not hrp then return end
    local behavior = npc:GetAttribute("Behavior") or "wander"

    if behavior == "stand" then
        -- Just pivot in place occasionally; no MoveTo.
        if math.random() < 0.4 then
            local theta = math.random() * math.pi * 2
            npc:PivotTo(CFrame.new(hrp.Position) * CFrame.Angles(0, theta, 0))
        end
        return
    end

    if behavior == "sit" then
        -- Anchor near where we already are; small steps only.
        local d = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
        hum:MoveTo(hrp.Position + d)
        return
    end

    if behavior == "group" then
        -- Find another nearby AmbientNPC and move toward them (within 6 studs).
        local targetPos
        for _, other in ipairs(crowdFolder:GetChildren()) do
            if other ~= npc and other:GetAttribute("AmbientNPC") and other.PrimaryPart then
                local d = (other.PrimaryPart.Position - hrp.Position).Magnitude
                if d < 80 and d > 6 then
                    targetPos = other.PrimaryPart.Position
                        + (hrp.Position - other.PrimaryPart.Position).Unit * 5
                    break
                end
            end
        end
        if targetPos then hum:MoveTo(targetPos)
        else hum:MoveTo(hrp.Position + Vector3.new(math.random(-15, 15), 0, math.random(-15, 15))) end
        return
    end

    -- wander (default)
    local d = Vector3.new(math.random(-25, 25), 0, math.random(-25, 25))
    hum:MoveTo(hrp.Position + d)
end

-- SINGLE MANAGER COROUTINE
task.spawn(function()
    while true do
        task.wait(TICK_INTERVAL)
        local npcs = {}
        for _, c in ipairs(crowdFolder:GetChildren()) do
            if c:IsA("Model") and c:GetAttribute("AmbientNPC") and not c:GetAttribute("Pranked") then
                table.insert(npcs, c)
            end
        end
        for _, npc in ipairs(npcs) do
            local hrp = npc.PrimaryPart
            if hrp then
                local closest = math.huge
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character and p.Character.PrimaryPart then
                        local d = (p.Character.PrimaryPart.Position - hrp.Position).Magnitude
                        if d < closest then closest = d end
                    end
                end
                if closest > DESPAWN_RADIUS then
                    npc:Destroy()
                else
                    applyBehavior(npc)
                end
            end
        end
        -- Top up
        local count = 0
        for _, c in ipairs(crowdFolder:GetChildren()) do
            if c:GetAttribute("AmbientNPC") and not c:GetAttribute("Pranked") then count = count + 1 end
        end
        -- CROWD WAVE buff: EventScheduler sets the workspace attribute to
        -- temporarily double the on-street ambient crowd.
        local effectiveTarget = TARGET_VISIBLE
        if workspace:GetAttribute("EventCrowdWave") then
            effectiveTarget = TARGET_VISIBLE * 2
        end
        local need = effectiveTarget - count
        local attempts = 0
        while need > 0 and attempts < need * 4 do
            attempts = attempts + 1
            local players = Players:GetPlayers()
            if #players == 0 then break end
            local p = players[math.random(1, #players)]
            if spawnNearPlayer(p) then need = need - 1 end
        end
    end
end)

print("[AmbientCrowd v5] GTA-style: 5 archetypes, 4 behaviors, head-track, target " .. TARGET_VISIBLE)
