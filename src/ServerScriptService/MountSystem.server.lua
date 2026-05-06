-- MountSystem.server.lua  v1 — 4 stray dogs around the city the cat can
-- ride. Each is a VehicleSeat-based 'mount' with primitive welded body.
-- Faster than walking (MaxSpeed 35 vs cat WalkSpeed 24). Eats civilians
-- on contact for +250 chaos to the rider (less than cars but still fun).

local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local DataHandler
task.spawn(function()
    while not _G.KittyRaiserData do task.wait() end
    DataHandler = _G.KittyRaiserData
end)

local MOUNT_POSITIONS = {
    Vector3.new( 250, 4,  100),  -- east of plaza
    Vector3.new(-250, 4,  100),  -- west of plaza
    Vector3.new( 250, 4, -100),  -- southeast
    Vector3.new(-250, 4, -100),  -- southwest
}

local DOG_COLORS = {
    Color3.fromRGB(140, 100, 70),   -- chocolate
    Color3.fromRGB(220, 200, 170),  -- cream
    Color3.fromRGB(80, 60, 50),     -- dark brown
    Color3.fromRGB(180, 165, 140),  -- tan
}

local folder = Workspace:FindFirstChild("Mounts") or Instance.new("Folder", Workspace)
folder.Name = "Mounts"
folder:ClearAllChildren()

local function makeDog(idx, position, color)
    local model = Instance.new("Model", folder)
    model.Name = "Mount_Dog_" .. idx

    local seat = Instance.new("VehicleSeat", model)
    seat.Name = "Saddle"
    seat.Size = Vector3.new(2.4, 1.6, 4.4)
    seat.Position = position
    seat.Color = color
    seat.Material = Enum.Material.SmoothPlastic
    seat.MaxSpeed = 35
    seat.Torque = 18
    seat.HeadsUpDisplay = false
    seat.TopSurface = Enum.SurfaceType.Smooth
    seat.BottomSurface = Enum.SurfaceType.Smooth

    -- Dog head, legs, tail (cosmetic; physics ride on the seat).
    local head = Instance.new("Part", model)
    head.Anchored = false; head.CanCollide = false; head.Massless = true
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(1.6, 1.4, 1.6)
    head.CFrame = seat.CFrame * CFrame.new(0, 0.6, -2.4)
    head.Color = color; head.Material = Enum.Material.SmoothPlastic
    local hw = Instance.new("WeldConstraint", head); hw.Part0 = seat; hw.Part1 = head

    local snout = Instance.new("Part", model)
    snout.Anchored = false; snout.CanCollide = false; snout.Massless = true
    snout.Size = Vector3.new(0.8, 0.6, 1.2)
    snout.CFrame = head.CFrame * CFrame.new(0, -0.2, -0.9)
    snout.Color = color:Lerp(Color3.new(0, 0, 0), 0.3); snout.Material = Enum.Material.SmoothPlastic
    local sw = Instance.new("WeldConstraint", snout); sw.Part0 = head; sw.Part1 = snout

    -- Floppy ears
    for _, sx in ipairs({-1, 1}) do
        local ear = Instance.new("Part", model)
        ear.Anchored = false; ear.CanCollide = false; ear.Massless = true
        ear.Size = Vector3.new(0.4, 0.8, 0.6)
        ear.CFrame = head.CFrame * CFrame.new(sx * 0.7, 0.5, 0)
        ear.Color = color:Lerp(Color3.new(0, 0, 0), 0.2)
        ear.Material = Enum.Material.SmoothPlastic
        local ew = Instance.new("WeldConstraint", ear); ew.Part0 = head; ew.Part1 = ear
    end

    -- 4 legs
    for _, lp in ipairs({
        Vector3.new(-0.9, -1.0, -1.6), Vector3.new( 0.9, -1.0, -1.6),
        Vector3.new(-0.9, -1.0,  1.6), Vector3.new( 0.9, -1.0,  1.6),
    }) do
        local leg = Instance.new("Part", model)
        leg.Anchored = false; leg.CanCollide = false; leg.Massless = true
        leg.Size = Vector3.new(0.6, 1.4, 0.6)
        leg.CFrame = seat.CFrame * CFrame.new(lp)
        leg.Color = color
        leg.Material = Enum.Material.SmoothPlastic
        local lw = Instance.new("WeldConstraint", leg); lw.Part0 = seat; lw.Part1 = leg
    end

    -- Tail
    local tail = Instance.new("Part", model)
    tail.Anchored = false; tail.CanCollide = false; tail.Massless = true
    tail.Size = Vector3.new(0.4, 0.4, 1.6)
    tail.CFrame = seat.CFrame * CFrame.new(0, 0.4, 2.4) * CFrame.Angles(math.rad(20), 0, 0)
    tail.Color = color
    tail.Material = Enum.Material.SmoothPlastic
    local tw = Instance.new("WeldConstraint", tail); tw.Part0 = seat; tw.Part1 = tail

    model.PrimaryPart = seat

    -- Floating name above mount
    local g = Instance.new("BillboardGui", head)
    g.Size = UDim2.new(0, 90, 0, 22)
    g.StudsOffset = Vector3.new(0, 1.4, 0)
    g.AlwaysOnTop = true
    local lbl = Instance.new("TextLabel", g)
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text = "RIDE: F"
    lbl.Font = Enum.Font.LuckiestGuy
    lbl.TextScaled = true
    lbl.TextColor3 = Color3.fromRGB(255, 240, 200)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)

    -- Proximity prompt to mount
    local prompt = Instance.new("ProximityPrompt", seat)
    prompt.ActionText = "RIDE"
    prompt.ObjectText = "Stray Dog"
    prompt.HoldDuration = 0
    prompt.MaxActivationDistance = 10
    prompt.KeyboardKeyCode = Enum.KeyCode.F
    prompt.Triggered:Connect(function(player)
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum and not seat.Occupant then
            seat:Sit(hum)
        end
    end)

    -- NPC contact damage (similar to cars but lower)
    local lastHit = {}
    seat.Touched:Connect(function(hit)
        if not seat.Occupant then return end
        local hitModel = hit:FindFirstAncestorOfClass("Model")
        if not hitModel or not hitModel:GetAttribute("KittyRaiserNPC") then return end
        if hitModel:GetAttribute("Pranked") then return end
        local now = os.clock()
        if lastHit[hitModel] and now - lastHit[hitModel] < 1.0 then return end
        lastHit[hitModel] = now
        local hp = hitModel:GetAttribute("NpcHp") or 3
        hp = math.max(0, hp - 1)
        hitModel:SetAttribute("NpcHp", hp)
        if hp == 0 then
            local rider = seat.Occupant and Players:GetPlayerFromCharacter(seat.Occupant.Parent)
            if rider and DataHandler then
                DataHandler.modify(rider, function(d)
                    d.chaosPoints = (d.chaosPoints or 0) + 250
                    d.totalPranks = (d.totalPranks or 0) + 1
                end)
                if Remotes.NotifyClient then
                    Remotes.NotifyClient:FireClient(rider, "DOG ATE  -  +250 CHAOS", "good")
                end
            end
        end
    end)

    return model
end

task.spawn(function()
    task.wait(2)
    for i, pos in ipairs(MOUNT_POSITIONS) do
        makeDog(i, pos, DOG_COLORS[((i - 1) % #DOG_COLORS) + 1])
    end
    print("[MountSystem v1] " .. #MOUNT_POSITIONS .. " stray dogs rideable")
end)
