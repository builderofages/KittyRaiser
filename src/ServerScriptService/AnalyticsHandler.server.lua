-- AnalyticsHandler.server.lua
-- Centralized analytics event firing. Uses Roblox AnalyticsService where possible,
-- falls back to print() in studio. External adapters (PlayFab, etc.) can hook here.
-- Place in: ServerScriptService > AnalyticsHandler (Script)

local Players = game:GetService("Players")
local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local Analytics = {}

local sessionStart = {}  -- userId -> os.time()

local function emit(eventName, player, props)
    if not GameConfig.ANALYTICS_ENABLED then return end
    local userId = player and player.UserId or 0
    local payload = {
        event = eventName,
        userId = userId,
        ts = os.time(),
        props = props or {},
    }
    if RunService:IsStudio() then
        print(string.format("[Analytics] %s userId=%d %s",
            eventName, userId, game:GetService("HttpService"):JSONEncode(props or {})))
    end
    -- Roblox built-in funnel tracking (when applicable). Guard against nil player
    -- because session_start fires synchronously and player can be nil for global events.
    pcall(function()
        if player and eventName == "level_up" and props and props.newLevel then
            AnalyticsService:LogProgressionEvent(
                player,
                "MainProgression",
                Enum.AnalyticsProgressionStatus.Complete,
                props.newLevel
            )
        end
    end)
end

function Analytics.sessionStart(player)
    if not player then return end
    sessionStart[player.UserId] = os.clock()
    emit("session_start", player)
end

function Analytics.sessionEnd(player)
    if not player then return end
    local start = sessionStart[player.UserId]
    local duration = start and (os.clock() - start) or 0
    emit("session_end", player, {duration = math.floor(duration)})
    sessionStart[player.UserId] = nil
end

function Analytics.firstSummon(player)
    emit("first_summon", player)
end

function Analytics.firstPrank(player, prankName)
    emit("first_prank", player, {prank = prankName})
end

function Analytics.levelUp(player, newLevel)
    emit("level_up", player, {newLevel = newLevel})
end

function Analytics.rebirth(player, rebirths)
    emit("rebirth_completed", player, {rebirths = rebirths})
end

function Analytics.gamepassPurchased(player, gamepassId)
    emit("gamepass_purchased", player, {gamepassId = gamepassId})
end

function Analytics.devProductPurchased(player, productId)
    emit("devproduct_purchased", player, {productId = productId})
end

Players.PlayerAdded:Connect(function(p) Analytics.sessionStart(p) end)
Players.PlayerRemoving:Connect(function(p) Analytics.sessionEnd(p) end)

_G.KittyRaiserAnalytics = Analytics
return Analytics
