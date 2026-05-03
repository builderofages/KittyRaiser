-- LeaderboardHandler.server.lua
-- Maintains a per-server live leaderboard of top 10 Chaos earners.
-- Place in: ServerScriptService > LeaderboardHandler (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local SharedUtil = require(ReplicatedStorage.Modules.SharedUtil)

local DataHandler = SharedUtil.waitForGlobal("KittyRaiserData", 30)
if not DataHandler then return end

local UPDATE_INTERVAL_MAX = 5
local UPDATE_INTERVAL_MIN = 0.5

local dirty = true
local lastBroadcast = ""

local function buildAndBroadcast()
    local entries = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local d = DataHandler.getData(p)
        if d then
            table.insert(entries, {
                name = p.DisplayName or p.Name,
                userId = p.UserId,
                chaos = d.chaosPoints or 0,
                level = d.level or 1,
                rebirths = d.rebirths or 0,
            })
        end
    end
    table.sort(entries, function(a, b) return a.chaos > b.chaos end)
    local top = {}
    for i = 1, math.min(10, #entries) do top[i] = entries[i] end

    -- Skip the broadcast if the snapshot hasn't changed (cuts wire traffic
    -- when nobody's pranked recently).
    local sig = ""
    for _, e in ipairs(top) do sig = sig .. e.userId .. ":" .. e.chaos .. "|" end
    if sig == lastBroadcast then return end
    lastBroadcast = sig
    Remotes.LeaderboardUpdated:FireAllClients(top)
end

-- Public: anyone (e.g., PrankSystem) can mark the board dirty after a chaos
-- change. We coalesce by polling at a fast min interval but only broadcasting
-- if dirty AND content changed.
function _G.KittyRaiserMarkLeaderboardDirty() dirty = true end

task.spawn(function()
    local lastTick = 0
    while true do
        task.wait(UPDATE_INTERVAL_MIN)
        local now = os.clock()
        if dirty or (now - lastTick) > UPDATE_INTERVAL_MAX then
            dirty = false
            lastTick = now
            pcall(buildAndBroadcast)
        end
    end
end)

return true
