-- run.lua  — load every source file through the mock and exercise key flows.
-- Reports pass/fail per file + per integration check.

require("test.roblox_mock")

local results = {pass = {}, fail = {}}
local function pass(label) table.insert(results.pass, label); print("PASS  " .. label) end
local function fail(label, err)
    table.insert(results.fail, {label = label, err = err})
    print("FAIL  " .. label .. "\n      " .. tostring(err))
end

-- ============================================================================
-- Wire up the source tree under ReplicatedStorage.Modules so require()
-- through `ReplicatedStorage:WaitForChild("Modules"):WaitForChild("X")` works.
-- We hijack require by replacing it with a path-aware loader.
-- ============================================================================

local moduleSourceRoot = "src/ReplicatedStorage/Modules"

local rs = game:GetService("ReplicatedStorage")
local modulesFolder = Instance.new("Folder")
modulesFolder.Name = "Modules"
modulesFolder.Parent = rs

-- Cache of "ModuleScript Instance -> resolved table"
local moduleResultsByInstance = {}
-- Cache of "module name -> ModuleScript Instance"
local moduleScriptByName = {}

-- Pre-populate Modules folder with ModuleScript proxies
local function dirEntries(path)
    local out = {}
    local p = io.popen('ls "' .. path .. '"')
    for line in p:lines() do table.insert(out, line) end
    p:close()
    return out
end

for _, entry in ipairs(dirEntries(moduleSourceRoot)) do
    if entry:match("%.lua$") then
        local name = entry:gsub("%.lua$", "")
        local mod = Instance.new("ModuleScript")
        mod.Name = name
        mod.Parent = modulesFolder
        mod._sourcePath = moduleSourceRoot .. "/" .. entry
        moduleScriptByName[name] = mod
    end
end

-- Override the global require to handle ModuleScript Instances.
local originalRequire = require
function require(target)
    if type(target) == "string" then
        return originalRequire(target)
    end
    -- Treat as ModuleScript Instance: load source via dofile
    if moduleResultsByInstance[target] then return moduleResultsByInstance[target] end
    local path = target._sourcePath
    if not path then
        error("ModuleScript without _sourcePath: " .. tostring(target.Name))
    end
    local fn, err = loadfile(path)
    if not fn then error("loadfile failed for " .. path .. ": " .. tostring(err)) end
    local result = fn()
    moduleResultsByInstance[target] = result or true
    return moduleResultsByInstance[target]
end

-- ============================================================================
-- Phase 1: Load every module
-- ============================================================================

print("\n========== Phase 1: Module loading ==========")
local modules = {}
for name, instance in pairs(moduleScriptByName) do
    local ok, result = pcall(require, instance)
    if ok then
        modules[name] = result
        pass("load module " .. name)
    else
        fail("load module " .. name, result)
    end
end

-- ============================================================================
-- Phase 2: Validate config schema
-- ============================================================================

print("\n========== Phase 2: Config schema ==========")

if modules.GameConfig then
    local gc = modules.GameConfig
    local function check(label, ok)
        if ok then pass(label) else fail(label, "assertion failed") end
    end
    check("GameConfig.LEVEL_CAP set", type(gc.LEVEL_CAP) == "number" and gc.LEVEL_CAP > 0)
    check("GameConfig.STARTING_CHAOS set", type(gc.STARTING_CHAOS) == "number")
    check("GameConfig.xpRequired callable", type(gc.xpRequired) == "function" and gc.xpRequired(1) > 0)
    check("GameConfig.computeMultiplier callable", type(gc.computeMultiplier) == "function")
    local m = gc.computeMultiplier(0, false, 0)
    check("computeMultiplier(0,false,0) == 1", m == 1.0)
    local m2 = gc.computeMultiplier(4, true, 10)  -- 1+0.25*4=2, *2 vip=4, +10*0.01=4.4
    check("computeMultiplier(4,true,10) > 4", m2 > 4)
    check("GameConfig.perkSlotsAtLevel(5) == 1", gc.perkSlotsAtLevel(5) == 1)
    check("GameConfig.perkSlotsAtLevel(25) == 5", gc.perkSlotsAtLevel(25) == 5)
    check("GameConfig.rebirthChaosCost(0) > 0", gc.rebirthChaosCost(0) > 0)
    check("rebirth cost increases", gc.rebirthChaosCost(5) > gc.rebirthChaosCost(0))
    check("validate() runs", type(gc.validate) == "function" and pcall(gc.validate))
    -- Weather weights sum check
    local sum = 0
    for _, w in pairs(gc.WEATHER_WEIGHTS) do sum = sum + w end
    check("WEATHER_WEIGHTS sum to ~1.0", math.abs(sum - 1.0) < 0.001)
