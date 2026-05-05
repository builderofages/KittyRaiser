-- MonetizationAudit.server.lua  v1
-- Validates every gamepass + dev product ID at boot via MarketplaceService.
-- Logs results so we know if any are missing/wrong.
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

task.spawn(function()
    task.wait(15)  -- let other systems boot first
    print("===== MONETIZATION AUDIT START =====")
    -- Gamepasses
    if GameConfig.GAMEPASS_IDS then
        for name, id in pairs(GameConfig.GAMEPASS_IDS) do
            if id and id ~= 0 then
                local ok, info = pcall(function()
                    return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
                end)
                if ok and info then
                    print(string.format("[Audit] GAMEPASS %s (id=%d) → %s — %d Robux — %s",
                        name, id, info.Name, info.PriceInRobux or 0, info.IsForSale and "ON SALE" or "NOT FOR SALE"))
                else
                    warn(string.format("[Audit] GAMEPASS %s (id=%d) → FAILED LOOKUP: %s", name, id, tostring(info)))
                end
            else
                warn("[Audit] GAMEPASS " .. name .. " has no ID (skipped)")
            end
        end
    end
    -- Dev products
    if GameConfig.DEVPRODUCT_IDS then
        for name, id in pairs(GameConfig.DEVPRODUCT_IDS) do
            if id and id ~= 0 then
                local ok, info = pcall(function()
                    return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
                end)
                if ok and info then
                    print(string.format("[Audit] DEVPRODUCT %s (id=%d) → %s — %d Robux",
                        name, id, info.Name, info.PriceInRobux or 0))
                else
                    warn(string.format("[Audit] DEVPRODUCT %s (id=%d) → FAILED LOOKUP: %s", name, id, tostring(info)))
                end
            else
                warn("[Audit] DEVPRODUCT " .. name .. " has no ID")
            end
        end
    end
    print("===== MONETIZATION AUDIT END =====")
end)
