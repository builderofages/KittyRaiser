-- RebirthHandler.server.lua
-- Handles rebirth requests, validates eligibility, applies prestige.
-- Place in: ServerScriptService > RebirthHandler (Script)

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local SharedUtil = require(ReplicatedStorage.Modules.SharedUtil)

local DataHandler = SharedUtil.waitForGlobal("KittyRaiserData", 30)
if not DataHandler then return end

local function hasVIP(player)
    local id = GameConfig.GAMEPASS_IDS.VIP
    if id == 0 then return false end
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
    end)
    return ok and owns or false
end

Remotes.RequestRebirth.OnServerInvoke = function(player)
    if not SharedUtil.checkRate(player, "rebirth", 1.0) then
        return false, "rate_limited"
    end
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end

    if (data.level or 1) < GameConfig.REBIRTH_REQUIRED_LEVEL then
        return false, "level_too_low"
    end
    if (data.rebirths or 0) >= GameConfig.REBIRTH_SOFT_CAP then
        return false, "soft_cap_reached"
    end

    local cost = GameConfig.rebirthChaosCost(data.rebirths or 0)
    if (data.chaosPoints or 0) < cost then
        return false, "insufficient_chaos", cost
    end

    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) - cost
        d.rebirths = (d.rebirths or 0) + 1
        d.level = 1
        d.xp = 0
        d.unspentStatPoints = 0
        d.stats = {Speed=0, Jump=0, Luck=0, Strength=0, Agility=0}
        d.perks = {}
    end)

    local newData = DataHandler.getData(player)
    local luck = (newData.stats and newData.stats.Luck) or 0
    local newMult = GameConfig.computeMultiplier(newData.rebirths, hasVIP(player), luck)
    Remotes.RebirthCompleted:FireClient(player, newData.rebirths, newMult)
    return true, newData.rebirths
end

return true
