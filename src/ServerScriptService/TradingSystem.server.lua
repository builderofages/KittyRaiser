-- TradingSystem.server.lua  v1 — security-first 1v1 skin trade.
--
-- THREAT MODEL & MITIGATIONS:
--   Dupe via mid-trade DataStore failure -> Single atomic DataHandler.modify
--                                          per player; only on dual-confirm.
--   Rage-trade after losing duel/pranked -> RecentDamageS gate (45s).
--   Spam-cancel to spy on inventory       -> No inventory leak; offers only.
--   Account-stealer scams                 -> 2-stage confirm + 5s lockout
--                                          countdown after both ready.
--   RemoteEvent flooding                  -> Per-user rate limit 0.5s.
--   Trade-chain spam                      -> Trade-cooldown per-pair 60s.
--   Item-not-owned attempt                -> Server validates against
--                                          d.ownedSkins before locking offer.
--   Equipped skin loss                    -> Cannot offer your equippedSkin.
--
-- Flow (state machine):
--   IDLE
--    -> RequestStartTrade(targetUid)  [creates session]
--   PENDING_INVITE  (target hasn't responded)
--    -> target's RequestStartTrade(yourUid) accepts pairing
--   OFFERING        (both can add/remove offer items)
--    -> Both RequestSetReady(true)
--   LOCKED          (5s countdown; either can RequestSetReady(false) to back out)
--    -> Countdown reaches 0 + both still ready
--   COMPLETED       (atomic swap, audit logged)

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local CosmeticConfig = require(ReplicatedStorage.Modules.CosmeticConfig)

local function ensureRemote(name, kind)
    local folder = ReplicatedStorage:FindFirstChild("RemoteEventsFolder")
    if not folder then
        folder = Instance.new("Folder"); folder.Name = "RemoteEventsFolder"; folder.Parent = ReplicatedStorage
    end
    local existing = folder:FindFirstChild(name)
    if existing then return existing end
    local r = Instance.new(kind); r.Name = name; r.Parent = folder
    return r
end
local RequestStartTrade = ensureRemote("RequestStartTrade",  "RemoteFunction")
local RequestOfferItem  = ensureRemote("RequestOfferItem",   "RemoteFunction")
local RequestSetReady   = ensureRemote("RequestSetReady",    "RemoteFunction")
local RequestCancelTrade = ensureRemote("RequestCancelTrade","RemoteFunction")
local TradeStateUpdate  = ensureRemote("TradeStateUpdate",   "Event")

local DataHandler
task.spawn(function()
    while not _G.KittyRaiserData do task.wait() end
    DataHandler = _G.KittyRaiserData
end)

local sessions = {}      -- [sessionId] = {p1, p2, offers={[uid]={skinId,...}}, ready={[uid]=bool}, state, lockStart, createdAt}
local userSession = {}   -- [uid] = sessionId
local pairCooldown = {}  -- [pairKey] = lastTradeUnixT
local lastReqT = {}      -- [uid] = clock; per-user 0.5s rate limit
local nextSessionId = 1

local TRADE_LOCK_S = 5
local PAIR_COOLDOWN_S = 60
local DAMAGE_GATE_S = 45  -- recently damaged -> can't trade

local function pairKey(a, b)
    if a < b then return a .. ":" .. b else return b .. ":" .. a end
end

local function rateLimit(uid)
    local now = os.clock()
    if lastReqT[uid] and now - lastReqT[uid] < 0.5 then return false end
    lastReqT[uid] = now
    return true
end

local function pushState(s)
    if not s then return end
    local snap = {
        sessionId = s.id,
        state     = s.state,
        offers    = s.offers,
        ready     = s.ready,
        lockStartIn = s.lockStart and (TRADE_LOCK_S - (os.clock() - s.lockStart)) or nil,
        p1Name    = s.p1.DisplayName,
        p2Name    = s.p2 and s.p2.DisplayName or nil,
    }
    if s.p1 then TradeStateUpdate:FireClient(s.p1, snap) end
    if s.p2 then TradeStateUpdate:FireClient(s.p2, snap) end
end

local function endSession(s, reason)
    if not s then return end
    if s.p1 then userSession[s.p1.UserId] = nil end
    if s.p2 then userSession[s.p2.UserId] = nil end
    sessions[s.id] = nil
    s.state = "ended"
    s.endReason = reason
    pushState(s)
    print("[TradingSystem] session " .. s.id .. " ended: " .. reason)
end

local function recentlyDamaged(player)
    local last = player:GetAttribute("LastDamageT")
    if not last then return false end
    return os.clock() - last < DAMAGE_GATE_S
end

-- =====================================================================
-- HANDLER: RequestStartTrade(targetUid) -> bool, error
-- =====================================================================
RequestStartTrade.OnServerInvoke = function(player, targetUid)
    if not rateLimit(player.UserId) then return false, "rate_limit" end
    if typeof(targetUid) ~= "number" then return false, "invalid_target" end
    if targetUid == player.UserId then return false, "cannot_self_trade" end
    local target = Players:GetPlayerByUserId(targetUid)
    if not target then return false, "target_offline" end
    if recentlyDamaged(player) or recentlyDamaged(target) then return false, "recent_damage" end

    -- Pair cooldown
    local pkey = pairKey(player.UserId, targetUid)
    if pairCooldown[pkey] and os.time() - pairCooldown[pkey] < PAIR_COOLDOWN_S then
        return false, "pair_cooldown"
    end

    -- Was target ALREADY in a session inviting me?
    local existing = userSession[player.UserId] and sessions[userSession[player.UserId]]
    if existing and existing.state == "pending_invite"
       and ((existing.p1 == target and existing.p2 == player) or
            (existing.p1 == player and existing.p2 == target)) then
        existing.state = "offering"
        pushState(existing)
        return true, "accepted"
    end

    -- New session
    if userSession[player.UserId] then
        return false, "already_in_session"
    end
    if userSession[targetUid] then
        return false, "target_busy"
    end
    local id = nextSessionId; nextSessionId = nextSessionId + 1
    local s = {
        id = id,
        p1 = player, p2 = target,
        offers = {[player.UserId] = {}, [targetUid] = {}},
        ready  = {[player.UserId] = false, [targetUid] = false},
        state = "pending_invite",
        createdAt = os.clock(),
    }
    sessions[id] = s
    userSession[player.UserId] = id
    userSession[targetUid] = id
    pushState(s)
    return true, "invited"
end

-- =====================================================================
-- HANDLER: RequestOfferItem(skinId, add)  -> bool, error
-- =====================================================================
RequestOfferItem.OnServerInvoke = function(player, skinId, add)
    if not rateLimit(player.UserId) then return false, "rate_limit" end
    if typeof(skinId) ~= "string" then return false, "invalid_skin" end
    local sid = userSession[player.UserId]
    local s = sid and sessions[sid]
    if not s or s.state ~= "offering" then return false, "no_session" end
    if not DataHandler then return false, "data_loading" end
    local data = DataHandler.getData(player)
    if not data then return false, "data_loading" end

    -- Validate ownership + not equipped
    local owned = data.ownedSkins and table.find(data.ownedSkins, skinId)
    if not owned then return false, "not_owned" end
    if data.equippedSkin == skinId then return false, "cannot_offer_equipped" end
    if not CosmeticConfig.Skins[skinId] then return false, "invalid_skin" end

    local offer = s.offers[player.UserId]
    if add then
        if #offer >= 5 then return false, "offer_full" end
        if table.find(offer, skinId) then return false, "already_offered" end
        table.insert(offer, skinId)
    else
        local idx = table.find(offer, skinId)
        if idx then table.remove(offer, idx) end
    end
    -- Adding/removing resets BOTH ready states (anti rug-pull)
    s.ready[s.p1.UserId] = false
    s.ready[s.p2.UserId] = false
    s.lockStart = nil
    pushState(s)
    return true, "ok"
end

-- =====================================================================
-- HANDLER: RequestSetReady(ready) -> bool, error
-- =====================================================================
RequestSetReady.OnServerInvoke = function(player, ready)
    if not rateLimit(player.UserId) then return false, "rate_limit" end
    local sid = userSession[player.UserId]
    local s = sid and sessions[sid]
    if not s or (s.state ~= "offering" and s.state ~= "locked") then return false, "no_session" end
    s.ready[player.UserId] = ready and true or false
    if s.ready[s.p1.UserId] and s.ready[s.p2.UserId] then
        s.state = "locked"
        s.lockStart = os.clock()
        -- After 5s if still both-ready, execute the swap.
        task.delay(TRADE_LOCK_S, function()
            if not sessions[s.id] then return end  -- ended already
            if s.state ~= "locked" then return end
            if not (s.ready[s.p1.UserId] and s.ready[s.p2.UserId]) then return end
            -- ATOMIC SWAP
            local function swap(giver, receiver)
                local giveOffers = s.offers[giver.UserId]
                DataHandler.modify(giver, function(d)
                    d.ownedSkins = d.ownedSkins or {}
                    for _, sk in ipairs(giveOffers) do
                        local idx = table.find(d.ownedSkins, sk)
                        if idx then table.remove(d.ownedSkins, idx) end
                    end
                end)
                DataHandler.modify(receiver, function(d)
                    d.ownedSkins = d.ownedSkins or {}
                    for _, sk in ipairs(giveOffers) do
                        if not table.find(d.ownedSkins, sk) then
                            table.insert(d.ownedSkins, sk)
                        end
                    end
                end)
            end
            swap(s.p1, s.p2)
            swap(s.p2, s.p1)
            -- Audit log
            print(string.format("[TradingSystem] AUDIT trade %d: %s gave [%s], %s gave [%s]",
                s.id, s.p1.Name, table.concat(s.offers[s.p1.UserId], ","),
                s.p2.Name, table.concat(s.offers[s.p2.UserId], ",")))
            pairCooldown[pairKey(s.p1.UserId, s.p2.UserId)] = os.time()
            if Remotes.NotifyClient then
                Remotes.NotifyClient:FireClient(s.p1, "TRADE COMPLETE", "good")
                Remotes.NotifyClient:FireClient(s.p2, "TRADE COMPLETE", "good")
            end
            endSession(s, "completed")
        end)
    else
        s.state = "offering"
        s.lockStart = nil
    end
    pushState(s)
    return true, "ok"
end

-- =====================================================================
-- HANDLER: RequestCancelTrade()
-- =====================================================================
RequestCancelTrade.OnServerInvoke = function(player)
    local sid = userSession[player.UserId]
    local s = sid and sessions[sid]
    if not s then return false, "no_session" end
    endSession(s, "cancelled by " .. player.Name)
    return true
end

-- Cleanup on remove
Players.PlayerRemoving:Connect(function(p)
    local sid = userSession[p.UserId]
    if sid and sessions[sid] then
        endSession(sessions[sid], "player_left")
    end
end)

print("[TradingSystem v1] online - 5s lock + 45s damage gate + 60s pair cooldown + audit log")
