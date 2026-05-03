-- DailyRewardSystem.server.lua
-- Daily login reward with 7-day streak cycle.
-- Place in: ServerScriptService > DailyRewardSystem (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local SharedUtil = require(ReplicatedStorage.Modules.SharedUtil)

local DataHandler = SharedUtil.waitForGlobal("KittyRaiserData", 30)
if not DataHandler then return end

local DAY_SECONDS = 86400

local REWARDS = {
    [1] = {chaos = 500, hellTokens = 0, msg = "Day 1: 500 Chaos"},
    [2] = {chaos = 1500, hellTokens = 0, msg = "Day 2: 1.5K Chaos"},
    [3] = {chaos = 3000, hellTokens = 1, msg = "Day 3: 3K Chaos + 1 Hell Token"},
    [4] = {chaos = 5000, hellTokens = 0, msg = "Day 4: 5K Chaos"},
    [5] = {chaos = 7500, hellTokens = 2, msg = "Day 5: 7.5K Chaos + 2 Hell Tokens"},
    [6] = {chaos = 10000, hellTokens = 0, msg = "Day 6: 10K Chaos"},
    [7] = {chaos = 25000, hellTokens = 5, msg = "Day 7: 25K Chaos + 5 Hell Tokens!"},
}

local function isAvailable(data)
    if not data.lastDailyClaim or data.lastDailyClaim == 0 then return true end
    return (os.time() - data.lastDailyClaim) >= DAY_SECONDS
end

local function streakBroken(data)
    if not data.lastDailyClaim or data.lastDailyClaim == 0 then return true end
    return (os.time() - data.lastDailyClaim) >= (DAY_SECONDS * 2)
end

local function nextStreakOf(data)
    if streakBroken(data) then return 1 end
    return ((data.dailyStreak or 0) % 7) + 1
end

Remotes.RequestClaimDaily.OnServerInvoke = function(player)
    if not SharedUtil.checkRate(player, "claimDaily", 1.0) then return false, "rate_limited" end
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end
    if not isAvailable(data) then
        return false, "wait", (data.lastDailyClaim or 0) + DAY_SECONDS - os.time()
    end
    local newStreak = nextStreakOf(data)
    local reward = REWARDS[newStreak]
    if not reward then return false, "no_reward_for_streak" end
    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) + reward.chaos
        d.hellTokens = (d.hellTokens or 0) + reward.hellTokens
        d.dailyStreak = newStreak
        d.lastDailyClaim = os.time()
    end)
    Remotes.NotifyClient:FireClient(player, reward.msg, "success")
    return true, newStreak
end

-- Use a poll loop instead of a hardcoded task.wait(3) so we don't fire before
-- DataHandler has actually loaded the player.
local function announceWhenReady(player)
    local deadline = os.clock() + 30
    while os.clock() < deadline do
        local data = DataHandler.getData(player)
        if data then
            if isAvailable(data) then
                local s = nextStreakOf(data)
                Remotes.DailyAvailable:FireClient(player, s, REWARDS[s])
            end
            return
        end
        task.wait(0.5)
    end
end

Players.PlayerAdded:Connect(function(player)
    task.spawn(announceWhenReady, player)
end)

return true
