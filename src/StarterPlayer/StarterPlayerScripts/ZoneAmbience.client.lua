-- ZoneAmbience.client.lua
-- Adds light per-zone ambient particles (no global lighting change) so each
-- of the 3 city zones FEELS different even when the global Weather is the
-- same:
--   * downtown (NE):  faint dust motes drifting downward
--   * suburbs  (cross): occasional cherry-blossom-like petals
--   * harbor   (SW):  faint salt mist drifting upward
-- Detects current zone by player XZ position. Re-evaluates every 2s.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- Same quadrant rules as CityRebuild.zoneForCell, but on world coords:
-- one cell = 220 studs, so detect zone by sign of X/Z.
local function zoneFor(pos)
    local gx = pos.X >= 0 and 1 or -1
    local gz = pos.Z >= 0 and 1 or -1
    if gx >= 0 and gz >= 0 then return "downtown" end
    if gx <  0 and gz <  0 then return "harbor"   end
    return "suburbs"
end

-- One Attachment + ParticleEmitter per zone, parented to player's HRP and
-- enabled only when the player is in that zone.
local function makeEmitter(parent, opts)
    local p = Instance.new("ParticleEmitter")
    p.Texture = opts.texture or "rbxasset://textures/particles/smoke_main.dds"
    p.Color = ColorSequence.new(opts.color)
    p.Lifetime = opts.lifetime or NumberRange.new(2, 4)
    p.Rate = 0  -- enabled by setting Rate
    p.Speed = opts.speed or NumberRange.new(1, 3)
    p.SpreadAngle = Vector2.new(180, 180)
    p.Size = opts.size or NumberSequence.new(0.6, 0.1)
    p.Acceleration = opts.acceleration or Vector3.new(0, -0.2, 0)
    p.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.7),
        NumberSequenceKeypoint.new(0.5, 0.4),
        NumberSequenceKeypoint.new(1, 1),
    })
    p.Parent = parent
    return p
end

local emitters = {}
local currentZone = nil

local function setup(char)
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return end

    local att = Instance.new("Attachment", hrp)
    att.Name = "ZoneAmbienceAttachment"
    att.Position = Vector3.new(0, 8, 0)  -- above the player

    -- downtown: dust motes
    emitters.downtown = makeEmitter(att, {
        color = Color3.fromRGB(220, 215, 200),
        size  = NumberSequence.new(0.3, 0.05),
        lifetime = NumberRange.new(3, 5),
        speed = NumberRange.new(0.5, 1.5),
        acceleration = Vector3.new(0, -0.4, 0),
    })
    -- suburbs: pink-ish petals
    emitters.suburbs = makeEmitter(att, {
        color = Color3.fromRGB(255, 200, 220),
        size  = NumberSequence.new(0.4, 0.08),
        lifetime = NumberRange.new(3, 6),
        speed = NumberRange.new(0.8, 2.0),
        acceleration = Vector3.new(0.4, -0.6, 0),
    })
    -- harbor: salt mist drifts upward
    emitters.harbor = makeEmitter(att, {
        color = Color3.fromRGB(220, 230, 240),
        size  = NumberSequence.new(0.5, 0.2),
        lifetime = NumberRange.new(2, 4),
        speed = NumberRange.new(0.5, 1.0),
        acceleration = Vector3.new(0, 0.4, 0),
    })

    task.spawn(function()
        while char.Parent and att.Parent do
            local pos = hrp.Position
            local z = zoneFor(pos)
            if z ~= currentZone then
                currentZone = z
                for name, em in pairs(emitters) do
                    em.Rate = (name == z) and 4 or 0
                end
            end
            task.wait(2)
        end
    end)
end

if player.Character then setup(player.Character) end
player.CharacterAdded:Connect(setup)

print("[ZoneAmbience v1] online")
