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
    end)
    Remotes.NotifyClient:FireClient(player, "+" .. amount .. " Chaos!", "success")
end

-- Wire DevProducts (filled when IDs are known)
local function registerDevProducts()
    if GameConfig.DEVPRODUCT_IDS.CHAOS_5K ~= 0 then
        DevProductHandlers[GameConfig.DEVPRODUCT_IDS.CHAOS_5K] = function(player) awardChaos(player, 5000) end
    end
    if GameConfig.DEVPRODUCT_IDS.CHAOS_50K ~= 0 then
        DevProductHandlers[GameConfig.DEVPRODUCT_IDS.CHAOS_50K] = function(player) awardChaos(player, 50000) end
    end
    if GameConfig.DEVPRODUCT_IDS.REBIRTH_SKIP ~= 0 then
        DevProductHandlers[GameConfig.DEVPRODUCT_IDS.REBIRTH_SKIP] = function(player)
            DataHandler.modify(player, function(d)
                d.level = math.max(d.level, GameConfig.REBIRTH_REQUIRED_LEVEL)
                d.xp = 0
            end)
            Remotes.NotifyClient:FireClient(player, "Rebirth requirement skipped!", "success")
        end
    end
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

-- GamePass purchase listener (live grants)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, purchased)
    if not purchased then return end
    -- Guard: if a config gamepass id is still 0 (unconfigured), don't false-match
    -- a purchased pass against the 0 placeholder.
    if not gamepassId or gamepassId == 0 then return end
    -- Demon skin
    if GameConfig.GAMEPASS_IDS.DEMON_SKIN ~= 0 and gamepassId == GameConfig.GAMEPASS_IDS.DEMON_SKIN then
        DataHandler.modify(player, function(d)
            if not table.find(d.ownedSkins, "Demon") then
                table.insert(d.ownedSkins, "Demon")
            end
        end)
        Remotes.NotifyClient:FireClient(player, "Demon Cat unlocked!", "success")
    elseif GameConfig.GAMEPASS_IDS.NEON_SKIN ~= 0 and gamepassId == GameConfig.GAMEPASS_IDS.NEON_SKIN then
        DataHandler.modify(player, function(d)
            if not table.find(d.ownedSkins, "Neon") then
                table.insert(d.ownedSkins, "Neon")
            end
        end)
        Remotes.NotifyClient:FireClient(player, "Neon Cat unlocked!", "success")
    elseif GameConfig.GAMEPASS_IDS.VIP ~= 0 and gamepassId == GameConfig.GAMEPASS_IDS.VIP then
        Remotes.NotifyClient:FireClient(player, "VIP active! 2x Chaos!", "success")
    end
end)

-- On player join, sync their existing GamePass ownership into ownedSkins (covers prior purchases)
Players.PlayerAdded:Connect(function(player)
    task.wait(2) -- let DataHandler load
    local data = DataHandler.getData(player)
    if not data then return end
    for skinId, skin in pairs(CosmeticConfig.Skins) do
        if skin.currency == "robux" then
            local gpId = GameConfig.GAMEPASS_IDS[string.upper(skinId) .. "_SKIN"]
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
