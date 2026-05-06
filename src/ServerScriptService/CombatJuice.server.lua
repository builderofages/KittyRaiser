-- CombatJuice.server.lua  v1 — chunky hit feedback per Phase-13 directive.
--
-- Listens to PrankRegistered fire (server-side via PrankSystem) by tagging
-- the targetModel with attributes the client reads. Adds:
--   * KNOCKBACK: applies AssemblyLinearVelocity impulse on the NPC's HRP
--   * RAGDOLL FLAIL: when an NPC's NpcHp hits 0, briefly disables their
--     Humanoid + applies impulse so they tumble before despawn
--   * SCREAM: random scream sound from a small pool

local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes  = require(ReplicatedStorage.Modules.RemoteEvents)
local AssetIds = require(ReplicatedStorage.Modules.AssetIds)
local AudioGroups
do
    local m = ReplicatedStorage.Modules:WaitForChild("AudioGroups", 5)
    if m then local ok, mod = pcall(require, m); if ok then AudioGroups = mod end end
end

local SCREAM_KEYS = {"npc_scream_1","npc_scream_2","npc_scream_3"}  -- assets pending; gracefully skip if 0

local function pickScreamId()
    for _, k in ipairs(SCREAM_KEYS) do
        if AssetIds.has(k) then return AssetIds[k] end
    end
    return nil
end

local function playScream(npc)
    local id = pickScreamId()
    if not id then return end
    local head = npc:FindFirstChild("Head") or npc.PrimaryPart
    if not head then return end
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = 0.85
    s.PlaybackSpeed = 0.85 + math.random() * 0.4  -- pitch variation
    if AudioGroups then AudioGroups.assign(s, "SFX") end
    s.Parent = head
    s:Play()
    game:GetService("Debris"):AddItem(s, 3)
end

local function applyKnockback(npc, fromPos, magnitude)
    local hrp = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
    if not hrp then return end
    local dir = (hrp.Position - fromPos)
    if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
    dir = dir.Unit
    local impulse = dir * magnitude + Vector3.new(0, magnitude * 0.4, 0)
    pcall(function() hrp.AssemblyLinearVelocity = impulse end)
end

local function ragdollFlail(npc)
    local hum = npc:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    -- Disable platform-stand briefly so the NPC physics-tumbles
    pcall(function()
        hum:ChangeState(Enum.HumanoidStateType.Physics)
        hum.PlatformStand = true
    end)
    local hrp = npc:FindFirstChild("HumanoidRootPart")
    if hrp then
        -- Random spin
        pcall(function()
            hrp.AssemblyAngularVelocity = Vector3.new(
                math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
        end)
    end
end

-- Server-side hook: PrankSystem fires PrankRegistered for the actor + nearby
-- broadcasters. We piggyback on a workspace attribute the client doesn't
-- need — server applies impulses directly.
Remotes.PrankRegistered.OnClientEvent = nil  -- no-op (server side)

-- Hook into PrankRegistered being fired from PrankSystem. We can't directly
-- intercept FireClient, so instead poll on PrankNPC attributes. Simpler:
-- read NpcHp drop and react.
task.spawn(function()
    local seenAttrConn = {}
    local function attach(npc)
        if seenAttrConn[npc] then return end
        seenAttrConn[npc] = true
        npc:GetAttributeChangedSignal("NpcHp"):Connect(function()
            local hp = npc:GetAttribute("NpcHp")
            if not hp then return end
            -- Find the closest player (the pranker) for knockback origin
            local hrp = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
            if not hrp then return end
            local nearestPlayer
            local nearestD = math.huge
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character and p.Character.PrimaryPart then
                    local d = (p.Character.PrimaryPart.Position - hrp.Position).Magnitude
                    if d < nearestD then nearestD = d; nearestPlayer = p end
                end
            end
            local fromPos = nearestPlayer and nearestPlayer.Character.PrimaryPart.Position
                or hrp.Position - Vector3.new(0, 0, 8)
            if hp > 0 then
                -- Hit but not killed: small knockback + scream chance
                applyKnockback(npc, fromPos, 35)
                if math.random() < 0.5 then playScream(npc) end
            else
                -- Killed: big knockback + ragdoll + guaranteed scream
                applyKnockback(npc, fromPos, 80)
                ragdollFlail(npc)
                playScream(npc)
            end
        end)
    end
    -- Attach to existing NPCs + watch for new ones
    local function watchFolder(folder)
        if not folder then return end
        for _, npc in ipairs(folder:GetChildren()) do attach(npc) end
        folder.ChildAdded:Connect(function(c) attach(c) end)
    end
    watchFolder(Workspace:WaitForChild("PrankNPCs", 30))
    watchFolder(Workspace:WaitForChild("AmbientCrowd", 30))
end)

-- =====================================================================
-- HIT-STOP BROADCAST — server fires EventBroadcast 'hit_stop' on every
-- prank. Client freezes the world for a fraction of a second.
-- =====================================================================
Remotes.PrankRegistered.OnServerEvent = nil  -- safety; PrankSystem owns this server-side
-- We tap into the PrankSystem flow indirectly: when an NPC's NpcHp drops
-- the client also receives PrankRegistered, so we don't need a separate
-- broadcast here — the client-side HitStop.client.lua reads PrankRegistered.

print("[CombatJuice v1] online — knockback + ragdoll + scream on prank")
