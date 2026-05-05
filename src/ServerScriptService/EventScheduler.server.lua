-- EventScheduler.server.lua  v1 — server-wide live-ops event broadcasts.
--
-- Cycles through event states (rotates every N minutes per server uptime).
-- Each event has a server-wide buff (chaos multiplier / boss spawn rate /
-- AmbientCrowd density) plus a banner message broadcast to every client
-- via Remotes.EventBroadcast 'event' kind.
--
-- Use cases:
--   * "Rush Hour"  — 1.5x chaos for 5 minutes, every 20 minutes
--   * "Boss Surge" — boss-on-every-summon for 3 minutes, every 30 min
--   * "Crowd Wave" — denser ambient crowd for 4 minutes, every 25 min
--
-- Place in: ServerScriptService > EventScheduler. Auto-runs.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

-- =====================================================================
-- EVENT TABLE
-- =====================================================================
local EVENTS = {
    {
        id = "rush_hour",
        title = "RUSH HOUR",
        message = "1.5x CHAOS for 5 minutes! Stack pranks fast.",
        durationS = 300,
        intervalS = 12 * 60,
        startsAtS = 30,        -- v3.64: 60s -> 30s so new joiners see it fast
        flag = "EventRushHour",
        buff = {chaosMultiplier = 1.5},
    },
    {
        id = "boss_surge",
        title = "BOSS SURGE",
        message = "Every summon spawns a BOSS for 3 minutes.",
        durationS = 180,
        intervalS = 18 * 60,   -- v3.64: 30min -> 18min cycle
        startsAtS = 4 * 60,    -- v3.64: 8min -> 4min initial
        flag = "EventBossSurge",
        buff = {bossEveryTime = true},
    },
    {
        id = "crowd_wave",
        title = "CROWD WAVE",
        message = "Sidewalks are PACKED for 4 minutes.",
        durationS = 240,
        intervalS = 15 * 60,   -- v3.64: 25min -> 15min cycle
        startsAtS = 2 * 60,    -- v3.64: 4min -> 2min initial
        flag = "EventCrowdWave",
        buff = {crowdDense = true},
    },
}

-- =====================================================================
-- BROADCAST
-- =====================================================================
local function broadcast(payload)
    for _, p in ipairs(Players:GetPlayers()) do
        Remotes.EventBroadcast:FireClient(p, "event", payload)
    end
end

local function setFlag(flagName, value)
    -- Mirror to a workspace attribute so other systems (PrankSystem,
    -- AmbientCrowd, SummonSystem) can read the buff state.
    workspace:SetAttribute(flagName, value)
end

-- =====================================================================
-- SCHEDULE LOOP — checks every 5s whether any event should start/stop.
-- =====================================================================
local startT = os.clock()
local activeUntil = {}  -- [eventId] = clock when it ends

task.spawn(function()
    while true do
        task.wait(5)
        local elapsed = os.clock() - startT
        for _, e in ipairs(EVENTS) do
            -- Has the event passed its first scheduled trigger?
            if elapsed >= e.startsAtS then
                local cyclePos = (elapsed - e.startsAtS) % e.intervalS
                local shouldBeActive = cyclePos < e.durationS
                local isActive = activeUntil[e.id] and os.clock() < activeUntil[e.id]
                if shouldBeActive and not isActive then
                    -- START
                    activeUntil[e.id] = os.clock() + e.durationS
                    setFlag(e.flag, true)
                    broadcast({
                        kind = "start",
                        title = e.title,
                        message = e.message,
                        durationS = e.durationS,
                    })
                elseif not shouldBeActive and isActive then
                    -- END
                    activeUntil[e.id] = nil
                    setFlag(e.flag, false)
                    broadcast({
                        kind = "end",
                        title = e.title,
                        message = e.title .. " ended.",
                    })
                end
            end
        end
    end
end)

-- Fresh joiners get current state announced.
Players.PlayerAdded:Connect(function(p)
    task.wait(3)
    for _, e in ipairs(EVENTS) do
        if activeUntil[e.id] and os.clock() < activeUntil[e.id] then
            local remaining = math.floor(activeUntil[e.id] - os.clock())
            Remotes.EventBroadcast:FireClient(p, "event", {
                kind = "start",
                title = e.title,
                message = e.message .. "  (" .. remaining .. "s left)",
                durationS = remaining,
            })
        end
    end
end)

print("[EventScheduler v1] online — " .. #EVENTS .. " events scheduled")
