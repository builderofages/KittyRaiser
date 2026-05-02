-- CatCharacterBuilder.server.lua
-- Replaces every player's default Roblox character with a 4-legged cat.
-- Uses Blender mesh assets if AssetIds are wired; falls back to scaled primitives otherwise.
-- Place in: ServerScriptService > CatCharacterBuilder (Script)
-- Auto-runs on server boot.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")

local AssetIds
do
    local mods = ReplicatedStorage:FindFirstChild("Modules")
    local m = mods and mods:FindFirstChild("AssetIds")
    if m then
        local ok, mod = pcall(require, m)
        if ok then AssetIds = mod end
    end
    if not AssetIds then
        AssetIds = setmetatable({}, {__index = function() return "rbxassetid://0" end})
        AssetIds.has = function() return false end
    end
end

local FUR_COLORS = {
    Color3.fromRGB(220, 130, 50),    -- orange tabby
    Color3.fromRGB(80, 60, 50),      -- brown
    Color3.fromRGB(40, 40, 40),      -- black
    Color3.fromRGB(220, 220, 215),   -- white
    Color3.fromRGB(140, 130, 120),   -- grey tabby
    Color3.fromRGB(255, 200, 180),   -- cream
}

local function makePart(props)
    local p = Instance.new("Part")
    p.Anchored = false
    p.CanCollide = props.CanCollide ~= false
    p.Material = Enum.Material.SmoothPlastic
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    for k, v in pairs(props) do
        if k ~= "CanCollide" then p[k] = v end
    end
    return p
end

local function applyMesh(part, meshName)
    if not AssetIds.has(meshName) then return end
    local sm = Instance.new("SpecialMesh")
    sm.MeshType = Enum.MeshType.FileMesh
    sm.MeshId = AssetIds[meshName]
    if AssetIds.has("fur_orange") then sm.TextureId = AssetIds.fur_orange end
    sm.Scale = Vector3.new(1, 1, 1)
    sm.Parent = part
end

local function makeCatCharacter(player, plr_color)
    local model = Instance.new("Model")
    model.Name = player.Name

    -- HumanoidRootPart (invisible, drives physics)
    local hrp = makePart({
        Name = "HumanoidRootPart",
        Size = Vector3.new(2, 1, 4),
        Color = Color3.fromRGB(255, 255, 255),
        Transparency = 1,
        CanCollide = false,
        Massless = true,
    })
    hrp.Parent = model

    -- BODY (mesh if available, else scaled cube)
    local body = makePart({
        Name = "Torso",
        Size = Vector3.new(2, 1.5, 4),
        Color = plr_color,
    })
    if AssetIds.has("mesh_cat_body") then
        applyMesh(body, "mesh_cat_body")
        body.Size = Vector3.new(3, 2.5, 4.5)
    else
        body.Shape = Enum.PartType.Block
    end
    body.CFrame = hrp.CFrame
    body.Parent = model
    body:SetAttribute("PartType", "Torso")

    -- HEAD (mesh if available, else sphere)
    local head = makePart({
        Name = "Head",
        Size = Vector3.new(1.6, 1.6, 1.6),
        Color = plr_color,
    })
    if AssetIds.has("mesh_cat_head") then
        applyMesh(head, "mesh_cat_head")
        head.Size = Vector3.new(2.2, 2.2, 2.2)
    else
        head.Shape = Enum.PartType.Ball
    end
    head.CFrame = hrp.CFrame * CFrame.new(0, 0.4, -2.4)
    head.Parent = model

    -- EYES (white sclera + green pupil)
    for _, eyeOffset in ipairs({Vector3.new(-0.4, 0.2, -0.7), Vector3.new(0.4, 0.2, -0.7)}) do
        local eye = makePart({
            Name = "Eye",
            Size = Vector3.new(0.35, 0.35, 0.35),
            Color = Color3.fromRGB(255, 255, 255),
            CanCollide = false,
            Massless = true,
        })
        eye.Shape = Enum.PartType.Ball
        eye.CFrame = head.CFrame * CFrame.new(eyeOffset)
        eye.Parent = model
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = head; weld.Part1 = eye; weld.Parent = head

        local pupil = makePart({
            Name = "Pupil",
            Size = Vector3.new(0.18, 0.32, 0.18),
            Color = Color3.fromRGB(50, 200, 100),
            CanCollide = false,
            Massless = true,
        })
        pupil.Shape = Enum.PartType.Ball
        pupil.CFrame = eye.CFrame * CFrame.new(0, 0, -0.12)
        pupil.Parent = model
        local w2 = Instance.new("WeldConstraint")
        w2.Part0 = eye; w2.Part1 = pupil; w2.Parent = eye
    end

    -- EARS (2 triangular ears on top of head)
    for _, earOffset in ipairs({Vector3.new(-0.55, 0.85, -0.05), Vector3.new(0.55, 0.85, -0.05)}) do
        local ear = makePart({
            Name = "Ear",
            Size = Vector3.new(0.5, 0.7, 0.4),
            Color = plr_color,
            CanCollide = false,
            Massless = true,
        })
        if AssetIds.has("mesh_cat_ear") then
            applyMesh(ear, "mesh_cat_ear")
        end
        ear.CFrame = head.CFrame * CFrame.new(earOffset) * CFrame.Angles(math.rad(-15), 0, 0)
        ear.Parent = model
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = head; weld.Part1 = ear; weld.Parent = head
    end

    -- NOSE (pink triangle on muzzle)
    local nose = makePart({
        Name = "Nose",
        Size = Vector3.new(0.3, 0.2, 0.2),
        Color = Color3.fromRGB(255, 130, 140),
        CanCollide = false,
        Massless = true,
    })
    nose.CFrame = head.CFrame * CFrame.new(0, -0.05, -0.85)
    nose.Parent = model
    local weld = Instance.new("WeldConstraint"); weld.Part0 = head; weld.Part1 = nose; weld.Parent = head

    -- 4 LEGS
    local legPositions = {
        {name = "LegFrontLeft",  offset = Vector3.new(-0.7, -1.0, -1.5)},
        {name = "LegFrontRight", offset = Vector3.new( 0.7, -1.0, -1.5)},
        {name = "LegBackLeft",   offset = Vector3.new(-0.7, -1.0,  1.4)},
        {name = "LegBackRight",  offset = Vector3.new( 0.7, -1.0,  1.4)},
    }
    for _, lp in ipairs(legPositions) do
        local leg = makePart({
            Name = lp.name,
            Size = Vector3.new(0.55, 1.4, 0.55),
            Color = plr_color,
            CanCollide = false,
            Massless = true,
        })
        if AssetIds.has("mesh_cat_leg") then
            applyMesh(leg, "mesh_cat_leg")
        end
        leg.CFrame = hrp.CFrame * CFrame.new(lp.offset)
        leg.Parent = model
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = body; weld.Part1 = leg; weld.Parent = body
    end

    -- TAIL (5 chained segments curving up)
    local tailParent = body
    for i = 1, 5 do
        local seg = makePart({
            Name = "TailSeg" .. i,
            Size = Vector3.new(0.45 - i*0.05, 0.45 - i*0.05, 0.7),
            Color = plr_color,
            CanCollide = false,
            Massless = true,
        })
        if i == 1 and AssetIds.has("mesh_cat_tail") then
            applyMesh(seg, "mesh_cat_tail")
        end
        local angle = math.rad(20 + i*5)
        seg.CFrame = body.CFrame * CFrame.new(0, 0.2 + i*0.25, 1.8 + i*0.55) * CFrame.Angles(angle, 0, 0)
        seg.Parent = model
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = tailParent; weld.Part1 = seg; weld.Parent = tailParent
    end

    -- WELD HEAD AND TORSO TO HRP
    local headWeld = Instance.new("WeldConstraint")
    headWeld.Part0 = hrp; headWeld.Part1 = head; headWeld.Parent = hrp
    local bodyWeld = Instance.new("WeldConstraint")
    bodyWeld.Part0 = hrp; bodyWeld.Part1 = body; bodyWeld.Parent = hrp

    -- HUMANOID
    local hum = Instance.new("Humanoid")
    hum.RigType = Enum.HumanoidRigType.R6
    hum.WalkSpeed = 16
    hum.JumpPower = 50
    hum.Health = 100
    hum.MaxHealth = 100
    hum.HipHeight = 0
    hum.AutoRotate = true
    hum.Parent = model

    -- Set primary part for CFrame teleport
    model.PrimaryPart = hrp

    return model
