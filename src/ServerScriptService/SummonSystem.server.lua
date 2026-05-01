-- SummonSystem.server.lua
-- Spawns Robloxian "human" NPCs for the player to prank.
-- Place in: ServerScriptService > SummonSystem (Script)

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local SummonSystem = {}

local SUMMON_COOLDOWN = 1.5
local NPC_DESPAWN_AFTER = 25 -- seconds if not pranked
local lastSummonTime = {}  -- [userId] = os.clock()

-- Find or create the NPC folder in workspace
local npcFolder = Workspace:FindFirstChild("PrankNPCs")
if not npcFolder then
    npcFolder = Instance.new("Folder")
    npcFolder.Name = "PrankNPCs"
    npcFolder.Parent = Workspace
end

-- Get spawn pads (placed in workspace by MapBuilder)
local function getSpawnPads()
    local pads = Workspace:FindFirstChild("SpawnPads")
    if not pads then return {} end
    return pads:GetChildren()
end

-- Build a simple Robloxian-style NPC programmatically (no asset deps)
local function buildHumanNPC()
    local model = Instance.new("Model")
    model.Name = "PrankTarget"
    model:SetAttribute("KittyRaiserNPC", true)
    model:SetAttribute("Pranked", false)

    -- HumanoidRootPart
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2, 2, 1)
    hrp.Transparency = 1
    hrp.CanCollide = false
    hrp.Anchored = false
    hrp.Parent = model

    -- Torso
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    torso.Color = Color3.fromRGB(0, 100, 200)
    torso.Position = hrp.Position
    torso.Parent = model
    local torsoWeld = Instance.new("WeldConstraint")
    torsoWeld.Part0 = hrp
    torsoWeld.Part1 = torso
    torsoWeld.Parent = torso

    -- Head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.5, 1.5, 1.5)
    head.Shape = Enum.PartType.Ball
    head.Color = Color3.fromRGB(245, 205, 160)
    head.Position = torso.Position + Vector3.new(0, 1.75, 0)
    head.Parent = model
    local headWeld = Instance.new("WeldConstraint")
    headWeld.Part0 = torso
    headWeld.Part1 = head
    headWeld.Parent = head

    -- Face decal (simple)
    local face = Instance.new("Decal")
    face.Texture = "rbxasset://textures/face.png"
    face.Face = Enum.NormalId.Front
    face.Parent = head

    -- Legs (combined block)
    local legs = Instance.new("Part")
    legs.Name = "Legs"
    legs.Size = Vector3.new(2, 2, 1)
    legs.Color = Color3.fromRGB(40, 40, 80)
    legs.Position = torso.Position + Vector3.new(0, -2, 0)
    legs.Parent = model
    local legWeld = Instance.new("WeldConstraint")
    legWeld.Part0 = torso
    legWeld.Part1 = legs
    legWeld.Parent = legs

    -- Humanoid for ragdoll-style animation later
    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = 100
    humanoid.Health = 100
    humanoid.WalkSpeed = 8
    humanoid.Parent = model

    model.PrimaryPart = hrp
    return model
end

-- Wander AI: NPC walks randomly until pranked or despawn
local function wanderAI(model)
    task.spawn(function()
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local startTime = os.clock()
        while model.Parent and (os.clock() - startTime) < NPC_DESPAWN_AFTER do
            local hrp = model.PrimaryPart
            if not hrp then break end
            local rand = Vector3.new(math.random(-15, 15), 0, math.random(-15, 15))
            hum:MoveTo(hrp.Position + rand)
            task.wait(math.random(2, 4))
        end
        if model.Parent and not model:GetAttribute("Pranked") then
            model:Destroy()
        end
    end)
end

-- Public: summon an NPC for a player
function SummonSystem.summon(player)
    local now = os.clock()
    local last = lastSummonTime[player.UserId] or 0
    if (now - last) < SUMMON_COOLDOWN then
        return false, "summon_cooldown"
    end
    lastSummonTime[player.UserId] = now

    local pads = getSpawnPads()
    if #pads == 0 then
        warn("[SummonSystem] No spawn pads found - using default position")
    end

    local npc = buildHumanNPC()
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

    npc:PivotTo(CFrame.new(spawnPos))
    npc:SetAttribute("SummonedBy", player.UserId)
    npc.Parent = npcFolder

    -- Spawn-in animation: tween scale up
    for _, p in ipairs(npc:GetDescendants()) do
        if p:IsA("BasePart") then
            local origSize = p.Size
            p.Size = Vector3.new(0.1, 0.1, 0.1)
            TweenService:Create(p, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = origSize}):Play()
        end
    end

    wanderAI(npc)
    return true, npc
end

-- Despawn pranked NPC after a delay
function SummonSystem.markPranked(npc)
    if not npc then return end
    npc:SetAttribute("Pranked", true)
    task.delay(2, function()
        if npc.Parent then npc:Destroy() end
    end)
end

-- Wire remote
Remotes.RequestSummonHuman.OnServerEvent:Connect(function(player)
    SummonSystem.summon(player)
end)

Players.PlayerRemoving:Connect(function(player)
    lastSummonTime[player.UserId] = nil
    -- Despawn this player's NPCs
    for _, npc in ipairs(npcFolder:GetChildren()) do
        if npc:GetAttribute("SummonedBy") == player.UserId then
            npc:Destroy()
        end
    end
end)

_G.KittyRaiserSummon = SummonSystem
return SummonSystem
