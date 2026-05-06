-- DrivableVehicles.server.lua  v1 — 8 parked cars the player can hop into,
-- drive around, and run over NPCs with for chaos.
--
-- Design:
--   * 8 parked cars placed at fixed positions in/around plaza.
--   * Each car has a VehicleSeat (Roblox built-in) wired so WASD drives.
--   * ProximityPrompt on each car: 'PRESS E TO DRIVE'.
--   * When the seat is occupied, car damages any AmbientCrowd / PrankNPC
--     it touches (10 HP per hit per NPC, throttled per-NPC 1s).
--   * NPC kill = +500 chaos to the player driving + scream + ragdoll.
--   * Cars use heuristic Tank-style steering: VehicleSeat MaxSpeed=60.

local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local AssetIds
do
    local m = ReplicatedStorage:FindFirstChild("Modules")
    local mod = m and m:FindFirstChild("AssetIds")
    if mod then local ok, ai = pcall(require, mod); if ok then AssetIds = ai end end
end

local DataHandler
task.spawn(function()
    while not _G.KittyRaiserData do task.wait() end
    DataHandler = _G.KittyRaiserData
end)

local CAR_POSITIONS = {
    Vector3.new( 60, 3,  20),
    Vector3.new(-60, 3,  20),
    Vector3.new( 60, 3, -20),
    Vector3.new(-60, 3, -20),
    Vector3.new(140, 3,  60),
    Vector3.new(-140, 3, 60),
    Vector3.new(140, 3, -60),
    Vector3.new(-140, 3, -60),
}
local CAR_COLORS = {
    Color3.fromRGB(255, 200, 0),    -- yellow taxi
    Color3.fromRGB(220, 60, 60),    -- red sport
    Color3.fromRGB(60, 100, 180),   -- blue sedan
    Color3.fromRGB(40, 40, 50),     -- black
    Color3.fromRGB(220, 220, 220),  -- white
    Color3.fromRGB(80, 130, 80),    -- olive
    Color3.fromRGB(200, 130, 60),   -- orange
    Color3.fromRGB(140, 95, 60),    -- brown
}

local folder = Workspace:FindFirstChild("DrivableCars") or Instance.new("Folder", Workspace)
folder.Name = "DrivableCars"
folder:ClearAllChildren()

local function makeCar(idx, position, color)
    local model = Instance.new("Model")
    model.Name = "DrivableCar_" .. idx

    -- Body (the vehicle seat itself, oversized to act as the chassis)
    local body = Instance.new("VehicleSeat", model)
    body.Name = "Chassis"
    body.Size = Vector3.new(8, 2, 16)
    body.Position = position
    body.Color = color
    body.Material = Enum.Material.SmoothPlastic
    body.MaxSpeed = 60
    body.Torque = 25
    body.HeadsUpDisplay = false
    body.TopSurface = Enum.SurfaceType.Smooth
    body.BottomSurface = Enum.SurfaceType.Smooth
    -- Roof + cabin (welded for visual style)
    local roof = Instance.new("Part", model)
    roof.Anchored = false; roof.CanCollide = false; roof.Massless = true
    roof.Size = Vector3.new(7, 2, 8)
    roof.CFrame = body.CFrame * CFrame.new(0, 1.8, 0.5)
    roof.Color = color:Lerp(Color3.new(0, 0, 0), 0.2)
    roof.Material = Enum.Material.SmoothPlastic
    local rw = Instance.new("WeldConstraint", roof); rw.Part0 = body; rw.Part1 = roof
    -- 4 wheels (cosmetic; physics handled by VehicleSeat)
    for _, wp in ipairs({
        Vector3.new(-4, -1.2, -5), Vector3.new(4, -1.2, -5),
        Vector3.new(-4, -1.2,  5), Vector3.new(4, -1.2,  5),
    }) do
        local wheel = Instance.new("Part", model)
        wheel.Anchored = false; wheel.CanCollide = false; wheel.Massless = true
        wheel.Shape = Enum.PartType.Cylinder
        wheel.Size = Vector3.new(1.6, 2.6, 2.6)
        wheel.CFrame = body.CFrame * CFrame.new(wp) * CFrame.Angles(0, 0, math.rad(90))
        wheel.Color = Color3.fromRGB(35, 35, 40)
        wheel.Material = Enum.Material.SmoothPlastic
        local ww = Instance.new("WeldConstraint", wheel); ww.Part0 = body; ww.Part1 = wheel
    end
    model.PrimaryPart = body
    model.Parent = folder

    -- Proximity prompt for E-to-drive (Roblox built-in)
    local prompt = Instance.new("ProximityPrompt", body)
    prompt.ActionText = "DRIVE"
    prompt.ObjectText = "Car"
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 12
    prompt.RequiresLineOfSight = false
    prompt.KeyboardKeyCode = Enum.KeyCode.E
    prompt.Triggered:Connect(function(player)
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and not body.Occupant then
            body:Sit(hum)
        end
    end)

    -- Damage NPCs on contact while occupied
    local lastHit = {}
    body.Touched:Connect(function(hit)
        if not body.Occupant then return end
        local model = hit:FindFirstAncestorOfClass("Model")
        if not model or not model:GetAttribute("KittyRaiserNPC") then return end
        if model:GetAttribute("Pranked") then return end
        local now = os.clock()
        if lastHit[model] and now - lastHit[model] < 1.0 then return end
        lastHit[model] = now
        -- Drive the NPC's HP down via the existing NpcHp attribute
        local hp = model:GetAttribute("NpcHp")
        if not hp then hp = 3 end
        hp = math.max(0, hp - 1)
        model:SetAttribute("NpcHp", hp)
        -- Award the driver
        local driver = body.Occupant and Players:GetPlayerFromCharacter(body.Occupant.Parent)
        if driver and DataHandler and hp == 0 then
            DataHandler.modify(driver, function(d)
                d.chaosPoints = (d.chaosPoints or 0) + 500
                d.totalPranks = (d.totalPranks or 0) + 1
            end)
            if Remotes.NotifyClient then
                Remotes.NotifyClient:FireClient(driver, "RAN OVER  -  +500 CHAOS", "good")
            end
        end
    end)

    return model
end

task.spawn(function()
    task.wait(2)
    for i, pos in ipairs(CAR_POSITIONS) do
        makeCar(i, pos, CAR_COLORS[((i - 1) % #CAR_COLORS) + 1])
    end
    print("[DrivableVehicles v1] " .. #CAR_POSITIONS .. " parked cars ready")
end)
