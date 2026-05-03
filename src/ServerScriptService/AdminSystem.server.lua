-- AdminSystem.server.lua
-- Admin-only chat commands and remote calls. Edit ADMIN_USERIDS below.
-- Place in: ServerScriptService > AdminSystem (Script)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local CosmeticConfig = require(ReplicatedStorage.Modules.CosmeticConfig)
local SharedUtil = require(ReplicatedStorage.Modules.SharedUtil)

local DataHandler = SharedUtil.waitForGlobal("KittyRaiserData", 30)
if not DataHandler then return end

-- TODO: replace with real admin UserIds (yours + trusted staff)
local ADMIN_USERIDS = {10878595931}  -- Katoxbt (trainyouragent@gmail.com)

-- Studio auto-admin only fires when running solo (no real teammates).
local function studioSoloMode()
    return RunService:IsStudio() and #Players:GetPlayers() <= 1
end

local function isAdmin(player)
    if table.find(ADMIN_USERIDS, player.UserId) then return true end
    if studioSoloMode() then return true end
    if player:GetAttribute("AdminOverride") == true then return true end
    return false
end

-- Audit log: keep last N admin commands in DataStore for forensics.
local auditStore = DataStoreService:GetDataStore("KittyRaiserAdminAudit_v1")
local function audit(actor, command, args)
    pcall(function()
        local key = os.date("!%Y%m%d") .. "_" .. tostring(actor.UserId)
        auditStore:UpdateAsync(key, function(old)
            old = old or {}
            table.insert(old, {ts = os.time(), cmd = command, args = args})
            while #old > 200 do table.remove(old, 1) end
            return old
        end)
    end)
end

local Commands = {}

local function resolveTarget(arg)
    -- accept UserId number, exact name match, or partial-display-name fallback
    local asId = tonumber(arg)
    if asId then return Players:GetPlayerByUserId(asId) end
    if not arg then return nil end
    -- exact name first to avoid prefix collisions
    local exact = Players:FindFirstChild(arg)
    if exact then return exact end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name == arg or p.DisplayName == arg then return p end
    end
    return nil
end

Commands.chaos = function(actor, amount)
    amount = tonumber(amount) or 0
    DataHandler.modify(actor, function(d)
        d.chaosPoints = math.max(0, (d.chaosPoints or 0) + amount)
    end)
    return "chaos +" .. amount
end

Commands.helltokens = function(actor, amount)
    amount = tonumber(amount) or 0
    DataHandler.modify(actor, function(d)
        d.hellTokens = math.max(0, (d.hellTokens or 0) + amount)
    end)
    return "hellTokens +" .. amount
end

Commands.level = function(actor, amount)
    amount = tonumber(amount) or 1
    DataHandler.modify(actor, function(d)
        d.level = math.clamp(amount, 1, 100); d.xp = 0
    end)
    return "level set to " .. amount
end

Commands.skin = function(actor, skinId)
    if type(skinId) ~= "string" or not CosmeticConfig.getSkin(skinId) then
        return "invalid skin id"
    end
    DataHandler.modify(actor, function(d)
        d.ownedSkins = d.ownedSkins or {}
        if not table.find(d.ownedSkins, skinId) then table.insert(d.ownedSkins, skinId) end
        d.equippedSkin = skinId
    end)
    return "skin set " .. tostring(skinId)
end

-- Full reset: writes the schema default, preserving identity fields
Commands.reset = function(actor)
    DataHandler.modify(actor, function(d)
        d.chaosPoints = 0
        d.hellTokens = 0
        d.level = 1
        d.xp = 0
        d.rebirths = 0
        d.perks = {}
        d.unspentStatPoints = 0
        d.stats = {Speed=0,Jump=0,Luck=0,Strength=0,Agility=0}
        d.hunger = 100
        d.thirst = 100
        d.dailyStreak = 0
        d.lastDailyClaim = 0
        d.totalPranks = 0
        d.equippedSkin = "Default"
        d.ownedSkins = {"Default"}
        d.flagCount = 0
        d.suspended = false
    end)
    return "fully reset"
end

Commands.kick = function(actor, targetArg, reason)
    local target = resolveTarget(targetArg)
    if not target then return "not found" end
    target:Kick(reason or "Admin kick")
    return "kicked " .. target.Name
end

Commands.unsuspend = function(actor, targetArg)
    local target = resolveTarget(targetArg)
    if not target then return "not found" end
    DataHandler.modify(target, function(d)
        d.flagCount = 0; d.suspended = false
    end)
    return "unsuspended " .. target.Name
end

local function processChatCommand(player, msg)
    if not msg or msg:sub(1,1) ~= "/" then return end
    if not isAdmin(player) then return end
    local parts = msg:sub(2):split(" ")
    local cmd = parts[1]
    local args = {}
    for i = 2, #parts do args[i-1] = parts[i] end
    local fn = Commands[cmd]
    if not fn then return end
    local ok, result = pcall(fn, player, table.unpack(args))
    if ok then
        Remotes.NotifyClient:FireClient(player, "admin: " .. tostring(result), "success")
    else
        Remotes.NotifyClient:FireClient(player, "admin err: " .. tostring(result), "error")
    end
    audit(player, cmd, args)
end

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(msg) processChatCommand(player, msg) end)
end)

if RunService:IsStudio() then
    Players.PlayerAdded:Connect(function(player)
        if studioSoloMode() then
            player:SetAttribute("AdminOverride", true)
            print("[AdminSystem] Studio solo-mode auto-admin granted to", player.Name)
        end
    end)
end

Remotes.RequestAdminCommand.OnServerInvoke = function(player, cmd, ...)
    if not SharedUtil.checkRate(player, "adminCmd", 0.2) then return false, "rate_limited" end
    if not isAdmin(player) then return false, "not_admin" end
    local fn = Commands[cmd]
    if not fn then return false, "unknown_cmd" end
    local args = {...}
    local ok, result = pcall(fn, player, ...)
    audit(player, cmd, args)
    return ok, result
end

return true
