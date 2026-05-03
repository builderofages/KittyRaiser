-- KillBarrier.server.lua
-- A wide invisible CanCollide=false plate at Y=-100 that kills any humanoid
-- that touches it, so a player who falls through the map respawns instead of
-- falling forever. Anchored, no collision, big enough to catch from any spawn.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local barrier = Workspace:FindFirstChild("__KillBarrier")
if not barrier then
    barrier = Instance.new("Part")
    barrier.Name = "__KillBarrier"
    barrier.Size = Vector3.new(8000, 4, 8000)
    barrier.Position = Vector3.new(0, -200, 0)
    barrier.Anchored = true
    barrier.CanCollide = false
    barrier.Transparency = 1
    barrier.Parent = Workspace
end

barrier.Touched:Connect(function(hit)
    local model = hit and hit.Parent
    if not model then return end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 then
        hum.Health = 0
    end
end)

print("[KillBarrier] online at y=-200")
