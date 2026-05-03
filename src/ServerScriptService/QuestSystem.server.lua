-- QuestSystem.server.lua
-- Daily quest tracking. Hooks into gameplay events (prank, summon, emote,
-- rebirth) and bumps the per-counter values on the player's data. Rewards are
-- claimed via RequestQuestClaim. Resets at UTC midnight.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local QuestConfig = require(ReplicatedStorage.Modules.QuestConfig)
local SharedUtil = require(ReplicatedStorage.Modules.SharedUtil)

local DataHandler = SharedUtil.waitForGlobal("KittyRaiserData", 30)
if not DataHandler then return end

local QuestSystem = {}

local function ensureToday(d)
    d.questDay = d.questDay or ""
    d.questCounters = d.questCounters or {}
    d.questClaimed = d.questClaimed or {}
    d.questAssigned = d.questAssigned or {}
    local today = QuestConfig.dayKey()
    if d.questDay ~= today then
        d.questDay = today
        d.questCounters = {}
        d.questClaimed = {}
        d.questAssigned = {}  -- recomputed lazily; deterministic from today
    end
    if #d.questAssigned == 0 then
        for _, q in ipairs(QuestConfig.pickForDay(today)) do
            table.insert(d.questAssigned, q.id)
        end
    end
end

function QuestSystem.bump(player, counterKey, amount)
    if not player or not counterKey then return end
    amount = amount or 1
    DataHandler.modify(player, function(d)
        ensureToday(d)
        d.questCounters[counterKey] = (d.questCounters[counterKey] or 0) + amount
    end)
end

function QuestSystem.setBest(player, counterKey, value)
    -- For "best of day" counters like bestComboToday — store max not sum
    if not player or not counterKey then return end
    DataHandler.modify(player, function(d)
        ensureToday(d)
        d.questCounters[counterKey] = math.max(d.questCounters[counterKey] or 0, value or 0)
    end)
end

-- Lookup a quest entry by id from the pool.
local POOL_BY_ID = {}
for _, q in ipairs(QuestConfig.Pool) do POOL_BY_ID[q.id] = q end

Remotes.RequestQuestClaim.OnServerInvoke = function(player, questId)
    if not SharedUtil.checkRate(player, "questClaim", 0.5) then
        return false, "rate_limited"
    end
    if type(questId) ~= "string" or #questId > 32 then return false, "bad_id" end
    local q = POOL_BY_ID[questId]
    if not q then return false, "unknown_quest" end
    local d = DataHandler.getData(player)
    if not d then return false, "no_data" end
    ensureToday(d)
    if not table.find(d.questAssigned, questId) then return false, "not_today" end
    if d.questClaimed[questId] then return false, "already_claimed" end
    local progress = d.questCounters[q.counter] or 0
    if progress < q.target then return false, "incomplete", progress, q.target end

    DataHandler.modify(player, function(dd)
        dd.questClaimed[questId] = true
        dd.chaosPoints = (dd.chaosPoints or 0) + (q.chaos or 0)
        dd.hellTokens = (dd.hellTokens or 0) + (q.hellTokens or 0)
    end)
    Remotes.NotifyClient:FireClient(player,
        ("Quest complete! +%d chaos%s"):format(q.chaos or 0,
            (q.hellTokens or 0) > 0 and (" + " .. q.hellTokens .. " HT") or ""),
        "success")
    return true, q
end

-- Attach hooks to gameplay events. Each hook bumps a per-day counter.
-- We listen on the server-side OnServerEvent of remotes that gameplay uses.
local prankHook = Remotes.RequestPrank
if prankHook and prankHook.OnServerEvent then
    prankHook.OnServerEvent:Connect(function(player, prankName)
        QuestSystem.bump(player, "totalPranks", 1)
        if type(prankName) == "string" then
            QuestSystem.bump(player, "prank_" .. prankName, 1)
            -- distinctPranksToday: unique count
            DataHandler.modify(player, function(d)
                ensureToday(d)
                d.questDistinctPranks = d.questDistinctPranks or {}
                if d.questDistinctPranks._day ~= d.questDay then
                    d.questDistinctPranks = {_day = d.questDay}
                end
                if not d.questDistinctPranks[prankName] then
                    d.questDistinctPranks[prankName] = true
                    local n = 0
                    for k, _ in pairs(d.questDistinctPranks) do
                        if k ~= "_day" then n = n + 1 end
                    end
                    d.questCounters.distinctPranksToday = n
                end
            end)
        end
    end)
end

local summonHook = Remotes.RequestSummonHuman
if summonHook and summonHook.OnServerEvent then
    summonHook.OnServerEvent:Connect(function(player)
        QuestSystem.bump(player, "totalSummons", 1)
    end)
end

local emoteHook = Remotes.RequestEmote
if emoteHook and emoteHook.OnServerEvent then
    emoteHook.OnServerEvent:Connect(function(player)
        QuestSystem.bump(player, "totalEmotes", 1)
    end)
end

-- Rebirth hook: poll player data, bump rebirthsToday whenever rebirth count
-- changes upward.
local lastSeenRebirths = {}
task.spawn(function()
    while true do
        task.wait(2)
        for _, p in ipairs(Players:GetPlayers()) do
            local d = DataHandler.getData(p)
            if d then
                local prev = lastSeenRebirths[p.UserId]
                if prev and (d.rebirths or 0) > prev then
                    QuestSystem.bump(p, "rebirthsToday", (d.rebirths or 0) - prev)
                end
                lastSeenRebirths[p.UserId] = d.rebirths or 0
            end
        end
    end
end)
Players.PlayerRemoving:Connect(function(p) lastSeenRebirths[p.UserId] = nil end)

_G.KittyRaiserQuests = QuestSystem
print("[QuestSystem] online — " .. #QuestConfig.Pool .. " quests in pool, " .. QuestConfig.PER_DAY .. " per day")
