-- KOTHSystem.server.lua  v1 — plaza fountain is the 'hill'.
--
-- 1Hz tick: count players within 12 studs of the fountain center.
-- If exactly 1 player there: they bank +10 chaos this tick.
-- If multiple: contested, nobody scores.
-- Round = 5 minutes. Winner (highest banked) gets +5,000 bonus.
-- Round end broadcasts winner via EventBroadcast 'event' kind.
-- Also shows a per-tick floating banner with current king + their score.

local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local DataHandler
task.spawn(function()
    while not _G.KittyRaiserData do task.wait() end
    DataHandler = _G.KittyRaiserData
end)

local HILL_CENTER = Vector3.new(0, 5, 0)  -- plaza fountain
local HILL_RADIUS = 12
local TICK_RATE = 1
local PER_TICK_CHAOS = 10
local ROUND_S = 5 * 60
local WINNER_BONUS = 5000

local roundBanked = {}  -- [userId] = chaos this round
local roundStartT = os.clock()

local function broadcast(payload)
    for _, p in ipairs(Players:GetPlayers()) do
        Remotes.EventBroadcast:FireClient(p, "event", payload)
    end
end

local function notify(p, msg, kind)
    if Remotes.NotifyClient then
        Remotes.NotifyClient:FireClient(p, msg, kind or "info")
    end
end

local function endRound()
    local winner, winnerScore = nil, 0
    for uid, chaos in pairs(roundBanked) do
        if chaos > winnerScore then
            winnerScore = chaos
            winner = uid
        end
    end
    if winner and winnerScore > 0 then
        local winnerPlayer = Players:GetPlayerByUserId(winner)
        if winnerPlayer and DataHandler then
            DataHandler.modify(winnerPlayer, function(d)
                d.chaosPoints = (d.chaosPoints or 0) + WINNER_BONUS
                d.tags = d.tags or {}
                if not table.find(d.tags, "KING") then
                    table.insert(d.tags, "KING")
                end
            end)
            broadcast({
                kind = "start",
                title = "KING OF THE HILL",
                message = winnerPlayer.DisplayName .. " was KING - " .. winnerScore .. " chaos. Bonus +" .. WINNER_BONUS .. "!",
                durationS = 8,
            })
        end
    end
    roundBanked = {}
    roundStartT = os.clock()
end

-- Tick loop
task.spawn(function()
    while true do
        task.wait(TICK_RATE)
        local kingsOnHill = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character and p.Character.PrimaryPart then
                local d = (p.Character.PrimaryPart.Position - HILL_CENTER).Magnitude
                if d <= HILL_RADIUS then
                    table.insert(kingsOnHill, p)
                end
            end
        end
        if #kingsOnHill == 1 then
            local king = kingsOnHill[1]
            roundBanked[king.UserId] = (roundBanked[king.UserId] or 0) + PER_TICK_CHAOS
            if DataHandler then
                DataHandler.modify(king, function(d)
                    d.chaosPoints = (d.chaosPoints or 0) + PER_TICK_CHAOS
                end)
            end
        end
        -- Round end?
        if os.clock() - roundStartT >= ROUND_S then
            endRound()
        end
    end
end)

-- Build a visible HILL marker at the fountain
local marker = Instance.new("Part", Workspace)
marker.Name = "KOTHMarker"
marker.Anchored = true; marker.CanCollide = false
marker.Shape = Enum.PartType.Cylinder
marker.Size = Vector3.new(2, HILL_RADIUS * 2, HILL_RADIUS * 2)
marker.Position = HILL_CENTER + Vector3.new(0, 0.5, 0)
marker.Material = Enum.Material.Neon
marker.Color = Color3.fromRGB(255, 215, 80)
marker.Transparency = 0.85
marker.CFrame = CFrame.new(marker.Position) * CFrame.Angles(0, 0, math.rad(90))
local g = Instance.new("BillboardGui", marker)
g.Size = UDim2.new(0, 120, 0, 30)
g.StudsOffset = Vector3.new(0, HILL_RADIUS + 4, 0)
g.AlwaysOnTop = true
local lbl = Instance.new("TextLabel", g)
lbl.Size = UDim2.fromScale(1, 1)
lbl.BackgroundTransparency = 1
lbl.Text = "KING OF THE HILL"
lbl.Font = Enum.Font.LuckiestGuy
lbl.TextScaled = true
lbl.TextColor3 = Color3.fromRGB(255, 215, 80)
lbl.TextStrokeTransparency = 0
lbl.TextStrokeColor3 = Color3.fromRGB(60, 35, 18)

-- Player cleanup
Players.PlayerRemoving:Connect(function(p)
    roundBanked[p.UserId] = nil
end)

print("[KOTHSystem v1] online - 12-stud hill at plaza fountain, " .. ROUND_S .. "s rounds")
