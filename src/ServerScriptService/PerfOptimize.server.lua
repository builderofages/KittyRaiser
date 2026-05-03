-- PerfOptimize.server.lua — Workspace + Lighting properties for 50-player mobile-friendly perf.
-- Place in: ServerScriptService > PerfOptimize. Auto-runs.

local Workspace = game:GetService("Workspace")

-- Streaming radii must comfortably exceed NPC spawn radius (80-200) AND keep
-- nearby buildings loaded for context. The previous 256 target unloaded NPCs
-- before they were visible.
Workspace.StreamingEnabled = true
Workspace.StreamingMinRadius = 256
Workspace.StreamingTargetRadius = 1500
Workspace.StreamingPauseMode = Enum.StreamingPauseMode.ClientPhysicsPause

-- DescendantAdded handler is set up FIRST so any MeshPart created during the
-- initial sweep is also caught. Then we sweep what's already there.
Workspace.DescendantAdded:Connect(function(p)
    if p:IsA("MeshPart") then
        pcall(function() p.CollisionFidelity = Enum.CollisionFidelity.Box end)
    end
end)

task.spawn(function()
    for _, p in ipairs(Workspace:GetDescendants()) do
        if p:IsA("MeshPart") then
            pcall(function() p.CollisionFidelity = Enum.CollisionFidelity.Box end)
        end
    end
end)

-- Note: Gravity = 196.2 is the Roblox default; setting it here is a no-op.
-- Removed.

print("[PerfOptimize] StreamingEnabled, Box collision (live + retro), mobile tuned")
