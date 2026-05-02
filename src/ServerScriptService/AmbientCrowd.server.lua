-- AmbientCrowd.server.lua v2 - spawn closer to player so they're visible
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CROWD_SIZE = 30
local NEAR_RADIUS = 80     -- spawn within 80 studs of any player
local FAR_RADIUS = 250
local DESPAWN_RADIUS = 600

local crowdFolder = Workspace:FindFirstChild("AmbientCrowd")
if not crowdFolder then
    crowdFolder = Instance.new("Folder")
    crowdFolder.Name = "AmbientCrowd"
    crowdFolder.Parent = Workspace
end

local SHIRT = {Color3.fromRGB(200,50,50),Color3.fromRGB(60,130,200),Color3.fromRGB(80,200,90),Color3.fromRGB(220,200,80),Color3.fromRGB(180,80,200),Color3.fromRGB(60,60,80),Color3.fromRGB(240,240,240),Color3.fromRGB(220,130,60),Color3.fromRGB(255,80,130),Color3.fromRGB(50,50,50)}
local SKIN = {Color3.fromRGB(245,205,160),Color3.fromRGB(200,165,130),Color3.fromRGB(160,110,80),Color3.fromRGB(120,80,55),Color3.fromRGB(95,65,45),Color3.fromRGB(80,50,35)}
local LEG = {Color3.fromRGB(40,40,80),Color3.fromRGB(80,50,30),Color3.fromRGB(50,50,50),Color3.fromRGB(100,100,110),Color3.fromRGB(60,80,50)}

local function buildPed()
    local m = Instance.new("Model")
    m.Name = "Pedestrian"
    m:SetAttribute("KittyRaiserNPC", true)
    m:SetAttribute("Pranked", false)
    m:SetAttribute("AmbientNPC", true)

    local size = math.random() < 0.2 and 0.7 or 1.0
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2*size, 2*size, 1*size)
    hrp.Transparency = 1; hrp.CanCollide = false
    hrp.Parent = m

    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2*size, 2*size, 1*size)
    torso.Color = SHIRT[math.random(1, #SHIRT)]
    torso.Material = Enum.Material.SmoothPlastic
    torso.Position = hrp.Position
    torso.Parent = m
    local tw = Instance.new("WeldConstraint"); tw.Part0 = hrp; tw.Part1 = torso; tw.Parent = torso

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(1.5*size, 1.5*size, 1.5*size)
    head.Color = SKIN[math.random(1, #SKIN)]
    head.Material = Enum.Material.SmoothPlastic
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
    legs.Position = torso.Position + Vector3.new(0, -2*size, 0)
    legs.Parent = m
    local lw = Instance.new("WeldConstraint"); lw.Part0 = torso; lw.Part1 = legs; lw.Parent = legs

    local hum = Instance.new("Humanoid")
    hum.MaxHealth = 100; hum.Health = 100
    hum.WalkSpeed = math.random(8, 14)
    hum.Parent = m

    m.PrimaryPart = hrp
    return m
end

local function spawnNearPlayer(player)
    local char = player.Character
    if not char or not char.PrimaryPart then return nil end
    local origin = char.PrimaryPart.Position
    local angle = math.random() * math.pi * 2
    local r = math.random(NEAR_RADIUS, FAR_RADIUS)
    local pos = origin + Vector3.new(math.cos(angle) * r, 5, math.sin(angle) * r)
    local npc = buildPed()
    npc:PivotTo(CFrame.new(pos))
    npc.Parent = crowdFolder
    -- wander
    task.spawn(function()
        local hum = npc:FindFirstChildOfClass("Humanoid")
        while npc.Parent and not npc:GetAttribute("Pranked") do
            local hrp = npc.PrimaryPart
            if not hrp then break end
            local d = Vector3.new(math.random(-25, 25), 0, math.random(-25, 25))
            hum:MoveTo(hrp.Position + d)
            -- despawn far away
            local closest = math.huge
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character and p.Character.PrimaryPart then
                    local dd = (p.Character.PrimaryPart.Position - hrp.Position).Magnitude
                    if dd < closest then closest = dd end
                end
            end
            if closest > DESPAWN_RADIUS then npc:Destroy(); return end
            task.wait(math.random(2, 5))
        end
    end)
    return npc
end

-- Main loop: maintain population near players
task.spawn(function()
    while true do
        for _, player in ipairs(Players:GetPlayers()) do
            local count = 0
            for _, c in ipairs(crowdFolder:GetChildren()) do
                if c:GetAttribute("AmbientNPC") and not c:GetAttribute("Pranked") then count = count + 1 end
            end
            local need = math.min(CROWD_SIZE - count, 5)
            for i = 1, need do
                spawnNearPlayer(player)
                task.wait(0.1)
            end
        end
        task.wait(3)
    end
end)

print("[AmbientCrowd v2] maintaining " .. CROWD_SIZE .. " peds near players")
