-- LeaderstatsSystem.server.lua
-- Populates Roblox's default player-list leaderboard with Chaos / Level / Rebirths
-- so other players see your stats when they hover over your name.
-- Place in: ServerScriptService > LeaderstatsSystem (Script). Auto-runs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local SharedUtil = require(ReplicatedStorage.Modules.SharedUtil)

local DataHandler = SharedUtil.waitForGlobal("KittyRaiserData", 30)
if not DataHandler then return end

local function abbreviate(n)
    n = n or 0
    if n >= 1e9 then return string.format("%.2fB", n/1e9) end
    if n >= 1e6 then return string.format("%.2fM", n/1e6) end
    if n >= 1e3 then return string.format("%.1fK", n/1e3) end
    return tostring(math.floor(n))
end

local function setupLeaderstats(player)
    local existing = player:FindFirstChild("leaderstats")
    if existing then existing:Destroy() end

    local ls = Instance.new("Folder")
    ls.Name = "leaderstats"

    local chaos = Instance.new("StringValue")
    chaos.Name = "Chaos"
    chaos.Value = "0"
    chaos.Parent = ls

    local level = Instance.new("IntValue")
    level.Name = "Level"
    level.Value = 1
    level.Parent = ls

    local rebirths = Instance.new("IntValue")
    rebirths.Name = "Rebirths"
    rebirths.Value = 0
    rebirths.Parent = ls

    ls.Parent = player
    return ls
end

local function syncFromData(player)
    local ls = player:FindFirstChild("leaderstats") or setupLeaderstats(player)
    local d = DataHandler.getData(player)
    if not d then return end
    ls.Chaos.Value = abbreviate(d.chaosPoints or 0)
    ls.Level.Value = d.level or 1
    ls.Rebirths.Value = d.rebirths or 0
end

Players.PlayerAdded:Connect(function(player)
    setupLeaderstats(player)
    -- Wait for DataHandler to populate, then sync periodically.
    task.spawn(function()
        for _ = 1, 60 do
            if DataHandler.getData(player) then break end
            task.wait(0.5)
        end
        syncFromData(player)
    end)
end)
for _, p in ipairs(Players:GetPlayers()) do
    setupLeaderstats(p)
    task.spawn(syncFromData, p)
end

-- Update leaderstats whenever player data changes
Remotes.UpdatePlayerData.OnServerEvent:Connect(function() end)  -- noop hook
task.spawn(function()
    while true do
        task.wait(2)
        for _, p in ipairs(Players:GetPlayers()) do
            syncFromData(p)
        end
    end
end)

print("[LeaderstatsSystem] online")
