-- KillCam.client.lua  v1 — short cinematic camera punch on boss-kill or
-- 5+ combo finish. Pulls camera in close to the target NPC, slows time
-- briefly, holds for ~1.2s, then restores.
--
-- Trigger: PrankRegistered with chaosGained > 200 (boss reward) OR a
-- combo-detected event. Cooldown 8s so it doesn't spam during regular
-- chaining.

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local player    = Players.LocalPlayer
local lastKillCam = 0

local function playKillCam(targetCFrame)
    if not targetCFrame then return end
    local cam = workspace.CurrentCamera
    if not cam then return end

    local prevType = cam.CameraType
    local prevCFrame = cam.CFrame
    local prevFOV = cam.FieldOfView

    cam.CameraType = Enum.CameraType.Scriptable

    -- Frame the target from a low angle, ~12 studs back, ~3 up.
    local targetPos = targetCFrame.Position
    local viewer   = targetPos + Vector3.new(0, 3, 12)
    cam.CFrame = CFrame.new(viewer, targetPos)
    cam.FieldOfView = 50

    -- Slow-zoom dolly in
    TweenService:Create(cam, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        CFrame = CFrame.new(targetPos + Vector3.new(0, 2, 7), targetPos),
        FieldOfView = 38,
    }):Play()

    -- Time-slow during the cam
    local origG = workspace.Gravity
    workspace.Gravity = origG * 0.5

    task.delay(1.2, function()
        workspace.Gravity = origG
        cam.CameraType = prevType
        if prevCFrame then cam.CFrame = prevCFrame end
        cam.FieldOfView = prevFOV
    end)
end

Remotes.PrankRegistered.OnClientEvent:Connect(function(prankName, target, chaosGained, fxPayload)
    if not chaosGained or chaosGained <= 0 then return end
    if not fxPayload or not fxPayload.targetCFrame then return end
    -- Only fire on big hits (boss kills earn 200+ chaos via multiplier)
    if chaosGained < 200 then return end
    local now = os.clock()
    if now - lastKillCam < 8 then return end
    lastKillCam = now
    playKillCam(fxPayload.targetCFrame)
end)

print("[KillCam v1] online - triggers on big-chaos hits (>=200), 8s cooldown")
