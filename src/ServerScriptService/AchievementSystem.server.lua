-- AchievementSystem.server.lua
-- Listens for game events (first prank, level milestones, rebirth, boss
-- defeat, cop ticket) and awards Roblox badges via BadgeService:AwardBadge.
-- Only attempts an award when the badge id in AssetIds is non-zero
-- (otherwise it's a no-op until the user creates badges in Creator Hub).
-- Tracks awarded badges per session so we don't spam Roblox API.
--
-- Place in: ServerScriptService > AchievementSystem (Script). Auto-runs.

local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes      = require(ReplicatedStorage.Modules.RemoteEvents)
local AssetIds     = require(ReplicatedStorage.Modules.AssetIds)
local Achievements = require(ReplicatedStorage.Modules:WaitForChild("AchievementConfig"))

local function waitForGlobal(name)
    while not _G[name] do task.wait() end
    return _G[name]
end
local DataHandler = waitForGlobal("KittyRaiserData")

-- Per-session "already-awarded-this-session" cache so we don't re-award.
local awarded = {}  -- userId -> { [achId] = true }

local function getAwarded(player)
    awarded[player.UserId] = awarded[player.UserId] or {}
    return awarded[player.UserId]
end

local function tryAward(player, ach)
    local cache = getAwarded(player)
    if cache[ach.id] then return end
    cache[ach.id] = true

    -- Only call BadgeService if a real badge id has been pasted.
    if not AssetIds.has(ach.badgeAssetKey) then return end
    local badgeIdNumeric = tonumber(string.match(tostring(AssetIds[ach.badgeAssetKey]), "%d+"))
    if not badgeIdNumeric or badgeIdNumeric == 0 then return end

    -- Check whether the player already owns the badge to avoid duplicate calls.
    local owns = false
    pcall(function()
        owns = BadgeService:UserHasBadgeAsync(player.UserId, badgeIdNumeric)
    end)
    if owns then return end

    local ok, err = pcall(function()
        BadgeService:AwardBadge(player.UserId, badgeIdNumeric)
    end)
    if ok and Remotes.NotifyClient then
        Remotes.NotifyClient:FireClient(player, "ACHIEVEMENT  ·  " .. ach.name, "success")
    elseif not ok then
        warn("[AchievementSystem] AwardBadge failed:", err)
    end
end

-- Iterate achievements + check trigger
local function checkAll(player, kind, payload)
    for _, ach in ipairs(Achievements.List) do
        if ach.trigger ~= kind then continue end
        if kind == "level" and payload and payload >= ach.threshold then
            tryAward(player, ach)
        elseif kind == "rebirth" and payload and payload >= 1 then
            tryAward(player, ach)
        else
            tryAward(player, ach)
        end
    end
end

-- =====================================================================
-- HOOK GAME EVENTS via globals + remotes
-- =====================================================================
-- First prank: hook the bump that PrankSystem already calls.
-- We piggyback on _G.KittyRaiserBumpQuest so we don't need a new global.
local origBumpQuest = _G.KittyRaiserBumpQuest
_G.KittyRaiserBumpQuest = function(player, kind, amount, prankName)
    if origBumpQuest then pcall(origBumpQuest, player, kind, amount, prankName) end
    if kind == "any_prank" then
        checkAll(player, "first_prank", nil)
    end
end

-- Level up
local origBumpLevel = _G.KittyRaiserBumpLevelUp
_G.KittyRaiserBumpLevelUp = function(player)
    if origBumpLevel then pcall(origBumpLevel, player) end
    local d = DataHandler.getData and DataHandler.getData(player)
    if d and d.level then checkAll(player, "level", d.level) end
end

-- Rebirth
if Remotes.RebirthCompleted then
    -- RebirthCompleted is server -> client; also fired from RebirthHandler.
    -- We tap by listening to player attribute / poll. Simpler: inspect after
    -- RebirthHandler bump via a global hook if it exists.
end

-- Poll once per 8s for level + rebirth changes (cheap fallback)
task.spawn(function()
    while true do
        task.wait(8)
        for _, p in ipairs(Players:GetPlayers()) do
            local d = DataHandler.getData and DataHandler.getData(p)
            if d then
                if d.level then checkAll(p, "level", d.level) end
                if d.rebirths and d.rebirths >= 1 then
                    checkAll(p, "rebirth", d.rebirths)
                end
            end
        end
    end
end)

-- Boss defeat: watch BossDefeated attribute on PrankNPCs
Workspace.DescendantAdded:Connect(function(inst)
    if not inst:IsA("Model") or not inst:GetAttribute("Boss") then return end
    inst:GetAttributeChangedSignal("BossDefeated"):Connect(function()
        if not inst:GetAttribute("BossDefeated") then return end
        local summonedBy = inst:GetAttribute("SummonedBy")
        if not summonedBy then return end
        local p = Players:GetPlayerByUserId(summonedBy)
        if p then checkAll(p, "boss_defeat", nil) end
    end)
end)

-- Ticketed: watch player attribute set by CopSystem
Players.PlayerAdded:Connect(function(player)
    player:GetAttributeChangedSignal("RecentlyTicketed"):Connect(function()
        if player:GetAttribute("RecentlyTicketed") then
            checkAll(player, "ticketed", nil)
        end
    end)
end)
for _, p in ipairs(Players:GetPlayers()) do
    p:GetAttributeChangedSignal("RecentlyTicketed"):Connect(function()
        if p:GetAttribute("RecentlyTicketed") then checkAll(p, "ticketed", nil) end
    end)
end

print(("[AchievementSystem v1] online — %d achievements registered"):format(#Achievements.List))
