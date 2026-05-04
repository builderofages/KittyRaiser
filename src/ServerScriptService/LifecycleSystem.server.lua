-- LifecycleSystem.server.lua
-- * Anti-AFK: kicks players idle >10 minutes (no input + no humanoid movement)
--   to free server slots. Idle threshold: 600s. Warning toast at 540s.
-- * Respawn-at-last: when a player dies (NOT to a cop ticket), the next spawn
--   teleports them back to where they died, +6 studs up.
--
-- Place in: ServerScriptService > LifecycleSystem (Script). Auto-runs.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local IDLE_KICK_S = 600
local IDLE_WARN_S = 540

-- =====================================================================
-- ANTI-AFK
-- per-player lastActiveTime. Updated by:
--   * any RemoteEvent fire from this player
--   * humanoid moving (non-zero AssemblyLinearVelocity)
-- =====================================================================
local lastActive = {}

local function touch(player)
    lastActive[player.UserId] = os.clock()
end

local function watchPlayer(player)
    touch(player)
    -- Listen to common client->server remotes as activity heartbeats
    for _, rname in ipairs({
        "RequestPrank", "RequestSummonHuman", "RequestEmote",
        "RequestEquipSkin", "RequestEatFood", "RequestDrinkWater",
        "RequestSpawnCustomization",
    }) do
        local r = Remotes[rname]
        if r and r.OnServerEvent then
            r.OnServerEvent:Connect(function(p)
                if p == player then touch(player) end
            end)
        end
    end
end

Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(p) lastActive[p.UserId] = nil end)
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end

-- Per-second heartbeat: check movement + idle threshold
task.spawn(function()
    while true do
        task.wait(1)
        for _, p in ipairs(Players:GetPlayers()) do
            local char = p.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local v = hrp.AssemblyLinearVelocity
                if v.Magnitude > 1.5 then touch(p) end
            end
            local last = lastActive[p.UserId] or os.clock()
            local idle = os.clock() - last
            if idle >= IDLE_KICK_S then
                pcall(function() p:Kick("Kicked for inactivity. Rejoin to continue.") end)
            elseif idle >= IDLE_WARN_S and not p:GetAttribute("AFKWarned") then
                p:SetAttribute("AFKWarned", true)
                if Remotes.NotifyClient then
                    pcall(function()
                        Remotes.NotifyClient:FireClient(p,
                            "Move soon or you will be kicked for inactivity.", "warn")
                    end)
                end
            elseif idle < IDLE_WARN_S then
                p:SetAttribute("AFKWarned", false)
            end
        end
    end
end)

-- =====================================================================
-- RESPAWN AT LAST POSITION
-- We sample the player's HRP position each second and stash it. When the
-- humanoid dies and the next CharacterAdded fires, we PivotTo back there.
-- Skipped if the player was ticketed by a cop (they should respawn at spawn).
-- =====================================================================
local lastDeathPos = {}

local function watchCharacterDeath(player)
    player.CharacterAdded:Connect(function(char)
        local pos = lastDeathPos[player.UserId]
        if pos then
            -- Wait one frame so the rig is fully built before we move it
            task.wait(0.1)
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                pcall(function() char:PivotTo(CFrame.new(pos + Vector3.new(0, 6, 0))) end)
            end
            lastDeathPos[player.UserId] = nil
        end
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        hum.Died:Connect(function()
            -- Skip respawn-at-last if cop ticket happened recently
            if player:GetAttribute("RecentlyTicketed") then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then lastDeathPos[player.UserId] = hrp.Position end
        end)
    end)
end

Players.PlayerAdded:Connect(watchCharacterDeath)
for _, p in ipairs(Players:GetPlayers()) do watchCharacterDeath(p) end

print("[LifecycleSystem v1] online — AFK kick at "..IDLE_KICK_S.."s, respawn-at-last on natural death")
