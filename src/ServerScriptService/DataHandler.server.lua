-- DataHandler.server.lua
-- Session-locked DataStore wrapper. Schema v2 (adds Hell Tokens, perks, stats, survival, daily streak).
-- Place in: ServerScriptService > DataHandler (Script)

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))
local CosmeticConfig = require(ReplicatedStorage.Modules.CosmeticConfig)
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local store = DataStoreService:GetDataStore(GameConfig.DATASTORE_NAME)

local PlayerData = {}
local LastSave = {}
local LoadingPlayers = {}

local DataHandler = {}

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
        soulShards = 0,        -- secondary cosmetic currency
        totalPranks = 0,
        totalRobuxSpent = 0,
        firstPlayDate = os.time(),
        lastPlayDate = os.time(),
        flagCount = 0,
        settingsMusicOn = true,
        settingsSFXOn = true,
        purchasedDevProductIds = {},
        -- Stats (Fallout style)
        stats = {Speed=0, Jump=0, Luck=0, Strength=0, Agility=0},
        unspentStatPoints = 0,
        -- Perks (slot -> perkId)
        perks = {},  -- {[1]="QuickPaws", [2]="PieMaster", ...}
        -- Survival
        hunger = 100,
        thirst = 100,
        -- Daily reward
        dailyStreak = 0,
        lastDailyClaim = 0,
        -- Pre-spawn customization (custom color override)
        customSpawnColor = nil,
        customSpawnSkin = nil,
        -- Tutorial flags
        seenTutorial = false,
    }
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
    -- Backfill any new keys
    local def = defaultData()
    for k, v in pairs(def) do
        if data[k] == nil then data[k] = v end
    end
    return data
end

local function key(userId)
    return GameConfig.DATASTORE_KEY_PREFIX .. tostring(userId)
end

local function attemptSessionLock(userId)
    local jobId = game.JobId == "" and "studio_" .. tostring(os.time()) or game.JobId
    local acquired = false
    local existingData = nil
    local ok, err = pcall(function()
        store:UpdateAsync(key(userId), function(old)
            old = old or defaultData()
            old = migrate(old)
            if old.activeJobId and old.activeJobId ~= jobId then
                local lockTime = old.lockTime or 0
                if (os.time() - lockTime) < 120 then
                    return nil
                end
            end
            old.activeJobId = jobId
            old.lockTime = os.time()
            existingData = old
            acquired = true
            return old
        end)
    end)
    if not ok then warn("[DataHandler] Lock acquire failed:", err); return false, nil end
    return acquired, existingData
end

local function releaseLock(userId, finalData)
    finalData.activeJobId = nil
    finalData.lockTime = nil
    finalData.lastPlayDate = os.time()
    local ok, err = pcall(function()
        store:UpdateAsync(key(userId), function(_) return finalData end)
    end)
    if not ok then warn("[DataHandler] Release lock failed:", err) end
end

function DataHandler.getData(player) return PlayerData[player.UserId] end
function DataHandler.setData(player, data)
    PlayerData[player.UserId] = data
    DataHandler.replicateToClient(player)
end

function DataHandler.modify(player, modifierFn)
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
    if releaseSessionLock then
        releaseLock(player.UserId, data)
    else
        local ok, err = pcall(function()
            store:UpdateAsync(key(player.UserId), function(_)
                data.lastPlayDate = os.time()
                return data
            end)
        end)
        if not ok then warn("[DataHandler] Save failed:", player.Name, err) end
    end
    LastSave[player.UserId] = os.time()
end

local function onPlayerAdded(player)
    LoadingPlayers[player.UserId] = true
    local acquired, data = attemptSessionLock(player.UserId)
    LoadingPlayers[player.UserId] = nil
    if not acquired then
        player:Kick("Could not load your save data. Please rejoin.")
        return
    end
    PlayerData[player.UserId] = migrate(data)
    DataHandler.replicateToClient(player)
    print("[DataHandler] Loaded", player.Name, "L"..data.level, "Chaos="..data.chaosPoints, "HT="..data.hellTokens)
end

local function onPlayerRemoving(player)
    if PlayerData[player.UserId] then
        DataHandler.save(player, true)
        PlayerData[player.UserId] = nil
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, player) end

task.spawn(function()
    while true do
        task.wait(GameConfig.AUTOSAVE_INTERVAL)
        for userId, _ in pairs(PlayerData) do
            local player = Players:GetPlayerByUserId(userId)
            if player then DataHandler.save(player, false) end
        end
    end
end)

game:BindToClose(function()
    if RunService:IsStudio() then return end
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function() DataHandler.save(player, true) end)
    end
    task.wait(3)
end)

_G.KittyRaiserData = DataHandler
return DataHandler
