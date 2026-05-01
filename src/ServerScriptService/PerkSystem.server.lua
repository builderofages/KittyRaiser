-- PerkSystem.server.lua
-- Grants perk slots every 5 levels, presents picker, applies effects, allows reset.
-- Place in: ServerScriptService > PerkSystem (Script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PerkConfig = require(ReplicatedStorage.Modules.PerkConfig)

local function waitFor(g) while not _G[g] do task.wait() end return _G[g] end
local DataHandler = waitFor("KittyRaiserData")

local PerkSystem = {}

-- Equip / pick perk for slot
Remotes.RequestEquipPerk.OnServerInvoke = function(player, slot, perkId)
    if type(slot) ~= "number" or not perkId then return false, "bad_args" end
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end
    local availableSlots = GameConfig.perkSlotsAtLevel(data.level or 1)
    if slot > availableSlots then return false, "slot_locked" end
    local options = PerkConfig.optionsForSlot(slot)
    if not options or not table.find(options, perkId) then return false, "invalid_perk_for_slot" end
    DataHandler.modify(player, function(d)
        d.perks = d.perks or {}
        d.perks[tostring(slot)] = perkId  -- store keys as strings (DataStore quirk)
    end)
    return true, nil
end

-- Reset all perks (Hell Tokens cost or Robux)
Remotes.RequestResetPerks.OnServerInvoke = function(player, useRobux)
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end
    if useRobux then
        local prodId = GameConfig.DEVPRODUCT_IDS.PERK_RESET
        if prodId == 0 then return false, "robux_product_unset" end
        -- Server can't directly charge; needs PromptProductPurchase via client.
        -- For server-side flow, the client should call MarketplaceService:PromptProductPurchase first then we await ProcessReceipt.
        return false, "use_client_prompt"
    else
        local cost = GameConfig.PERK_RESET_HELLTOKENS
        if (data.hellTokens or 0) < cost then return false, "not_enough_helltokens" end
        DataHandler.modify(player, function(d)
            d.hellTokens = d.hellTokens - cost
            d.perks = {}
        end)
        return true, nil
    end
end

-- Stat allocation (each level gives 1 unspent stat point + 5 levels gives a perk slot)
Remotes.RequestAllocStat.OnServerInvoke = function(player, statName)
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end
    if not table.find(GameConfig.STAT_NAMES, statName) then return false, "bad_stat" end
    if (data.unspentStatPoints or 0) <= 0 then return false, "no_points" end
    if (data.stats[statName] or 0) >= GameConfig.STAT_MAX then return false, "maxed" end
    DataHandler.modify(player, function(d)
        d.unspentStatPoints = d.unspentStatPoints - 1
        d.stats[statName] = (d.stats[statName] or 0) + 1
    end)
    -- Apply on character
    PerkSystem.applyStatsToCharacter(player)
    return true, nil
end

function PerkSystem.applyStatsToCharacter(player)
    local data = DataHandler.getData(player)
    if not data or not data.stats then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    -- Speed
    hum.WalkSpeed = 16 + (data.stats.Speed or 0) * GameConfig.STAT_EFFECTS.Speed.walkSpeedPerPoint
    -- Jump
    hum.JumpPower = 50 + (data.stats.Jump or 0) * GameConfig.STAT_EFFECTS.Jump.jumpPowerPerPoint
end

-- Hook into LevelUp event to grant stat points + perk slots
Remotes.LevelUp.OnServerEvent:Connect(function() end)  -- noop, but let server scripts watch
local function grantOnLevelUp(player)
    local data = DataHandler.getData(player)
    if not data then return end
    DataHandler.modify(player, function(d)
        d.unspentStatPoints = (d.unspentStatPoints or 0) + GameConfig.STATS_PER_LEVEL
    end)
    -- If multiple of 5, prompt perk picker
    if data.level % GameConfig.PERK_GRANT_EVERY == 0 then
        local slot = math.floor(data.level / GameConfig.PERK_GRANT_EVERY)
        Remotes.PerkSlotEarned:FireClient(player, slot, PerkConfig.optionsForSlot(slot))
    end
end

-- We can't directly listen to PrankSystem's level-up easily without a global pubsub.
-- Use a watcher on data.level.
local Players = game:GetService("Players")
local lastSeenLevel = {}
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        PerkSystem.applyStatsToCharacter(player)
    end)
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = DataHandler.getData(player)
            if data then
                local prev = lastSeenLevel[player.UserId] or data.level
                if data.level > prev then
                    -- Level up happened
                    for newLvl = prev+1, data.level do
                        DataHandler.modify(player, function(d)
                            d.unspentStatPoints = (d.unspentStatPoints or 0) + GameConfig.STATS_PER_LEVEL
                        end)
                        if newLvl % GameConfig.PERK_GRANT_EVERY == 0 then
                            local slot = math.floor(newLvl / GameConfig.PERK_GRANT_EVERY)
                            Remotes.PerkSlotEarned:FireClient(player, slot, PerkConfig.optionsForSlot(slot))
                        end
                    end
                end
                lastSeenLevel[player.UserId] = data.level
            end
        end
    end
end)

_G.KittyRaiserPerks = PerkSystem
return PerkSystem
