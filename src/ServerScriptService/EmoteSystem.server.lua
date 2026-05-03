-- EmoteSystem.server.lua
-- Broadcasts emote requests to nearby players.
-- Place in: ServerScriptService > EmoteSystem (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local EMOTE_COOLDOWN = 1.5
local lastUse = {}

Remotes.RequestEmote.OnServerEvent:Connect(function(player, emoteName)
    if type(emoteName) ~= "string" or #emoteName > 32 then return end
    if not table.find(GameConfig.EMOTES, emoteName) then return end
    local now = os.clock()
    if lastUse[player.UserId] and (now - lastUse[player.UserId]) < EMOTE_COOLDOWN then return end
    lastUse[player.UserId] = now
    local char = player.Character
    if not char or not char.PrimaryPart then return end
    local origin = char.PrimaryPart.Position
    for _, p in ipairs(Players:GetPlayers()) do
        local pchar = p.Character
        if pchar and pchar.PrimaryPart and (pchar.PrimaryPart.Position - origin).Magnitude < 80 then
            Remotes.EmoteBroadcast:FireClient(p, player.UserId, emoteName)
        end
    end
end)

Players.PlayerRemoving:Connect(function(p) lastUse[p.UserId] = nil end)

return true
