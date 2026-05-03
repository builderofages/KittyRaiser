-- BadgeSystem.server.lua
-- Walks every player's data once per second and awards badges whose check()
-- newly returns true. Internal achievement (always works) + optional Roblox
-- BadgeService award (when a real badge ID is configured).

local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local BadgeConfig = require(ReplicatedStorage.Modules.BadgeConfig)
local CosmeticConfig = require(ReplicatedStorage.Modules.CosmeticConfig)
local PrankConfig = require(ReplicatedStorage.Modules.PrankConfig)
local SharedUtil = require(ReplicatedStorage.Modules.SharedUtil)

local DataHandler = SharedUtil.waitForGlobal("KittyRaiserData", 30)
if not DataHandler then return end

local CTX = {CosmeticConfig = CosmeticConfig, PrankConfig = PrankConfig}

-- Per-player Roblox-badge award debounce so we never call AwardBadge twice in
-- quick succession (Roblox internally rate-limits, but we de-dup ourselves).
local rbxBadgeAwarding = {}

local function awardRobloxBadge(player, badgeId)
    if not badgeId or badgeId == 0 then return end
    local key = player.UserId .. "_" .. badgeId
    if rbxBadgeAwarding[key] then return end
    rbxBadgeAwarding[key] = true
    task.spawn(function()
        local ok, awarded = pcall(function()
            return BadgeService:AwardBadge(player.UserId, badgeId)
        end)
        if not ok then warn("[BadgeSystem] AwardBadge failed:", awarded) end
        task.wait(5); rbxBadgeAwarding[key] = nil
    end)
end

local function checkAll(player)
    local d = DataHandler.getData(player)
    if not d then return end
    d.awardedBadges = d.awardedBadges or {}
    local newlyAwarded = {}
    for _, b in ipairs(BadgeConfig.Badges) do
        if not d.awardedBadges[b.id] then
            local ok, result = pcall(b.check, d, CTX)
            if ok and result then
                d.awardedBadges[b.id] = os.time()
                table.insert(newlyAwarded, b)
            end
        end
    end
    if #newlyAwarded > 0 then
        DataHandler.replicateToClient(player)
        for _, b in ipairs(newlyAwarded) do
            Remotes.NotifyClient:FireClient(player,
                "🏆 BADGE: " .. b.name, "success")
            awardRobloxBadge(player, b.robloxBadgeId)
        end
    end
end

-- 5s tick (was 2s). Awarded badges short-circuit, so the only cost is checks
-- for not-yet-awarded ones, which is small per-player. Server-load wise this
-- scales to 50 players × 16 unawarded checks comfortably under 80 ops / 5s.
task.spawn(function()
    while true do
        task.wait(5)
        for _, p in ipairs(Players:GetPlayers()) do checkAll(p) end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    for k in pairs(rbxBadgeAwarding) do
        if k:find("^" .. p.UserId .. "_") then rbxBadgeAwarding[k] = nil end
    end
end)

print("[BadgeSystem] online — " .. #BadgeConfig.Badges .. " badges registered")
