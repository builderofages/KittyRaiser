-- AntiCheat.server.lua
-- Server-side rate limiting + sanity checks. Anti-cheat is server-authoritative.
-- Place in: ServerScriptService > AntiCheat (Script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local SharedUtil = require(ReplicatedStorage.Modules.SharedUtil)

local AntiCheat = {}

-- DataHandler comes up after AntiCheat sometimes; resolve lazily on first flag.
local _dataHandler = nil
local function dh()
    if _dataHandler then return _dataHandler end
    _dataHandler = _G.KittyRaiserData
    return _dataHandler
end

local State = {}

local function getState(userId)
    if not State[userId] then
        State[userId] = {
            lastPrankTime = {},
            prankWindow = {},   -- sliding window of recent prank timestamps
            lastPos = nil,
            lastPosTime = 0,
            flagCount = 0,      -- session flags; persisted flagCount lives in DataHandler
            suspended = false,
        }
    end
    return State[userId]
end

-- Initialize from persisted save when player loads, so cheaters can't reset
-- their flag count by rejoining.
local function initFromSave(player)
    local handler = dh()
    if not handler then return end
    local data = handler.getData(player)
    if not data then return end
    local s = getState(player.UserId)
    s.flagCount = data.flagCount or 0
    s.suspended = (data.suspended == true) or (s.flagCount >= GameConfig.SUSPICIOUS_FLAG_THRESHOLD)
end

Players.PlayerAdded:Connect(function(player)
    -- DataHandler also runs PlayerAdded; wait briefly for it to load
    task.delay(3, function() initFromSave(player) end)
end)

-- ===== Cooldown check (per prank type) =====
function AntiCheat.checkPrankCooldown(player, prankName, cooldownSec)
    local s = getState(player.UserId)
    local now = os.clock()
    local last = s.lastPrankTime[prankName] or 0
    if (now - last) < cooldownSec then
        return false, "cooldown"
    end
    s.lastPrankTime[prankName] = now
    return true, nil
end

-- ===== True sliding-window rate limit =====
-- The previous version trimmed entries older than (now - 1) on every call.
-- That allowed bursts at second boundaries (6 at t=0.0, 6 more at t=1.001).
-- The new version uses SharedUtil.slidingExceeds which keeps a real window.
function AntiCheat.checkRateLimit(player)
    local s = getState(player.UserId)
    if SharedUtil.slidingExceeds(s.prankWindow, 1.0, GameConfig.MAX_PRANKS_PER_SECOND) then
        AntiCheat.flag(player, "rate_limit_exceeded")
        return false, "rate_limited"
    end
    return true, nil
end

-- ===== Distance check =====
function AntiCheat.checkPrankDistance(player, targetPart, maxStuds)
    local char = player.Character
    if not char then return false, "no_character" end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, "no_root" end
    if not targetPart or not targetPart:IsA("BasePart") then return false, "invalid_target" end
    local dist = (hrp.Position - targetPart.Position).Magnitude
    if dist > maxStuds then
        return false, "out_of_range"
    end
    return true, nil
end

-- ===== Teleport detection =====
-- Tightened threshold: top legitimate speed is ~24 walk + ~50 jump arc; we
-- allow MAX_TELEPORT_SPEED_STUDS_PER_SEC = 35 with a small jitter buffer for
-- network lag spikes. Also: prime lastPos on character spawn so the first
-- post-spawn frame can't get a free teleport.
function AntiCheat.checkTeleport(player)
    local char = player.Character
    if not char then return true end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return true end
    local s = getState(player.UserId)
    local now = os.clock()
    if s.lastPos then
        local dt = math.max(now - s.lastPosTime, 0.001)
        local dist = (hrp.Position - s.lastPos).Magnitude
        local speed = dist / dt
        local maxSpeed = GameConfig.MAX_TELEPORT_SPEED_STUDS_PER_SEC * 2  -- 2x burst headroom for lag
        if speed > maxSpeed and dist > 6 then
            AntiCheat.flag(player, "teleport_detected")
            -- snap them back to keep the cheat from progressing
            pcall(function() hrp.CFrame = CFrame.new(s.lastPos) end)
            return false
        end
    end
    s.lastPos = hrp.Position
    s.lastPosTime = now
    return true
end

-- ===== Validate target NPC =====
-- Adds: Workspace ancestry check, optional ownership check (NPC was summoned by
-- this player). Returns false reason for logging.
function AntiCheat.isValidNPC(targetModel, summoningPlayer)
    if not targetModel or not targetModel:IsA("Model") then return false, "not_model" end
    if not targetModel.Parent or not targetModel:IsDescendantOf(workspace) then
        return false, "not_in_workspace"
    end
    if not targetModel:GetAttribute("KittyRaiserNPC") then return false, "missing_attr" end
    if targetModel:GetAttribute("Pranked") then return false, "already_pranked" end
    if summoningPlayer then
        local summonedBy = targetModel:GetAttribute("SummonedBy")
        -- ambient (non-summoned) NPCs have no SummonedBy and are fair game for anyone
        if summonedBy ~= nil and summonedBy ~= summoningPlayer.UserId then
            return false, "not_owner"
        end
    end
    return true, nil
end

-- ===== Flag a suspicious event =====
-- Persists the new flagCount to the DataHandler so it survives rejoin.
function AntiCheat.flag(player, reason)
    local s = getState(player.UserId)
    s.flagCount = s.flagCount + 1
    warn("[AntiCheat] FLAG", player.Name, reason, "total flags:", s.flagCount)
    if s.flagCount >= GameConfig.SUSPICIOUS_FLAG_THRESHOLD then
        s.suspended = true
        warn("[AntiCheat] Player", player.Name, "suspended for session")
    end
    local handler = dh()
    if handler then
        handler.modify(player, function(d)
            d.flagCount = math.max(d.flagCount or 0, s.flagCount)
            if s.suspended then d.suspended = true end
        end)
    end
end

function AntiCheat.isSuspended(player)
    local s = getState(player.UserId)
    return s.suspended or s.flagCount >= GameConfig.SUSPICIOUS_FLAG_THRESHOLD
end

-- Reset position-tracking on respawn so a death + respawn doesn't trip a
-- false-positive teleport alert.
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        local s = getState(player.UserId)
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        if hrp then
            s.lastPos = hrp.Position
            s.lastPosTime = os.clock()
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    State[player.UserId] = nil
    SharedUtil.clearRate(player.UserId)
end)

-- Heartbeat teleport check (throttled to 4Hz - sufficient for catching teleports
-- without burning per-frame CPU on every player).
local lastTpCheck = 0
RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastTpCheck < 0.25 then return end
    lastTpCheck = now
    for _, player in ipairs(Players:GetPlayers()) do
        AntiCheat.checkTeleport(player)
    end
end)

_G.KittyRaiserAntiCheat = AntiCheat
return AntiCheat
