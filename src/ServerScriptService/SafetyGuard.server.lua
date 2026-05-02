-- SafetyGuard.server.lua
-- Grok: kill _G race condition. After 10s if KittyRaiserData not set, install a stub
-- so PrankSystem/SummonSystem/etc don't hang forever.
-- Place in: ServerScriptService > SafetyGuard. Auto-runs FIRST.

local Players = game:GetService("Players")

-- Build a stub data store that mimics DataHandler API
local StubData = {}
local StubProfiles = {}

function StubData.getData(player)
  if not StubProfiles[player.UserId] then
    StubProfiles[player.UserId] = {
      version = 2,
      chaosPoints = 100,  -- give 100 starter chaos so first prank works
      hellTokens = 0,
      level = 1,
      xp = 0,
      rebirths = 0,
      hunger = 100,
      thirst = 100,
      perks = {},
      stats = {Speed=10, Jump=10, Luck=10, Strength=10, Agility=10},
      unspentStatPoints = 0,
      equippedSkin = "Default",
      ownedSkins = {Default = true},
      ownedAccessories = {},
      dailyStreak = 0,
      lastDailyClaim = 0,
      totalPranks = 0,
    }
  end
  return StubProfiles[player.UserId]
end

function StubData.setData(player, data)
  StubProfiles[player.UserId] = data
end

function StubData.modify(player, fn)
  local d = StubData.getData(player)
  if d then fn(d) end
  return true
end

function StubData.replicateToClient(player) end
function StubData.save(player) end

-- Stub anti-cheat
local StubAC = {}
function StubAC.isSuspended() return false end
function StubAC.checkPrankCooldown() return true end
function StubAC.checkRateLimit() return true end
function StubAC.checkPrankDistance() return true end
function StubAC.isValidNPC(model)
  return model and model:GetAttribute("KittyRaiserNPC")
end

-- Wait 10 sec then install stubs if needed
task.spawn(function()
  task.wait(10)
  if not _G.KittyRaiserData then
    warn("[SafetyGuard] DataHandler did not register _G.KittyRaiserData after 10s — installing stub")
    _G.KittyRaiserData = StubData
  end
  if not _G.KittyRaiserAntiCheat then
    warn("[SafetyGuard] AntiCheat did not register _G.KittyRaiserAntiCheat after 10s — installing stub")
    _G.KittyRaiserAntiCheat = StubAC
  end
end)

print("[SafetyGuard] watching for DataHandler / AntiCheat globals")
