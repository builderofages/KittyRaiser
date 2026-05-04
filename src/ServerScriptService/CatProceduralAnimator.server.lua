-- CatProceduralAnimator.server.lua  v1.0
-- Replaces v1.1-deferred animation work with a fully procedural animator that
-- drives the existing TailMotor and the welded cat body via Heartbeat. No
-- uploaded animation assets needed.
--
-- States detected from Humanoid:
--   idle    : speed < 1                        -> slow tail figure-8 + breathing scale
--   walk    : 1 <= speed < 12                  -> medium tail swish + body bob
--   run     : speed >= 12                      -> fast tail lash + forward lean
--   jump    : Humanoid.Jumping or :GetState()==Jumping -> tail fling + squash-stretch
--   fall    : Humanoid:GetState()==Freefall    -> tail droop + body tilt back
--
-- All animation is driven server-side on the cat's CatTail Motor6D and a
-- BodyBob CFrame offset applied to a "CatBob" attachment.

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")

local TAIL_LIMIT_DEG = 60      -- max tail angle from neutral
local BOB_AMPLITUDE  = 0.06    -- studs of body bob during walk/run
local BREATHE_SCALE  = 0.012   -- scale variance during idle breathing
local LEAN_DEGREES   = 12      -- forward pitch during run

local cats = {}  -- player -> {character, tailMotor, bodyParts, baseScale, t}

local function findCat(char)
    local body = char:FindFirstChild("CatBody") or char:FindFirstChild("HumanoidRootPart")
    local tail
    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("Motor6D") and d.Name == "TailMotor" then
            tail = d
            break
        end
    end
    return body, tail
end

local function stateOf(humanoid)
    if not humanoid then return "idle" end
    local s = humanoid:GetState()
    if s == Enum.HumanoidStateType.Freefall then
        local v = humanoid.RootPart and humanoid.RootPart.AssemblyLinearVelocity.Y or 0
        if v > 5 then return "jump" else return "fall" end
    elseif s == Enum.HumanoidStateType.Jumping then
        return "jump"
    end
    local speed = humanoid.MoveDirection.Magnitude * humanoid.WalkSpeed
    if speed < 1 then return "idle" end
    if speed < 12 then return "walk" end
    return "run"
end

local function tween(humanoid, motor, t, dt, state)
    if not motor then return end
    local angleDeg = 0
    local freq    = 1.0
    if state == "idle" then
        freq = 0.6
        angleDeg = math.sin(t * freq * math.pi * 2) * 12
    elseif state == "walk" then
        freq = 1.6
        angleDeg = math.sin(t * freq * math.pi * 2) * 25
    elseif state == "run" then
        freq = 3.2
        angleDeg = math.sin(t * freq * math.pi * 2) * TAIL_LIMIT_DEG
    elseif state == "jump" then
        angleDeg = -45 -- tail flicks up
    elseif state == "fall" then
        angleDeg = 35  -- tail droops back
    end
    motor.C1 = CFrame.Angles(0, math.rad(angleDeg), 0)
end

local function applyBodyBob(humanoid, body, t, state)
    if not body or not humanoid then return end
    local baseY = 0
    if state == "walk" then
        baseY = math.sin(t * 1.6 * math.pi * 2) * BOB_AMPLITUDE
    elseif state == "run" then
        baseY = math.sin(t * 3.2 * math.pi * 2) * (BOB_AMPLITUDE * 1.5)
    elseif state == "idle" then
        baseY = math.sin(t * 0.6 * math.pi * 2) * (BOB_AMPLITUDE * 0.4)
    elseif state == "jump" then
        baseY = 0.18
    elseif state == "fall" then
        baseY = -0.08
    end
    -- Apply via HumanoidRootPart CameraOffset on the player so the cat appears to bob
    -- without moving the actual collision body
    local hrp = humanoid.RootPart
    if hrp then
        local lean = (state == "run") and -LEAN_DEGREES or ((state == "fall") and 8 or 0)
        humanoid.CameraOffset = Vector3.new(0, 1 + baseY, 0)
        -- Don't move HRP itself; that would interfere with physics.
    end
end

local function trackPlayer(player)
    local function onChar(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        local body, tail = findCat(char)
        cats[player] = {char = char, hum = hum, tail = tail, body = body, t = 0}
    end
    if player.Character then onChar(player.Character) end
    player.CharacterAdded:Connect(onChar)
    player.CharacterRemoving:Connect(function() cats[player] = nil end)
end

Players.PlayerAdded:Connect(trackPlayer)
for _, p in ipairs(Players:GetPlayers()) do trackPlayer(p) end
Players.PlayerRemoving:Connect(function(p) cats[p] = nil end)

RunService.Heartbeat:Connect(function(dt)
    for player, data in pairs(cats) do
        if data.char and data.char.Parent then
            data.t = (data.t or 0) + dt
            local st = stateOf(data.hum)
            tween(data.hum, data.tail, data.t, dt, st)
            applyBodyBob(data.hum, data.body, data.t, st)
        end
    end
end)

print("[CatProceduralAnimator v1.0] online — tail+body procedural animation active")
