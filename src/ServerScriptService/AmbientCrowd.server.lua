-- AmbientCrowd.server.lua
-- Keeps 40 random NPCs walking the city at all times (not summoned by players).
-- Makes the city feel alive. NPCs are pranked-target-eligible too.
-- Place in: ServerScriptService > AmbientCrowd. Auto-runs.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local CROWD_SIZE = 40
local SPAWN_RADIUS = 600
local DESPAWN_RADIUS = 1200

local crowdFolder = Workspace:FindFirstChild("AmbientCrowd")
if not crowdFolder then
    crowdFolder = Instance.new("Folder")
    crowdFolder.Name = "AmbientCrowd"
    crowdFolder.Parent = Workspace
end

local SHIRT_COLORS = {
    Color3.fromRGB(200, 50, 50),    Color3.fromRGB(60, 130, 200),
    Color3.fromRGB(80, 200, 90),    Color3.fromRGB(220, 200, 80),
    Color3.fromRGB(180, 80, 200),   Color3.fromRGB(60, 60, 80),
    Color3.fromRGB(240, 240, 240),  Color3.fromRGB(220, 130, 60),
    Color3.fromRGB(255, 80, 130),   Color3.fromRGB(50, 50, 50),
}
local SKIN_COLORS = {
    Color3.fromRGB(245, 205, 160),  Color3.fromRGB(200, 165, 130),
    Color3.fromRGB(160, 110, 80),   Color3.fromRGB(120, 80, 55),
    Color3.fromRGB(95, 65, 45),     Color3.fromRGB(80, 50, 35),
}
local LEG_COLORS = {
    Color3.fromRGB(40, 40, 80),    Color3.fromRGB(80, 50, 30),
    Color3.fromRGB(50, 50, 50),    Color3.fromRGB(100, 100, 110),
    Color3.fromRGB(60, 80, 50),
}

local function buildPedestrian()
    local model = Instance.new("Model")
    model.Name = "Pedestrian"
    model:SetAttribute("KittyRaiserNPC", true)
    model:SetAttribute("Pranked", false)
    model:SetAttribute("AmbientNPC", true)

    local size = math.random() < 0.2 and 0.7 or 1.0
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2*size, 2*size, 1*size)
    hrp.Transparency = 1
    hrp.CanCollide = false
    hrp.Parent = model

    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2*size, 2*size, 1*size)
    torso.Color = SHIRT_COLORS[math.random(1, #SHIRT_COLORS)]
    torso.Material = Enum.Material.SmoothPlastic
    torso.Position = hrp.Position
    torso.Parent = model
    local tw = Instance.new("WeldConstraint"); tw.Part0 = hrp; tw.Part1 = torso; tw.Parent = torso

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(1.5*size, 1.5*size, 1.5*size)
    head.Color = SKIN_COLORS[math.random(1, #SKIN_COLORS)]
    head.Material = Enum.Material.SmoothPlastic
    head.Position = torso.Position + Vector3.new(0, 1.75*size, 0)
    head.Parent = model
    local hw = Instance.new("WeldConstraint"); hw.Part0 = torso; hw.Part1 = head; hw.Parent = head

    local face = Instance.new("Decal")
    face.Texture = "rbxasset://textures/face.png"
    face.Face = Enum.NormalId.Front
    face.Parent = head

    local legs = Instance.new("Part")
    legs.Name = "Legs"
    legs.Size = Vector3.new(2*size, 2*size, 1*size)
    legs.Color = LEG_COLORS[math.random(1, #LEG_COLORS)]
    legs.Material = Enum.Material.SmoothPlastic
    legs.Position = torso.Position + Vector3.new(0, -2*size, 0)
    legs.Parent = model
    local lw = Instance.new("WeldConstraint"); lw.Part0 = torso; lw.Part1 = legs; lw.Parent = legs

    local hum = Instance.new("Humanoid")
    hum.MaxHealth = 100
    hum.Health = 100
    hum.WalkSpeed = math.random(8, 14)
    hum.Parent = model

    model.PrimaryPart = hrp
    return model
end

local function randomCityPos()
    local angle = math.random() * math.pi * 2
    local r = math.random(60, SPAWN_RADIUS)
    return Vector3.new(math.cos(angle) * r, 5, math.sin(angle) * r)
end

local function wander(model)
    task.spawn(function()
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        while model.Parent and not model:GetAttribute("Pranked") do
            local hrp = model.PrimaryPart
            if not hrp then break end
            local d = Vector3.new(math.random(-25, 25), 0, math.random(-25, 25))
            hum:MoveTo(hrp.Position + d)
            local closest = math.huge
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character and p.Character.PrimaryPart then
                    local dist = (p.Character.PrimaryPart.Position - hrp.Position).Magnitude
                    if dist < closest then closest = dist end
                end
            end
            if closest > DESPAWN_RADIUS then
                model:Destroy()
                return
            end
            task.wait(math.random(2, 5))
        end
    end)
end

local function spawnOne()
    local npc = buildPedestrian()
    local pos = randomCityPos()
    npc:PivotTo(CFrame.new(pos))
    npc.Parent = crowdFolder
    wander(npc)
    return npc
end

task.wait(2)
for i = 1, CROWD_SIZE do
    spawnOne()
    task.wait(0.1)
end

task.spawn(function()
    while true do
        task.wait(5)
        local count = 0
        for _, c in ipairs(crowdFolder:GetChildren()) do
            if c:GetAttribute("AmbientNPC") and not c:GetAttribute("Pranked") then count = count + 1 end
        end
        local need = CROWD_SIZE - count
        for i = 1, math.max(0, need) do
            spawnOne()
            task.wait(0.05)
        end
    end
end)

print("[AmbientCrowd] populating " .. CROWD_SIZE .. " pedestrians")
