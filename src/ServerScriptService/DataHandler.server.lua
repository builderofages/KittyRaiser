-- DataHandler.server.lua
-- Session-locked DataStore wrapper. Schema v3 (purges deprecated keys, adds versioned merge).
-- Place in: ServerScriptService > DataHandler (Script)

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))
local CosmeticConfig = require(ReplicatedStorage.Modules.CosmeticConfig)
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

GameConfig.SCHEMA_VERSION = 3

local store = DataStoreService:GetDataStore(GameConfig.DATASTORE_NAME)

local PlayerData = {}
local LastSave = {}
local LoadingPlayers = {}
local SaveBarrier = 0  -- counter of in-flight saves; BindToClose waits for this to drain

local DataHandler = {}

-- Build a unique-per-server jobId. game.JobId is empty in Studio; fall back to a
-- random GUID so two studio servers don't collide on second-resolution timestamps.
local function getJobId()
    if game.JobId and game.JobId ~= "" then return game.JobId end
    return "studio_" .. HttpService:GenerateGUID(false)
end
local SERVER_JOB_ID = getJobId()

local LOCK_TIMEOUT_SEC = 600  -- 10 minutes; survives most server crashes without permanently locking players

local function defaultData()
    return {
        version = GameConfig.SCHEMA_VERSION,
        chaosPoints = GameConfig.STARTING_CHAOS,
        hellTokens = GameConfig.STARTING_HELLTOKENS,
        level = GameConfig.STARTING_LEVEL,
        xp = 0,
        rebirths = 0,
        equippedSkin = "Default",
        ownedSkins = table.clone(CosmeticConfig.DEFAULT_OWNED),
        soulShards = 0,
        totalPranks = 0,
        totalRobuxSpent = 0,
        firstPlayDate = os.time(),
        lastPlayDate = os.time(),
        flagCount = 0,
        suspended = false,             -- persisted ban-flag from anti-cheat
        settingsMusicOn = true,
        settingsSFXOn = true,
        settingsMusicVolume = 0.5,
        settingsSFXVolume = 0.7,
        settingsCameraMode = "third",
        redeemedCodes = {},
        purchasedDevProductIds = {},
        stats = {Speed=0, Jump=0, Luck=0, Strength=0, Agility=0},
        unspentStatPoints = 0,
        perks = {},
        hunger = 100,
        thirst = 100,
        dailyStreak = 0,
        lastDailyClaim = 0,
        customSpawnColor = nil,
        customSpawnSkin = nil,
        seenTutorial = false,
    }
end

-- Whitelist of keys we serialize. Keys not in the default schema are dropped on
-- migration so the DataStore record can never grow toward the 1MB cap.
local function pruneToSchema(data)
    local def = defaultData()
    local pruned = {}
    for k, _ in pairs(def) do
        pruned[k] = data[k]
    end
    -- preserve internal lock fields the schema doesn't list
    pruned.activeJobId = data.activeJobId
    pruned.lockTime = data.lockTime
    return pruned
end

local function migrate(data)
    if not data then data = defaultData() end
    if not data.version then data.version = 1 end
    if data.version < 2 then
        data.hellTokens = data.hellTokens or 0
        data.soulShards = data.soulShards or 0
        data.stats = data.stats or {Speed=0, Jump=0, Luck=0, Strength=0, Agility=0}
        data.unspentStatPoints = data.unspentStatPoints or 0
        data.perks = data.perks or {}
        data.hunger = data.hunger or 100
        data.thirst = data.thirst or 100
        data.dailyStreak = data.dailyStreak or 0
        data.lastDailyClaim = data.lastDailyClaim or 0
        data.version = 2
    end
    if data.version < 3 then
        data.suspended = data.suspended or false
        data.flagCount = data.flagCount or 0
        data = pruneToSchema(data)  -- drop any deprecated keys
        data.version = 3
    end
    -- Backfill any new keys (forward compat)
    local def = defaultData()
    for k, v in pairs(def) do
        if data[k] == nil then data[k] = v end
    end
    -- Defensive clamps so corrupt data can't permanently lock systems
    data.rebirths = math.clamp(data.rebirths or 0, 0, GameConfig.REBIRTH_SOFT_CAP)
    data.level = math.clamp(data.level or 1, 1, GameConfig.LEVEL_CAP)
    data.chaosPoints = math.max(0, data.chaosPoints or 0)
    data.hellTokens = math.max(0, data.hellTokens or 0)
    data.hunger = math.clamp(data.hunger or 100, 0, 100)
    data.thirst = math.clamp(data.thirst or 100, 0, 100)
    return data
end

local function key(userId)
    return GameConfig.DATASTORE_KEY_PREFIX .. tostring(userId)
end

