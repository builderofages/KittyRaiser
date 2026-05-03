-- EffectsController.client.lua
-- Plays prank visual + audio effects on PrankRegistered events.
-- Place in: StarterPlayer > StarterPlayerScripts > EffectsController (LocalScript)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local PrankConfig = require(ReplicatedStorage.Modules.PrankConfig)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local function shake(intensity)
    if intensity <= 0 then return end
    task.spawn(function()
        local steps = 10
        for i = 1, steps do
            local off = CFrame.new(
                (math.random()-0.5) * intensity * 0.1,
                (math.random()-0.5) * intensity * 0.1,
                0
            )
            camera.CFrame = camera.CFrame * off
            task.wait(0.02)
        end
    end)
end

local function spawnParticleBurst(cf, color, count, opts)
    opts = opts or {}
    local emitterPart = Instance.new("Part")
    emitterPart.Anchored = true
    emitterPart.CanCollide = false
    emitterPart.Transparency = 1
    emitterPart.Size = Vector3.new(1,1,1)
    emitterPart.CFrame = cf
    emitterPart.Parent = Workspace

    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = opts.texture or "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Color = ColorSequence.new(color)
    emitter.Lifetime = opts.lifetime or NumberRange.new(0.5, 1.0)
    emitter.Rate = 0
    emitter.Speed = opts.speed or NumberRange.new(8, 18)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Size = opts.size or NumberSequence.new(1.5, 0.2)
    emitter.Rotation = NumberRange.new(0, 360)
    emitter.RotSpeed = NumberRange.new(-180, 180)
    emitter.Transparency = opts.transparency or NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.7, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    emitter.LightEmission = opts.lightEmission or 0.4
    emitter.Parent = emitterPart
    emitter:Emit(count)

    -- Add a quick point-light flash
    if opts.flashColor then
        local light = Instance.new("PointLight")
        light.Color = opts.flashColor
        light.Range = 12
        light.Brightness = 4
        light.Parent = emitterPart
        TweenService:Create(light, TweenInfo.new(0.4), {Brightness = 0, Range = 0}):Play()
    end

    Debris:AddItem(emitterPart, 2)
end

local function buildAnvilModel(parent)
    -- Real anvil shape (top horn + body + base)
    local model = Instance.new("Model")
    model.Name = "AnvilFX"

    local body = Instance.new("Part")
    body.Anchored = true; body.CanCollide = false
    body.Size = Vector3.new(2.4, 1.4, 4.0)
    body.Material = Enum.Material.Metal
    body.Color = Color3.fromRGB(50, 50, 60)
    body.Reflectance = 0.05
    body.Parent = model

    local horn = Instance.new("Part")
    horn.Anchored = true; horn.CanCollide = false
    horn.Size = Vector3.new(1.2, 1.2, 2.0)
    horn.Material = Enum.Material.Metal
    horn.Color = Color3.fromRGB(60, 60, 70)
    horn.CFrame = body.CFrame * CFrame.new(0, 0.3, -2.6)
    horn.Parent = model

    local waist = Instance.new("Part")
    waist.Anchored = true; waist.CanCollide = false
    waist.Size = Vector3.new(1.6, 1.4, 2.4)
    waist.Material = Enum.Material.Metal
    waist.Color = Color3.fromRGB(40, 40, 50)
    waist.CFrame = body.CFrame * CFrame.new(0, -1.2, 0)
    waist.Parent = model

    local base = Instance.new("Part")
    base.Anchored = true; base.CanCollide = false
    base.Size = Vector3.new(2.8, 0.8, 3.2)
    base.Material = Enum.Material.Metal
    base.Color = Color3.fromRGB(35, 35, 45)
    base.CFrame = body.CFrame * CFrame.new(0, -2.2, 0)
    base.Parent = model

    model.PrimaryPart = body
    model.Parent = parent
    return model
end

