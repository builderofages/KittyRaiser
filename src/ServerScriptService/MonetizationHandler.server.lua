-- MonetizationHandler.server.lua
-- Processes GamePass ownership checks + DevProduct ProcessReceipt.
-- Place in: ServerScriptService > MonetizationHandler (Script)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local CosmeticConfig = require(ReplicatedStorage.Modules.CosmeticConfig)
local SharedUtil = require(ReplicatedStorage.Modules.SharedUtil)

local DataHandler = SharedUtil.waitForGlobal("KittyRaiserData", 30)
if not DataHandler then
    warn("[Monetization] DataHandler never came up; aborting init")
    return
end

GameConfig.validate()

-- Receipt de-dup store. We store transitions: nil -> "processing" -> "granted".
local receiptStore = DataStoreService:GetDataStore("KittyRaiserReceipts_v2")

-- Pending receipts for offline players: keyed by UserId
local pendingByUser = {}  -- {[userId] = {receiptInfo, receiptInfo, ...}}

-- Map DevProduct ID -> handler function. Each handler MUST be idempotent for the
-- same player given the same call; the receipt store enforces single-grant.
local DevProductHandlers = {}

local function awardChaos(player, amount)
    amount = math.max(0, math.floor(amount or 0))  -- never grant negative
    if amount <= 0 then return end
    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) + amount
        d.totalRobuxSpent = (d.totalRobuxSpent or 0) + 1
    end)
    Remotes.NotifyClient:FireClient(player, "+" .. amount .. " Chaos!", "success")
end

local function awardHellTokens(player, amount)
    amount = math.max(0, math.floor(amount or 0))
    if amount <= 0 then return end
    DataHandler.modify(player, function(d)
        d.hellTokens = (d.hellTokens or 0) + amount
    end)
    Remotes.NotifyClient:FireClient(player, "+" .. amount .. " Hell Tokens!", "success")
end

local function registerDevProducts()
    local IDS = GameConfig.DEVPRODUCT_IDS
    if IDS.CHAOS_5K   ~= 0 then DevProductHandlers[IDS.CHAOS_5K]   = function(p) awardChaos(p, 5000) end end
    if IDS.CHAOS_50K  ~= 0 then DevProductHandlers[IDS.CHAOS_50K]  = function(p) awardChaos(p, 50000) end end
    if IDS.CHAOS_500K ~= 0 then DevProductHandlers[IDS.CHAOS_500K] = function(p) awardChaos(p, 500000) end end
    if IDS.HELLTOKENS_100  ~= 0 then DevProductHandlers[IDS.HELLTOKENS_100]  = function(p) awardHellTokens(p, 100) end end
    if IDS.HELLTOKENS_1000 ~= 0 then DevProductHandlers[IDS.HELLTOKENS_1000] = function(p) awardHellTokens(p, 1000) end end
    if IDS.REBIRTH_SKIP ~= 0 then
        DevProductHandlers[IDS.REBIRTH_SKIP] = function(player)
            DataHandler.modify(player, function(d)
                d.level = math.max(d.level or 1, GameConfig.REBIRTH_REQUIRED_LEVEL)
                d.xp = 0
            end)
            Remotes.NotifyClient:FireClient(player, "Rebirth requirement skipped!", "success")
        end
    end
    if IDS.PERK_RESET ~= 0 then
        DevProductHandlers[IDS.PERK_RESET] = function(player)
            DataHandler.modify(player, function(d) d.perks = {} end)
            Remotes.NotifyClient:FireClient(player, "Perks reset!", "success")
        end
    end
    if IDS.DAILY_DOUBLE ~= 0 then
        DevProductHandlers[IDS.DAILY_DOUBLE] = function(player)
            DataHandler.modify(player, function(d) d.dailyDoubleUntil = os.time() + 86400 end)
            Remotes.NotifyClient:FireClient(player, "Daily Double active for 24h!", "success")
        end
    end
end
registerDevProducts()

