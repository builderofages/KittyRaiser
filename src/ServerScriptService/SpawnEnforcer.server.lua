-- SpawnEnforcer.server.lua  — guarantees a cat spawns for every player no matter what
-- Place in: ServerScriptService > SpawnEnforcer (Script). Auto-runs FIRST.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

print("[SpawnEnforcer] online — guaranteeing every player spawns a cat")

-- Idempotent toggle. Multiple scripts must not flip-flop this.
if Players.CharacterAutoLoads then
    Players.CharacterAutoLoads = false
end

local SAFE_FALLBACK_CFRAME = CFrame.new(0, 20, 0)
local function isUsableSpawn(cf)
    if not cf then return false end
    local p = cf.Position
    if p.Magnitude > 10000 then return false end
    if p.Y < -200 then return false end  -- below world = void
    return p.X == p.X and p.Y == p.Y and p.Z == p.Z  -- NaN guard
end

local function makeFallbackCat(player, fallbackColor)
    local model = Instance.new("Model")
    model.Name = player.Name

    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2, 1, 4)
    hrp.Transparency = 1; hrp.CanCollide = false; hrp.Massless = true
    hrp.Parent = model

    local body = Instance.new("Part")
    body.Name = "Torso"
    body.Size = Vector3.new(3, 2.5, 4.5)
    body.Color = fallbackColor or Color3.fromRGB(220, 130, 50)
    body.Material = Enum.Material.SmoothPlastic
    body.CFrame = hrp.CFrame
    body.Parent = model
    local bw = Instance.new("WeldConstraint"); bw.Part0 = hrp; bw.Part1 = body; bw.Parent = hrp

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(2.2, 2.2, 2.2)
    head.Color = fallbackColor or Color3.fromRGB(220, 130, 50)
    head.Material = Enum.Material.SmoothPlastic
    head.CanCollide = false; head.Massless = true
    head.CFrame = hrp.CFrame * CFrame.new(0, 0.4, -2.6)
    head.Parent = model
    local hw = Instance.new("WeldConstraint"); hw.Part0 = hrp; hw.Part1 = head; hw.Parent = hrp

    for _, off in ipairs({Vector3.new(-0.5, 0.3, -0.85), Vector3.new(0.5, 0.3, -0.85)}) do
        local eye = Instance.new("Part")
        eye.Shape = Enum.PartType.Ball
        eye.Size = Vector3.new(0.45, 0.45, 0.45)
        eye.Color = Color3.fromRGB(255, 255, 255)
        eye.Material = Enum.Material.Neon
        eye.CanCollide = false; eye.Massless = true
        eye:SetAttribute("NoTint", true)
        eye.CFrame = head.CFrame * CFrame.new(off)
        eye.Parent = model
        local w = Instance.new("WeldConstraint"); w.Part0 = head; w.Part1 = eye; w.Parent = head
        local pupil = Instance.new("Part")
        pupil.Shape = Enum.PartType.Ball
        pupil.Size = Vector3.new(0.25, 0.4, 0.25)
        pupil.Color = Color3.fromRGB(50, 220, 100)
        pupil.Material = Enum.Material.Neon
        pupil.CanCollide = false; pupil.Massless = true
        pupil:SetAttribute("NoTint", true)
        pupil.CFrame = eye.CFrame * CFrame.new(0, 0, -0.15)
        pupil.Parent = model
        local w2 = Instance.new("WeldConstraint"); w2.Part0 = eye; w2.Part1 = pupil; w2.Parent = eye
    end

    for _, off in ipairs({Vector3.new(-0.7, 1.0, 0), Vector3.new(0.7, 1.0, 0)}) do
        local ear = Instance.new("Part")
        ear.Size = Vector3.new(0.6, 0.9, 0.5)
        ear.Color = fallbackColor or Color3.fromRGB(220, 130, 50)
        ear.Material = Enum.Material.SmoothPlastic
        ear.CanCollide = false; ear.Massless = true
        ear.CFrame = head.CFrame * CFrame.new(off) * CFrame.Angles(math.rad(-15), 0, 0)
        ear.Parent = model
        local w = Instance.new("WeldConstraint"); w.Part0 = head; w.Part1 = ear; w.Parent = head
    end

    local nose = Instance.new("Part")
    nose.Size = Vector3.new(0.35, 0.25, 0.25)
    nose.Color = Color3.fromRGB(255, 130, 140)
    nose.Material = Enum.Material.SmoothPlastic
    nose.CanCollide = false; nose.Massless = true
    nose:SetAttribute("NoTint", true)
    nose.CFrame = head.CFrame * CFrame.new(0, -0.1, -1.0)
    nose.Parent = model
    local nw = Instance.new("WeldConstraint"); nw.Part0 = head; nw.Part1 = nose; nw.Parent = head

    for _, lp in ipairs({Vector3.new(-0.8, -1.2, -1.6), Vector3.new(0.8, -1.2, -1.6),
                         Vector3.new(-0.8, -1.2, 1.5), Vector3.new(0.8, -1.2, 1.5)}) do
        local leg = Instance.new("Part")
        leg.Size = Vector3.new(0.6, 1.5, 0.6)
        leg.Color = fallbackColor or Color3.fromRGB(220, 130, 50)
        leg.Material = Enum.Material.SmoothPlastic
        leg.CanCollide = false; leg.Massless = true
        leg.CFrame = hrp.CFrame * CFrame.new(lp)
        leg.Parent = model
        local w = Instance.new("WeldConstraint"); w.Part0 = body; w.Part1 = leg; w.Parent = body
    end

    for i = 1, 5 do
        local seg = Instance.new("Part")
        seg.Name = "TailSeg" .. i
        seg.Size = Vector3.new(0.5 - i*0.06, 0.5 - i*0.06, 0.7)
        seg.Color = fallbackColor or Color3.fromRGB(220, 130, 50)
        seg.Material = Enum.Material.SmoothPlastic
        seg.CanCollide = false; seg.Massless = true
        local angle = math.rad(20 + i*5)
        seg.CFrame = body.CFrame * CFrame.new(0, 0.3 + i*0.25, 1.9 + i*0.55) * CFrame.Angles(angle, 0, 0)
        seg.Parent = model
        local w = Instance.new("WeldConstraint"); w.Part0 = body; w.Part1 = seg; w.Parent = body
    end

    local hum = Instance.new("Humanoid")
    hum.RigType = Enum.HumanoidRigType.R6
    hum.WalkSpeed = 16
    hum.JumpPower = 50
    hum.Health = 100; hum.MaxHealth = 100
    hum.HipHeight = 0
    hum.Parent = model

    model.PrimaryPart = hrp
    return model
