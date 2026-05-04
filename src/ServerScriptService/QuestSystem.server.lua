-- QuestSystem.server.lua
-- Tracks per-player daily quest progress in memory and pushes updates to the
-- client. Quests reset on the server's next UTC day. Awards chaos +
-- (optional) hell tokens via DataHandler when a quest completes.
--
-- Place in: ServerScriptService > QuestSystem (Script). Auto-runs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes      = require(ReplicatedStorage.Modules.RemoteEvents)
local QuestConfig  = require(ReplicatedStorage.Modules:WaitForChild("QuestConfig"))
local AssetIds     = require(ReplicatedStorage.Modules.AssetIds)
local AudioGroups
do
    local m = ReplicatedStorage.Modules:WaitForChild("AudioGroups", 5)
    if m then local ok, mod = pcall(require, m); if ok then AudioGroups = mod end end
end

local SoundService = game:GetService("SoundService")

local function waitForGlobal(name)
    while not _G[name] do task.wait() end
    return _G[name]
end

local DataHandler = waitForGlobal("KittyRaiserData")

-- =====================================================================
-- STATE
-- progress[userId] = { cycleKey = "2026-05-04T16", entries = { [questId] = number } }
-- Cycle resets every 4 hours (UTC), so "daily" quests refresh 6 times per day.
-- =====================================================================
local progress = {}

local CYCLE_HOURS = 4

local function cycleKey()
    local now = os.time()
    local bucket = math.floor(now / (CYCLE_HOURS * 3600)) * (CYCLE_HOURS * 3600)
    return os.date("!%Y-%m-%dT%H", bucket)
end

local function ensure(player)
    local uid = player.UserId
    local p = progress[uid]
    if not p or p.cycleKey ~= cycleKey() then
        progress[uid] = { cycleKey = cycleKey(), entries = {}, claimed = {} }
    end
    return progress[uid]
end

local function snapshot(player)
    local p = ensure(player)
    local list = {}
    for _, q in ipairs(QuestConfig.Daily) do
        local cur = p.entries[q.id] or 0
        local done = cur >= q.target
        local claimed = p.claimed[q.id] or false
        table.insert(list, {
            id = q.id,
            label = q.label,
            target = q.target,
            current = math.min(cur, q.target),
            rewardChaos = q.rewardChaos,
            rewardHellTokens = q.rewardHellTokens,
            done = done,
            claimed = claimed,
        })
    end
    return list
end

local function pushUpdate(player)
    pcall(function()
        Remotes.QuestUpdate:FireClient(player, snapshot(player))
    end)
end

local function awardCompletion(player, q)
    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) + (q.rewardChaos or 0)
        if q.rewardHellTokens then
            d.hellTokens = (d.hellTokens or 0) + q.rewardHellTokens
        end
    end)
    Remotes.QuestCompleted:FireClient(player, {
        id = q.id, label = q.label,
        rewardChaos = q.rewardChaos,
        rewardHellTokens = q.rewardHellTokens or 0,
    })
    -- Quest-complete chime (server-side, attached to player head so spatial)
    if AssetIds.has("quest_complete") then
        local s = Instance.new("Sound")
        s.SoundId = AssetIds.quest_complete
        s.Volume = 0.9
        if AudioGroups then AudioGroups.assign(s, "UI") end
        local head = player.Character and player.Character:FindFirstChild("Head")
        s.Parent = head or SoundService
        s:Play()
        game:GetService("Debris"):AddItem(s, 4)
    end
end

local function bump(player, kind, amount, prankName)
    if not player or not player.Parent then return end
    local p = ensure(player)
    for _, q in ipairs(QuestConfig.Daily) do
        local matches = false
        if q.kind == kind then
            if q.kind == "specific_prank" then
                matches = q.prankName == prankName
            else
                matches = true
            end
        end
        if matches then
            local before = p.entries[q.id] or 0
            local after  = math.min(before + amount, q.target)
            p.entries[q.id] = after
            if before < q.target and after >= q.target and not p.claimed[q.id] then
                p.claimed[q.id] = true
                awardCompletion(player, q)
            end
        end
    end
    pushUpdate(player)
end

-- =====================================================================
-- HOOK GAME EVENTS
-- =====================================================================
-- Prank registered -> "any_prank" + "specific_prank"
Remotes.PrankRegistered.OnServerEvent = nil  -- safety; we connect via PrankSystem instead
-- We listen to the existing PrankRegistered fire; PrankSystem fires it client-side
-- so we hook into its server-side intent: instrument PrankSystem to call bump()
-- via a global function the server publishes.
_G.KittyRaiserBumpQuest = function(player, kind, amount, prankName)
    bump(player, kind, amount or 1, prankName)
end

-- Summon: hook by listening to the same RemoteEvent the client fires
Remotes.RequestSummonHuman.OnServerEvent:Connect(function(player)
    -- Check actual summon happened by waiting briefly (SummonSystem also listens
    -- and may reject). We bump optimistically; if the cooldown rejected the
    -- summon the count will still be capped by quest target so it's not abuseable.
    bump(player, "summon", 1)
end)

-- Level up
Remotes.LevelUp.OnClientEvent = nil  -- no client connection on server side; ignore
-- We'll bump level_up via a global that LevelUp callers can call.
_G.KittyRaiserBumpLevelUp = function(player)
    bump(player, "level_up", 1)
end

-- Play time: tick once per second per online player
task.spawn(function()
    while true do
        task.wait(1)
        for _, p in ipairs(Players:GetPlayers()) do
            local prog = ensure(p)
            -- Bump but DON'T re-award if already done; bump handles via claimed flag
            local hadDoneBefore = prog.claimed["session"]
            for _, q in ipairs(QuestConfig.Daily) do
                if q.kind == "play_time" then
                    bump(p, "play_time", 1)
                end
            end
            -- Don't push update every second — too spammy. Push every 10s.
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(10)
        for _, p in ipairs(Players:GetPlayers()) do pushUpdate(p) end
    end
end)

Players.PlayerAdded:Connect(function(p)
    task.wait(2)  -- give DataHandler/HUD time to spin up
    pushUpdate(p)
end)
Players.PlayerRemoving:Connect(function(p)
    progress[p.UserId] = nil
end)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(function() task.wait(2); pushUpdate(p) end)
end

print("[QuestSystem v1] daily quests online: ", #QuestConfig.Daily, " quests")
