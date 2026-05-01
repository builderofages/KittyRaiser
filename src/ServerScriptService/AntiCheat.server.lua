-- AntiCheat.server.lua
-- Server-side rate limiting + sanity checks. Anti-cheat is server-authoritative.
-- Place in: ServerScriptService > AntiCheat (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local AntiCheat = {}

-- Per-player rolling window: { [userId] = { lastPrankTime, prankCount, windowStart, lastPos, lastPosTime } }
local State = {}

local function getState(userId)
    if not State[userId] then
        State[userId] = {
            lastPrankTime = {},  -- per prank type
            prankWindow = {},    -- list of recent prank times
            lastPos = nil,
            lastPosTime = 0,
            flagCount = 0,
        }
    end
    return State[userId]
end

-- ===== Cooldown check =====
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

-- ===== Rate limit (global pranks/sec) =====
function AntiCheat.checkRateLimit(player)
    local s = getState(player.UserId)
    local now = os.clock()
    -- Clean window
    local cutoff = now - 1
    local cleaned = {}
    for _, t in ipairs(s.prankWindow) do
        if t > cutoff then table.insert(cleaned, t) end
    end
    s.prankWindow = cleaned
    if #s.prankWindow >= GameConfig.MAX_PRANKS_PER_SECOND then
        AntiCheat.flag(player, "rate_limit_exceeded")
        return false, "rate_limited"
    end
    table.insert(s.prankWindow, now)
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
        -- Roblox max running speed ~24 studs/sec; allow 3x for jumps/lag
        if speed > 80 and dist > GameConfig.MAX_DISTANCE_TELEPORT then
            AntiCheat.flag(player, "teleport_detected")
            return false
        end
    end
    s.lastPos = hrp.Position
    s.lastPosTime = now
    return true
end

-- ===== Validate target NPC =====
function AntiCheat.isValidNPC(targetModel)
    if not targetModel or not targetModel:IsA("Model") then return false end
    if not targetModel:GetAttribute("KittyRaiserNPC") then return false end
    if targetModel:GetAttribute("Pranked") then return false end -- already pranked, prevent double-grant
    return true
end

-- ===== Flag a suspicious event =====
function AntiCheat.flag(player, reason)
    local s = getState(player.UserId)
    s.flagCount = s.flagCount + 1
    warn("[AntiCheat] FLAG", player.Name, reason, "total flags:", s.flagCount)
    if s.flagCount >= GameConfig.SUSPICIOUS_FLAG_THRESHOLD then
        warn("[AntiCheat] Player", player.Name, "exceeded flag threshold - chaos grants suspended for session")
    end
end

function AntiCheat.isSuspended(player)
    local s = getState(player.UserId)
    return s.flagCount >= GameConfig.SUSPICIOUS_FLAG_THRESHOLD
end

-- Cleanup on leave
Players.PlayerRemoving:Connect(function(player)
    State[player.UserId] = nil
end)

-- Heartbeat teleport check
game:GetService("RunService").Heartbeat:Connect(function()
    for _, player in ipairs(Players:GetPlayers()) do
        AntiCheat.checkTeleport(player)
    end
end)

_G.KittyRaiserAntiCheat = AntiCheat
return AntiCheat