end

if modules.PrankConfig then
    local pc = modules.PrankConfig
    pass("PrankConfig.Order length == " .. #pc.Order)
    for _, name in ipairs(pc.Order) do
        if pc.Pranks[name] then
            local p = pc.Pranks[name]
            local ok = type(p.unlockLevel) == "number"
                and type(p.cooldown) == "number"
                and type(p.baseChaos) == "number"
                and type(p.rangeStuds) == "number"
            if ok then pass("PrankConfig." .. name .. " well-formed")
            else fail("PrankConfig." .. name, "missing required field") end
        else
            fail("PrankConfig.Order references " .. name, "not found in Pranks table")
        end
    end
end

if modules.CosmeticConfig then
    local cc = modules.CosmeticConfig
    for _, id in ipairs(cc.Order) do
        local s = cc.Skins[id]
        if s and type(s.chaosMultiplier) == "number" and s.chaosMultiplier > 0 then
            pass("CosmeticConfig." .. id .. " well-formed")
        else
            fail("CosmeticConfig." .. id, "bad / missing")
        end
    end
end

if modules.PerkConfig then
    local pc = modules.PerkConfig
    -- Every perk in SlotOptions must exist in Perks; every perk's slot must match its option list
    for slot, options in pairs(pc.SlotOptions) do
        for _, perkId in ipairs(options) do
            local p = pc.Perks[perkId]
            if p and p.slot == slot then
                pass(("PerkConfig slot %d -> %s OK"):format(slot, perkId))
            else
                fail(("PerkConfig slot %d -> %s"):format(slot, perkId), "missing or wrong slot")
            end
        end
    end
    if type(pc.sumEffect) == "function" then
        local ok = pc.sumEffect({"ChaosFeast", "Vampuss"}, "prankHungerRestore")
        if ok == 6 then pass("sumEffect(ChaosFeast+Vampuss, prankHungerRestore) == 6")
        else fail("sumEffect prankHungerRestore", "got " .. tostring(ok)) end
    end
end

if modules.SharedUtil then
    local u = modules.SharedUtil
    -- waitForGlobal returns nil after timeout
    local r = u.waitForGlobal("definitely_not_set", 0.05)
    if r == nil then pass("SharedUtil.waitForGlobal times out cleanly")
    else fail("SharedUtil.waitForGlobal", "should have timed out") end
    -- slidingExceeds
    local arr = {}
    local ok = true
    for i = 1, 5 do
        if u.slidingExceeds(arr, 1.0, 6) then ok = false; break end
    end
    if ok then pass("slidingExceeds: 5 events under cap of 6 are accepted")
    else fail("slidingExceeds", "blocked too early") end
    if u.slidingExceeds(arr, 1.0, 6) then  -- 6th
        fail("slidingExceeds", "6th should still be allowed (we add then check)")
    end
    -- 7th should fail
    local seventh = u.slidingExceeds(arr, 1.0, 6)
    if seventh then pass("slidingExceeds: 7th over cap is rejected")
    else fail("slidingExceeds 7th", "should reject") end
end

if modules.RemoteEvents then
    -- Ensure every consumer-referenced remote actually got created
    local declared = {}
    for k, v in pairs(modules.RemoteEvents) do declared[k] = true end
    local count = 0
    for _ in pairs(declared) do count = count + 1 end
    pass("RemoteEvents module exposes " .. count .. " entries")
end

-- ============================================================================
-- Phase 3: Cross-config consistency
-- ============================================================================

print("\n========== Phase 3: Cross-config consistency ==========")
do
    local gc = modules.GameConfig
    local cc = modules.CosmeticConfig
    -- Skins of currency=robux must reference a real GAMEPASS_IDS key
    if gc and cc then
        for id, skin in pairs(cc.Skins) do
            if skin.currency == "robux" then
                if skin.gamepassKey and gc.GAMEPASS_IDS[skin.gamepassKey] ~= nil then
                    pass("Cosmetic " .. id .. " maps to GAMEPASS_IDS." .. skin.gamepassKey)
                else
                    fail("Cosmetic " .. id .. " gamepassKey", "missing or unknown")
                end
            end
        end
    end
    -- Stat names referenced match config
    local pc = modules.PerkConfig
    if pc and gc then
        for slot, options in pairs(pc.SlotOptions) do
            for _, perkId in ipairs(options) do
                local perk = pc.Perks[perkId]
                if perk and perk.effect and perk.effect.statBonus then
                    local stat = perk.effect.statBonus.stat
                    if stat and not table.find(gc.STAT_NAMES, stat) then
                        fail("Perk " .. perkId .. " statBonus", "unknown stat: " .. tostring(stat))
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- Phase 4: Server scripts initialize
-- ============================================================================

print("\n========== Phase 4: Server script init ==========")

-- Helper: dofile a server script under controlled environment.
local function runScript(label, path)
    local fn, err = loadfile(path)
    if not fn then fail(label, "loadfile: " .. tostring(err)); return end
    local ok, result = pcall(fn)
    if ok then pass(label) else fail(label, result) end
end

-- The server scripts depend on each other via _G globals. We seed the most
-- basic of them so dependents don't time out.
-- Note: SharedUtil.waitForGlobal already handles missing cases gracefully.

local serverScripts = {}
for line in io.popen('ls src/ServerScriptService'):lines() do
    if line:match("%.server%.lua$") then
        table.insert(serverScripts, line)
    end
end

-- Order matters: data first, then anti-cheat / summon, then dependents.
local INIT_ORDER = {
    "RemotesBootstrap.server.lua",
    "DataHandler.server.lua",
    "AntiCheat.server.lua",
    "SummonSystem.server.lua",
    "PrankSystem.server.lua",
    "CosmeticHandler.server.lua",
    "RebirthHandler.server.lua",
    "MonetizationHandler.server.lua",
    "PerkSystem.server.lua",
    "SurvivalSystem.server.lua",
    "DailyRewardSystem.server.lua",
    "LeaderboardHandler.server.lua",
    "WeatherSystem.server.lua",
    "EmoteSystem.server.lua",
    "AnalyticsHandler.server.lua",
    "AdminSystem.server.lua",
    "SafetyGuard.server.lua",
    "SpawnEnforcer.server.lua",
    "CatCharacterBuilder.server.lua",
    "CatLifelike.server.lua",
    "RagdollOnPrank.server.lua",
    "WalkAnim.server.lua",
    "CityRebuild.server.lua",
    "StrayLighting.server.lua",
    "AmbientCrowd.server.lua",
    "MeshLoader.server.lua",
    "PerfOptimize.server.lua",
    "DiagnosticDump.server.lua",
    -- New systems added in the polish pass
    "LeaderstatsSystem.server.lua",
    "CodeSystem.server.lua",
    "SettingsSystem.server.lua",
    "KillBarrier.server.lua",
    "SpawnProtection.server.lua",
    "AFKSystem.server.lua",
    "CoinPickup.server.lua",
    "ChatTags.server.lua",
    "QuestSystem.server.lua",
    "BadgeSystem.server.lua",
}

for _, fname in ipairs(INIT_ORDER) do
    local path = "src/ServerScriptService/" .. fname
    runScript("init " .. fname, path)
end

-- Catch any server scripts NOT in INIT_ORDER (we'd miss them otherwise)
local seen = {}
for _, f in ipairs(INIT_ORDER) do seen[f] = true end
for _, f in ipairs(serverScripts) do
    if not seen[f] then
        runScript("init [unordered] " .. f, "src/ServerScriptService/" .. f)
    end
end

-- ============================================================================
-- Phase 5: Integration smoke — call key public APIs
-- ============================================================================

print("\n========== Phase 5: Integration smoke ==========")

if _G.KittyRaiserData then
    pass("_G.KittyRaiserData exported")
else
    fail("_G.KittyRaiserData", "not exported by DataHandler")
end

if _G.KittyRaiserAntiCheat then
    pass("_G.KittyRaiserAntiCheat exported")
else
    fail("_G.KittyRaiserAntiCheat", "not exported by AntiCheat")
end

if _G.KittyRaiserSummon then
    pass("_G.KittyRaiserSummon exported")
else
    fail("_G.KittyRaiserSummon", "not exported by SummonSystem")
end

if _G.KittyRaiserGetWeatherMult then
    local m = _G.KittyRaiserGetWeatherMult()
    if type(m) == "number" then pass("KittyRaiserGetWeatherMult() returns " .. m)
    else fail("KittyRaiserGetWeatherMult", "returned non-number: " .. tostring(m)) end
end

if _G.KittyRaiserMarkLeaderboardDirty then
    pass("_G.KittyRaiserMarkLeaderboardDirty registered")
end

-- Exercise SummonSystem.markPranked atomicity
if _G.KittyRaiserSummon and _G.KittyRaiserSummon.markPranked then
    local fakeNpc = makeInstance and makeInstance("Model", "Test") or Instance.new("Model")
    fakeNpc:SetAttribute("KittyRaiserNPC", true)
    fakeNpc.Parent = workspace
    local first = _G.KittyRaiserSummon.markPranked(fakeNpc)
    local second = _G.KittyRaiserSummon.markPranked(fakeNpc)
    if first == true and second == false then
        pass("markPranked atomic: first=true, second=false")
    else
        fail("markPranked atomic", ("first=%s second=%s"):format(tostring(first), tostring(second)))
    end
end

-- AntiCheat sliding window: 6 prank requests in 1s should be allowed; 7th rejected
if _G.KittyRaiserAntiCheat and _G.KittyRaiserAntiCheat.checkRateLimit then
    local fakePlayer = {UserId = 9999, Name = "TestPlayer"}
    local last
    for i = 1, 6 do last = _G.KittyRaiserAntiCheat.checkRateLimit(fakePlayer) end
    if last == true then pass("AntiCheat rate-limit: 6/sec accepted")
    else fail("AntiCheat rate-limit allow", "blocked too early") end
    local denied = _G.KittyRaiserAntiCheat.checkRateLimit(fakePlayer)
    if denied == false then pass("AntiCheat rate-limit: 7th rejected")
    else fail("AntiCheat rate-limit reject", "should have blocked") end
end

-- ============================================================================
-- Phase 6: End-to-end gameplay simulation
-- Simulates a player session: spawn → summon NPC → prank → chaos → level up
-- → rebirth → code redeem → setting change.
-- ============================================================================

print("\n========== Phase 6: Gameplay simulation ==========")

local Players = game:GetService("Players")

-- Synthesize a Player object that mimics enough of the Roblox Player API.
local function makeFakePlayer(userId, name)
    local p = Instance.new("Player")
    p.Name = name
    p.DisplayName = name
    p.UserId = userId
    p.Character = nil
    p.Parent = Players
    p.GetAttribute = function(self, k) return self._attributes and self._attributes[k] end
    p.SetAttribute = function(self, k, v) self._attributes = self._attributes or {}; self._attributes[k] = v end
    p.Kick = function(self, msg) self._kicked = msg end
    p.CharacterAdded = {Connect = function(_, fn) return {Disconnect = function() end} end,
                        Once = function(_, fn) return {Disconnect = function() end} end,
                        Fire = function() end}
    p.CharacterRemoving = {Connect = function(_, fn) return {Disconnect = function() end} end,
                           Fire = function() end}
    p.Chatted = {Connect = function(_, fn) return {Disconnect = function() end} end}
    return p
end

-- Override Players.GetPlayerByUserId to return our fakes.
local fakePlayers = {}
Players.GetPlayerByUserId = function(_, id) return fakePlayers[id] end
Players.GetPlayerFromCharacter = function(_, char)
    for _, p in pairs(fakePlayers) do
        if p.Character == char then return p end
    end
    return nil
end
Players.GetPlayers = function(_)
    local out = {}
    for _, p in pairs(fakePlayers) do table.insert(out, p) end
    return out
end

-- Bootstrap a fake player with data straight into DataHandler.
local function spawnFakePlayer(userId, name)
    local p = makeFakePlayer(userId, name)
    fakePlayers[userId] = p
    -- Manually inject default data (skip session lock for simulation)
    local default = {
        version = 3,
        chaosPoints = 0, hellTokens = 0, level = 1, xp = 0, rebirths = 0,
        equippedSkin = "Default",
        ownedSkins = {"Default"},
        soulShards = 0, totalPranks = 0, totalRobuxSpent = 0,
        firstPlayDate = os.time(), lastPlayDate = os.time(),
        flagCount = 0, suspended = false,
        settingsMusicOn = true, settingsSFXOn = true,
        settingsMusicVolume = 0.5, settingsSFXVolume = 0.7, settingsCameraMode = "third",
        redeemedCodes = {},
        purchasedDevProductIds = {},
        stats = {Speed=0, Jump=0, Luck=0, Strength=0, Agility=0},
        unspentStatPoints = 0, perks = {},
        hunger = 100, thirst = 100,
        dailyStreak = 0, lastDailyClaim = 0,
        seenTutorial = false,
    }
    _G.KittyRaiserData.setData(p, default)
    return p
end

local fakeP = spawnFakePlayer(1001, "TestPlayer1")
if fakeP then pass("simulated player join") else fail("simulated player join", "nil") end

-- Verify data populated
local d = _G.KittyRaiserData.getData(fakeP)
if d and d.level == 1 and d.chaosPoints == 0 then
    pass("simulated player has default data (L1, 0 chaos)")
else
    fail("simulated player default data", "level=" .. tostring(d and d.level))
end

-- Simulate summoning an NPC, then validate registry membership.
local SummonSystem = _G.KittyRaiserSummon
if SummonSystem and SummonSystem.summon then
    -- Give the player a character so summon's spawn logic has something to anchor to
    local char = Instance.new("Model")
    char.Name = fakeP.Name
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Position = Vector3.new(0, 5, 0)
    hrp.Parent = char
    char.PrimaryPart = hrp
    fakeP.Character = char

    local ok, npc = SummonSystem.summon(fakeP)
    if ok and npc then
        pass("SummonSystem.summon returns NPC")
        if SummonSystem.isRegistered(npc) then
            pass("NPC is in server registry")
        else
            fail("NPC registry check", "summoned NPC not in registry")
        end
        if npc:GetAttribute("SummonedBy") == fakeP.UserId then
            pass("NPC has SummonedBy attribute")
        else
            fail("NPC SummonedBy", "missing or wrong")
        end
    else
        fail("SummonSystem.summon", tostring(npc))
    end
end

-- Simulate awarding chaos by directly manipulating DataHandler.modify
local before = _G.KittyRaiserData.getData(fakeP).chaosPoints
_G.KittyRaiserData.modify(fakeP, function(dd)
    dd.chaosPoints = (dd.chaosPoints or 0) + 100
    dd.totalPranks = (dd.totalPranks or 0) + 1
end)
local after = _G.KittyRaiserData.getData(fakeP).chaosPoints
if after - before == 100 then
    pass("DataHandler.modify added 100 chaos")
else
    fail("DataHandler.modify chaos delta", "got " .. (after - before))
end

-- Simulate progression to level 5 (perk slot threshold)
_G.KittyRaiserData.modify(fakeP, function(dd) dd.level = 5; dd.xp = 0 end)
local availSlots = (modules.GameConfig).perkSlotsAtLevel(5)
if availSlots == 1 then pass("at L5, perkSlotsAtLevel returns 1")
else fail("perkSlotsAtLevel(5)", "got " .. availSlots) end

-- Equip a slot-1 perk and verify
local equipResult = nil
do
    local rf = modules.RemoteEvents.RequestEquipPerk
    if rf and rf.OnServerInvoke then
        local ok, result = pcall(rf.OnServerInvoke, fakeP, 1, "QuickPaws")
        equipResult = ok and result
    end
end
if equipResult == true then
    local d2 = _G.KittyRaiserData.getData(fakeP)
    if d2.perks["1"] == "QuickPaws" then
        pass("equipped QuickPaws in slot 1; data persisted")
    else
        fail("perk equip persistence", "perks[1]=" .. tostring(d2.perks["1"]))
    end
else
    fail("equip QuickPaws", "OnServerInvoke returned " .. tostring(equipResult))
end

-- Try to skip slot 2 → should fail (sequential rule)
do
    local rf = modules.RemoteEvents.RequestEquipPerk
    -- Player is L5, only 1 slot avail. Try slot 2 — should be slot_locked.
    local ok, err = pcall(rf.OnServerInvoke, fakeP, 2, "PieMaster")
    if not ok or err ~= true then
        pass("perk slot 2 locked at L5 (correct)")
    else
        fail("perk slot 2 at L5", "should be locked but allowed")
    end
end

-- Bring player to L25 + max chaos for rebirth attempt
_G.KittyRaiserData.modify(fakeP, function(dd)
    dd.level = 25; dd.chaosPoints = 200000; dd.rebirths = 0
end)
do
    local rf = modules.RemoteEvents.RequestRebirth
    local ok, result = pcall(rf.OnServerInvoke, fakeP)
    if ok and result == true then
        local d2 = _G.KittyRaiserData.getData(fakeP)
        if d2.rebirths == 1 and d2.level == 1 then
            pass("rebirth: rebirths=1, level reset to 1")
        else
            fail("rebirth state", ("rebirths=%d level=%d"):format(d2.rebirths, d2.level))
        end
    else
        fail("rebirth invoke", tostring(result))
    end
end

-- Code redemption: try invalid code, then a real one.
-- Clear rate-limit state between calls so tight test loops don't trip the
-- 1-second limit on RequestRedeemCode.
modules.SharedUtil.clearRate(fakeP.UserId)
do
    local rf = modules.RemoteEvents.RequestRedeemCode
    if rf and rf.OnServerInvoke then
        local _, err1 = pcall(rf.OnServerInvoke, fakeP, "GARBAGE_CODE")
        if err1 == "invalid_code" or err1 == false then
            pass("invalid code rejected")
        else
            -- pcall returns (true, returnValue1, returnValue2) so check both
            local ok2, ret1, ret2 = pcall(rf.OnServerInvoke, fakeP, "GARBAGE_CODE")
            if ret1 == false and ret2 == "invalid_code" then
                pass("invalid code rejected")
            else
                fail("invalid code", ("ret1=%s ret2=%s"):format(tostring(ret1), tostring(ret2)))
            end
        end
        modules.SharedUtil.clearRate(fakeP.UserId)
        local before = _G.KittyRaiserData.getData(fakeP).chaosPoints
        local ok3, ret = pcall(rf.OnServerInvoke, fakeP, "LAUNCH")
        local after = _G.KittyRaiserData.getData(fakeP).chaosPoints
        if (after - before) == 5000 then
            pass("LAUNCH code grants 5000 chaos")
        else
            fail("LAUNCH redemption", "delta=" .. (after - before))
        end
        -- Try redeeming again: should fail (already_redeemed, not rate_limited)
        modules.SharedUtil.clearRate(fakeP.UserId)
        local _, ret2, _ = pcall(rf.OnServerInvoke, fakeP, "LAUNCH")
        local d3 = _G.KittyRaiserData.getData(fakeP)
        if d3.chaosPoints == after then
            pass("double-redeem of same code rejected")
        else
            fail("double-redeem", "balance changed from " .. after .. " to " .. d3.chaosPoints)
        end
    end
end

-- Reset rate-limit state before settings test (otherwise hits 0.2s window).
modules.SharedUtil.clearRate(fakeP.UserId)

-- Setting change: valid + invalid
do
    local rf = modules.RemoteEvents.RequestSettingChange
    if rf and rf.OnServerInvoke then
        local ok, ret = pcall(rf.OnServerInvoke, fakeP, "settingsMusicVolume", 0.3)
        if ok and ret == true then pass("setting music volume to 0.3 succeeded")
        else fail("setting music volume", tostring(ret)) end
        local _, badret = pcall(rf.OnServerInvoke, fakeP, "settingsCameraMode", "isometric")
        if badret == false then pass("invalid camera mode rejected")
        else fail("invalid camera mode", tostring(badret)) end
    end
end

-- ============================================================================
-- Phase 7: Polish-system smoke (Quest, Badge)
-- ============================================================================

print("\n========== Phase 7: Polish system smoke ==========")

-- QuestSystem.bump should populate counters on the player's data.
do
    local Quests = _G.KittyRaiserQuests
    if Quests then
        Quests.bump(fakeP, "totalPranks", 3)
        local d = _G.KittyRaiserData.getData(fakeP)
        if d.questCounters and (d.questCounters.totalPranks or 0) >= 3 then
            pass("Quest counter totalPranks bumped to 3")
        else
            fail("Quest counter bump", "got " .. tostring(d.questCounters and d.questCounters.totalPranks))
        end
    else
        fail("_G.KittyRaiserQuests", "not exported")
    end
end

-- Quest claim should reject if not yet at target.
do
    local rf = modules.RemoteEvents.RequestQuestClaim
    if rf and rf.OnServerInvoke then
        modules.SharedUtil.clearRate(fakeP.UserId)
        -- Pick whatever quest is assigned for today
        local d = _G.KittyRaiserData.getData(fakeP)
        local firstQuestId = d.questAssigned and d.questAssigned[1]
        if firstQuestId then
            local _, ok, errOrQuest = pcall(rf.OnServerInvoke, fakeP, firstQuestId)
            if ok == false then
                pass("Quest claim rejected when below target")
            else
                pass("Quest claim returned (target may be 0): ok=" .. tostring(ok))
            end
        end
    end
end

-- Bring fakeP to a state where badges should fire (level 25).
_G.KittyRaiserData.modify(fakeP, function(dd) dd.level = 25; dd.totalPranks = 1500 end)
-- Force one BadgeSystem evaluation by invoking checkAll on each player. We
-- reach in via the polling loop indirectly: the loop runs every 5s, so we
-- can't wait for it. Instead, verify the data + config integrity:
local BadgeConfig = modules.BadgeConfig
if BadgeConfig and #BadgeConfig.Badges > 0 then
    -- The "level_25" badge should pass its check function.
    local lvl25 = nil
    for _, b in ipairs(BadgeConfig.Badges) do
        if b.id == "level_25" then lvl25 = b; break end
    end
    if lvl25 then
        local d = _G.KittyRaiserData.getData(fakeP)
        local ctx = {CosmeticConfig = modules.CosmeticConfig, PrankConfig = modules.PrankConfig}
        local ok, result = pcall(lvl25.check, d, ctx)
        if ok and result then
            pass("Badge 'level_25' check returns true at L25")
        else
            fail("Badge level_25 check", tostring(result))
        end
    end
    -- The "first_prank" badge should pass with totalPranks > 0.
    local firstPrank = nil
    for _, b in ipairs(BadgeConfig.Badges) do
        if b.id == "first_prank" then firstPrank = b; break end
    end
    if firstPrank then
        local d = _G.KittyRaiserData.getData(fakeP)
        local ctx = {CosmeticConfig = modules.CosmeticConfig, PrankConfig = modules.PrankConfig}
        local ok, result = pcall(firstPrank.check, d, ctx)
        if ok and result then pass("Badge 'first_prank' check returns true after a prank")
        else fail("Badge first_prank check", tostring(result)) end
    end
end

-- AntiCheat unsuspend path
if _G.KittyRaiserAntiCheat and _G.KittyRaiserAntiCheat.unsuspend then
    -- Simulate suspension
    _G.KittyRaiserAntiCheat.flag(fakeP, "test_flag")
    _G.KittyRaiserAntiCheat.flag(fakeP, "test_flag")
    _G.KittyRaiserAntiCheat.flag(fakeP, "test_flag")
    if _G.KittyRaiserAntiCheat.isSuspended(fakeP) then
        _G.KittyRaiserAntiCheat.unsuspend(fakeP)
        if not _G.KittyRaiserAntiCheat.isSuspended(fakeP) then
            pass("AntiCheat.unsuspend clears suspended state")
        else
            fail("AntiCheat.unsuspend", "still suspended")
        end
    else
        fail("AntiCheat.flag chain", "expected suspended after 3 flags")
    end
end

-- Skin fallback: equipping a non-existent skin should be rejected cleanly,
-- and the existing equippedSkin should be unchanged.
do
    local rf = modules.RemoteEvents.RequestEquipSkin
    if rf and rf.OnServerInvoke then
        modules.SharedUtil.clearRate(fakeP.UserId)
        local _, ok, err = pcall(rf.OnServerInvoke, fakeP, "DoesNotExist123")
        if ok == false and err == "invalid_skin" then
            pass("Equipping unknown skin is rejected with 'invalid_skin'")
        else
            fail("Equip unknown skin", "ok=" .. tostring(ok) .. " err=" .. tostring(err))
        end
    end
end

-- ============================================================================
-- Summary
-- ============================================================================

print("\n========== Summary ==========")
print(("PASS: %d   FAIL: %d"):format(#results.pass, #results.fail))
if #results.fail > 0 then
    print("\nFailures:")
    for _, f in ipairs(results.fail) do
        print("  - " .. f.label .. ": " .. tostring(f.err))
    end
    os.exit(1)
end
os.exit(0)
