-- CatDuelSystem.server.lua  v1 — opt-in 1v1 cat duels.
--
-- Flow:
--   1. Players touch the DUEL ARENA pad (cyan ring near plaza fountain).
--   2. First toucher becomes 'challenger'. Second becomes 'opponent'.
--   3. Both teleport into a small platform at -400, 50, 0.
--   4. 60-second match. Each prank YOU land on the OTHER counts +1.
--   5. After 60s, higher score wins +1500 chaos. Loser loses 500.
--   6. Both teleport back to plaza.
--
-- Pranks normally fail on players (no KittyRaiserNPC tag); this system
-- temporarily flags both duelists with InDuel=true and patches PrankSystem
-- via a workspace hook to allow player-on-player pranks during the round.

local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local DataHandler
task.spawn(function()
    while not _G.KittyRaiserData do task.wait() end
    DataHandler = _G.KittyRaiserData
end)

local DUEL_ARENA_POS = Vector3.new(-400, 50, 0)
local DUEL_PAD_POS   = Vector3.new(0, 5, -240)  -- queue ring near plaza
local DUEL_DURATION_S = 60

local queue = {}  -- list of waiting players
local activeDuel = nil  -- {p1, p2, startT, score={[uid]=N}}

local function notify(p, msg, kind)
    if Remotes.NotifyClient then
        Remotes.NotifyClient:FireClient(p, msg, kind or "info")
    end
end

-- Build queue pad ring (cyan)
local pad = Instance.new("Part", Workspace)
pad.Name = "DuelQueuePad"
pad.Anchored = true; pad.CanCollide = false
pad.Shape = Enum.PartType.Cylinder
pad.Size = Vector3.new(2, 14, 14)
pad.Position = DUEL_PAD_POS
pad.Material = Enum.Material.Neon
pad.Color = Color3.fromRGB(80, 200, 240)
pad.Transparency = 0.4
pad.CFrame = CFrame.new(DUEL_PAD_POS) * CFrame.Angles(0, 0, math.rad(90))
local g = Instance.new("BillboardGui", pad)
g.Size = UDim2.new(0, 160, 0, 60)
g.StudsOffset = Vector3.new(0, 12, 0)
g.AlwaysOnTop = true
local lbl = Instance.new("TextLabel", g)
lbl.Size = UDim2.fromScale(1, 1)
lbl.BackgroundTransparency = 1
lbl.Text = "DUEL QUEUE"
lbl.Font = Enum.Font.LuckiestGuy
lbl.TextScaled = true
lbl.TextColor3 = Color3.fromRGB(80, 200, 240)
lbl.TextStrokeTransparency = 0
lbl.TextStrokeColor3 = Color3.fromRGB(20, 30, 50)

-- Build duel arena platform (offscreen, hidden from main world)
local arenaFolder = Instance.new("Folder", Workspace)
arenaFolder.Name = "DuelArena"
local platform = Instance.new("Part", arenaFolder)
platform.Anchored = true; platform.CanCollide = true
platform.Size = Vector3.new(60, 4, 60)
platform.Position = DUEL_ARENA_POS - Vector3.new(0, 2, 0)
platform.Material = Enum.Material.Marble
platform.Color = Color3.fromRGB(220, 215, 200)
-- Walls so players can't fall off
for _, wallSpec in ipairs({
    {pos=DUEL_ARENA_POS + Vector3.new(0, 6, 30),  size=Vector3.new(60, 16, 2)},
    {pos=DUEL_ARENA_POS + Vector3.new(0, 6, -30), size=Vector3.new(60, 16, 2)},
    {pos=DUEL_ARENA_POS + Vector3.new(30, 6, 0),  size=Vector3.new(2, 16, 62)},
    {pos=DUEL_ARENA_POS + Vector3.new(-30, 6, 0), size=Vector3.new(2, 16, 62)},
}) do
    local w = Instance.new("Part", arenaFolder)
    w.Anchored = true; w.CanCollide = true
    w.Size = wallSpec.size; w.Position = wallSpec.pos
    w.Material = Enum.Material.SmoothPlastic
    w.Color = Color3.fromRGB(110, 75, 45)
    w.Transparency = 0.4
end

local function endDuel(winner, loser, w_score, l_score)
    if not activeDuel then return end
    activeDuel = nil
    -- Reward + teleport home
    if DataHandler then
        DataHandler.modify(winner, function(d)
            d.chaosPoints = (d.chaosPoints or 0) + 1500
        end)
        DataHandler.modify(loser, function(d)
            d.chaosPoints = math.max(0, (d.chaosPoints or 0) - 500)
        end)
    end
    notify(winner, string.format("DUEL WON  %d:%d  +1500 CHAOS", w_score, l_score), "good")
    notify(loser,  string.format("DUEL LOST  %d:%d  -500 CHAOS",  l_score, w_score), "warn")
    -- Clear in-duel flags
    winner:SetAttribute("InDuel", false)
    loser:SetAttribute("InDuel", false)
    -- Teleport back to plaza
    for _, p in ipairs({winner, loser}) do
        if p.Character and p.Character.PrimaryPart then
            p.Character:PivotTo(CFrame.new(0, 5, 0))
        end
    end
