-- SharedUtil.lua
-- Tiny utilities used across server scripts. Place in ReplicatedStorage > Modules.

local SharedUtil = {}

-- Wait for a value in _G with a timeout. Avoids deadlocks when a dependency
-- script errors during init.
function SharedUtil.waitForGlobal(name, timeoutSec)
    timeoutSec = timeoutSec or 15
    local deadline = os.clock() + timeoutSec
    while not _G[name] do
        if os.clock() > deadline then
            warn(("[SharedUtil] Timed out waiting for _G.%s after %ss"):format(name, tostring(timeoutSec)))
            return nil
        end
        task.wait(0.05)
    end
    return _G[name]
end

-- Per-player remote rate limiter. Returns true if the call should proceed.
-- key isolates separate remotes (so RequestRebirth and RequestPurchaseSkinChaos
-- don't share a budget).
local rateLimitState = {}
function SharedUtil.checkRate(player, key, intervalSec)
    if not player then return false end
    local userId = player.UserId
    rateLimitState[userId] = rateLimitState[userId] or {}
    local now = os.clock()
    local last = rateLimitState[userId][key] or 0
    if now - last < (intervalSec or 0.4) then
        return false
    end
    rateLimitState[userId][key] = now
    return true
end

function SharedUtil.clearRate(userId)
    rateLimitState[userId] = nil
end

-- Wrap a server-side handler so any Lua error is caught and reported to the
-- client via ErrorNotify, instead of silently leaving the UI hung.
function SharedUtil.safeHandle(remotes, player, handler, ...)
    local ok, result, err = pcall(handler, ...)
    if not ok then
        warn("[SharedUtil] handler error: " .. tostring(result))
        if remotes and remotes.ErrorNotify and player then
            pcall(function() remotes.ErrorNotify:FireClient(player, "internal_error") end)
        end
        return nil, "internal_error"
    end
    return result, err
end

-- Sliding-window counter. Stores timestamps of recent events; trims older than
-- windowSec. Returns true if appending now would exceed maxCount.
function SharedUtil.slidingExceeds(timestamps, windowSec, maxCount)
    local now = os.clock()
    local i = 1
    while i <= #timestamps do
        if now - timestamps[i] > windowSec then
            table.remove(timestamps, i)
        else
            i = i + 1
        end
    end
    if #timestamps >= maxCount then
        return true
    end
    table.insert(timestamps, now)
    return false
end

return SharedUtil
