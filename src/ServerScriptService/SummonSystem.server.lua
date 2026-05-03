-- SummonSystem.server.lua
-- Spawns Robloxian "human" NPCs for the player to prank.
-- Place in: ServerScriptService > SummonSystem (Script)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local SharedUtil = require(ReplicatedStorage.Modules.SharedUtil)

local SummonSystem = {}

-- Export to _G FIRST so dependents (PrankSystem) never deadlock if anything below errors.
_G.KittyRaiserSummon = SummonSystem

local SUMMON_COOLDOWN = 1.5
local NPC_DESPAWN_AFTER = 25
local lastSummonTime = {}

-- Server-side registry of legitimate NPCs. Clients can no longer pass arbitrary
-- Workspace Models with the KittyRaiserNPC attribute spoofed.
local registry = setmetatable({}, {__mode = "k"})  -- weak keys: cleared on GC

local npcFolder = Workspace:FindFirstChild("PrankNPCs")
if not npcFolder then
    npcFolder = Instance.new("Folder")
    npcFolder.Name = "PrankNPCs"
    npcFolder.Parent = Workspace
end

local function getSpawnPads()
    local pads = Workspace:FindFirstChild("SpawnPads")
    if not pads then return {} end
    return pads:GetChildren()
end

local function isValidSpawnPosition(v)
    if not v then return false end
    if v.Magnitude > 10000 then return false end
    -- guard against NaN
    return v.X == v.X and v.Y == v.Y and v.Z == v.Z
end

local function buildHumanNPC()
    local model = Instance.new("Model")
    model.Name = "PrankTarget"
    model:SetAttribute("KittyRaiserNPC", true)
    model:SetAttribute("Pranked", false)

    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2, 2, 1)
    hrp.Transparency = 1
    hrp.CanCollide = true   -- HRP MUST collide for humanoid physics
    hrp.Anchored = false
    hrp.Massless = true
    hrp.Parent = model

    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    torso.Color = Color3.fromRGB(0, 100, 200)
    torso.CanCollide = false
    torso.Position = hrp.Position
    torso.Parent = model
    local torsoWeld = Instance.new("WeldConstraint")
    torsoWeld.Part0, torsoWeld.Part1, torsoWeld.Parent = hrp, torso, torso

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.5, 1.5, 1.5)
    head.Shape = Enum.PartType.Ball
    head.Color = Color3.fromRGB(245, 205, 160)
    head.CanCollide = false
    head.Position = torso.Position + Vector3.new(0, 1.75, 0)
    head.Parent = model
    local headWeld = Instance.new("WeldConstraint")
    headWeld.Part0, headWeld.Part1, headWeld.Parent = torso, head, head

    local face = Instance.new("Decal")
    face.Texture = "rbxasset://textures/face.png"
    face.Face = Enum.NormalId.Front
    face.Parent = head

    local legs = Instance.new("Part")
    legs.Name = "Legs"
    legs.Size = Vector3.new(2, 2, 1)
    legs.Color = Color3.fromRGB(40, 40, 80)
    legs.CanCollide = false
    legs.Position = torso.Position + Vector3.new(0, -2, 0)
    legs.Parent = model
    local legWeld = Instance.new("WeldConstraint")
    legWeld.Part0, legWeld.Part1, legWeld.Parent = torso, legs, legs

    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = math.huge   -- NPCs can't die from stray world damage
    humanoid.Health = math.huge
    humanoid.WalkSpeed = 8
    humanoid.JumpPower = 0
    humanoid.HealthDisplayDistance = 0
    humanoid.Parent = model

    model.PrimaryPart = hrp
    return model
end

-- Despawn pranked NPC after a delay. Atomic claim semantics: returns true if
-- THIS caller successfully marked it; false if it was already pranked.
function SummonSystem.markPranked(npc)
    if not npc or not npc.Parent then return false end
    if npc:GetAttribute("Pranked") then return false end
    npc:SetAttribute("Pranked", true)
    task.delay(2, function()
        if npc.Parent then npc:Destroy() end
    end)
    return true
end

function SummonSystem.isRegistered(npc)
    return npc and registry[npc] == true
end

-- Pick a non-overlapping spawn position from a candidate set.
local function findClearSpawn(candidatePos)
    -- check existing NPCs in the radius and offset if too close
    local minSpacing = 5
    for _, existing in ipairs(npcFolder:GetChildren()) do
        local p = existing.PrimaryPart
        if p and (p.Position - candidatePos).Magnitude < minSpacing then
            candidatePos = candidatePos + Vector3.new(math.random(-8, 8), 0, math.random(-8, 8))
        end
    end
    return candidatePos
end

function SummonSystem.summon(player)
    local now = os.clock()
    local last = lastSummonTime[player.UserId] or 0
    if (now - last) < SUMMON_COOLDOWN then
        return false, "summon_cooldown"
    end

    -- global server-wide cap so 50 players spamming summon doesn't tank perf
    if #npcFolder:GetChildren() >= GameConfig.MAX_NPCS_ON_SERVER then
        return false, "server_npc_cap"
    end

    lastSummonTime[player.UserId] = now

    local pads = getSpawnPads()
    local spawnPos
    if #pads > 0 then
        local pad = pads[math.random(1, #pads)]
        spawnPos = pad.Position + Vector3.new(0, 4, 0)
    else
        local char = player.Character
        if char and char.PrimaryPart then
            spawnPos = char.PrimaryPart.Position + Vector3.new(math.random(-10, 10), 5, math.random(-10, 10))
        else
            spawnPos = Vector3.new(0, 10, 0)
        end
    end
    if not isValidSpawnPosition(spawnPos) then
        spawnPos = Vector3.new(0, 10, 0)
    end
    spawnPos = findClearSpawn(spawnPos)

    local npc = buildHumanNPC()
    npc:PivotTo(CFrame.new(spawnPos))
    npc:SetAttribute("SummonedBy", player.UserId)
    npc.Parent = npcFolder
    registry[npc] = true

    -- Spawn-in tween: pop from tiny scale. We fire-and-forget; tween cleanup is
    -- automatic when the part is destroyed.
    for _, p in ipairs(npc:GetDescendants()) do
        if p:IsA("BasePart") then
            local origSize = p.Size
            p.Size = Vector3.new(0.1, 0.1, 0.1)
            local tween = TweenService:Create(
                p, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                {Size = origSize}
            )
            pcall(function() tween:Play() end)
        end
    end

    -- Wander AI scoped to this NPC
    task.spawn(function()
        local hum = npc:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local startTime = os.clock()
        while npc.Parent == npcFolder and (os.clock() - startTime) < NPC_DESPAWN_AFTER do
            local hrp = npc.PrimaryPart
            if not hrp then break end
            local rand = Vector3.new(math.random(-15, 15), 0, math.random(-15, 15))
            hum:MoveTo(hrp.Position + rand)
            task.wait(math.random(2, 4))
        end
        if npc.Parent and not npc:GetAttribute("Pranked") then
            registry[npc] = nil
            npc:Destroy()
        end
    end)
    return true, npc
end

Remotes.RequestSummonHuman.OnServerEvent:Connect(function(player)
    if not SharedUtil.checkRate(player, "summon", 0.6) then return end
    SummonSystem.summon(player)
end)

Players.PlayerRemoving:Connect(function(player)
    lastSummonTime[player.UserId] = nil
    for _, npc in ipairs(npcFolder:GetChildren()) do
        if npc:GetAttribute("SummonedBy") == player.UserId then
            registry[npc] = nil
            npc:Destroy()
        end
    end
end)

return SummonSystem
