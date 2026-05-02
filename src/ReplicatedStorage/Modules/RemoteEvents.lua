-- RemoteEvents.lua — single source of truth for all RemoteEvents and RemoteFunctions
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
  RequestSpawnCustomization = "Event",
  RequestAdminCommand = "Function",
  -- Server -> Client
  UpdatePlayerData = "Event",
  PrankRegistered = "Event",
  PrankFailed = "Event",
  LevelUp = "Event",
  PerkSlotEarned = "Event",
  RebirthCompleted = "Event",
  NotifyClient = "Event",
  LeaderboardUpdated = "Event",
  TutorialStep = "Event",
  WeatherChanged = "Event",
  EventBroadcast = "Event",
  SurvivalUpdate = "Event",
  ForceSpawn = "Event",  -- NEW: force server to spawn cat
}

-- Find or create folder under ReplicatedStorage
local folder = ReplicatedStorage:FindFirstChild("RemoteEventsFolder")
if not folder then
  folder = Instance.new("Folder")
  folder.Name = "RemoteEventsFolder"
  folder.Parent = ReplicatedStorage
end

for name, kind in pairs(DEFINITIONS) do
  local existing = folder:FindFirstChild(name)
  if not existing then
    local className = (kind == "Function") and "RemoteFunction" or "RemoteEvent"
    if RunService:IsServer() then
      existing = Instance.new(className)
      existing.Name = name
      existing.Parent = folder
    else
      -- Client waits for server to create
      existing = folder:WaitForChild(name, 10)
    end
  end
  Remotes[name] = existing
end

return Remotes
