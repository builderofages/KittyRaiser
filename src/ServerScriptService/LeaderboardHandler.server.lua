-- LeaderboardHandler.server.lua
-- Maintains a per-server live leaderboard of top 10 Chaos earners.
-- Place in: ServerScriptService > LeaderboardHandler (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local function waitFor(globalName) while not _G[globalName] do task.wait() end return _G[globalName] end
local DataHandler = waitFor("KittyRaiserData")

local UPDATE_INTERVAL = 5

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
    -- Top 10
    local top = {}
    for i = 1, math.min(10, #entries) do top[i] = entries[i] end
    Remotes.LeaderboardUpdated:FireAllClients(top)
end

task.spawn(function()
    while true do
        task.wait(UPDATE_INTERVAL)
        pcall(buildAndBroadcast)
    end
end)

return true
