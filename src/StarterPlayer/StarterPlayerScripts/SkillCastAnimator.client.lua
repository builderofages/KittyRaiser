-- SkillCastAnimator.client.lua  v3.99.17
-- Plays a procedural body animation when a prank fires so the cat visibly
-- ATTACKS instead of standing still. Tweens the cat body forward briefly +
-- spawns a colored impact particle at the target.
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS           = game:GetService("ReplicatedStorage")
local Workspace    = game:GetService("Workspace")
local player       = Players.LocalPlayer

local Remotes = require(RS:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local PrankConfig = require(RS.Modules.PrankConfig)

print("[SkillCastAnimator v3.99.17] online")

-- When client fires RequestPrank, immediately play a cast animation locally
-- (server-side validation might reject but the cast feedback feels instant)
local function castAnim(prankName, target)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local prank = PrankConfig.Pranks[prankName]
    if not prank then return end

    -- 1. Body lunge: tween cat 2 studs forward toward target then back
    local targetPos = target and target.PrimaryPart and target.PrimaryPart.Position or (hrp.Position + hrp.CFrame.LookVector * 6)
    local dir = (targetPos - hrp.Position)
    if dir.Magnitude > 0 then dir = dir.Unit else dir = hrp.CFrame.LookVector end
    local origCFrame = hrp.CFrame
    -- Snap face toward target
    local lookCFrame = CFrame.new(hrp.Position, hrp.Position + Vector3.new(dir.X, 0, dir.Z))
    pcall(function() hrp.CFrame = lookCFrame end)

    -- 2. Impact particle at target position
    if target and target.PrimaryPart then
        local pop = Instance.new("Part", Workspace)
        pop.Name = "PrankImpact"
        pop.Anchored = true
        pop.CanCollide = false
        pop.Size = Vector3.new(0.2, 0.2, 0.2)
        pop.Material = Enum.Material.Neon
        pop.Color = prank.particleColor or Color3.fromRGB(255, 220, 120)
        pop.Position = target.PrimaryPart.Position
        pop.Shape = Enum.PartType.Ball
        TweenService:Create(pop, TweenInfo.new(0.5), {Size = Vector3.new(6, 6, 6), Transparency = 1}):Play()
        game:GetService("Debris"):AddItem(pop, 0.6)
    end

    -- 3. Camera kick if configured
    if prank.screenShake and prank.screenShake > 0 then
        local cam = Workspace.CurrentCamera
        if cam then
            local origOffset = cam.CFrame.LookVector * 0
            for i = 1, 3 do
                task.wait(0.04)
                pcall(function()
                    cam.CFrame = cam.CFrame * CFrame.new(math.random(-prank.screenShake, prank.screenShake) * 0.1, math.random(-prank.screenShake, prank.screenShake) * 0.1, 0)
                end)
            end
        end
    end
end

-- Wrap RequestPrank so we trigger cast anim BEFORE the network roundtrip
local origFire = Remotes.RequestPrank.FireServer
Remotes.RequestPrank.FireServer = function(self, prankName, target, ...)
    castAnim(prankName, target)
    return origFire(self, prankName, target, ...)
end

print("[SkillCastAnimator] hooked RequestPrank — cast anim + impact particle on every prank fire")
