-- RemoteEvents.lua
-- Single source of truth for all RemoteEvents and RemoteFunctions.
-- Place in: ReplicatedStorage > Modules > RemoteEvents (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local DEFINITIONS = {
    -- Client -> Server
    RequestSummonHuman = "Event",
    RequestPrank = "Event",
    RequestRebirth = "Function",
    RequestEquipSkin = "Function",
    RequestPurchaseSkinChaos = "Function",
    RequestPurchaseSkinHellTokens = "Function",
    RequestUseDevProduct = "Event",
    RequestEquipPerk = "Function",
    RequestResetPerks = "Function",
    RequestAllocStat = "Function",
    RequestEatFood = "Event",
    RequestDrinkWater = "Event",
    RequestEmote = "Event",
    RequestClaimDaily = "Function",
    RequestSpawnCustomization = "Event",  -- pre-spawn cat color/skin
    RequestAdminCommand = "Function",     -- admin only

    -- Server -> Client
    UpdatePlayerData = "Event",
    PrankRegistered = "Event",
    PrankFailed = "Event",
    LevelUp = "Event",
    PerkSlotEarned = "Event",  -- present picker
    RebirthCompleted = "Event",
    NotifyClient = "Event",
    LeaderboardUpdated = "Event",
    TutorialStep = "Event",
    WeatherChanged = "Event",  -- ("Sunny" | "Rainy" | "Foggy" | "RedMist")
    EventBroadcast = "Event",  -- server-wide event (eg "RedMistHour" with payload)
    EmoteBroadcast = "Event",  -- announce other player emote
    SurvivalUpdate = "Event",  -- (hunger, thirst)
    DailyAvailable = "Event",  -- (day#, reward)
}

local FOLDER_NAME = "KittyRaiserRemotes"

local function getOrCreateFolder()
    local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
    if not folder and RunService:IsServer() then
        folder = Instance.new("Folder")
        folder.Name = FOLDER_NAME
        folder.Parent = ReplicatedStorage
    elseif not folder then
        folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 10)
    end
    return folder
end

local folder = getOrCreateFolder()

local function getOrCreate(name, kind)
    local existing = folder:FindFirstChild(name)
    if existing then return existing end
    if RunService:IsServer() then
        local className = kind == "Event" and "RemoteEvent" or "RemoteFunction"
        local r = Instance.new(className)
        r.Name = name
        r.Parent = folder
        return r
    else
        return folder:WaitForChild(name, 10)
    end
end

for name, kind in pairs(DEFINITIONS) do
    Remotes[name] = getOrCreate(name, kind)
end

return Remotes
