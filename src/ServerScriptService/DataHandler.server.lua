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
        -- User settings (also mirrored to player attributes for client read)
        settings = {
            masterVolume    = 0.8,
            musicVolume     = 0.6,
            sfxVolume       = 0.9,
            uiVolume        = 0.8,
            graphicsQuality = "med",  -- low | med | high
            motionShake     = true,
        },
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
    if data.version < 3 then
        -- v3: persisted settings + seenTutorial flag
        data.settings = data.settings or {
            masterVolume = 0.8, musicVolume = 0.6,
            sfxVolume = 0.9, uiVolume = 0.8,
            graphicsQuality = "med", motionShake = true,
        }
        data.seenTutorial = data.seenTutorial or false
        data.version = 3
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
        -- Retry with exponential backoff: 0, 1s, 2s, 4s. Roblox DataStore
        -- intermittent failures (rate limit, network blip) shouldn't lose data.
        local attempts = 0
        local lastErr
        while attempts < 4 do
            local ok, err = pcall(function()
                store:UpdateAsync(key(player.UserId), function(_)
                    data.lastPlayDate = os.time()
                    return data
                end)
            end)
            if ok then lastErr = nil; break end
            lastErr = err
            attempts = attempts + 1
            task.wait(2 ^ (attempts - 1))
        end
        if lastErr then
            warn(("[DataHandler] Save failed after %d attempts for %s: %s"):format(
                attempts, player.Name, tostring(lastErr)))
        end
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

    -- Mirror persisted settings onto player attributes so SettingsMenu reads them.
    local d = PlayerData[player.UserId]
    if d.settings then
        player:SetAttribute("MasterVolume",    d.settings.masterVolume    or 0.8)
        player:SetAttribute("MusicVolume",     d.settings.musicVolume     or 0.6)
        player:SetAttribute("SFXVolume",       d.settings.sfxVolume       or 0.9)
        player:SetAttribute("UIVolume",        d.settings.uiVolume        or 0.8)
        player:SetAttribute("GraphicsQuality", d.settings.graphicsQuality or "med")
        player:SetAttribute("MotionShake",     d.settings.motionShake ~= false)
    end
    -- When attributes change, write back to the stored settings table.
    local function syncSetting(attr, key)
        player:GetAttributeChangedSignal(attr):Connect(function()
            local v = player:GetAttribute(attr)
            d.settings = d.settings or {}
            d.settings[key] = v
        end)
    end
    syncSetting("MasterVolume",    "masterVolume")
    syncSetting("MusicVolume",     "musicVolume")
    syncSetting("SFXVolume",       "sfxVolume")
    syncSetting("UIVolume",        "uiVolume")
    syncSetting("GraphicsQuality", "graphicsQuality")
    syncSetting("MotionShake",     "motionShake")

    -- Mirror persisted tutorial flag onto the player so OnboardingFlow can
    -- skip the intro for returning players.
    if d.seenTutorial then
        player:SetAttribute("OnboardingDone", true)
    end

    DataHandler.replicateToClient(player)
    print("[DataHandler] Loaded", player.Name, "L"..data.level, "Chaos="..data.chaosPoints, "HT="..data.hellTokens)
end

-- Tutorial-done remote: client (OnboardingFlow) fires this on completion;
-- we set the persisted flag so future sessions skip onboarding.
task.spawn(function()
    local Modules = ReplicatedStorage:WaitForChild("Modules", 10)
    local RE = Modules and Modules:WaitForChild("RemoteEvents", 5)
    if not RE then return end
    local ok, Remotes = pcall(require, RE)
    if not ok or not Remotes or not Remotes.RequestMarkTutorialDone then return end
    Remotes.RequestMarkTutorialDone.OnServerEvent:Connect(function(player)
        local d = PlayerData[player.UserId]
        if d then d.seenTutorial = true end
        player:SetAttribute("OnboardingDone", true)
    end)
end)

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
