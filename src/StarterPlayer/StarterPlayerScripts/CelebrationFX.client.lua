-- CelebrationFX.client.lua
-- Confetti / fireworks / screen-flash on level up + rebirth.
-- Listens to LevelUp + RebirthCompleted; spawns particles around the camera.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer

local function spawnConfetti(intensity)
    intensity = intensity or 1
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local origin = cam.CFrame.Position + cam.CFrame.LookVector * 8

    local part = Instance.new("Part")
    part.Anchored = true; part.CanCollide = false; part.Transparency = 1
    part.Size = Vector3.new(1, 1, 1)
    part.CFrame = CFrame.new(origin)
    part.Parent = Workspace

    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 215, 0)),
        ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 80, 200)),
        ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 255, 200)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(120, 200, 255)),
    }
    emitter.Lifetime = NumberRange.new(1.5, 2.5)
    emitter.Rate = 0
    emitter.Speed = NumberRange.new(20, 40)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Size = NumberSequence.new(1.0, 0.1)
    emitter.Acceleration = Vector3.new(0, -25, 0)
    emitter.Rotation = NumberRange.new(-180, 180)
    emitter.RotSpeed = NumberRange.new(-180, 180)
    emitter.Parent = part
    emitter:Emit(60 * intensity)

    Debris:AddItem(part, 4)
end

Remotes.LevelUp.OnClientEvent:Connect(function(newLevel)
    spawnConfetti(1)
    -- Bigger one every 5 levels
    if newLevel % 5 == 0 then spawnConfetti(2) end
end)

Remotes.RebirthCompleted.OnClientEvent:Connect(function()
    -- Three bursts in sequence for rebirth
    spawnConfetti(3)
    task.delay(0.4, function() spawnConfetti(3) end)
    task.delay(0.8, function() spawnConfetti(3) end)
end)

print("[CelebrationFX] online")
