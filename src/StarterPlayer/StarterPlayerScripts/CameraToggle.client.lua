-- CameraToggle.client.lua
-- Listen for settingsCameraMode and force camera distance accordingly.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer

local function applyMode(mode)
    if mode == "first" then
        player.CameraMaxZoomDistance = 0.5
        player.CameraMinZoomDistance = 0.5
    else
        player.CameraMaxZoomDistance = 30
        player.CameraMinZoomDistance = 8
    end
end

Remotes.UpdatePlayerData.OnClientEvent:Connect(function(d)
    if d.settingsCameraMode then applyMode(d.settingsCameraMode) end
end)

-- Hotkey: V toggles
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.V then
        local current = (player.CameraMaxZoomDistance == 0.5) and "first" or "third"
        local new = current == "first" and "third" or "first"
        applyMode(new)
        Remotes.RequestSettingChange:InvokeServer("settingsCameraMode", new)
    end
end)
