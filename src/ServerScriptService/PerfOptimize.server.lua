-- PerfOptimize.server.lua — Grok mobile/performance settings
-- Configures Workspace + Lighting properties for 50-player mobile-friendly perf.
-- Place in: ServerScriptService > PerfOptimize. Auto-runs.

local Workspace = game:GetService("Workspace")

-- StreamingEnabled (per Grok review)
Workspace.StreamingEnabled = true
Workspace.StreamingMinRadius = 128
Workspace.StreamingTargetRadius = 256
Workspace.StreamingPauseMode = Enum.StreamingPauseMode.ClientPhysicsPause

-- Mesh collision fidelity = Box (cheaper than Default)
task.spawn(function()
  task.wait(5)  -- after city loads
  for _, p in ipairs(Workspace:GetDescendants()) do
    if p:IsA("MeshPart") then
      pcall(function() p.CollisionFidelity = Enum.CollisionFidelity.Box end)
    end
  end
  Workspace.DescendantAdded:Connect(function(p)
    if p:IsA("MeshPart") then
      pcall(function() p.CollisionFidelity = Enum.CollisionFidelity.Box end)
    end
  end)
end)

-- Physics tuning
pcall(function()
  Workspace.Gravity = 196.2
end)

print("[PerfOptimize] StreamingEnabled, Box collision, mobile tuned")