-- Receipt processing core. Idempotent: marks receipt "granted" only if the
-- handler succeeds. If we see a "granted" receipt, it's a duplicate retry,
-- which we ack as PurchaseGranted. If "processing" is set and we crashed last
-- time, we reprocess.
local function processReceipt(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    local key = "p_" .. receiptInfo.PurchaseId

    -- read state first
    local stateOk, state = pcall(function() return receiptStore:GetAsync(key) end)
    if not stateOk then return Enum.ProductPurchaseDecision.NotProcessedYet end
    if state == "granted" then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    -- if player isn't here, queue and ask Roblox to retry later (it will,
    -- and they may have rejoined by then)
    if not player then
        pendingByUser[receiptInfo.PlayerId] = pendingByUser[receiptInfo.PlayerId] or {}
        table.insert(pendingByUser[receiptInfo.PlayerId], receiptInfo)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- mark processing BEFORE running the handler. If the server dies after this
    -- the next attempt sees "processing" and re-runs the handler exactly once
    -- (handlers are required to be idempotent for the same receipt).
    local markOk = pcall(function()
        receiptStore:UpdateAsync(key, function(old) return old or "processing" end)
    end)
    if not markOk then return Enum.ProductPurchaseDecision.NotProcessedYet end

    local handler = DevProductHandlers[receiptInfo.ProductId]
    if not handler then
        -- Don't let an unrecognized product trap us in an infinite retry loop.
        warn("[Monetization] No handler for product " .. tostring(receiptInfo.ProductId)
            .. " — granting and logging so it doesn't retry forever")
        pcall(function()
            receiptStore:UpdateAsync(key, function() return "granted" end)
        end)
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    local ok, err = pcall(handler, player)
    if not ok then
        warn("[Monetization] Handler errored for product "
            .. tostring(receiptInfo.ProductId) .. ": " .. tostring(err))
        return Enum.ProductPurchaseDecision.NotProcessedYet  -- Roblox retries
    end

    pcall(function()
        receiptStore:UpdateAsync(key, function() return "granted" end)
    end)

    DataHandler.modify(player, function(d)
        d.purchasedDevProductIds = d.purchasedDevProductIds or {}
        table.insert(d.purchasedDevProductIds, receiptInfo.ProductId)
    end)

    return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt

-- When players join, drain any pending receipts they had while offline.
Players.PlayerAdded:Connect(function(player)
    task.wait(3)
    local pending = pendingByUser[player.UserId]
    if not pending then return end
    pendingByUser[player.UserId] = nil
    for _, receiptInfo in ipairs(pending) do
        task.spawn(processReceipt, receiptInfo)
    end
end)

-- GamePass purchase listener (live grants). Only act on whitelisted ids.
local function grantSkinForGamepass(player, gamepassKey, skinId, message)
    if not CosmeticConfig.getSkin(skinId) then
        warn("[Monetization] Tried to grant unknown skin: " .. tostring(skinId))
        return
    end
    DataHandler.modify(player, function(d)
        d.ownedSkins = d.ownedSkins or {}
        if not table.find(d.ownedSkins, skinId) then
            table.insert(d.ownedSkins, skinId)
        end
    end)
    if message then
        Remotes.NotifyClient:FireClient(player, message, "success")
    end
end

local GAMEPASS_TO_SKIN = {
    [GameConfig.GAMEPASS_IDS.DEMON_SKIN]    = {skinId = "Demon",    label = "Demon Cat unlocked!"},
    [GameConfig.GAMEPASS_IDS.NEON_SKIN]     = {skinId = "Neon",     label = "Neon Cat unlocked!"},
    [GameConfig.GAMEPASS_IDS.HELLBORN_SKIN] = {skinId = "Hellborn", label = "Hellborn unlocked!"},
}
GAMEPASS_TO_SKIN[0] = nil  -- ignore unfilled placeholder ids

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, purchased)
    if not purchased or not player or not gamepassId then return end
    local mapping = GAMEPASS_TO_SKIN[gamepassId]
    if mapping then
        grantSkinForGamepass(player, nil, mapping.skinId, mapping.label)
    elseif gamepassId == GameConfig.GAMEPASS_IDS.VIP and gamepassId ~= 0 then
        Remotes.NotifyClient:FireClient(player, "VIP active! 2x Chaos!", "success")
    end
end)

-- On player join, sync existing GamePass ownership into ownedSkins. Use the
-- explicit gamepassKey from CosmeticConfig instead of constructing it from
-- the skin id (which broke for skins like "Hellborn" -> "HELLBORN_SKIN" only
-- coincidentally matched the convention).
Players.PlayerAdded:Connect(function(player)
    task.wait(3)
    local data = DataHandler.getData(player)
    if not data then return end
    for skinId, skin in pairs(CosmeticConfig.Skins) do
        if skin.currency == "robux" and skin.gamepassKey then
            local gpId = GameConfig.GAMEPASS_IDS[skin.gamepassKey]
            if gpId and gpId ~= 0 then
                local ok, owns = pcall(function()
                    return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gpId)
                end)
                if ok and owns and not table.find(data.ownedSkins, skinId) then
                    table.insert(data.ownedSkins, skinId)
                end
            end
        end
    end
    DataHandler.replicateToClient(player)
end)

-- Client-prompted DevProduct buy flow. Server is still source of truth via ProcessReceipt.
Remotes.RequestUseDevProduct.OnServerEvent:Connect(function(player, productKey)
    if not SharedUtil.checkRate(player, "useDevProduct", 0.5) then return end
    if type(productKey) ~= "string" or #productKey > 32 then return end
    local id = GameConfig.DEVPRODUCT_IDS[productKey]
    if not id or id == 0 then return end
    MarketplaceService:PromptProductPurchase(player, id)
end)

return true
