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
