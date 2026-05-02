-- RemotesBootstrap.server.lua  — runs first, creates RemoteEvents at ReplicatedStorage root
-- Per Grok: avoids race condition where client WaitForChild blocks because event is nested.
-- Place in: ServerScriptService > RemotesBootstrap (Script). Auto-runs FIRST.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EVENTS = {
  "RequestSpawnCustomization",
  "RequestSummonHuman",
  "RequestPrank",
  "RequestUseDevProduct",
  "RequestEatFood",
  "RequestDrinkWater",
  "RequestEmote",
  "UpdatePlayerData",
  "PrankRegistered",
  "PrankFailed",
  "LevelUp",
  "PerkSlotEarned",
  "RebirthCompleted",
  "NotifyClient",
  "LeaderboardUpdated",
  "TutorialStep",
  "WeatherChanged",
  "EventBroadcast",
  "SurvivalUpdate",
  "ForceSpawn",
}

local FUNCTIONS = {
  "RequestRebirth",
  "RequestEquipSkin",
  "RequestPurchaseSkinChaos",
  "RequestPurchaseSkinHellTokens",
  "RequestEquipPerk",
  "RequestResetPerks",
  "RequestAllocStat",
  "RequestClaimDaily",
  "RequestAdminCommand",
}

for _, name in ipairs(EVENTS) do
  if not ReplicatedStorage:FindFirstChild(name) then
    local re = Instance.new("RemoteEvent")
    re.Name = name
    re.Parent = ReplicatedStorage
  end
end
for _, name in ipairs(FUNCTIONS) do
  if not ReplicatedStorage:FindFirstChild(name) then
    local rf = Instance.new("RemoteFunction")
    rf.Name = name
    rf.Parent = ReplicatedStorage
  end
end

print("[RemotesBootstrap] created " .. #EVENTS .. " RemoteEvents + " .. #FUNCTIONS .. " RemoteFunctions at ReplicatedStorage root")
