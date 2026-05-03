-- CatLifelike.server.lua — micro-animations: ear twitch, blink, breathing, tail dynamics.
-- Place in: ServerScriptService > CatLifelike (Script). Auto-runs.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local TAIL_HZ = 12   -- tail-update rate (was 20Hz; 12 is plenty visually and ~half the cost)

-- Track per-character state so we can clean up on respawn instead of leaking
-- breathing tweens forever.
local activeChars = setmetatable({}, {__mode = "k"})

local function cleanupChar(state)
    if state.cleaned then return end
    state.cleaned = true
    if state.breathTween then
        pcall(function() state.breathTween:Cancel() end)
        state.breathTween = nil
    end
end

local function setupCat(char)
    if activeChars[char] then return end
    local state = {char = char, cleaned = false}
    activeChars[char] = state

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    char.AncestryChanged:Connect(function()
        if not char:IsDescendantOf(workspace) then cleanupChar(state) end
    end)

    local body = char:FindFirstChild("Torso")
    local ears = {}
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("BasePart") and c.Name == "Ear" then
            table.insert(ears, {part = c, origCFrame = c.CFrame})
        end
    end
    local pupils = {}
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("BasePart") and c.Name == "Pupil" then
            table.insert(pupils, {part = c, origSize = c.Size})
        end
    end
    local tailSegs = {}
    for i = 1, 5 do
        local seg = char:FindFirstChild("TailSeg" .. i)
        if seg then table.insert(tailSegs, {part = seg, origCFrame = seg.CFrame, idx = i}) end
    end

    -- Ear twitches
    task.spawn(function()
        while not state.cleaned and char.Parent do
            task.wait(math.random(8, 15))
            for _, e in ipairs(ears) do
                if not e.part.Parent then break end
                TweenService:Create(e.part, TweenInfo.new(0.08, Enum.EasingStyle.Quad), {
                    CFrame = e.origCFrame * CFrame.Angles(math.rad(math.random(-12, 12)), 0, 0)
                }):Play()
                task.wait(0.1)
                if e.part.Parent then
                    TweenService:Create(e.part, TweenInfo.new(0.15), {CFrame = e.origCFrame}):Play()
                end
            end
        end
    end)

    -- Blink
    task.spawn(function()
        while not state.cleaned and char.Parent do
            task.wait(math.random(4, 7))
            for _, p in ipairs(pupils) do
                if not p.part.Parent then break end
                local origSize = p.origSize
                TweenService:Create(p.part, TweenInfo.new(0.08), {Size = Vector3.new(origSize.X, 0.05, origSize.Z)}):Play()
                task.wait(0.12)
                if p.part.Parent then
                    TweenService:Create(p.part, TweenInfo.new(0.1), {Size = origSize}):Play()
                end
            end
        end
    end)

    -- Breathing: ONE long tween with TweenInfo's repeatCount=-1 instead of
    -- spawning a new tween every 2.5s. The old version leaked one tween per cycle.
    if body then
        local origSize = body.Size
        local breathTween = TweenService:Create(
            body,
            TweenInfo.new(2.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            {Size = origSize + Vector3.new(0.05, 0.05, 0)}
        )
        state.breathTween = breathTween
        breathTween:Play()
    end

    -- Tail whip: lower update rate, manual loop with proper exit.
    if #tailSegs > 0 and char.PrimaryPart then
        local hrp = char.PrimaryPart
        task.spawn(function()
            local interval = 1 / TAIL_HZ
            while not state.cleaned and char.Parent and hrp.Parent do
                local v = hrp.AssemblyLinearVelocity
                local speed = Vector3.new(v.X, 0, v.Z).Magnitude
                local now = os.clock()
                for _, seg in ipairs(tailSegs) do
                    if seg.part.Parent then
                        local sway = math.sin(now * 4 + seg.idx * 0.5) * (0.1 + speed * 0.005) * seg.idx
                        seg.part.CFrame = seg.origCFrame * CFrame.Angles(0, sway, 0)
                    end
                end
                task.wait(interval)
            end
        end)
    end
end

local function attach(player)
    if player.Character then setupCat(player.Character) end
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        setupCat(char)
    end)
    player.CharacterRemoving:Connect(function(char)
        local state = activeChars[char]
        if state then cleanupChar(state) end
    end)
end

Players.PlayerAdded:Connect(attach)
for _, plr in ipairs(Players:GetPlayers()) do attach(plr) end

print("[CatLifelike] ready — ear twitch, blink, breathing, tail dynamics")
