-- WalkAnim.server.lua  — applies walk/idle animation to spawned cat
-- Place in: ServerScriptService > WalkAnim. Auto-runs.

local Players = game:GetService("Players")

local ANIMS = {
    walk = "rbxassetid://507777826",
    run  = "rbxassetid://507767714",
    idle = "rbxassetid://507766388",
    jump = "rbxassetid://507765000",
}

local SPEED_THRESHOLD = 4  -- studs/sec; below this, idle animation plays

local function setupAnim(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)

    local idle = Instance.new("Animation"); idle.AnimationId = ANIMS.idle
    local idleTrack = animator:LoadAnimation(idle)
    idleTrack.Looped = true
    idleTrack.Priority = Enum.AnimationPriority.Idle
    idleTrack:Play()

    local walk = Instance.new("Animation"); walk.AnimationId = ANIMS.walk
    local walkTrack = animator:LoadAnimation(walk)
    walkTrack.Looped = true
    walkTrack.Priority = Enum.AnimationPriority.Movement

    -- Watch hum.Running — it's the canonical Roblox signal for "moving" and
    -- doesn't false-positive on slide physics like raw velocity does.
    task.spawn(function()
        while char.Parent and hum.Parent do
            local moving = hum.MoveDirection.Magnitude > 0.1
                or hum:GetState() == Enum.HumanoidStateType.Running
                or (char.PrimaryPart
                    and Vector3.new(char.PrimaryPart.AssemblyLinearVelocity.X, 0,
                                    char.PrimaryPart.AssemblyLinearVelocity.Z).Magnitude > SPEED_THRESHOLD)

            if moving then
                if not walkTrack.IsPlaying then walkTrack:Play(0.2) end
                if idleTrack.IsPlaying then idleTrack:Stop(0.2) end
            else
                if not idleTrack.IsPlaying then idleTrack:Play(0.2) end
                if walkTrack.IsPlaying then walkTrack:Stop(0.2) end
            end
            task.wait(0.15)
        end
    end)

    -- Procedural tail wag: only while moving so it doesn't conflict with
    -- CatLifelike's idle tail dynamics.
    local tail
    for i = 1, 5 do
        local seg = char:FindFirstChild("TailSeg" .. i)
        if seg then tail = seg; break end
    end
    if tail and tail:IsA("BasePart") then
        local origCF = tail.CFrame
        task.spawn(function()
            local t = 0
            while char.Parent and tail.Parent do
                local moving = (char.PrimaryPart and char.PrimaryPart.AssemblyLinearVelocity.Magnitude > SPEED_THRESHOLD)
                if moving then
                    t = t + 0.05
                    local angle = math.sin(t * 3) * 0.2
                    pcall(function() tail.CFrame = origCF * CFrame.Angles(0, angle, 0) end)
                end
                task.wait(0.08)
            end
        end)
    end
end

local function setup(player)
    if player.Character then setupAnim(player.Character) end
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        setupAnim(char)
    end)
end

Players.PlayerAdded:Connect(setup)
for _, plr in ipairs(Players:GetPlayers()) do setup(plr) end

print("[WalkAnim] cat walk/idle animations + tail wag ready")
