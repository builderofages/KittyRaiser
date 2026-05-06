-- HitStop.client.lua  v1 — micro time-stop on prank land for chunky feel.
-- Listens to PrankRegistered and briefly slows workspace.Gravity + tweens
-- a black flash on the screen edges. Pure juice.

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local sg = Instance.new("ScreenGui", playerGui)
sg.Name = "HitStopFlash"
sg.IgnoreGuiInset = true
sg.ResetOnSpawn = false
sg.DisplayOrder = 250

-- Edge-vignette flash on hit (using radial fade texture)
local flash = Instance.new("ImageLabel", sg)
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundTransparency = 1
flash.Image = "rbxasset://textures/ui/Controls/RadialFade.png"
flash.ScaleType = Enum.ScaleType.Stretch
flash.ImageColor3 = Color3.fromRGB(255, 230, 120)
flash.ImageTransparency = 1
flash.ZIndex = 0

local lastHitStop = 0
Remotes.PrankRegistered.OnClientEvent:Connect(function(prankName, target, chaosGained, fxPayload)
    -- Only the actor's hit triggers hit-stop (chaosGained > 0 means it's
    -- their hit, nearby observers see other juice).
    if not chaosGained or chaosGained <= 0 then return end
    local now = os.clock()
    if now - lastHitStop < 0.15 then return end  -- throttle so combos don't lock
    lastHitStop = now

    -- Edge flash: 0.2s pop, 0.4s fade
    flash.ImageTransparency = 0.55
    TweenService:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad),
        {ImageTransparency = 1}):Play()

    -- Camera FOV micro-punch: +6 over 0.05s, decay 0.25s
    local cam = workspace.CurrentCamera
    if cam then
        local origFOV = cam.FieldOfView
        TweenService:Create(cam, TweenInfo.new(0.05, Enum.EasingStyle.Linear),
            {FieldOfView = origFOV + 6}):Play()
        task.delay(0.06, function()
            TweenService:Create(cam, TweenInfo.new(0.25, Enum.EasingStyle.Quad),
                {FieldOfView = origFOV}):Play()
        end)
    end

    -- Time-slow: drop Gravity 30%, restore over 0.18s
    local origG = workspace.Gravity
    if math.abs(workspace.Gravity - origG) < 1 then  -- only if not already adjusted
        TweenService:Create(workspace, TweenInfo.new(0.06), {Gravity = origG * 0.55}):Play()
        task.delay(0.1, function()
            TweenService:Create(workspace, TweenInfo.new(0.18), {Gravity = origG}):Play()
        end)
    end
end)

print("[HitStop v1] online — flash + FOV punch + gravity-slow on prank land")
