-- RebirthHandler.server.lua
-- Handles rebirth requests, validates eligibility, applies prestige.
-- Place in: ServerScriptService > RebirthHandler (Script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local function waitFor(globalName)
    while not _G[globalName] do task.wait() end
    return _G[globalName]
end
local DataHandler = waitFor("KittyRaiserData")

Remotes.RequestRebirth.OnServerInvoke = function(player)
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end

    if data.level < GameConfig.REBIRTH_REQUIRED_LEVEL then
        return false, "level_too_low"
    end

    if data.rebirths >= GameConfig.REBIRTH_SOFT_CAP then
        return false, "soft_cap_reached"
    end

    DataHandler.modify(player, function(d)
        d.rebirths = (d.rebirths or 0) + 1
        d.level = 1
        d.xp = 0
        -- Keep chaos points across rebirths so player feels progress
        -- Drop ownedSkins, equippedSkin remain
    end)

    local newData = DataHandler.getData(player)
    local newMult = GameConfig.computeMultiplier(newData.rebirths, false)
    Remotes.RebirthCompleted:FireClient(player, newData.rebirths, newMult)
    return true, newData.rebirths
end

return true
