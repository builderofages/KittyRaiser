-- PerkSystem.server.lua
-- Grants perk slots every 5 levels, presents picker, applies effects, allows reset.
-- Place in: ServerScriptService > PerkSystem (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PerkConfig = require(ReplicatedStorage.Modules.PerkConfig)
local SharedUtil = require(ReplicatedStorage.Modules.SharedUtil)

local DataHandler = SharedUtil.waitForGlobal("KittyRaiserData", 30)
if not DataHandler then return end

local PerkSystem = {}

-- Equip / pick perk for slot. Sequential rule: slot N can only be equipped if
-- slots 1..N-1 are already filled (no skipping).
Remotes.RequestEquipPerk.OnServerInvoke = function(player, slot, perkId)
    if not SharedUtil.checkRate(player, "equipPerk", GameConfig.REMOTE_RATE_LIMIT_SEC) then
        return false, "rate_limited"
    end
    if type(slot) ~= "number" or type(perkId) ~= "string" or #perkId > 64 then
        return false, "bad_args"
    end
    if slot ~= math.floor(slot) or slot < 1 or slot > 5 then
        return false, "bad_slot"
    end
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end

    local availableSlots = GameConfig.perkSlotsAtLevel(data.level or 1)
    if slot > availableSlots then return false, "slot_locked" end

    -- enforce sequential claim
    data.perks = data.perks or {}
    for i = 1, slot - 1 do
        if not data.perks[tostring(i)] then return false, "earlier_slot_unfilled" end
    end

    local options = PerkConfig.optionsForSlot(slot)
    if not options or not table.find(options, perkId) then
        return false, "invalid_perk_for_slot"
    end

    DataHandler.modify(player, function(d)
        d.perks = d.perks or {}
        d.perks[tostring(slot)] = perkId
    end)
    PerkSystem.applyStatsToCharacter(player)
    return true, nil
end

Remotes.RequestResetPerks.OnServerInvoke = function(player, useRobux)
    if not SharedUtil.checkRate(player, "resetPerks", 1.0) then return false, "rate_limited" end
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end
    if useRobux then
        local prodId = GameConfig.DEVPRODUCT_IDS.PERK_RESET
        if prodId == 0 then return false, "robux_product_unset" end
        return false, "use_client_prompt"
    else
        local cost = GameConfig.PERK_RESET_HELLTOKENS
        if cost < 0 or (data.hellTokens or 0) < cost then return false, "not_enough_helltokens" end
        DataHandler.modify(player, function(d)
            d.hellTokens = d.hellTokens - cost
            d.perks = {}
        end)
        return true, nil
    end
end

-- Atomic stat allocation. Re-read inside modify to prevent rapid-double-call
-- from going negative.
Remotes.RequestAllocStat.OnServerInvoke = function(player, statName)
    if not SharedUtil.checkRate(player, "allocStat", GameConfig.REMOTE_RATE_LIMIT_SEC) then
        return false, "rate_limited"
    end
    if type(statName) ~= "string" then return false, "bad_stat" end
    if not table.find(GameConfig.STAT_NAMES, statName) then return false, "bad_stat" end
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end

    local success
    DataHandler.modify(player, function(d)
        d.stats = d.stats or {}
        local current = d.stats[statName] or 0
        if (d.unspentStatPoints or 0) <= 0 or current >= GameConfig.STAT_MAX then
            success = false
            return
        end
        d.unspentStatPoints = d.unspentStatPoints - 1
        d.stats[statName] = current + 1
        success = true
    end)
    if not success then return false, "no_points_or_maxed" end
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
    local speedMult = 1 + PerkConfig.sumEffect(data.perks, "speedMult")  -- LightFeet etc
    local baseSpeed = (16 + (data.stats.Speed or 0) * GameConfig.STAT_EFFECTS.Speed.walkSpeedPerPoint) * speedMult
    hum.WalkSpeed = baseSpeed
    hum.JumpPower = 50 + (data.stats.Jump or 0) * GameConfig.STAT_EFFECTS.Jump.jumpPowerPerPoint
    -- Update the survival debuff baseline so reverting after low-vitals uses the boosted value.
    char:SetAttribute("BaseWalkSpeed", baseSpeed)
end

-- Level-up integration. We treat PrankSystem's update to data.level as the
-- single source of truth. The previous design also ran a parallel "watcher"
-- that double-granted stat points on each level. We replace it with a direct
-- LevelUp listener using data attributes.
local lastSeenLevel = {}

local function ensureLevelGrants(player, prevLevel, newLevel)
    if newLevel <= prevLevel then return end
    DataHandler.modify(player, function(d)
        d.unspentStatPoints = (d.unspentStatPoints or 0) + GameConfig.STATS_PER_LEVEL * (newLevel - prevLevel)
    end)
    for newLvl = prevLevel + 1, newLevel do
        if newLvl % GameConfig.PERK_GRANT_EVERY == 0 then
            local slot = math.floor(newLvl / GameConfig.PERK_GRANT_EVERY)
            local options = PerkConfig.optionsForSlot(slot)
            if options and #options > 0 then
                Remotes.PerkSlotEarned:FireClient(player, slot, options)
            end
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        PerkSystem.applyStatsToCharacter(player)
    end)
end)

Players.PlayerRemoving:Connect(function(p) lastSeenLevel[p.UserId] = nil end)

-- Throttled change-detector. Idempotent: only fires for the *delta* in level
-- since we last saw it (so it never double-grants for the same level).
-- 0.5s tick (was 1s) so quick double-level-ups can't slip past unnoticed if a
-- single prank pushes the player across two thresholds.
task.spawn(function()
    while true do
        task.wait(0.5)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = DataHandler.getData(player)
            if data then
                local prev = lastSeenLevel[player.UserId]
                if prev == nil then
                    lastSeenLevel[player.UserId] = data.level
                elseif data.level > prev then
                    ensureLevelGrants(player, prev, data.level)
                    lastSeenLevel[player.UserId] = data.level
                end
            end
        end
    end
end)

_G.KittyRaiserPerks = PerkSystem
return PerkSystem
