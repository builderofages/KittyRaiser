-- BattlePassSystem.server.lua  v1 — claim handler for the BattlePass track.
--
-- Client sends RequestClaimBattlePass(tier, track) where track is
-- "free" | "premium". Server validates totalPranks >= threshold, the tier
-- isn't already claimed, and (if premium) the player owns ULTIMATE_CHAOS
-- gamepass. On success: grants chaos / hellTokens / skin, marks tier
-- claimed, fires NotifyClient toast.

local Players              = game:GetService("Players")
local MarketplaceService   = game:GetService("MarketplaceService")
local ReplicatedStorage    = game:GetService("ReplicatedStorage")

local Remotes           = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig        = require(ReplicatedStorage.Modules.GameConfig)
local BattlePassConfig  = require(ReplicatedStorage.Modules:WaitForChild("BattlePassConfig"))

-- Lazily create the RemoteFunction so RemoteEvents.lua doesn't need editing.
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
local RequestClaimBP = ensureRemote("RequestClaimBattlePass", "RemoteFunction")

local DataHandler
task.spawn(function()
    while not _G.KittyRaiserData do task.wait() end
    DataHandler = _G.KittyRaiserData
end)

local function notify(player, msg, kind)
    if Remotes.NotifyClient then
        Remotes.NotifyClient:FireClient(player, msg, kind or "info")
    end
end

local function ownsUltimate(player)
    local id = GameConfig.GAMEPASS_IDS and GameConfig.GAMEPASS_IDS.ULTIMATE_CHAOS
    if not id or id == 0 then return false end
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
    end)
    return ok and owns
end

RequestClaimBP.OnServerInvoke = function(player, tierNum, trackKind)
    if typeof(tierNum) ~= "number" or (trackKind ~= "free" and trackKind ~= "premium") then
        return false, "invalid_input"
    end
    if not DataHandler then return false, "data_loading" end
    local data = DataHandler.getData(player)
    if not data then return false, "data_loading" end

    local entry
    for _, t in ipairs(BattlePassConfig.Tiers) do
        if t.tier == tierNum then entry = t; break end
    end
    if not entry then return false, "invalid_tier" end

    if (data.totalPranks or 0) < entry.threshold then
        notify(player, "TIER LOCKED  -  prank more first", "warn")
        return false, "threshold_not_met"
    end

    data.bpClaimed = data.bpClaimed or {free = {}, premium = {}}
    data.bpClaimed.free    = data.bpClaimed.free    or {}
    data.bpClaimed.premium = data.bpClaimed.premium or {}

    local key = tostring(tierNum)
    if data.bpClaimed[trackKind][key] then
        notify(player, "ALREADY CLAIMED", "warn")
        return false, "already_claimed"
    end

    if trackKind == "premium" and not ownsUltimate(player) then
        notify(player, "PREMIUM TIER  -  needs ULTIMATE CHAOS gamepass", "warn")
        return false, "no_premium"
    end

    local reward = entry[trackKind]
    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) + (reward.chaos or 0)
        d.hellTokens  = (d.hellTokens  or 0) + (reward.hellTokens or 0)
        if reward.skinId then
            d.ownedSkins = d.ownedSkins or {}
            if not table.find(d.ownedSkins, reward.skinId) then
                table.insert(d.ownedSkins, reward.skinId)
            end
        end
        d.bpClaimed = d.bpClaimed or {free = {}, premium = {}}
        d.bpClaimed.free    = d.bpClaimed.free    or {}
        d.bpClaimed.premium = d.bpClaimed.premium or {}
        d.bpClaimed[trackKind][key] = os.time()
    end)
    local pieces = {}
    if reward.chaos      and reward.chaos > 0      then table.insert(pieces, "+" .. reward.chaos .. " chaos") end
    if reward.hellTokens and reward.hellTokens > 0 then table.insert(pieces, "+" .. reward.hellTokens .. " HT") end
    if reward.skinId then table.insert(pieces, "skin: " .. reward.skinId) end
    notify(player, "TIER " .. tierNum .. " CLAIMED  -  " .. table.concat(pieces, ", "), "good")
    return true
end

print("[BattlePassSystem v1] online — " .. #BattlePassConfig.Tiers .. " tiers")