local function playSound(soundId, parent)
    if not soundId or soundId == "" then return end
    local s = Instance.new("Sound")
    s.SoundId = soundId
    s.Volume = 1
    s.Parent = parent or SoundService
    s:Play()
    Debris:AddItem(s, 5)
end

local function chaosFlyUp(amount, atCFrame)
    if amount <= 0 then return end
    local b = Instance.new("BillboardGui")
    b.Size = UDim2.new(0, 120, 0, 50)
    b.AlwaysOnTop = true
    b.StudsOffset = Vector3.new(0, 4, 0)
    -- attach to a temp part
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.Transparency = 1
    p.Size = Vector3.new(0.1,0.1,0.1)
    p.CFrame = atCFrame
    p.Parent = Workspace
    b.Parent = p

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "+" .. amount .. " 💚"
    lbl.TextColor3 = GameConfig.HUD_ACCENT_COLOR
    lbl.TextStrokeTransparency = 0
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    lbl.Parent = b

    TweenService:Create(p, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = atCFrame * CFrame.new(0, 6, 0)}):Play()
    TweenService:Create(lbl, TweenInfo.new(1.2), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    Debris:AddItem(p, 1.5)
end

-- ===== Prank effect dispatch =====
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local function effectFor(prankName, cf, color)
    if prankName == "Pie" then
        -- Cream splat: thick white blob + cream particles
        local splat = Instance.new("Part")
        splat.Anchored = true; splat.CanCollide = false
        splat.Shape = Enum.PartType.Ball
        splat.Size = Vector3.new(0.5, 0.5, 0.5)
        splat.Material = Enum.Material.SmoothPlastic
        splat.Color = Color3.fromRGB(255, 250, 235)
        splat.CFrame = cf
        splat.Parent = Workspace
        TweenService:Create(splat, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Size = Vector3.new(3.4, 3.4, 3.4)}):Play()
        TweenService:Create(splat, TweenInfo.new(1.2),
            {Transparency = 1}):Play()
        Debris:AddItem(splat, 1.4)
        spawnParticleBurst(cf, Color3.fromRGB(255, 245, 220), 45, {
            speed = NumberRange.new(10, 20),
            size = NumberSequence.new(2.2, 0.4),
            flashColor = Color3.fromRGB(255, 255, 240),
        })

    elseif prankName == "Anvil" then
        -- Real anvil drops with anticipation, impact dust, shockwave
        local target = cf.Position
        local startCF = CFrame.new(target + Vector3.new(0, 40, 0))
        local landCF = CFrame.new(target + Vector3.new(0, 1.6, 0))
        local anvil = buildAnvilModel(Workspace)
        anvil:PivotTo(startCF)
        local impactTime = 0.32
        task.spawn(function()
            -- Accelerating fall via eased lerp on the model pivot
            local steps = 16
            for i = 1, steps do
                local t = i / steps
                local eased = t * t  -- quadratic ease-in (gravity feel)
                anvil:PivotTo(startCF:Lerp(landCF, eased))
                task.wait(impactTime / steps)
            end
            -- Impact: dust, shockwave, screen shake
            spawnParticleBurst(landCF, Color3.fromRGB(160, 150, 140), 80, {
                texture = SMOKE_TEXTURE,
                lifetime = NumberRange.new(0.6, 1.4),
                speed = NumberRange.new(12, 28),
                size = NumberSequence.new(3.5, 0.5),
                lightEmission = 0.1,
                flashColor = Color3.fromRGB(255, 220, 180),
            })
            local ring = Instance.new("Part")
            ring.Anchored = true; ring.CanCollide = false; ring.Massless = true
            ring.Shape = Enum.PartType.Cylinder
            ring.Size = Vector3.new(0.4, 1, 1)
            ring.Material = Enum.Material.Neon
            ring.Color = Color3.fromRGB(255, 220, 130)
            ring.CFrame = CFrame.new(target + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
            ring.Parent = Workspace
            TweenService:Create(ring, TweenInfo.new(0.5),
                {Size = Vector3.new(0.4, 14, 14), Transparency = 1}):Play()
            Debris:AddItem(ring, 0.6)
            Debris:AddItem(anvil, 1.2)
        end)

    elseif prankName == "FartCloud" then
        -- Real volumetric green smoke cloud (multiple offset balls + particles)
        for i = 1, 6 do
            local cloud = Instance.new("Part")
            cloud.Anchored = true; cloud.CanCollide = false
            cloud.Shape = Enum.PartType.Ball
            cloud.Size = Vector3.new(2 + math.random(), 2 + math.random(), 2 + math.random())
            cloud.Material = Enum.Material.SmoothPlastic
            cloud.Color = Color3.fromRGB(150 + math.random(0, 30), 200, 80 + math.random(0, 40))
            cloud.Transparency = 0.35
            cloud.CFrame = cf * CFrame.new(math.random(-3, 3), math.random(0, 3), math.random(-3, 3))
            cloud.Parent = Workspace
            TweenService:Create(cloud, TweenInfo.new(1.4),
                {Transparency = 1, Size = cloud.Size * 3}):Play()
            Debris:AddItem(cloud, 1.6)
        end
        spawnParticleBurst(cf, color, 60, {
            texture = SMOKE_TEXTURE,
            lifetime = NumberRange.new(1.0, 1.8),
            speed = NumberRange.new(4, 10),
            size = NumberSequence.new(3, 1),
        })

    elseif prankName == "LaserEyes" then
        -- Twin glowing red beams from cat head, with hit flash + sparks
        local char = player.Character
        if char and char:FindFirstChild("Head") then
            local origin = char.Head.Position
            local target = cf.Position
            local dist = (origin - target).Magnitude
            for _, eyeOff in ipairs({Vector3.new(-0.25, 0, 0), Vector3.new(0.25, 0, 0)}) do
                local startPos = origin + eyeOff
                local mid = (startPos + target) / 2
                local beam = Instance.new("Part")
                beam.Anchored = true; beam.CanCollide = false
                beam.Size = Vector3.new(0.18, 0.18, dist)
                beam.Color = Color3.fromRGB(255, 50, 60)
                beam.Material = Enum.Material.Neon
                beam.CFrame = CFrame.new(mid, target)
                beam.Parent = Workspace
                TweenService:Create(beam, TweenInfo.new(0.45),
                    {Transparency = 1, Size = Vector3.new(0.05, 0.05, dist)}):Play()
                Debris:AddItem(beam, 0.5)
            end
            -- Glowing impact at target
            local impact = Instance.new("Part")
            impact.Anchored = true; impact.CanCollide = false
            impact.Shape = Enum.PartType.Ball
            impact.Size = Vector3.new(1, 1, 1)
            impact.Material = Enum.Material.Neon
            impact.Color = Color3.fromRGB(255, 200, 100)
            impact.CFrame = cf
            impact.Parent = Workspace
            TweenService:Create(impact, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = Vector3.new(5, 5, 5), Transparency = 1}):Play()
            Debris:AddItem(impact, 0.5)
        end
        spawnParticleBurst(cf, Color3.fromRGB(255, 80, 40), 60, {
            speed = NumberRange.new(15, 30),
            size = NumberSequence.new(0.8, 0.1),
            lightEmission = 0.8,
            flashColor = Color3.fromRGB(255, 80, 40),
        })
    end
end

Remotes.PrankRegistered.OnClientEvent:Connect(function(prankName, target, chaosGained, fxPayload)
    local prank = PrankConfig.getPrank(prankName)
    if not prank then return end
    local cf = fxPayload and fxPayload.targetCFrame or (target and target.PrimaryPart and target.PrimaryPart.CFrame) or CFrame.new()
    effectFor(prankName, cf, prank.particleColor)
    playSound(prank.soundId)
    if chaosGained and chaosGained > 0 then
        chaosFlyUp(chaosGained, cf)
        shake(prank.screenShake or 0)
    end
end)

return true