end

local function spawnCatFor(player)
    -- Pick a fur color, persisted via attribute
    local fc = player:GetAttribute("FurColor")
    local color
    if fc then
        color = Color3.fromRGB(fc[1] or 220, fc[2] or 130, fc[3] or 50)
    else
        color = FUR_COLORS[math.random(1, #FUR_COLORS)]
        player:SetAttribute("FurColor", {math.floor(color.R*255), math.floor(color.G*255), math.floor(color.B*255)})
    end

    -- Find the spawn
    local sp = Workspace:FindFirstChild("MainSpawn")
    local spawnCFrame = sp and (sp.CFrame * CFrame.new(0, 4, 0)) or CFrame.new(0, 8, 0)

    local cat = makeCatCharacter(player, color)
    cat:PivotTo(spawnCFrame)
    cat.Parent = Workspace
    player.Character = cat

    -- Floating name above
    local nameGui = Instance.new("BillboardGui")
    nameGui.Name = "NameTag"
    nameGui.Size = UDim2.new(0, 200, 0, 50)
    nameGui.StudsOffset = Vector3.new(0, 3, 0)
    nameGui.AlwaysOnTop = true
    nameGui.Parent = cat:FindFirstChild("Head")
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.fromScale(1, 1)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.DisplayName
    nameLabel.Font = Enum.Font.GothamBlack
    nameLabel.TextScaled = true
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.Parent = nameGui

    return cat
end

local function setupPlayer(player)
    -- Disable default character so we can replace it
    player.CharacterAutoLoads = false
    -- Initial spawn
    task.spawn(function()
        task.wait(0.2)
        spawnCatFor(player)
    end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, plr in ipairs(Players:GetPlayers()) do setupPlayer(plr) end

-- Respawn handler
Players.PlayerAdded:Connect(function(plr)
    plr.CharacterRemoving:Connect(function()
        task.wait(2)
        if plr.Parent then spawnCatFor(plr) end
    end)
end)
for _, plr in ipairs(Players:GetPlayers()) do
    plr.CharacterRemoving:Connect(function()
        task.wait(2)
        if plr.Parent then spawnCatFor(plr) end
    end)
end

print("[CatCharacterBuilder] ready — every player spawns as a cat")
