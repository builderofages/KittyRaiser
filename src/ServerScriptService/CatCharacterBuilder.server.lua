-- CatCharacterBuilder.server.lua  v3 - actually works
-- KEY FIX: set Players.CharacterAutoLoads = false at script load (before any join)
-- so Roblox doesn't auto-spawn default character before our cat builder runs.
-- Place in: ServerScriptService > CatCharacterBuilder. Auto-runs.
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

-- DISABLE auto character spawn IMMEDIATELY at script load
Players.CharacterAutoLoads = false

local AssetIds = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("AssetIds"))

-- Wait for MeshLoader cache (with timeout fallback to primitives)
local function getMeshes()
    local timeout = 0
    while not _G.KittyRaiserMeshes do
        task.wait(0.25); timeout = timeout + 1
        if timeout > 80 then break end
    end
    return _G.KittyRaiserMeshes or {}
end

local FUR_COLORS = {
    Color3.fromRGB(220, 130, 50),
    Color3.fromRGB(80, 60, 50),
    Color3.fromRGB(40, 40, 40),
    Color3.fromRGB(220, 220, 215),
    Color3.fromRGB(140, 130, 120),
    Color3.fromRGB(255, 200, 180),
}

local MESHES  -- populated lazily after first cat spawn (allows MeshLoader to finish)

local function setColor(part, color)
    if part:IsA("MeshPart") then
        part.Color = color
        part.Material = Enum.Material.SmoothPlastic
        if AssetIds.has("fur_orange") then
            pcall(function() part.TextureID = AssetIds.fur_orange end)
        end
    elseif part:IsA("BasePart") then
        part.Color = color
        part.Material = Enum.Material.SmoothPlastic
    end
end

local function makePart(meshKey, fallbackSize, color, name)
    local entry = MESHES and MESHES[meshKey]
    local p
    if entry and entry.meshTemplate then
        p = entry.meshTemplate:Clone()
        p.Anchored = false
        p.CanCollide = false
        p.Massless = true
        if fallbackSize then p.Size = fallbackSize end
    else
        p = Instance.new("Part")
        p.Anchored = false
        p.CanCollide = false
        p.Massless = true
        p.Shape = (meshKey == "mesh_cat_head") and Enum.PartType.Ball or Enum.PartType.Block
        p.Size = fallbackSize or Vector3.new(2, 2, 2)
    end
    p.Name = name or p.Name
    setColor(p, color)
    return p
end

