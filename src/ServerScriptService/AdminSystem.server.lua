-- AdminSystem.server.lua
-- Admin-only chat commands and remote calls. Edit ADMIN_USERIDS below.
-- Place in: ServerScriptService > AdminSystem (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local function waitFor(g) while not _G[g] do task.wait() end return _G[g] end
local DataHandler = waitFor("KittyRaiserData")

-- TODO: replace with real admin UserIds (yours + trusted staff)
local ADMIN_USERIDS = {10878595931}  -- Katoxbt (trainyouragent@gmail.com)

local function isAdmin(player)
    return table.find(ADMIN_USERIDS, player.UserId) ~= nil or player:GetAttribute("AdminOverride") == true
end

local Commands = {}

Commands.chaos = function(player, amount)
    amount = tonumber(amount) or 0
    DataHandler.modify(player, function(d) d.chaosPoints = (d.chaosPoints or 0) + amount end)
    return "chaos +" .. amount
end

Commands.helltokens = function(player, amount)
    amount = tonumber(amount) or 0
    DataHandler.modify(player, function(d) d.hellTokens = (d.hellTokens or 0) + amount end)
    return "hellTokens +" .. amount
end

Commands.level = function(player, amount)
    amount = tonumber(amount) or 1
    DataHandler.modify(player, function(d) d.level = math.clamp(amount, 1, 100); d.xp = 0 end)
    return "level set to " .. amount
end

Commands.skin = function(player, skinId)
    DataHandler.modify(player, function(d)
        if not table.find(d.ownedSkins, skinId) then table.insert(d.ownedSkins, skinId) end
        d.equippedSkin = skinId
    end)
    return "skin set " .. tostring(skinId)
end

Commands.reset = function(player)
    DataHandler.modify(player, function(d)
        d.chaosPoints = 0
        d.level = 1
        d.xp = 0
        d.rebirths = 0
        d.perks = {}
        d.unspentStatPoints = 0
        d.stats = {Speed=0,Jump=0,Luck=0,Strength=0,Agility=0}
    end)
    return "reset"
end

Commands.kick = function(player, targetName, reason)
    local target = Players:FindFirstChild(targetName)
    if target then target:Kick(reason or "Admin kick"); return "kicked "..targetName end
    return "not found"
end

local function processChatCommand(player, msg)
    if not msg or msg:sub(1,1) ~= "/" then return end
    if not isAdmin(player) then return end
    local parts = msg:sub(2):split(" ")
    local cmd = parts[1]
    local args = {}
    for i = 2, #parts do args[i-1] = parts[i] end
    local fn = Commands[cmd]
    if fn then
        local ok, result = pcall(fn, player, table.unpack(args))
        if ok then
            Remotes.NotifyClient:FireClient(player, "admin: "..tostring(result), "success")
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(msg)
        processChatCommand(player, msg)
    end)
end)

-- Allow Studio testing without admin list (auto-admin in Studio)
local RunService = game:GetService("RunService")
if RunService:IsStudio() then
    Players.PlayerAdded:Connect(function(player)
        player:SetAttribute("AdminOverride", true)
        print("[AdminSystem] Studio auto-admin granted to", player.Name)
    end)
end

Remotes.RequestAdminCommand.OnServerInvoke = function(player, cmd, ...)
    if not isAdmin(player) then return false, "not_admin" end
    local fn = Commands[cmd]
    if not fn then return false, "unknown_cmd" end
    local args = {...}
    local ok, result = pcall(fn, player, table.unpack(args))
    return ok, result
end

return true
