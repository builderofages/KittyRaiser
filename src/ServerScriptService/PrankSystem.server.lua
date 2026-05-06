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

local function waitFor(globalName)
    while not _G[globalName] do task.wait() end
    return _G[globalName]
end

local DataHandler = waitFor("KittyRaiserData")
local AntiCheat = waitFor("KittyRaiserAntiCheat")
local SummonSystem = waitFor("KittyRaiserSummon")

local PrankSystem = {}

local function hasVIP(player)
    local vipId = GameConfig.GAMEPASS_IDS.VIP
    if vipId == 0 then return false end
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, vipId)
    end)
    return ok and owns or false
end

local function awardChaosAndXP(player, baseChaos)
    local data = DataHandler.getData(player)
    if not data then return 0, 0 end

    -- Multiplier from skin + rebirths + VIP
    local skinMult = CosmeticConfig.getMultiplier(data.equippedSkin or "Default")
    local totalMult = GameConfig.computeMultiplier(data.rebirths or 0, hasVIP(player)) * skinMult

    local chaosGained = math.floor(baseChaos * totalMult)

    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) + chaosGained
        d.totalPranks = (d.totalPranks or 0) + 1
        local xpGain = GameConfig.PRANK_XP_PER_HIT
        d.xp = (d.xp or 0) + xpGain
        -- Level up loop
        while d.level < GameConfig.LEVEL_CAP and d.xp >= GameConfig.xpRequired(d.level) do
            d.xp = d.xp - GameConfig.xpRequired(d.level)
            d.level = d.level + 1
            -- Determine newly unlocked pranks
            local unlocked = {}
            for _, name in ipairs(PrankConfig.Order) do
                if PrankConfig.Pranks[name].unlockLevel == d.level then
                    table.insert(unlocked, name)
                end
            end
            Remotes.LevelUp:FireClient(player, d.level, unlocked)
            if _G.KittyRaiserBumpLevelUp then
                pcall(_G.KittyRaiserBumpLevelUp, player)
            end
        end
    end)
    return chaosGained, GameConfig.PRANK_XP_PER_HIT
end

