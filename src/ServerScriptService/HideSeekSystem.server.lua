-- HideSeekSystem.server.lua  v1 — automatic round-robin hide & seek.
--
-- Every 6 minutes a hide-and-seek round starts:
--   1. Random online player is tagged 'IT' (red glow + nametag).
--   2. 30-second hide phase: all OTHER online players see 'HIDE NOW' banner.
--   3. 60-second seek phase: 'IT' must touch (catch) other players.
--   4. Each catch: -300 chaos to caught player, +500 to 'IT'.
--   5. After 60s, last uncaught player wins +1500 chaos + SURVIVOR tag.
--
-- Players who don't want to participate can /skip via chat (sets attribute);
-- excluded for the round. State broadcast via Remotes.EventBroadcast.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local DataHandler
task.spawn(function()
    while not _G.KittyRaiserData do task.wait() end
    DataHandler = _G.KittyRaiserData
end)

local ROUND_INTERVAL_S = 6 * 60
local HIDE_PHASE_S = 30
local SEEK_PHASE_S = 60

local activeRound = nil  -- {it=Player, startT, phase, caught={[uid]=true}}

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

local function eligiblePlayers()
    local out = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character.PrimaryPart and not p:GetAttribute("HSSkip") then
            table.insert(out, p)
        end
    end
    return out
end

local function endRound(reason)
    if not activeRound then return end
    local round = activeRound
    activeRound = nil
    -- Award survivors
    if reason == "timeout" and DataHandler then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= round.it and not round.caught[p.UserId] then
                DataHandler.modify(p, function(d)
                    d.chaosPoints = (d.chaosPoints or 0) + 1500
                    d.tags = d.tags or {}
                    if not table.find(d.tags, "SURVIVOR") then
                        table.insert(d.tags, "SURVIVOR")
                    end
                end)
                notify(p, "SURVIVED HIDE & SEEK  -  +1500 CHAOS", "good")
            end
        end
    end
    broadcast({kind="end", title="HIDE & SEEK", message="Round ended."})
    -- Clean up the IT visual marker if still on character
    if round.it and round.it.Character then
        local hrp = round.it.Character:FindFirstChild("HumanoidRootPart")
        local marker = hrp and hrp:FindFirstChild("HSItMarker")
        if marker then marker:Destroy() end
    end
end

local function tagIt(player)
    -- Visual: floating red exclamation above their head
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    local g = Instance.new("BillboardGui", head)
    g.Name = "HSItMarker"
    g.Size = UDim2.new(0, 80, 0, 80)
    g.StudsOffset = Vector3.new(0, 4, 0)
    g.AlwaysOnTop = true
    local lbl = Instance.new("TextLabel", g)
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text = "IT"
    lbl.Font = Enum.Font.LuckiestGuy
    lbl.TextScaled = true
    lbl.TextColor3 = Color3.fromRGB(255, 80, 80)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(40, 0, 0)
end

local function startRound()
    if activeRound then return end
    local pool = eligiblePlayers()
    if #pool < 2 then
        return  -- need at least 2 players
    end
    local it = pool[math.random(1, #pool)]
    activeRound = {it=it, startT=os.clock(), phase="hide", caught={}}
    tagIt(it)
    broadcast({kind="start", title="HIDE & SEEK",
        message="HIDING - " .. it.DisplayName .. " is IT. Run!",
        durationS = HIDE_PHASE_S})
    notify(it, "YOU ARE IT  -  catch the other cats", "warn")
    for _, p in ipairs(pool) do
        if p ~= it then notify(p, "HIDE  -  " .. it.DisplayName .. " is IT", "warn") end
    end
    -- Hide phase: just wait
    task.wait(HIDE_PHASE_S)
    if not activeRound then return end
    activeRound.phase = "seek"
    broadcast({kind="start", title="HIDE & SEEK",
        message="SEEKING - " .. it.DisplayName .. " is hunting!",
        durationS = SEEK_PHASE_S})
    -- Seek phase: monitor IT's touches via Heartbeat distance check
    local seekStart = os.clock()
    while activeRound and (os.clock() - seekStart) < SEEK_PHASE_S do
        task.wait(0.5)
        local itHRP = it.Character and it.Character:FindFirstChild("HumanoidRootPart")
        if not itHRP then break end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= it and not activeRound.caught[p.UserId] then
                local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if hrp and (hrp.Position - itHRP.Position).Magnitude < 6 then
                    activeRound.caught[p.UserId] = true
                    if DataHandler then
                        DataHandler.modify(p, function(d)
                            d.chaosPoints = math.max(0, (d.chaosPoints or 0) - 300)
                        end)
                        DataHandler.modify(it, function(d)
                            d.chaosPoints = (d.chaosPoints or 0) + 500
                        end)
                    end
                    notify(p, "CAUGHT  -  -300 CHAOS", "warn")
                    notify(it, "CAUGHT " .. p.DisplayName .. "  -  +500 CHAOS", "good")
                end
            end
        end
    end
    endRound("timeout")
end

-- Round scheduler
task.spawn(function()
    while true do
        task.wait(ROUND_INTERVAL_S)
        startRound()
    end
end)

-- Cleanup if IT leaves
Players.PlayerRemoving:Connect(function(p)
    if activeRound and activeRound.it == p then
        endRound("it_left")
    end
end)

print("[HideSeekSystem v1] online - rounds every " .. ROUND_INTERVAL_S .. "s")
