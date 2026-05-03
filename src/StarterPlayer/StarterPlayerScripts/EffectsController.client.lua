-- EffectsController.client.lua
-- Plays prank visual + audio effects on PrankRegistered events.
-- Place in: StarterPlayer > StarterPlayerScripts > EffectsController (LocalScript)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local PrankConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PrankConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))

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

local function spawnParticleBurst(cf, color, count)
    local emitterPart = Instance.new("Part")
    emitterPart.Anchored = true
    emitterPart.CanCollide = false
    emitterPart.Transparency = 1
    emitterPart.Size = Vector3.new(1,1,1)
    emitterPart.CFrame = cf
    emitterPart.Parent = Workspace

    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Color = ColorSequence.new(color)
    emitter.Lifetime = NumberRange.new(0.5, 1.0)
    emitter.Rate = 0
    emitter.Speed = NumberRange.new(8, 18)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Size = NumberSequence.new(1.5, 0.2)
    emitter.Parent = emitterPart
    emitter:Emit(count)
    Debris:AddItem(emitterPart, 2)
end

local function playSound(soundId, parent, volume)
    if not soundId or soundId == "" or soundId == 0 or soundId == "rbxassetid://0" then return end
    local s = Instance.new("Sound")
    s.SoundId = tostring(soundId)
    s.Volume = math.clamp(volume or 1, 0, 1)
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

    local moveTween = TweenService:Create(p, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = atCFrame * CFrame.new(0, 6, 0)})
    local fadeTween = TweenService:Create(lbl, TweenInfo.new(1.2), {TextTransparency = 1, TextStrokeTransparency = 1})
    moveTween:Play(); fadeTween:Play()
    p.AncestryChanged:Connect(function()
        if not p.Parent then
            pcall(function() moveTween:Cancel() end)
            pcall(function() fadeTween:Cancel() end)
        end
    end)
    Debris:AddItem(p, 1.5)
end

-- ===== Prank effect dispatch =====
local function effectFor(prankName, cf, color)
    if prankName == "Pie" then
        spawnParticleBurst(cf, color, 35)
    elseif prankName == "Anvil" then
        -- Spawn a fake anvil that drops from sky
        local anvil = Instance.new("Part")
        anvil.Size = Vector3.new(4, 3, 3)
        anvil.Color = Color3.fromRGB(80, 80, 80)
        anvil.Material = Enum.Material.Metal
        anvil.Anchored = true
        anvil.CanCollide = false
        anvil.CFrame = cf * CFrame.new(0, 30, 0)
        anvil.Parent = Workspace
        TweenService:Create(anvil, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {CFrame = cf * CFrame.new(0, 1.5, 0)}):Play()
        task.delay(0.4, function()
            spawnParticleBurst(cf, Color3.fromRGB(150, 150, 150), 50)
            Debris:AddItem(anvil, 1)
        end)
    elseif prankName == "FartCloud" then
        -- AOE green smoke
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Size = Vector3.new(8, 4, 8)
        part.Material = Enum.Material.SmoothPlastic
        part.Color = Color3.fromRGB(140, 200, 80)
        part.Transparency = 0.4
        part.CFrame = cf
        part.Parent = Workspace
        TweenService:Create(part, TweenInfo.new(1.2), {Transparency = 1, Size = Vector3.new(16, 8, 16)}):Play()
        Debris:AddItem(part, 1.5)
        spawnParticleBurst(cf, color, 80)
    elseif prankName == "LaserEyes" then
        -- Beam from player char head to target
        local char = player.Character
        if char and char:FindFirstChild("Head") then
            local origin = char.Head.Position
            local target = cf.Position
            local mid = (origin + target) / 2
            local dist = (origin - target).Magnitude
            local beam = Instance.new("Part")
            beam.Anchored = true
            beam.CanCollide = false
            beam.Size = Vector3.new(0.5, 0.5, dist)
            beam.Color = Color3.fromRGB(255, 50, 50)
            beam.Material = Enum.Material.Neon
            beam.CFrame = CFrame.new(mid, target)
            beam.Parent = Workspace
            TweenService:Create(beam, TweenInfo.new(0.4), {Transparency = 1}):Play()
            Debris:AddItem(beam, 0.5)
        end
        spawnParticleBurst(cf, color, 60)
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
