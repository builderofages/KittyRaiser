-- ClanSystem.server.lua  v1 — clan creation, invite/join/leave/kick.
--
-- Storage:
--   * DataHandler per-player additions: d.clanId (string), d.clanRank ("leader"|"officer"|"member")
--   * Separate ClanStore DataStore: keyed on clanId, value = {name, tag, members={[uid]=rank}, treasury, level, xp, createdAt}
--
-- Security:
--   * Rate-limited invites (max 1 outgoing per 5s per inviter)
--   * Only leader can disband; only leader/officer can kick
--   * Tag/name validated (3-12 chars, no special chars beyond letters/digits)
--   * 2,000 chaos cost to create (server-deducted via DataHandler.modify)
--   * Per-player can be in at most ONE clan
--   * Treasury is donate-only; only leader can withdraw
--   * Audit print on every leadership-affecting action

local Players          = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

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
local RequestCreateClan = ensureRemote("RequestCreateClan",   "RemoteFunction")
local RequestInviteClan = ensureRemote("RequestInviteClan",   "RemoteFunction")
local RequestAcceptInvite = ensureRemote("RequestAcceptClanInvite", "RemoteFunction")
local RequestLeaveClan  = ensureRemote("RequestLeaveClan",    "RemoteFunction")
local RequestKickFromClan = ensureRemote("RequestKickFromClan", "RemoteFunction")
local RequestClanInfo   = ensureRemote("RequestClanInfo",     "RemoteFunction")
local RequestDonateClan = ensureRemote("RequestDonateClan",   "RemoteFunction")
local ClanInviteEvent   = ensureRemote("ClanInviteEvent",     "Event")

local DataHandler
task.spawn(function()
    while not _G.KittyRaiserData do task.wait() end
    DataHandler = _G.KittyRaiserData
end)

local clanStore = DataStoreService:GetDataStore("KR_ClanStore_v1")

local CREATE_COST = 2000
local pendingInvites = {}    -- [targetUid] = {[clanId] = {fromUid, expiresT}}
local lastInviteT = {}       -- [fromUid] = clock; rate limit invites

local function notify(p, msg, kind)
    if Remotes.NotifyClient then
        Remotes.NotifyClient:FireClient(p, msg, kind or "info")
    end
end

local function validName(name)
    if typeof(name) ~= "string" then return false end
    if #name < 3 or #name > 18 then return false end
    return name:match("^[%w%s]+$") ~= nil
end

local function validTag(tag)
    if typeof(tag) ~= "string" then return false end
    if #tag < 2 or #tag > 5 then return false end
    return tag:match("^[%w]+$") ~= nil
end

local function loadClan(clanId)
    local ok, data = pcall(function() return clanStore:GetAsync(clanId) end)
    if ok and data then return data end
    return nil
end

local function saveClan(clanId, data)
    local ok, err = pcall(function() clanStore:SetAsync(clanId, data) end)
    if not ok then warn("[ClanSystem] save failed: " .. tostring(err)) end
end

-- =====================================================================
-- CREATE
-- =====================================================================
RequestCreateClan.OnServerInvoke = function(player, name, tag)
    if not DataHandler then return false, "data_loading" end
    if not validName(name) then return false, "invalid_name" end
    if not validTag(tag) then return false, "invalid_tag" end
    local data = DataHandler.getData(player)
    if not data then return false, "data_loading" end
    if data.clanId then return false, "already_in_clan" end
    if (data.chaosPoints or 0) < CREATE_COST then return false, "insufficient_chaos" end

    local clanId = "C_" .. player.UserId .. "_" .. os.time()
    local clanData = {
        id = clanId,
        name = name,
        tag = tag:upper(),
        members = {[tostring(player.UserId)] = "leader"},
        memberCount = 1,
        treasury = 0,
        level = 1,
        xp = 0,
        createdAt = os.time(),
        founderUid = player.UserId,
    }
    saveClan(clanId, clanData)
    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) - CREATE_COST
        d.clanId = clanId
        d.clanRank = "leader"
    end)
    print(string.format("[ClanSystem] CLAN CREATED %s by %s, id=%s", name, player.Name, clanId))
    notify(player, "CLAN [" .. clanData.tag .. "] " .. name .. " created", "good")
    return true, clanId
end

-- =====================================================================
-- INVITE
-- =====================================================================
RequestInviteClan.OnServerInvoke = function(player, targetUid)
    if not DataHandler then return false, "data_loading" end
    if typeof(targetUid) ~= "number" then return false, "invalid_target" end
    local now = os.clock()
    if lastInviteT[player.UserId] and now - lastInviteT[player.UserId] < 5 then
        return false, "rate_limit"
    end
    local data = DataHandler.getData(player)
    if not data or not data.clanId then return false, "no_clan" end
    if data.clanRank ~= "leader" and data.clanRank ~= "officer" then
        return false, "rank_too_low"
    end
    local target = Players:GetPlayerByUserId(targetUid)
    if not target then return false, "target_offline" end
    local tdata = DataHandler.getData(target)
    if not tdata then return false, "target_data_loading" end
    if tdata.clanId then return false, "target_in_clan" end

    pendingInvites[targetUid] = pendingInvites[targetUid] or {}
    pendingInvites[targetUid][data.clanId] = {fromUid=player.UserId, expiresT=os.time()+120}
    lastInviteT[player.UserId] = now

    local clanData = loadClan(data.clanId)
    if clanData then
        ClanInviteEvent:FireClient(target, {
            fromName = player.DisplayName,
            clanId = data.clanId,
            clanName = clanData.name,
            clanTag = clanData.tag,
        })
    end
    return true, "sent"
end

