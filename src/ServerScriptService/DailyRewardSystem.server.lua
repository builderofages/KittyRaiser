-- DailyRewardSystem.server.lua  v2
-- Daily login reward with 7-day streak cycle PLUS milestone mega-rewards at
-- absolute streak day 14, 30, 60, 100. The 7-day cycle keeps casual players
-- engaged; the milestones reward dedicated returners.
--
-- Place in: ServerScriptService > DailyRewardSystem (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local function waitFor(g) while not _G[g] do task.wait() end return _G[g] end
local DataHandler = waitFor("KittyRaiserData")

local DAY_SECONDS = 86400

-- 7-day cycle rewards (repeating)
local CYCLE_REWARDS = {
    [1] = {chaos = 500,   hellTokens = 0, msg = "Day 1: +500 chaos"},
    [2] = {chaos = 1500,  hellTokens = 0, msg = "Day 2: +1.5K chaos"},
    [3] = {chaos = 3000,  hellTokens = 1, msg = "Day 3: +3K chaos + 1 hell token"},
    [4] = {chaos = 5000,  hellTokens = 0, msg = "Day 4: +5K chaos"},
    [5] = {chaos = 7500,  hellTokens = 2, msg = "Day 5: +7.5K chaos + 2 hell tokens"},
    [6] = {chaos = 10000, hellTokens = 0, msg = "Day 6: +10K chaos"},
    [7] = {chaos = 25000, hellTokens = 5, msg = "Day 7: +25K chaos + 5 hell tokens"},
}

-- ABSOLUTE-streak milestone rewards (one-time, on top of the cycle reward)
local MEGA = {
    [14]  = {chaos =  60000, hellTokens = 15, msg = "MEGA: 14-day streak  +60K chaos + 15 hell tokens"},
    [30]  = {chaos = 200000, hellTokens = 50, msg = "MEGA: 30-day streak  +200K chaos + 50 hell tokens"},
    [60]  = {chaos = 500000, hellTokens = 100, msg = "MEGA: 60-day streak  +500K chaos + 100 hell tokens"},
    [100] = {chaos = 1500000,hellTokens = 250, msg = "MEGA: 100-day streak  +1.5M chaos + 250 hell tokens"},
}

local function isAvailable(data)
    if not data.lastDailyClaim then return true end
    return (os.time() - data.lastDailyClaim) >= DAY_SECONDS
end

local function streakBroken(data)
    if not data.lastDailyClaim then return true end
    return (os.time() - data.lastDailyClaim) >= (DAY_SECONDS * 2)
end

-- Per-player debounce so rapid double-fire from the client can't double-claim.
local claimingNow = {}

Remotes.RequestClaimDaily.OnServerInvoke = function(player)
    if claimingNow[player.UserId] then return false, "in_progress" end
    claimingNow[player.UserId] = true
    -- Auto-clear after 2s in case of mid-claim error
    task.delay(2, function() claimingNow[player.UserId] = nil end)

    local data = DataHandler.getData(player)
    if not data then claimingNow[player.UserId] = nil; return false, "no_data" end
    if not isAvailable(data) then
        local nextAt = (data.lastDailyClaim or 0) + DAY_SECONDS
        claimingNow[player.UserId] = nil
        return false, "wait", nextAt - os.time()
    end

    -- Absolute streak: never resets unless broken (>2d gap). Used for milestone
    -- rewards. Cycle position is ((absoluteStreak - 1) % 7) + 1.
    local newAbs
    if streakBroken(data) then newAbs = 1
    else newAbs = (data.dailyStreak or 0) + 1 end
    local cycleDay = ((newAbs - 1) % 7) + 1
    local reward = CYCLE_REWARDS[cycleDay]

    -- Mega bonus if absolute streak hits a milestone
    local mega = MEGA[newAbs]

    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) + reward.chaos + (mega and mega.chaos or 0)
        d.hellTokens  = (d.hellTokens  or 0) + reward.hellTokens + (mega and mega.hellTokens or 0)
        d.dailyStreak = newAbs
        d.lastDailyClaim = os.time()
    end)

    Remotes.NotifyClient:FireClient(player, reward.msg, "success")
    if mega then
        task.delay(0.6, function()
            Remotes.NotifyClient:FireClient(player, mega.msg, "success")
        end)
    end
    claimingNow[player.UserId] = nil
    return true, newAbs
end

return true
