-- PrankSystem.server.lua
-- Receives prank requests from client, validates, awards Chaos & XP, fires effect events.
-- Place in: ServerScriptService > PrankSystem (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local PrankConfig = require(ReplicatedStorage.Modules.PrankConfig)
local CosmeticConfig = require(ReplicatedStorage.Modules.CosmeticConfig)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local SharedUtil = require(ReplicatedStorage.Modules.SharedUtil)

local DataHandler = SharedUtil.waitForGlobal("KittyRaiserData", 30)
local AntiCheat = SharedUtil.waitForGlobal("KittyRaiserAntiCheat", 30)
local SummonSystem = SharedUtil.waitForGlobal("KittyRaiserSummon", 30)
if not (DataHandler and AntiCheat and SummonSystem) then
    warn("[PrankSystem] One of DataHandler/AntiCheat/SummonSystem failed to init; aborting")
    return
end

local PrankSystem = {}

local MAX_LEVELUPS_PER_PRANK = 5  -- cap RemoteEvent fan-out from a giant XP grant

-- Cache VIP ownership per player; UserOwnsGamePassAsync hits the network and
-- the result rarely changes within a session.
local vipCache = {}
local function hasVIP(player)
    if vipCache[player.UserId] ~= nil then return vipCache[player.UserId] end
    local vipId = GameConfig.GAMEPASS_IDS.VIP
    if vipId == 0 then vipCache[player.UserId] = false; return false end
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, vipId)
    end)
    local result = (ok and owns) or false
    vipCache[player.UserId] = result
    return result
end
Players.PlayerRemoving:Connect(function(p) vipCache[p.UserId] = nil end)

local function awardChaosAndXP(player, baseChaos)
    local data = DataHandler.getData(player)
    if not data then return 0, 0 end

    local skinMult = math.max(0, CosmeticConfig.getMultiplier(data.equippedSkin or "Default") or 1)
    local luckStat = (data.stats and data.stats.Luck) or 0
    local weatherMult = (_G.KittyRaiserGetWeatherMult and _G.KittyRaiserGetWeatherMult()) or 1
    local totalMult = GameConfig.computeMultiplier(data.rebirths or 0, hasVIP(player), luckStat)
        * skinMult * weatherMult

    local chaosGained = math.max(0, math.floor(baseChaos * totalMult))

    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) + chaosGained
        d.totalPranks = (d.totalPranks or 0) + 1
        d.xp = (d.xp or 0) + GameConfig.PRANK_XP_PER_HIT

        local levelUps = 0
        while d.level < GameConfig.LEVEL_CAP
            and d.xp >= GameConfig.xpRequired(d.level)
            and levelUps < MAX_LEVELUPS_PER_PRANK
        do
            d.xp = d.xp - GameConfig.xpRequired(d.level)
            d.level = d.level + 1
            levelUps = levelUps + 1
            local unlocked = {}
            for _, name in ipairs(PrankConfig.Order) do
                if PrankConfig.Pranks[name].unlockLevel == d.level then
                    table.insert(unlocked, name)
                end
            end
            Remotes.LevelUp:FireClient(player, d.level, unlocked)
        end
        -- if we still have surplus XP after the batch, clamp it so subsequent
        -- pranks still benefit from level-ups normally
        if levelUps >= MAX_LEVELUPS_PER_PRANK and d.level < GameConfig.LEVEL_CAP then
            d.xp = math.min(d.xp, GameConfig.xpRequired(d.level) - 1)
        end
    end)
    if _G.KittyRaiserMarkLeaderboardDirty then _G.KittyRaiserMarkLeaderboardDirty() end
    return chaosGained, GameConfig.PRANK_XP_PER_HIT
end

function PrankSystem.handlePrankRequest(player, prankName, targetModel)
    if AntiCheat.isSuspended(player) then
        Remotes.PrankFailed:FireClient(player, "suspended")
        return
    end

    if type(prankName) ~= "string" or #prankName > 32 then
        Remotes.PrankFailed:FireClient(player, "invalid_prank")
        return
    end

    local prank = PrankConfig.getPrank(prankName)
    if not prank then
        Remotes.PrankFailed:FireClient(player, "invalid_prank")
        return
    end

    local data = DataHandler.getData(player)
    if not data then
        Remotes.PrankFailed:FireClient(player, "no_data")
        return
    end

    if data.level < prank.unlockLevel then
        Remotes.PrankFailed:FireClient(player, "level_locked")
        return
    end

    if not AntiCheat.checkRateLimit(player) then
        Remotes.PrankFailed:FireClient(player, "rate_limited")
        return
    end

    if not AntiCheat.checkPrankCooldown(player, prankName, prank.cooldown) then
        Remotes.PrankFailed:FireClient(player, "cooldown")
        return
    end

    -- NPC validity (now requires registry membership + ownership match)
    local valid, vErr = AntiCheat.isValidNPC(targetModel, player)
    if not valid then
        Remotes.PrankFailed:FireClient(player, vErr or "invalid_target")
        return
    end
    if not SummonSystem.isRegistered(targetModel) then
        Remotes.PrankFailed:FireClient(player, "unregistered_target")
        return
    end

    local primary = targetModel.PrimaryPart or targetModel:FindFirstChild("HumanoidRootPart")
    if not primary then
        Remotes.PrankFailed:FireClient(player, "no_primary_part")
        return
    end
    local distOk, distErr = AntiCheat.checkPrankDistance(player, primary, prank.rangeStuds)
    if not distOk then
        Remotes.PrankFailed:FireClient(player, distErr or "out_of_range")
        return
    end

    -- ATOMIC GUARD: claim the NPC BEFORE awarding so two simultaneous pranks
    -- against the same NPC can't both pass validation.
    if not SummonSystem.markPranked(targetModel) then
        Remotes.PrankFailed:FireClient(player, "already_pranked")
        return
    end

    local chaos = awardChaosAndXP(player, prank.baseChaos)

    -- Sanity: never broadcast bogus CFrames
    local cf = primary.CFrame
    if not cf or cf.Position.Magnitude > 100000 then
        cf = CFrame.new(0, 0, 0)
    end

    local fxPayload = {
        prank = prankName,
        targetCFrame = cf,
        chaosGained = chaos,
        screenShake = prank.screenShake or 0,
    }
    Remotes.PrankRegistered:FireClient(player, prankName, targetModel, chaos, fxPayload)

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local pChar = p.Character
            if pChar and pChar.PrimaryPart
                and (pChar.PrimaryPart.Position - primary.Position).Magnitude < 80
            then
                Remotes.PrankRegistered:FireClient(p, prankName, targetModel, 0, fxPayload)
            end
        end
    end
end

Remotes.RequestPrank.OnServerEvent:Connect(function(player, prankName, targetModel)
    PrankSystem.handlePrankRequest(player, prankName, targetModel)
end)

return PrankSystem