function PrankSystem.handlePrankRequest(player, prankName, targetModel)
    if AntiCheat.isSuspended(player) then
        Remotes.PrankFailed:FireClient(player, "suspended")
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

    -- Level lock
    if data.level < prank.unlockLevel then
        Remotes.PrankFailed:FireClient(player, "level_locked")
        return
    end

    -- Rate limit
    local rlOk = AntiCheat.checkRateLimit(player)
    if not rlOk then
        Remotes.PrankFailed:FireClient(player, "rate_limited")
        return
    end

    -- Cooldown
    local cdOk = AntiCheat.checkPrankCooldown(player, prankName, prank.cooldown)
    if not cdOk then
        Remotes.PrankFailed:FireClient(player, "cooldown")
        return
    end

    -- NPC validity
    if not AntiCheat.isValidNPC(targetModel) then
        Remotes.PrankFailed:FireClient(player, "invalid_target")
        return
    end

    -- Distance
    local primary = targetModel.PrimaryPart or targetModel:FindFirstChild("HumanoidRootPart")
    -- Force a teleport sanity check at prank time too (Heartbeat sample
    -- can miss between-frame teleport+prank exploits).
    AntiCheat.checkTeleport(player)
    local distOk, distErr = AntiCheat.checkPrankDistance(player, primary, prank.rangeStuds)
    if not distOk then
        Remotes.PrankFailed:FireClient(player, distErr or "out_of_range")
        return
    end

    -- All checks pass — award + mark.
    -- Boss targets give bigger chaos via SummonSystem.getRewardMultiplier.
    local rewardMult = (SummonSystem.getRewardMultiplier and SummonSystem.getRewardMultiplier(targetModel)) or 1
    -- EventScheduler "RUSH HOUR" buff: workspace.EventRushHour=true -> 1.5x.
    if workspace:GetAttribute("EventRushHour") then
        rewardMult = rewardMult * 1.5
    end
    -- v3.82 WorldPowerups "chaos_x2" buff: per-player attribute timeout.
    local x2Until = player:GetAttribute("ChaosX2Until")
    if x2Until and os.clock() < x2Until then
        rewardMult = rewardMult * 2
    end
    local chaos, xp = awardChaosAndXP(player, prank.baseChaos * rewardMult)
    -- v3.69: NPC HP system. Non-boss NPCs start at 3 HP. Each prank reduces by 1.
    -- Only flag Pranked (which kills/ragdolls them) when HP hits 0. Player gets
    -- chaos+XP per HIT, but only the killing blow triggers cleanup.
    if not targetModel:GetAttribute("Boss") then
        local npcHp = targetModel:GetAttribute("NpcHp")
        if not npcHp then
            npcHp = 3
            targetModel:SetAttribute("NpcHp", npcHp)
        end
        npcHp = npcHp - 1
        targetModel:SetAttribute("NpcHp", math.max(0, npcHp))
        if npcHp > 0 then
            -- Show floating damage number above NPC head
            local head = targetModel:FindFirstChild("Head")
            if head then
                local g = Instance.new("BillboardGui")
                g.Size = UDim2.new(0, 60, 0, 24)
                g.AlwaysOnTop = true
                g.StudsOffset = Vector3.new(0, 1.5, 0)
                g.Parent = head
                local lbl = Instance.new("TextLabel", g)
                lbl.Size = UDim2.new(1, 0, 1, 0)
                lbl.BackgroundTransparency = 1
                lbl.Text = "-1 HP (" .. npcHp .. " left)"
                lbl.Font = Enum.Font.GothamBlack
                lbl.TextScaled = true
                lbl.TextColor3 = Color3.fromRGB(255, 200, 60)
                lbl.TextStrokeTransparency = 0
                game:GetService("Debris"):AddItem(g, 1.2)
            end
            -- Award chaos+XP for the hit but DON'T mark as Pranked yet
            -- (already awarded earlier in awardChaosAndXP at the top of handlePrankRequest)
            return  -- skip markPranked, NPC is still alive
        end
    end
    SummonSystem.markPranked(targetModel)

    -- Quest tracker hook (no-op if QuestSystem hasn't loaded)
    if _G.KittyRaiserBumpQuest then
        pcall(_G.KittyRaiserBumpQuest, player, "any_prank", 1)
        pcall(_G.KittyRaiserBumpQuest, player, "specific_prank", 1, prankName)
    end

    -- Heat / cop pursuit hook
    if _G.KittyRaiserAddHeat then
        pcall(_G.KittyRaiserAddHeat, player)
    end

    -- Squad-combo detection (Phase-12): if any other player pranked within
    -- 3s and 80 studs, broadcast SQUAD COMBO to both/all.
    local now = os.clock()
    PrankSystem._recentPranks = PrankSystem._recentPranks or {}
    local squadHits = {}
    for _, recent in ipairs(PrankSystem._recentPranks) do
        if (now - recent.t) <= 3.0
           and recent.userId ~= player.UserId
           and (recent.pos - primary.Position).Magnitude <= 80 then
            table.insert(squadHits, recent.userId)
        end
    end
    table.insert(PrankSystem._recentPranks, {
        userId = player.UserId, t = now, pos = primary.Position
    })
    if #PrankSystem._recentPranks > 32 then
        table.remove(PrankSystem._recentPranks, 1)
    end
    local squadBonusMult = 1
    if #squadHits > 0 then
        squadBonusMult = 1.5
        local participants = { player.UserId }
        for _, uid in ipairs(squadHits) do table.insert(participants, uid) end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character and p.Character.PrimaryPart
               and (p.Character.PrimaryPart.Position - primary.Position).Magnitude < 200 then
                Remotes.EventBroadcast:FireClient(p, "squad_combo", {
                    count = #participants,
                    actorName = player.DisplayName,
                    targetCFrame = primary.CFrame,
                })
            end
        end
    end

    -- Tell client to play effects
    local fxPayload = {
        prank = prankName,
        targetCFrame = primary.CFrame,
        chaosGained = chaos,
        screenShake = prank.screenShake,
        actorName = player.DisplayName,
        actorUserId = player.UserId,
        squadMult = squadBonusMult,
    }
    Remotes.PrankRegistered:FireClient(player, prankName, targetModel, chaos, fxPayload)

    -- Tell ALL clients in range to see the splash effect (so it's social)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local pChar = p.Character
            if pChar and pChar.PrimaryPart then
                if (pChar.PrimaryPart.Position - primary.Position).Magnitude < 80 then
                    Remotes.PrankRegistered:FireClient(p, prankName, targetModel, 0, fxPayload)
                end
            end
        end
    end
end

Remotes.RequestPrank.OnServerEvent:Connect(function(player, prankName, targetModel)
    PrankSystem.handlePrankRequest(player, prankName, targetModel)
end)

return PrankSystem
