-- ServerHUDGuard.server.lua  v3.99.14 — server-side fallback HUD elements + diagnostics
local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local TS      = game:GetService("TweenService")
local VersionInfo = require(RS:WaitForChild("Modules"):WaitForChild("VersionInfo"))

print("[ServerHUDGuard] online — " .. VersionInfo.tag .. "  build " .. VersionInfo.buildDate)

-- When a player joins, ensure server-side defaults are correct regardless of client scripts
Players.PlayerAdded:Connect(function(p)
    print("[ServerHUDGuard] player joined: " .. p.Name .. "  on build " .. VersionInfo.tag)
    p.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            -- Force-disable Roblox auto-nameplate (server-side, always works)
            hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
            hum.NameDisplayDistance = 0
            hum.HealthDisplayDistance = 0
            print("[ServerHUDGuard] killed auto-nameplate for " .. p.Name)
        end
    end)
end)

-- Server-side proximity broadcast that fires every 2 seconds to remind clients of important interaction states
local Workspace = game:GetService("Workspace")
task.spawn(function()
    while task.wait(5) do
        local count = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then count = count + 1 end
        end
        -- Verify ambient crowd has spawned
        local ac = Workspace:FindFirstChild("AmbientCrowd")
        local acCount = ac and #ac:GetChildren() or 0
        local sv = Workspace:FindFirstChild("StreetVendors")
        local svCount = sv and #sv:GetChildren() or 0
        print(string.format("[ServerHUDGuard] heartbeat — players=%d ambient=%d vendors=%d build=%s",
            count, acCount, svCount, VersionInfo.tag))
    end
end)
