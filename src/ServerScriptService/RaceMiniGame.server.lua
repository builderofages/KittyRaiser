-- RaceMiniGame.server.lua  v1 — pickup-and-play time-trial race.
--
-- Course: 6 numbered checkpoint rings around the plaza perimeter, plus a
-- start/finish line. Player walks through ring 1 to start the timer, then
-- must hit 2..6 in order, then return to the finish line. Personal best
-- persists in DataHandler. Beating the global server-record awards bonus
-- chaos.
--
-- No specialized vehicle needed; works with the cat's own movement (or
-- whatever DrivableCar they're in).

local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local DataHandler
task.spawn(function()
    while not _G.KittyRaiserData do task.wait() end
    DataHandler = _G.KittyRaiserData
end)

-- 6 checkpoints in a rough loop around the plaza (within 200 stud radius)
local CHECKPOINTS = {
    Vector3.new( 100, 5,  100),
    Vector3.new( 180, 5,  -20),
    Vector3.new( 100, 5, -180),
    Vector3.new(-100, 5, -180),
    Vector3.new(-180, 5,  -20),
    Vector3.new(-100, 5,  180),
}
local START_POS = Vector3.new(0, 5, 200)

local raceFolder = Workspace:FindFirstChild("RaceCourse") or Instance.new("Folder", Workspace)
raceFolder.Name = "RaceCourse"
raceFolder:ClearAllChildren()

-- Per-player race state
local activeRuns = {}  -- [userId] = {nextCheckpoint=1, startT=clock}
local serverBest = math.huge

local function makeRing(name, position, color, idx)
    local ring = Instance.new("Part", raceFolder)
    ring.Name = name
    ring.Anchored = true
    ring.CanCollide = false
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(2, 16, 16)
    ring.Position = position
    ring.Material = Enum.Material.Neon
    ring.Color = color
    ring.Transparency = 0.3
    ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
    -- Number label
    local g = Instance.new("BillboardGui", ring)
    g.Size = UDim2.new(0, 80, 0, 80)
    g.StudsOffset = Vector3.new(0, 14, 0)
    g.AlwaysOnTop = true
    local lbl = Instance.new("TextLabel", g)
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text = tostring(idx)
    lbl.Font = Enum.Font.LuckiestGuy
    lbl.TextScaled = true
    lbl.TextColor3 = Color3.fromRGB(255, 240, 200)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)
    return ring
end

local function notify(player, text, kind)
    if Remotes.NotifyClient then
        Remotes.NotifyClient:FireClient(player, text, kind or "info")
    end
end

local function attemptCheckpoint(player, idx)
    local run = activeRuns[player.UserId]
    if not run then
        if idx == 1 then
            -- Start the run
            activeRuns[player.UserId] = {nextCheckpoint=2, startT=os.clock()}
            notify(player, "RACE START - hit checkpoints 2..6 then finish", "good")
        end
        return
    end
    if idx == run.nextCheckpoint then
        run.nextCheckpoint = run.nextCheckpoint + 1
        if run.nextCheckpoint > #CHECKPOINTS then
            -- Move to finish state
            run.nextCheckpoint = "finish"
            notify(player, "FINAL CHECKPOINT - return to start line", "good")
        else
            notify(player, "CHECKPOINT " .. (run.nextCheckpoint - 1) .. "/" .. #CHECKPOINTS, "info")
        end
    end
end

local function attemptFinish(player)
    local run = activeRuns[player.UserId]
    if not run or run.nextCheckpoint ~= "finish" then return end
    local elapsed = os.clock() - run.startT
    activeRuns[player.UserId] = nil
    notify(player, string.format("RACE COMPLETE  -  %.2fs", elapsed), "good")
    -- Personal best
    if DataHandler then
        DataHandler.modify(player, function(d)
            d.bestRaceS = d.bestRaceS or math.huge
            local prev = d.bestRaceS
            if elapsed < prev then
                d.bestRaceS = elapsed
                d.chaosPoints = (d.chaosPoints or 0) + 1500
                notify(player, "NEW PERSONAL BEST  -  +1500 CHAOS", "good")
            else
                d.chaosPoints = (d.chaosPoints or 0) + 250
            end
        end)
    end
    -- Server record
    if elapsed < serverBest then
        serverBest = elapsed
        if DataHandler then
            DataHandler.modify(player, function(d)
                d.chaosPoints = (d.chaosPoints or 0) + 5000
            end)
        end
        for _, p in ipairs(Players:GetPlayers()) do
            notify(p, string.format("SERVER RECORD  -  %s  %.2fs", player.DisplayName, elapsed), "good")
        end
    end
end

-- Build rings
for i, pos in ipairs(CHECKPOINTS) do
    local ring = makeRing("Checkpoint_" .. i, pos, Color3.fromRGB(80, 200, 220), i)
    ring.Touched:Connect(function(hit)
        local model = hit:FindFirstAncestorOfClass("Model")
        if not model then return end
        local p = Players:GetPlayerFromCharacter(model)
        if not p then return end
        attemptCheckpoint(p, i)
    end)
end
local startRing = makeRing("StartFinish", START_POS, Color3.fromRGB(255, 215, 80), 0)
local startLbl = startRing:FindFirstChildOfClass("BillboardGui")
   and startRing:FindFirstChildOfClass("BillboardGui"):FindFirstChildOfClass("TextLabel")
if startLbl then startLbl.Text = "START" end
startRing.Touched:Connect(function(hit)
    local model = hit:FindFirstAncestorOfClass("Model")
    if not model then return end
    local p = Players:GetPlayerFromCharacter(model)
    if not p then return end
    if activeRuns[p.UserId] then
        attemptFinish(p)
    else
        -- Hit ring 1 to start (mirroring the rule)
        attemptCheckpoint(p, 1)
    end
end)

-- Cleanup on player remove
Players.PlayerRemoving:Connect(function(p) activeRuns[p.UserId] = nil end)

print("[RaceMiniGame v1] online — 6-checkpoint course around plaza perimeter")
