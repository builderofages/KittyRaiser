-- SettingsSystem.server.lua
-- Persists per-player audio + UI settings. Client reads these on join via
-- UpdatePlayerData.settings; can change them via RequestSettingChange.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local SharedUtil = require(ReplicatedStorage.Modules.SharedUtil)

local DataHandler = SharedUtil.waitForGlobal("KittyRaiserData", 30)
if not DataHandler then return end

local ALLOWED_KEYS = {
    settingsMusicOn = "boolean",
    settingsSFXOn = "boolean",
    settingsMusicVolume = "number",
    settingsSFXVolume = "number",
    settingsCameraMode = "string",   -- "third" or "first"
}

Remotes.RequestSettingChange.OnServerInvoke = function(player, key, value)
    if not SharedUtil.checkRate(player, "setting:" .. tostring(key), 0.2) then
        return false, "rate_limited"
    end
    local expected = ALLOWED_KEYS[key]
    if not expected then return false, "bad_key" end
    if type(value) ~= expected then return false, "bad_type" end
    if expected == "number" then
        value = math.clamp(value, 0, 1)
    elseif expected == "string" and key == "settingsCameraMode" then
        if value ~= "third" and value ~= "first" then return false, "bad_value" end
    end
    DataHandler.modify(player, function(d) d[key] = value end)
    return true, value
end

print("[SettingsSystem] online — " .. (function() local n=0; for _ in pairs(ALLOWED_KEYS) do n=n+1 end; return n end)() .. " settings keys")
