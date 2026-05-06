--[[
  NPCHitboxExpander.server.lua
  Place in: ServerScriptService

  Attaches a large invisible "hit zone" part to every NPC HumanoidRootPart
  so that raycasts, clicks, and sphere overlaps from ClickAttack reliably
  connect even when the player is on mobile with imprecise taps.

  Hit zone: 5 × 6 × 5 studs  (wider + taller than a default R15 torso)
  Also sets the NPC's existing HumanoidRootPart to non-cancollide so the
  big zone does the collision work.

  Works with both existing NPCs (AmbientCrowd) and any new ones spawned
  later via CollectionService tag "NPC".
--]]

local CollectionService = game:GetService("CollectionService")

local HIT_ZONE_SIZE   = Vector3.new(5, 6, 5)
local HIT_ZONE_TAG    = "NPCHitZone"
local NPC_TAG         = "NPC"   -- AmbientCrowd tags all NPCs with this

local function attachHitZone(npcModel)
  -- Guard: don't double-attach
  if npcModel:FindFirstChild("HitZone") then return end

  local root = npcModel:FindFirstChild("HumanoidRootPart")
  if not root then
    -- Try again shortly (NPC might still be building)
    task.delay(0.5, function()
      if npcModel and npcModel.Parent then
        attachHitZone(npcModel)
      end
    end)
    return
  end

  -- Make the original root non-cancollide so physics isn't weird
  root.CanCollide = false

  -- Big transparent hit zone welded to root
  local zone = Instance.new("Part")
  zone.Name = "HitZone"
  zone.Size = HIT_ZONE_SIZE
  zone.Transparency = 1
  zone.CanCollide = false
  zone.CanQuery = true       -- raycasts WILL hit this
  zone.CanTouch = true
  zone.Anchored = false
  zone.CastShadow = false
  zone.Massless = true
  -- Tag so ClickAttack getNPCFromHit can find the parent model
  CollectionService:AddTag(zone, HIT_ZONE_TAG)
  zone.Parent = npcModel

  -- Weld to root
  local weld = Instance.new("WeldConstraint")
  weld.Part0 = root
  weld.Part1 = zone
  weld.Parent = zone

  -- Keep zone centred on root (offset: slightly higher to cover head too)
  zone.CFrame = root.CFrame * CFrame.new(0, 0.5, 0)
end

-- ── Wire existing + future NPCs ───────────────────────────────────────────────

-- All existing tagged NPCs
for _, npc in ipairs(CollectionService:GetTagged(NPC_TAG)) do
  task.spawn(attachHitZone, npc)
end

-- Any future spawned NPCs
CollectionService:GetInstanceAddedSignal(NPC_TAG):Connect(function(npc)
  task.spawn(attachHitZone, npc)
end)

-- Fallback: scan workspace every 3s for untagged Humanoid models
-- (handles AmbientCrowd NPCs that might not have the tag yet on first load)
task.spawn(function()
  while true do
    task.wait(3)
    for _, model in ipairs(workspace:GetDescendants()) do
      if model:IsA("Model") then
        local hum = model:FindFirstChildOfClass("Humanoid")
        local root = model:FindFirstChild("HumanoidRootPart")
        if hum and root and not model:FindFirstChild("HitZone") then
          -- Only expand NPCs, not players
          if not game:GetService("Players"):GetPlayerFromCharacter(model) then
            task.spawn(attachHitZone, model)
          end
        end
      end
    end
  end
end)

print("[NPCHitboxExpander] Running — all NPCs get 5×6×5 hit zones")