local function makeCatCharacter(player, color)
    local model = Instance.new("Model")
    model.Name = player.Name

    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2, 1, 4)
    hrp.Transparency = 1
    hrp.CanCollide = false
    hrp.Massless = true
    hrp.TopSurface = Enum.SurfaceType.Smooth
    hrp.BottomSurface = Enum.SurfaceType.Smooth
    hrp.Parent = model

    local body = makePart("mesh_cat_body", Vector3.new(3, 2.5, 4.5), color, "Torso")
    body.CanCollide = true
    body.CFrame = hrp.CFrame
    body.Parent = model

    local head = makePart("mesh_cat_head", Vector3.new(2.2, 2.2, 2.2), color, "Head")
    head.CanCollide = false
    head.CFrame = hrp.CFrame * CFrame.new(0, 0.4, -2.6)
    head.Parent = model

    -- Eyes
    for _, off in ipairs({Vector3.new(-0.5, 0.3, -0.85), Vector3.new(0.5, 0.3, -0.85)}) do
        local eye = Instance.new("Part")
        eye.Name = "Eye"
        eye.Shape = Enum.PartType.Ball
        eye.Size = Vector3.new(0.45, 0.45, 0.45)
        eye.Color = Color3.fromRGB(255, 255, 255)
        eye.Material = Enum.Material.SmoothPlastic
        eye.CanCollide = false; eye.Massless = true
        eye.CFrame = head.CFrame * CFrame.new(off)
        eye.Parent = model
        local w = Instance.new("WeldConstraint"); w.Part0 = head; w.Part1 = eye; w.Parent = head
        local pupil = Instance.new("Part")
        pupil.Shape = Enum.PartType.Ball
        pupil.Size = Vector3.new(0.25, 0.4, 0.25)
        pupil.Color = Color3.fromRGB(50, 200, 100)
        pupil.Material = Enum.Material.SmoothPlastic
        pupil.CanCollide = false; pupil.Massless = true
        pupil.CFrame = eye.CFrame * CFrame.new(0, 0, -0.15)
        pupil.Parent = model
        local w2 = Instance.new("WeldConstraint"); w2.Part0 = eye; w2.Part1 = pupil; w2.Parent = eye
    end

    -- Ears
    for _, off in ipairs({Vector3.new(-0.7, 1.0, 0), Vector3.new(0.7, 1.0, 0)}) do
        local ear = makePart("mesh_cat_ear", Vector3.new(0.6, 0.9, 0.5), color, "Ear")
        ear.CFrame = head.CFrame * CFrame.new(off) * CFrame.Angles(math.rad(-15), 0, 0)
        ear.Parent = model
        local w = Instance.new("WeldConstraint"); w.Part0 = head; w.Part1 = ear; w.Parent = head
    end

    -- Nose
    local nose = Instance.new("Part")
    nose.Size = Vector3.new(0.35, 0.25, 0.25)
    nose.Color = Color3.fromRGB(255, 130, 140)
    nose.Material = Enum.Material.SmoothPlastic
    nose.CanCollide = false; nose.Massless = true
    nose.CFrame = head.CFrame * CFrame.new(0, -0.1, -1.0)
    nose.Parent = model
    local nw = Instance.new("WeldConstraint"); nw.Part0 = head; nw.Part1 = nose; nw.Parent = head

    -- 4 legs
    for _, lp in ipairs({
        {name="LegFL", off=Vector3.new(-0.8, -1.2, -1.6)},
        {name="LegFR", off=Vector3.new( 0.8, -1.2, -1.6)},
        {name="LegBL", off=Vector3.new(-0.8, -1.2,  1.5)},
        {name="LegBR", off=Vector3.new( 0.8, -1.2,  1.5)},
    }) do
        local leg = makePart("mesh_cat_leg", Vector3.new(0.6, 1.5, 0.6), color, lp.name)
        leg.CFrame = hrp.CFrame * CFrame.new(lp.off)
        leg.Parent = model
        local w = Instance.new("WeldConstraint"); w.Part0 = body; w.Part1 = leg; w.Parent = body
    end

    -- Tail
    local tailParent = body
    for i = 1, 5 do
        local seg
        if i == 1 then
            seg = makePart("mesh_cat_tail", Vector3.new(0.5, 0.5, 0.8), color, "TailSeg"..i)
        else
            seg = Instance.new("Part")
            seg.Size = Vector3.new(0.5 - i*0.06, 0.5 - i*0.06, 0.7)
            seg.Color = color
            seg.Material = Enum.Material.SmoothPlastic
            seg.CanCollide = false; seg.Massless = true
        end
        local angle = math.rad(20 + i*5)
        seg.CFrame = body.CFrame * CFrame.new(0, 0.3 + i*0.25, 1.9 + i*0.55) * CFrame.Angles(angle, 0, 0)
        seg.Parent = model
        local w = Instance.new("WeldConstraint"); w.Part0 = tailParent; w.Part1 = seg; w.Parent = tailParent
    end

    local hw = Instance.new("WeldConstraint"); hw.Part0 = hrp; hw.Part1 = head; hw.Parent = hrp
    local bw = Instance.new("WeldConstraint"); bw.Part0 = hrp; bw.Part1 = body; bw.Parent = hrp

    local hum = Instance.new("Humanoid")
    hum.RigType = Enum.HumanoidRigType.R6
    hum.WalkSpeed = 16
    hum.JumpPower = 50
    hum.Health = 100
    hum.MaxHealth = 100
    hum.HipHeight = 0
    hum.AutoRotate = true
    hum.Parent = model

    model.PrimaryPart = hrp
    return model
end

local function spawnCat(player)
    -- lazy load mesh cache once
    if not MESHES then MESHES = getMeshes() end

    local fc = player:GetAttribute("FurColor")
    local color
    if fc and type(fc) == "table" then
        color = Color3.fromRGB(fc[1] or 220, fc[2] or 130, fc[3] or 50)
    else
        color = FUR_COLORS[math.random(1, #FUR_COLORS)]
        player:SetAttribute("FurColor", {math.floor(color.R*255), math.floor(color.G*255), math.floor(color.B*255)})
    end

    local sp = Workspace:FindFirstChild("MainSpawn") or Workspace:FindFirstChildOfClass("SpawnLocation")
    local cf = sp and (sp.CFrame * CFrame.new(0, 5, 0)) or CFrame.new(0, 8, 0)

    -- Destroy any existing character first
    if player.Character then player.Character:Destroy() end

    local cat = makeCatCharacter(player, color)
    cat:PivotTo(cf)
    cat.Parent = Workspace
    player.Character = cat

    -- Floating name above head
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
        l.Text = player.DisplayName
        l.Font = Enum.Font.GothamBlack
        l.TextScaled = true
        l.TextColor3 = Color3.fromRGB(255, 255, 255)
        l.TextStrokeTransparency = 0
        l.TextStrokeColor3 = Color3.new(0, 0, 0)
        l.Parent = g
    end

    return cat
end

local function setup(player)
    -- Defer to after Players cache + give MeshLoader time on first player
    task.spawn(function()
        task.wait(1.0)
        spawnCat(player)
    end)

    player.CharacterRemoving:Connect(function()
        task.wait(2)
        if player.Parent then spawnCat(player) end
    end)
end

Players.PlayerAdded:Connect(setup)
-- Handle players already in (Studio play test)
for _, plr in ipairs(Players:GetPlayers()) do
    setup(plr)
end

print("[CatCharacterBuilder v3] CharacterAutoLoads OFF, manual cat spawn ready")