-- DataStore call with retry + exponential backoff. Used by all reads/writes.
local function callWithRetry(label, fn)
    local lastErr
    for attempt = 1, 4 do
        local ok, result = pcall(fn)
        if ok then return true, result end
        lastErr = result
        warn(("[DataHandler] %s attempt %d failed: %s"):format(label, attempt, tostring(result)))
        task.wait(2 ^ (attempt - 1))  -- 1s, 2s, 4s, 8s
    end
    return false, lastErr
end

local function attemptSessionLock(userId)
    local acquired = false
    local existingData = nil
    local ok = callWithRetry("LockAcquire", function()
        store:UpdateAsync(key(userId), function(old)
            old = old or defaultData()
            old = migrate(old)
            if old.activeJobId and old.activeJobId ~= SERVER_JOB_ID then
                local lockTime = old.lockTime or 0
                if (os.time() - lockTime) < LOCK_TIMEOUT_SEC then
                    return nil  -- another live server holds the lock
                end
            end
            old.activeJobId = SERVER_JOB_ID
            old.lockTime = os.time()
            existingData = old
            acquired = true
            return old
        end)
    end)
    if not ok then return false, nil end
    return acquired, existingData
end

local function releaseLock(userId, finalData)
    finalData.activeJobId = nil
    finalData.lockTime = nil
    finalData.lastPlayDate = os.time()
    callWithRetry("LockRelease", function()
        store:UpdateAsync(key(userId), function(old)
            -- merge into whatever's there to avoid clobbering external mods (e.g. ban tools)
            old = old or {}
            for k, v in pairs(finalData) do old[k] = v end
            old.activeJobId = nil
            old.lockTime = nil
            return old
        end)
    end)
end

function DataHandler.getData(player) return PlayerData[player.UserId] end
function DataHandler.setData(player, data)
    PlayerData[player.UserId] = data
    DataHandler.replicateToClient(player)
end

function DataHandler.modify(player, modifierFn)
    if not player then return false end
    local data = PlayerData[player.UserId]
    if not data then return false end
    modifierFn(data)
    DataHandler.replicateToClient(player)
    return true
end

function DataHandler.replicateToClient(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    local copy = {}
    for k, v in pairs(data) do
        if k ~= "activeJobId" and k ~= "lockTime" then copy[k] = v end
    end
    Remotes.UpdatePlayerData:FireClient(player, copy)
end

function DataHandler.save(player, releaseSessionLock)
    local data = PlayerData[player.UserId]
    if not data then return end
    SaveBarrier = SaveBarrier + 1
    local snapshot = {}
    for k, v in pairs(data) do snapshot[k] = v end  -- shallow snapshot avoids races during await
    snapshot.lastPlayDate = os.time()

    if releaseSessionLock then
        releaseLock(player.UserId, snapshot)
    else
        callWithRetry("Save:" .. player.Name, function()
            store:UpdateAsync(key(player.UserId), function(old)
                -- preserve fields modified externally (e.g., admin tools, bans)
                old = old or {}
                for k, v in pairs(snapshot) do old[k] = v end
                return old
            end)
        end)
    end
    LastSave[player.UserId] = os.time()
    SaveBarrier = SaveBarrier - 1
end

local function onPlayerAdded(player)
    LoadingPlayers[player.UserId] = true
    local acquired, data = attemptSessionLock(player.UserId)
    LoadingPlayers[player.UserId] = nil  -- always cleared, even on failure
    if not acquired then
        player:Kick("Could not load your save data. Please rejoin in a moment.")
        return
    end
    PlayerData[player.UserId] = migrate(data)
    DataHandler.replicateToClient(player)
    print("[DataHandler] Loaded", player.Name, "L"..PlayerData[player.UserId].level,
        "Chaos="..PlayerData[player.UserId].chaosPoints, "HT="..PlayerData[player.UserId].hellTokens)
end

local function onPlayerRemoving(player)
    if PlayerData[player.UserId] then
        DataHandler.save(player, true)
        PlayerData[player.UserId] = nil
    end
    LoadingPlayers[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, player) end

task.spawn(function()
    while true do
        task.wait(GameConfig.AUTOSAVE_INTERVAL)
        for userId, _ in pairs(PlayerData) do
            local player = Players:GetPlayerByUserId(userId)
            if player then task.spawn(DataHandler.save, player, false) end
        end
    end
end)

-- BindToClose: wait for the save barrier to drain, with a hard 25s ceiling
-- (Roblox BindToClose timeout is ~30s in production).
game:BindToClose(function()
    if RunService:IsStudio() then return end
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(DataHandler.save, player, true)
    end
    local deadline = os.clock() + 25
    while SaveBarrier > 0 and os.clock() < deadline do
        task.wait(0.2)
    end
    if SaveBarrier > 0 then
        warn(("[DataHandler] BindToClose timed out with %d saves still pending"):format(SaveBarrier))
    end
end)

_G.KittyRaiserData = DataHandler
return DataHandler
