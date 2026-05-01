-- DailyRewardSystem.server.lua
-- Daily login reward with 7-day streak cycle.
-- Place in: ServerScriptService > DailyRewardSystem (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local function waitFor(g) while not _G[g] do task.wait() end return _G[g] end
local DataHandler = waitFor("KittyRaiserData")

local DAY_SECONDS = 86400

-- 7-day streak rewards
local REWARDS = {
    [1] = {chaos = 500, hellTokens = 0, msg = "Day 1: 500 Chaos"},
    [2] = {chaos = 1500, hellTokens = 0, msg = "Day 2: 1.5K Chaos"},
    [3] = {chaos = 3000, hellTokens = 1, msg = "Day 3: 3K Chaos + 1 Hell Token"},
    [4] = {chaos = 5000, hellTokens = 0, msg = "Day 4: 5K Chaos"},
    [5] = {chaos = 7500, hellTokens = 2, msg = "Day 5: 7.5K Chaos + 2 Hell Tokens"},
    [6] = {chaos = 10000, hellTokens = 0, msg = "Day 6: 10K Chaos"},
    [7] = {chaos = 25000, hellTokens = 5, msg = "Day 7: 25K Chaos + 5 Hell Tokens! 🎉"},
}

local function isAvailable(data)
    if not data.lastDailyClaim then return true end
    return (os.time() - data.lastDailyClaim) >= DAY_SECONDS
end

local function streakBroken(data)
    if not data.lastDailyClaim then return true end
    return (os.time() - data.lastDailyClaim) >= (DAY_SECONDS * 2)
end

Remotes.RequestClaimDaily.OnServerInvoke = function(player)
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end
    if not isAvailable(data) then
        local nextAt = (data.lastDailyClaim or 0) + DAY_SECONDS
        return false, "wait", nextAt - os.time()
    end
    local newStreak
    if streakBroken(data) then newStreak = 1
    else newStreak = ((data.dailyStreak or 0) % 7) + 1 end
    local reward = REWARDS[newStreak]
    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) + reward.chaos
        d.hellTokens = (d.hellTokens or 0) + reward.hellTokens
        d.dailyStreak = newStreak
        d.lastDailyClaim = os.time()
    end)
    Remotes.NotifyClient:FireClient(player, reward.msg, "success")
    return true, newStreak
end

Players.PlayerAdded:Connect(function(player)
    task.wait(3)
    local data = DataHandler.getData(player)
    if data and isAvailable(data) then
        local nextStreak
        if streakBroken(data) then nextStreak = 1
        else nextStreak = ((data.dailyStreak or 0) % 7) + 1 end
        Remotes.DailyAvailable:FireClient(player, nextStreak, REWARDS[nextStreak])
    end
end)

return true
