-- run_luau.luau
-- Real-Luau test harness using Lune's @lune/roblox library for proper
-- Instance/Vector3/CFrame/Color3/UDim2 types. This is much closer to actual
-- Roblox behavior than the vanilla-Lua mock.
--
-- Usage: lune run test/run_luau.luau

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

-- ============================================================================
-- Patch globals to expose Roblox datatypes
-- ============================================================================
_G.Instance = roblox.Instance
_G.Vector3 = roblox.Vector3
_G.Vector2 = roblox.Vector2
_G.CFrame = roblox.CFrame
_G.Color3 = roblox.Color3
_G.UDim = roblox.UDim
_G.UDim2 = roblox.UDim2
_G.NumberRange = roblox.NumberRange
_G.NumberSequence = roblox.NumberSequence
_G.NumberSequenceKeypoint = roblox.NumberSequenceKeypoint
_G.ColorSequence = roblox.ColorSequence
_G.ColorSequenceKeypoint = roblox.ColorSequenceKeypoint
_G.BrickColor = roblox.BrickColor
_G.Region3 = roblox.Region3
_G.Ray = roblox.Ray
_G.Enum = roblox.Enum

-- Lune's TweenInfo. If missing, stub.
_G.TweenInfo = roblox.TweenInfo or function(...) return {args = {...}} end

-- Random
_G.Random = {
    new = function(seed)
        local rng = {
            _state = seed or os.time(),
            NextInteger = function(self, a, b) return math.random(a, b) end,
            NextNumber = function(self, a, b)
                a = a or 0; b = b or 1
                return math.random() * (b - a) + a
            end,
        }
        return rng
    end,
}

-- typeof: Lune already provides this for its own types
local origTypeof = typeof
function typeof(v)
    if type(v) == "table" and v.__type then return v.__type end
    local ok, t = pcall(origTypeof, v)
    if ok then return t end
    return type(v)
end

-- task scheduler (Lune has this natively)
_G.task = task

-- ============================================================================
-- Build a fake game DataModel with services
-- ============================================================================

local services = {}
local function makeService(className)
    local s = roblox.Instance.new(className)
    s.Name = className
    services[className] = s
    return s
end

-- Pre-create all services we use
local serviceNames = {
    "Workspace", "Players", "ReplicatedStorage", "ServerScriptService",
    "ServerStorage", "StarterGui", "StarterPlayer", "Lighting", "RunService",
    "TweenService", "Debris", "MarketplaceService", "DataStoreService",
    "InsertService", "HttpService", "AnalyticsService", "GuiService",
    "SoundService", "UserInputService", "TextChatService",
}
for _, n in ipairs(serviceNames) do makeService(n) end

local game = {
    JobId = "",
    PlaceId = 0,
    GetService = function(self, name)
        if not services[name] then services[name] = makeService(name) end
        return services[name]
    end,
    BindToClose = function(self, fn) end,
}
_G.game = game
_G.workspace = services.Workspace

-- Wire common services with method stubs Roblox scripts will call.
-- We must add these as fields on the existing Instances since roblox.Instance
-- doesn't expose service-specific methods.

local function addMethod(inst, name, fn)
    -- Lune's Instance is opaque; we can't add methods directly. So we store
    -- methods in a side-table keyed by the instance reference.
    inst[name] = fn  -- works if Lune lets you set arbitrary fields
end

local methodOk, methodErr = pcall(function()
    services.Players.GetPlayers = function() return {} end
    services.Players.GetPlayerByUserId = function(_, id) return nil end
    services.Players.GetPlayerFromCharacter = function(_, c) return nil end
end)
print("Method-attach test:", methodOk, methodErr or "ok")

-- ============================================================================
-- Just load every Luau source file under src/ and report parse + load
-- ============================================================================

local results = {pass = {}, fail = {}}
local function pass(label) table.insert(results.pass, label); print("PASS  " .. label) end
local function fail(label, err)
    table.insert(results.fail, {label = label, err = err})
    print("FAIL  " .. label .. "\n      " .. tostring(err))
end

-- Walk src/ for .lua files
local function walk(dir, out)
    out = out or {}
    for _, name in ipairs(fs.readDir(dir)) do
        local path = dir .. "/" .. name
        if fs.isDir(path) then
            walk(path, out)
        elseif name:match("%.lua$") then
            table.insert(out, path)
        end
    end
    return out
end

local files = walk("src")
table.sort(files)
print("\n========== Phase 1: Parse + load every source file via Luau ==========")
for _, path in ipairs(files) do
    local source = fs.readFile(path)
    -- loadstring (or loadfile) parses Luau.
    local fn, err = loadstring(source, path)
    if not fn then
        fail("parse " .. path, err)
    else
        pass("parse " .. path)
    end
end

print("\n========== Summary ==========")
print(("PASS: %d   FAIL: %d"):format(#results.pass, #results.fail))
if #results.fail > 0 then
    for _, f in ipairs(results.fail) do
        print("  - " .. f.label .. ": " .. tostring(f.err))
    end
    process.exit(1)
end
