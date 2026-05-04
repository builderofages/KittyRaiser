-- CodeRedemption.server.lua  v1 — promo code redemption.
--
-- Server-authoritative: client fires RequestRedeemCode with a code string,
-- server validates against CODES table, awards rewards if valid + not yet
-- claimed by this player. Per-player claim list persists via DataHandler.
--
-- Add new codes by extending CODES table. Codes are case-insensitive.
-- Grants chaos / hellTokens / specific skin via reward fields.
--
-- Place in: ServerScriptService > CodeRedemption (Script). Auto-runs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- =====================================================================
-- CODE TABLE — edit to add launch / event / streamer codes.
-- =====================================================================
local CODES = {
    LAUNCH      = {chaos = 5000,   hellTokens = 10,  message = "LAUNCH BONUS! +5K chaos +10 HT"},
    KITTYRAISER = {chaos = 2500,   hellTokens = 5,   message = "+2,500 CHAOS +5 HT"},
    NYAA        = {chaos = 1000,   hellTokens = 0,   message = "+1,000 CHAOS"},
    MEOW        = {chaos = 500,    hellTokens = 0,   message = "+500 CHAOS"},
    PURRFECT    = {chaos = 0,      hellTokens = 25,  message = "+25 HELL TOKENS"},
    GOLDENHOUR  = {chaos = 7500,   hellTokens = 0,   message = "+7,500 CHAOS  -  golden hour bonus"},
    -- Add more as you launch events. Players retain claimed list per-uid.
}

-- =====================================================================
-- REMOTE EVENT — created lazily under the existing RemoteEventsFolder so
-- the RemoteEvents module (which runs first) doesn't need to be edited.
-- =====================================================================
local function ensureRemote(name, kind)
    local folder = ReplicatedStorage:FindFirstChild("RemoteEventsFolder")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "RemoteEventsFolder"
        folder.Parent = ReplicatedStorage
    end
    local existing = folder:FindFirstChild(name)
    if existing then return existing end
    local r = Instance.new(kind)
    r.Name = name
    r.Parent = folder
    return r
end

local RequestRedeemCode = ensureRemote("RequestRedeemCode", "RemoteFunction")

-- =====================================================================
-- DATAHANDLER HOOK — wait for the global to populate (DataHandler exposes
-- itself as _G.KittyRaiserData) so we can read/write claimed-codes list.
-- =====================================================================
local DataHandler
task.spawn(function()
    while not _G.KittyRaiserData do task.wait() end
    DataHandler = _G.KittyRaiserData
end)

local function notifyClient(player, msg, kind)
    local Modules = ReplicatedStorage:FindFirstChild("Modules")
    local RE = Modules and Modules:FindFirstChild("RemoteEvents")
    if not RE then return end
    local ok, Remotes = pcall(require, RE)
    if ok and Remotes and Remotes.NotifyClient then
        Remotes.NotifyClient:FireClient(player, msg, kind or "info")
    end
end

RequestRedeemCode.OnServerInvoke = function(player, codeRaw)
    if typeof(codeRaw) ~= "string" then return false, "invalid_input" end
    local code = string.upper(codeRaw):gsub("%s+", "")
    if #code == 0 or #code > 32 then return false, "invalid_input" end
    local entry = CODES[code]
    if not entry then return false, "invalid_code" end
    if not DataHandler then return false, "data_loading" end
    local data = DataHandler.getData(player)
    if not data then return false, "data_loading" end
    data.redeemedCodes = data.redeemedCodes or {}
    if data.redeemedCodes[code] then
        notifyClient(player, "ALREADY REDEEMED", "warn")
        return false, "already_redeemed"
    end
    -- Apply reward
    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) + (entry.chaos or 0)
        d.hellTokens  = (d.hellTokens  or 0) + (entry.hellTokens or 0)
        d.redeemedCodes = d.redeemedCodes or {}
        d.redeemedCodes[code] = os.time()
    end)
    notifyClient(player, entry.message or ("CODE REDEEMED: " .. code), "good")
    return true, entry.message or "redeemed"
end

print("[CodeRedemption v1] online — " .. (function()
    local n = 0; for _ in pairs(CODES) do n = n + 1 end; return n
end)() .. " active codes")
