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

local function waitFor(globalName)
    while not _G[globalName] do task.wait() end
    return _G[globalName]
end
local DataHandler = waitFor("KittyRaiserData")

-- Receipt de-dup store
local receiptStore = DataStoreService:GetDataStore("KittyRaiserReceipts_v1")

-- Map DevProduct ID -> handler function
local DevProductHandlers = {}

local function awardChaos(player, amount)
    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) + amount
        d.totalRobuxSpent = (d.totalRobuxSpent or 0) + 1 -- approximate, real R$ via API
    end)    Remotes.NotifyClient:FireClient(player, "+" .. amount .. " Chaos!", "success")
end

local function awardHellTokens(player, amount)
    DataHandler.modify(player, function(d)
        d.hellTokens = (d.hellTokens or 0) + amount
        d.totalRobuxSpent = (d.totalRobuxSpent or 0) + 1
    end)
    Remotes.NotifyClient:FireClient(player, "+" .. amount .. " Hell Tokens!", "success")
end

local function resetPerks(player)
    DataHandler.modify(player, function(d)
        d.perks = {}
    end)
    Remotes.NotifyClient:FireClient(player, "Perks reset — pick again!", "success")
end

local function dailyDouble(player)
    -- Mark a 24h flag so DailyRewardSystem can double the next claim.
    DataHandler.modify(player, function(d)
        d.dailyDoubleUntil = os.time() + 86400
    end)
    Remotes.NotifyClient:FireClient(player, "Daily Reward 2x active for 24h!", "success")
end

-- Wire DevProducts (filled when IDs are known). Each handler is gated so
-- a 0-id (unconfigured) won't accidentally bind to product 0.
local function registerDevProducts()
    local IDS = GameConfig.DEVPRODUCT_IDS
    if IDS.CHAOS_5K   ~= 0 then DevProductHandlers[IDS.CHAOS_5K]   = function(p) awardChaos(p, 5000) end end
    if IDS.CHAOS_50K  ~= 0 then DevProductHandlers[IDS.CHAOS_50K]  = function(p) awardChaos(p, 50000) end end
    if IDS.CHAOS_500K ~= 0 then DevProductHandlers[IDS.CHAOS_500K] = function(p) awardChaos(p, 500000) end end
    if IDS.HELLTOKENS_100  ~= 0 then DevProductHandlers[IDS.HELLTOKENS_100]  = function(p) awardHellTokens(p, 100) end end
    if IDS.HELLTOKENS_1000 ~= 0 then DevProductHandlers[IDS.HELLTOKENS_1000] = function(p) awardHellTokens(p, 1000) end end
    if IDS.PERK_RESET   ~= 0 then DevProductHandlers[IDS.PERK_RESET]   = resetPerks end
    if IDS.DAILY_DOUBLE ~= 0 then DevProductHandlers[IDS.DAILY_DOUBLE] = dailyDouble end
    if IDS.REBIRTH_SKIP ~= 0 then
        DevProductHandlers[IDS.REBIRTH_SKIP] = function(player)
            DataHandler.modify(player, function(d)
                d.level = math.max(d.level, GameConfig.REBIRTH_REQUIRED_LEVEL)
                d.xp = 0
            end)
            Remotes.NotifyClient:FireClient(player, "Rebirth requirement skipped!", "success")
        end
    end
    local n = 0
    for _ in pairs(DevProductHandlers) do n = n + 1 end
    print(("[Monetization] %d dev products wired"):format(n))
end
registerDevProducts()

-- ProcessReceipt: must return PurchaseGranted or NotProcessedYet
MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

    local key = "p_" .. receiptInfo.PurchaseId

    -- Already processed?
    local alreadyProcessed = false
    local ok = pcall(function()
        receiptStore:UpdateAsync(key, function(old)
            if old then
                alreadyProcessed = true
                return old
            end
            return os.time()
        end)
    end)
    if not ok then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    if alreadyProcessed then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    local handler = DevProductHandlers[receiptInfo.ProductId]
    if not handler then
        warn("[Monetization] No handler for product", receiptInfo.ProductId)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local handled = pcall(function() handler(player) end)
    if handled then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- =====================================================================
