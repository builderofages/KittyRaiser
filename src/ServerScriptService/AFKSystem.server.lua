-- AFKSystem.server.lua
-- Track per-player last-active time. If no input or position change for
-- AFK_KICK_SECONDS, kick them so the slot opens up for an active player.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local AFK_WARN_SECONDS = 600   -- 10 min warning
local AFK_KICK_SECONDS = 900   -- 15 min kick

local lastActive = {}    -- userId -> os.clock()
local lastPos = {}       -- userId -> Vector3

local function bump(player)
    lastActive[player.UserId] = os.clock()
end

Players.PlayerAdded:Connect(function(player)
    bump(player)
    -- Any prank/summon/emote remote bumps activity.
    -- We hook a generic activity event via the player's chat as backup.
    pcall(function()
        player.Chatted:Connect(function() bump(player) end)
    end)
end)
Players.PlayerRemoving:Connect(function(player)
    lastActive[player.UserId] = nil
    lastPos[player.UserId] = nil
end)
for _, p in ipairs(Players:GetPlayers()) do bump(p) end

-- Bump on any of these remote-events too (active gameplay = not AFK).
local activityHooks = {Remotes.RequestPrank, Remotes.RequestSummonHuman,
    Remotes.RequestEmote, Remotes.RequestEatFood, Remotes.RequestDrinkWater}
for _, r in ipairs(activityHooks) do
    if r and r.OnServerEvent then
        r.OnServerEvent:Connect(function(player) bump(player) end)
    end
end

-- Position-change check every 30s. If position hasn't moved, no input either,
-- count as AFK.
task.spawn(function()
    while true do
        task.wait(30)
        for _, p in ipairs(Players:GetPlayers()) do
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local last = lastPos[p.UserId]
                if last and (hrp.Position - last).Magnitude > 5 then
                    bump(p)
                end
                lastPos[p.UserId] = hrp.Position
            end
            local idle = os.clock() - (lastActive[p.UserId] or os.clock())
            if idle > AFK_KICK_SECONDS then
                pcall(function()
                    p:Kick("AFK for too long. Rejoin when you're back.")
                end)
            elseif idle > AFK_WARN_SECONDS then
                pcall(function()
                    Remotes.NotifyClient:FireClient(p,
                        ("AFK warning — kicked in %ds"):format(AFK_KICK_SECONDS - math.floor(idle)),
                        "warn")
                end)
            end
        end
    end
end)

print("[AFKSystem] online — warn at " .. AFK_WARN_SECONDS .. "s, kick at " .. AFK_KICK_SECONDS .. "s")