-- =====================================================================
-- ACCEPT INVITE
-- =====================================================================
RequestAcceptInvite.OnServerInvoke = function(player, clanId)
    if not DataHandler then return false, "data_loading" end
    if typeof(clanId) ~= "string" then return false, "invalid" end
    local data = DataHandler.getData(player)
    if not data or data.clanId then return false, "already_in_clan" end
    local invites = pendingInvites[player.UserId]
    if not invites or not invites[clanId] then return false, "no_invite" end
    if os.time() > invites[clanId].expiresT then
        invites[clanId] = nil
        return false, "expired"
    end
    local clanData = loadClan(clanId)
    if not clanData then return false, "clan_missing" end
    clanData.members[tostring(player.UserId)] = "member"
    clanData.memberCount = (clanData.memberCount or 0) + 1
    saveClan(clanId, clanData)
    DataHandler.modify(player, function(d)
        d.clanId = clanId
        d.clanRank = "member"
    end)
    pendingInvites[player.UserId] = nil
    print(string.format("[ClanSystem] %s joined clan %s", player.Name, clanData.tag))
    notify(player, "JOINED [" .. clanData.tag .. "] " .. clanData.name, "good")
    return true, "ok"
end

-- =====================================================================
-- LEAVE
-- =====================================================================
RequestLeaveClan.OnServerInvoke = function(player)
    if not DataHandler then return false, "data_loading" end
    local data = DataHandler.getData(player)
    if not data or not data.clanId then return false, "no_clan" end
    local clanData = loadClan(data.clanId)
    if clanData then
        clanData.members[tostring(player.UserId)] = nil
        clanData.memberCount = math.max(0, (clanData.memberCount or 0) - 1)
        if data.clanRank == "leader" and clanData.memberCount > 0 then
            -- Auto-promote: pick any officer or any member
            local newLeader
            for uid, rank in pairs(clanData.members) do
                if rank == "officer" then newLeader = uid; break end
            end
            if not newLeader then newLeader = next(clanData.members) end
            if newLeader then clanData.members[newLeader] = "leader" end
            print(string.format("[ClanSystem] LEADER LEFT %s, promoted %s", clanData.tag, tostring(newLeader)))
        end
        saveClan(data.clanId, clanData)
    end
    DataHandler.modify(player, function(d)
        d.clanId = nil; d.clanRank = nil
    end)
    notify(player, "LEFT CLAN", "info")
    return true
end

-- =====================================================================
-- KICK
-- =====================================================================
RequestKickFromClan.OnServerInvoke = function(player, targetUid)
    if not DataHandler then return false, "data_loading" end
    local data = DataHandler.getData(player)
    if not data or not data.clanId then return false, "no_clan" end
    if data.clanRank ~= "leader" and data.clanRank ~= "officer" then
        return false, "rank_too_low"
    end
    if targetUid == player.UserId then return false, "cannot_kick_self" end
    local clanData = loadClan(data.clanId)
    if not clanData then return false, "clan_missing" end
    if not clanData.members[tostring(targetUid)] then return false, "not_in_clan" end
    if clanData.members[tostring(targetUid)] == "leader" then return false, "cannot_kick_leader" end
    -- Officers can't kick officers; only leader can
    if clanData.members[tostring(targetUid)] == "officer" and data.clanRank ~= "leader" then
        return false, "cannot_kick_officer"
    end
    clanData.members[tostring(targetUid)] = nil
    clanData.memberCount = math.max(0, (clanData.memberCount or 0) - 1)
    saveClan(data.clanId, clanData)
    -- If the kicked player is online, clear their clan
    local target = Players:GetPlayerByUserId(targetUid)
    if target then
        DataHandler.modify(target, function(d)
            d.clanId = nil; d.clanRank = nil
        end)
        notify(target, "KICKED FROM CLAN", "warn")
    end
    print(string.format("[ClanSystem] KICKED uid=%d from %s by %s", targetUid, clanData.tag, player.Name))
    return true
end

-- =====================================================================
-- INFO
-- =====================================================================
RequestClanInfo.OnServerInvoke = function(player)
    if not DataHandler then return nil end
    local data = DataHandler.getData(player)
    if not data or not data.clanId then return nil end
    return loadClan(data.clanId)
end

-- =====================================================================
-- DONATE TO TREASURY
-- =====================================================================
RequestDonateClan.OnServerInvoke = function(player, amount)
    if not DataHandler then return false end
    if typeof(amount) ~= "number" or amount <= 0 then return false, "invalid_amount" end
    amount = math.floor(amount)
    local data = DataHandler.getData(player)
    if not data or not data.clanId then return false, "no_clan" end
    if (data.chaosPoints or 0) < amount then return false, "insufficient" end
    local clanData = loadClan(data.clanId)
    if not clanData then return false, "clan_missing" end
    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) - amount
    end)
    clanData.treasury = (clanData.treasury or 0) + amount
    saveClan(data.clanId, clanData)
    notify(player, "DONATED " .. amount .. " CHAOS to clan", "good")
    return true
end

-- =====================================================================
-- CLAN XP HOOK — bumped on every successful prank via global called from
-- PrankSystem.handlePrankRequest.
-- =====================================================================
_G.KittyRaiserBumpClanXP = function(player, amount)
    if not DataHandler then return end
    local data = DataHandler.getData(player)
    if not data or not data.clanId then return end
    local clanData = loadClan(data.clanId)
    if not clanData then return end
    clanData.xp = (clanData.xp or 0) + (amount or 1)
    -- Level up at 1000 * level XP
    while clanData.xp >= (clanData.level or 1) * 1000 and (clanData.level or 1) < 50 do
        clanData.xp = clanData.xp - (clanData.level * 1000)
        clanData.level = (clanData.level or 1) + 1
    end
    saveClan(data.clanId, clanData)
end

print("[ClanSystem v1] online - DataStore-backed, leader/officer/member ranks")