end

-- One-at-a-time spawn per player to prevent the duplicate-character bug.
local spawnInProgress = {}

local function ensureCat(player, color)
    if spawnInProgress[player.UserId] then return end
    spawnInProgress[player.UserId] = true

    -- Skip if there's already a fully-built cat
    if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
        local count = 0
        for _ in ipairs(player.Character:GetChildren()) do count = count + 1 end
        if count >= 5 then
            spawnInProgress[player.UserId] = nil
            return
        end
    end

    local sp = Workspace:FindFirstChild("MainSpawn") or Workspace:FindFirstChildOfClass("SpawnLocation")
    local cf = sp and (sp.CFrame * CFrame.new(0, 5, 0)) or SAFE_FALLBACK_CFRAME
    if not isUsableSpawn(cf) then cf = SAFE_FALLBACK_CFRAME end

    local fc = player:GetAttribute("FurColor")
    local actualColor = (typeof(fc) == "Color3") and fc
        or (color or Color3.fromRGB(220, 130, 50))

    if player.Character then
        local old = player.Character
        player.Character = nil
        old:Destroy()
        task.wait(0.1)
    end

    if not player.Parent then
        spawnInProgress[player.UserId] = nil
        return
    end

    local cat = makeFallbackCat(player, actualColor)
    cat:PivotTo(cf)
    cat.Parent = Workspace
    player.Character = cat

    local head = cat:FindFirstChild("Head")
    if head then
        local g = Instance.new("BillboardGui")
        g.Size = UDim2.new(0, 200, 0, 50)
        g.StudsOffset = Vector3.new(0, 3, 0)
        g.AlwaysOnTop = true
        g.Parent = head
        local l = Instance.new("TextLabel")
        l.Size = UDim2.fromScale(1, 1)
        l.BackgroundTransparency = 1
        l.Text = string.sub(player.DisplayName or player.Name, 1, 30)
        l.Font = Enum.Font.GothamBlack
        l.TextScaled = true
        l.TextSize = 24  -- floor when TextScaled can't shrink further
        l.TextColor3 = Color3.fromRGB(255, 255, 255)
        l.TextStrokeTransparency = 0
        l.TextStrokeColor3 = Color3.new(0, 0, 0)
        l.Parent = g
    end

    spawnInProgress[player.UserId] = nil
    print("[SpawnEnforcer] spawned cat for " .. player.Name .. " at " .. tostring(cf.Position))
end

local function setup(player)
    task.spawn(function()
        task.wait(1)
        if player.Parent then ensureCat(player) end
    end)
    player.CharacterRemoving:Connect(function()
        task.wait(2)
        if player.Parent then ensureCat(player) end
    end)
end

Players.PlayerAdded:Connect(setup)
Players.PlayerRemoving:Connect(function(p) spawnInProgress[p.UserId] = nil end)
for _, plr in ipairs(Players:GetPlayers()) do setup(plr) end

-- Spawn customization listener via the canonical Remotes module.
if Remotes.RequestSpawnCustomization then
    Remotes.RequestSpawnCustomization.OnServerEvent:Connect(function(player, data)
        if type(data) ~= "table" or not data.furColor then return end
        local fc = data.furColor
        if type(fc) ~= "table" then return end
        local r = math.clamp(tonumber(fc[1]) or 220, 0, 255)
        local g = math.clamp(tonumber(fc[2]) or 130, 0, 255)
        local b = math.clamp(tonumber(fc[3]) or 50, 0, 255)
        local color = Color3.fromRGB(r, g, b)
        player:SetAttribute("FurColor", color)
        ensureCat(player, color)
    end)
    print("[SpawnEnforcer] listening for RequestSpawnCustomization")
else
    warn("[SpawnEnforcer] Remotes.RequestSpawnCustomization missing")
end