-- GAMEPASS GRANT TABLE — single source for "what does each pass do"
-- {gamepassConfigKey, action(player), confirm-msg}
-- Skin-grant passes append to ownedSkins so the cosmetic shop reflects it.
-- =====================================================================
local function grantSkin(skinId)
    return function(player)
        DataHandler.modify(player, function(d)
            d.ownedSkins = d.ownedSkins or {}
            if not table.find(d.ownedSkins, skinId) then
                table.insert(d.ownedSkins, skinId)
            end
        end)
        DataHandler.replicateToClient(player)
    end
end

local GAMEPASS_GRANTS = {
    -- key            =  { action,                    confirm message }
    VIP              = { function() end,             "VIP active!  2x Chaos." },
    GANG_LEADER      = { grantSkin("GangLeader"),    "Gang Leader name tag unlocked." },
    ULTIMATE_CHAOS   = { function(p)
                            grantSkin("Pearl")(p)
                            -- VIP perks already work via UserOwnsGamePassAsync check
                         end,                         "Ultimate Chaos pack granted." },
    PEARL_SKIN       = { grantSkin("Pearl"),         "Pearl fur unlocked." },
    EMBER_SKIN       = { grantSkin("Ember"),         "Ember fur unlocked." },
    GOLD_SKIN        = { grantSkin("Gold"),          "Gold fur unlocked." },
    -- Legacy (id is 0 in config; guarded below)
    DEMON_SKIN       = { grantSkin("Demon"),         "Demon Cat unlocked!" },
    NEON_SKIN        = { grantSkin("Neon"),          "Neon Cat unlocked!" },
    HELLBORN_SKIN    = { grantSkin("Hellborn"),      "Hellborn Cat unlocked!" },
}

local function gamepassIdToKey(gamepassId)
    for key, configId in pairs(GameConfig.GAMEPASS_IDS) do
        if configId ~= 0 and configId == gamepassId then return key end
    end
    return nil
end

-- GamePass purchase listener (live grants)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, purchased)
    if not purchased then return end
    if not gamepassId or gamepassId == 0 then return end
    local key = gamepassIdToKey(gamepassId)
    if not key then
        warn("[Monetization] Gamepass purchased but key not in config:", gamepassId)
        return
    end
    local entry = GAMEPASS_GRANTS[key]
    if not entry then
        warn("[Monetization] Gamepass " .. key .. " has no GAMEPASS_GRANTS entry")
        return
    end
    pcall(function() entry[1](player) end)
    if entry[2] and entry[2] ~= "" then
        Remotes.NotifyClient:FireClient(player, entry[2], "success")
    end
end)

-- On player join, sync their existing GamePass ownership into ownedSkins
-- (covers prior purchases). Resolves gamepass id via the cosmetic's
-- gamepassKey field first, falling back to the legacy <SKINID>_SKIN guess.
Players.PlayerAdded:Connect(function(player)
    task.wait(2) -- let DataHandler load
    local data = DataHandler.getData(player)
    if not data then return end
    data.ownedSkins = data.ownedSkins or {}
    for skinId, skin in pairs(CosmeticConfig.Skins) do
        if skin.currency == "robux" then
            local gpKey = skin.gamepassKey or (string.upper(skinId) .. "_SKIN")
            local gpId = GameConfig.GAMEPASS_IDS[gpKey]
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

-- DevProduct purchase via remote (client-initiated prompt is fine, but server is source of truth)
Remotes.RequestUseDevProduct.OnServerEvent:Connect(function(player, productKey)
    local id = GameConfig.DEVPRODUCT_IDS[productKey]
    if not id or id == 0 then return end
    MarketplaceService:PromptProductPurchase(player, id)
end)

return true
