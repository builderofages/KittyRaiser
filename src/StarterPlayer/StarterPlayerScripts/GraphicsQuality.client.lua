-- GraphicsQuality.client.lua
-- Auto-detect mobile (TouchEnabled + no Mouse) and apply lower-quality
-- visuals: dimmer post-FX, fewer particles, reduced StreamingTargetRadius
-- (clientside hint only — the server is authoritative).
-- Player can override via settingsGraphicsQuality.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer

local function applyPreset(quality)
    if quality == "low" then
        for _, fx in ipairs(Lighting:GetChildren()) do
            if fx:IsA("BloomEffect") then fx.Intensity = 1.2; fx.Size = 14 end
            if fx:IsA("DepthOfFieldEffect") then fx.Enabled = false end
            if fx:IsA("SunRaysEffect") then fx.Intensity = 0.05 end
        end
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then atm.Density = 0.18 end
        Workspace.StreamingTargetRadius = math.min(Workspace.StreamingTargetRadius, 800)
    elseif quality == "medium" then
        for _, fx in ipairs(Lighting:GetChildren()) do
            if fx:IsA("BloomEffect") then fx.Intensity = 2.0; fx.Size = 20 end
            if fx:IsA("DepthOfFieldEffect") then fx.Enabled = true; fx.FarIntensity = 0.04 end
            if fx:IsA("SunRaysEffect") then fx.Intensity = 0.15 end
        end
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then atm.Density = 0.24 end
    else  -- high
        for _, fx in ipairs(Lighting:GetChildren()) do
            if fx:IsA("BloomEffect") then fx.Intensity = 2.6; fx.Size = 24 end
            if fx:IsA("DepthOfFieldEffect") then fx.Enabled = true; fx.FarIntensity = 0.06 end
            if fx:IsA("SunRaysEffect") then fx.Intensity = 0.22 end
        end
    end
end

local function autoDetect()
    if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
        return "low"
    end
    -- Approximate desktop midrange detection: smaller workspaces or laptops
    if Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.X < 1366 then
        return "medium"
    end
    return "high"
end

-- Honor saved preference; otherwise use auto-detect
local applied = false
Remotes.UpdatePlayerData.OnClientEvent:Connect(function(d)
    if applied then return end
    applied = true
    local q = d.settingsGraphicsQuality
    if not q or q == "" then q = autoDetect() end
    applyPreset(q)
end)

-- Allow toggling at runtime via setting change
Remotes.UpdatePlayerData.OnClientEvent:Connect(function(d)
    if d.settingsGraphicsQuality then applyPreset(d.settingsGraphicsQuality) end
end)