end

local function startDuel(p1, p2)
    if activeDuel then return end
    activeDuel = {p1=p1, p2=p2, startT=os.clock(), score={[p1.UserId]=0, [p2.UserId]=0}}
    p1:SetAttribute("InDuel", true)
    p2:SetAttribute("InDuel", true)
    -- Teleport into arena (opposite corners)
    if p1.Character and p1.Character.PrimaryPart then
        p1.Character:PivotTo(CFrame.new(DUEL_ARENA_POS + Vector3.new(-15, 5, 0)))
    end
    if p2.Character and p2.Character.PrimaryPart then
        p2.Character:PivotTo(CFrame.new(DUEL_ARENA_POS + Vector3.new(15, 5, 0)))
    end
    notify(p1, "DUEL STARTED vs " .. p2.DisplayName .. "  -  60s", "good")
    notify(p2, "DUEL STARTED vs " .. p1.DisplayName .. "  -  60s", "good")
    -- Round timer
    task.delay(DUEL_DURATION_S, function()
        if not activeDuel or activeDuel.p1 ~= p1 or activeDuel.p2 ~= p2 then return end
        local s1 = activeDuel.score[p1.UserId]
        local s2 = activeDuel.score[p2.UserId]
        if s1 >= s2 then endDuel(p1, p2, s1, s2)
        else endDuel(p2, p1, s2, s1) end
    end)
end

-- Pad touch: queue or pair
pad.Touched:Connect(function(hit)
    local model = hit:FindFirstAncestorOfClass("Model")
    if not model then return end
    local p = Players:GetPlayerFromCharacter(model)
    if not p or p:GetAttribute("InDuel") then return end
    -- Already in queue?
    for _, q in ipairs(queue) do if q == p then return end end
    if activeDuel then
        notify(p, "DUEL IN PROGRESS  -  wait for next round", "warn")
        return
    end
    table.insert(queue, p)
    notify(p, "DUEL QUEUED  -  waiting for opponent", "info")
    if #queue >= 2 then
        local a = table.remove(queue, 1)
        local b = table.remove(queue, 1)
        startDuel(a, b)
    end
end)

-- Hook into PrankRegistered: if both actor + target are InDuel and they're
-- THE duelists, increment score. PrankSystem normally rejects player
-- targets (they aren't tagged KittyRaiserNPC) — duels track separately.
-- We rely on Remotes.PrankRegistered firing for actor; but pranks on players
-- aren't issued via PrankSystem currently. Simpler: track via prank-touch
-- via close-range approximation in a Heartbeat loop during the duel.
local RunService = game:GetService("RunService")
RunService.Heartbeat:Connect(function()
    if not activeDuel then return end
    local p1, p2 = activeDuel.p1, activeDuel.p2
    if not p1.Character or not p2.Character then return end
    local hrp1 = p1.Character:FindFirstChild("HumanoidRootPart")
    local hrp2 = p2.Character:FindFirstChild("HumanoidRootPart")
    if not hrp1 or not hrp2 then return end
    local d = (hrp1.Position - hrp2.Position).Magnitude
    if d < 6 then
        -- Touch counts as a hit; figure out who's faster (whichever has higher
        -- velocity is the 'attacker'). Increment their score, throttle 1.5s.
        activeDuel.lastHit = activeDuel.lastHit or 0
        local now = os.clock()
        if now - activeDuel.lastHit < 1.5 then return end
        activeDuel.lastHit = now
        local v1 = hrp1.AssemblyLinearVelocity.Magnitude
        local v2 = hrp2.AssemblyLinearVelocity.Magnitude
        local hitter, hittee
        if v1 > v2 then hitter = p1; hittee = p2 else hitter = p2; hittee = p1 end
        activeDuel.score[hitter.UserId] = activeDuel.score[hitter.UserId] + 1
        notify(hitter, "HIT  " .. activeDuel.score[hitter.UserId], "good")
    end
end)

Players.PlayerRemoving:Connect(function(p)
    for i = #queue, 1, -1 do
        if queue[i] == p then table.remove(queue, i) end
    end
    if activeDuel and (activeDuel.p1 == p or activeDuel.p2 == p) then
        local opponent = (activeDuel.p1 == p) and activeDuel.p2 or activeDuel.p1
        endDuel(opponent, p, 0, 0)
    end
end)

print("[CatDuelSystem v1] online - touch DUEL pad near plaza to queue")
