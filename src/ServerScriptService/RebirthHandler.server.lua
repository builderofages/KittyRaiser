-- RebirthHandler.server.lua
-- Handles rebirth requests, validates eligibility, applies prestige.
-- Place in: ServerScriptService > RebirthHandler (Script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local CosmeticConfig = require(ReplicatedStorage.Modules.CosmeticConfig)
local MarketplaceService = game:GetService("MarketplaceService")

local function waitFor(globalName)
    while not _G[globalName] do task.wait() end
    return _G[globalName]
end
local DataHandler = waitFor("KittyRaiserData")

local function hasVIP(player)
    local vipId = GameConfig.GAMEPASS_IDS.VIP
    if not vipId or vipId == 0 then return false end
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, vipId)
    end)
    return ok and owns or false
end

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
        -- Keep chaos points across rebirths so player feels progress.
        -- Verify equippedSkin is in ownedSkins; otherwise reset to Default
        -- (defensive against stale state).
        if d.equippedSkin and d.equippedSkin ~= "Default" then
            local owned = false
            for _, s in ipairs(d.ownedSkins or {}) do
                if s == d.equippedSkin then owned = true; break end
            end
            if not owned then d.equippedSkin = "Default" end
        end
    end)

    local newData = DataHandler.getData(player)
    local newMult = GameConfig.computeMultiplier(newData.rebirths, hasVIP(player))
    Remotes.RebirthCompleted:FireClient(player, newData.rebirths, newMult)
    return true, newData.rebirths
end

return true
