-- RuntimeDiag.client.lua
-- Dumps EVERYTHING to F9 console at game start so we can see the truth.
local Players      = game:GetService("Players")
local Workspace    = game:GetService("Workspace")
local RS           = game:GetService("ReplicatedStorage")
local UIS          = game:GetService("UserInputService")
local player       = Players.LocalPlayer
local playerGui    = player:WaitForChild("PlayerGui")

task.wait(5)  -- let everything else load

print("\n========== KITTY RAISER RUNTIME DIAGNOSTIC ==========")
local ok, vinfo = pcall(function() return require(RS.Modules.VersionInfo) end)
if ok then print("BUILD: " .. vinfo.tag .. "  " .. vinfo.buildDate) else print("BUILD: VersionInfo missing") end

print("\n--- ScreenGuis under PlayerGui ---")
for _, sg in ipairs(playerGui:GetChildren()) do
    if sg:IsA("ScreenGui") then
        print(string.format("  ScreenGui '%s' enabled=%s children=%d", sg.Name, tostring(sg.Enabled), #sg:GetChildren()))
    end
end

local hud = playerGui:FindFirstChild("MainHUD")
if hud then
    print("\n--- MainHUD direct children (sorted) ---")
    local kids = {}
    for _, c in ipairs(hud:GetChildren()) do table.insert(kids, c) end
    table.sort(kids, function(a, b) return a.Name < b.Name end)
    for _, c in ipairs(kids) do
        local pos = c:IsA("GuiObject") and string.format("pos=(%.2f,%d,%.2f,%d)", c.Position.X.Scale, c.Position.X.Offset, c.Position.Y.Scale, c.Position.Y.Offset) or ""
        local vis = c:IsA("GuiObject") and ("vis=" .. tostring(c.Visible)) or ""
        print(string.format("  %s [%s] %s %s", c.Name, c.ClassName, vis, pos))
    end
    print("\n--- TopBar contents ---")
    local tb = hud:FindFirstChild("TopBar")
    if tb then
        for _, c in ipairs(tb:GetChildren()) do
            if c:IsA("GuiObject") then
                print(string.format("  TopBar/%s [%s] vis=%s pos=(%.2f,%.2f) anchor=(%.1f,%.1f)",
                    c.Name, c.ClassName, tostring(c.Visible), c.Position.X.Scale, c.Position.Y.Scale, c.AnchorPoint.X, c.AnchorPoint.Y))
            end
        end
    end
    print("\n--- BottomBar contents ---")
    local bb = hud:FindFirstChild("BottomBar")
    if bb then
        print(string.format("  BottomBar visible=%s", tostring(bb.Visible)))
        for _, c in ipairs(bb:GetChildren()) do
            if c:IsA("GuiObject") then
                print(string.format("    BottomBar/%s [%s] vis=%s", c.Name, c.ClassName, tostring(c.Visible)))
            end
        end
    end
end

print("\n--- Workspace folders + counts ---")
for _, name in ipairs({"AmbientCrowd", "PrankNPCs", "DrivableVehicles", "Mounts", "WorldPowerups", "CollectiblesSystem", "InteriorBuildings", "DistrictExpansion", "Plaza", "CityRebuild"}) do
    local f = Workspace:FindFirstChild(name)
    if f then
        local n = #f:GetChildren()
        print(string.format("  %s: %d children", name, n))
    else
        print(string.format("  %s: MISSING", name))
    end
end

print("\n--- Player Character state ---")
local char = player.Character
if char then
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        print(string.format("  Humanoid: Health=%d/%d, DisplayDistanceType=%s", hum.Health, hum.MaxHealth, tostring(hum.DisplayDistanceType)))
    end
end

-- Listen for prank failures
local Remotes = require(RS.Modules.RemoteEvents)
if Remotes.PrankFailed then
    Remotes.PrankFailed.OnClientEvent:Connect(function(reason)
        warn("[RuntimeDiag] PRANK FAILED reason: " .. tostring(reason))
    end)
end
if Remotes.UpdatePlayerData then
    Remotes.UpdatePlayerData.OnClientEvent:Connect(function(data)
        print(string.format("[RuntimeDiag] UpdatePlayerData -> chaos=%d xp=%d level=%d",
            data.chaosPoints or 0, data.xp or 0, data.level or 1))
    end)
end

-- Hotkey M = manual diagnostic dump
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.M then
        print("\n======== MANUAL DIAG (key M) ========")
        for _, p in ipairs(Players:GetPlayers()) do
            local c = p.Character
            if c then
                local hrp = c:FindFirstChild("HumanoidRootPart")
                if hrp then print(string.format("  player %s at (%.1f, %.1f, %.1f)", p.Name, hrp.Position.X, hrp.Position.Y, hrp.Position.Z)) end
            end
        end
        local data = require(RS.Modules.RemoteEvents)
    end
end)

print("\n========== END DIAGNOSTIC ==========\n")
print("Press M anytime for live position dump")
