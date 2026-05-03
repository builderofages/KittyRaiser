-- CodeSystem.server.lua
-- Server-authoritative promo code redemption. Uses DataHandler to track which
-- codes a player has already used; uses a DataStore counter for global use caps.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local CodeConfig = require(ReplicatedStorage.Modules.CodeConfig)
local SharedUtil = require(ReplicatedStorage.Modules.SharedUtil)

local DataHandler = SharedUtil.waitForGlobal("KittyRaiserData", 30)
if not DataHandler then return end

local globalCounter = DataStoreService:GetDataStore("KittyRaiserCodes_v1")

Remotes.RequestRedeemCode.OnServerInvoke = function(player, rawCode)
    if not SharedUtil.checkRate(player, "redeemCode", 1.0) then
        return false, "rate_limited"
    end
    if type(rawCode) ~= "string" or #rawCode > 64 then
        return false, "bad_input"
    end
    local cfg, key = CodeConfig.get(rawCode)
    if not cfg then return false, "invalid_code" end

    if cfg.expiry and cfg.expiry > 0 and os.time() > cfg.expiry then
        return false, "expired"
    end

    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end
    data.redeemedCodes = data.redeemedCodes or {}
    if table.find(data.redeemedCodes, key) then return false, "already_redeemed" end

    -- Atomic global counter for capped codes.
    if cfg.max and cfg.max > 0 then
        local ok, used = pcall(function()
            return globalCounter:UpdateAsync(key, function(old)
                old = old or 0
                if old >= cfg.max then return nil end  -- cap hit, abort the update
                return old + 1
            end)
        end)
        if not ok or used == nil then
            return false, "max_redemptions_reached"
        end
    end

    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) + (cfg.chaos or 0)
        d.hellTokens = (d.hellTokens or 0) + (cfg.hellTokens or 0)
        d.redeemedCodes = d.redeemedCodes or {}
        table.insert(d.redeemedCodes, key)
    end)

    Remotes.NotifyClient:FireClient(player, cfg.message or "Code redeemed!", "success")
    return true, cfg.message
end

print("[CodeSystem] online — " .. (function() local n=0; for _ in pairs(CodeConfig.Codes) do n=n+1 end; return n end)() .. " codes registered")
