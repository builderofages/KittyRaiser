-- WorldPowerups.server.lua  v1 — pickup orbs scattered around the city.
-- 12 active powerups at any time; respawn 30s after grab. Server-validates
-- pickup and applies effect to the touching player. No client trust.
--
-- Powerup kinds:
--   chaos_boost  — +500 chaos instantly (gold orb)
--   speed_boost  — WalkSpeed +12 for 20s (cyan orb)
--   chaos_x2     — chaos rewards 2x for 30s (red orb)
--   ht_drop      — +3 hell tokens (purple orb)

local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local DataHandler
task.spawn(function()
    while not _G.KittyRaiserData do task.wait() end
    DataHandler = _G.KittyRaiserData
end)

local KINDS = {
    {id="chaos_boost", color=Color3.fromRGB(255, 215, 80),  msg="+500 CHAOS"},
    {id="speed_boost", color=Color3.fromRGB(80, 200, 240),  msg="SPEED BOOST 20s"},
    {id="chaos_x2",    color=Color3.fromRGB(255, 90, 80),   msg="2x CHAOS 30s"},
    {id="ht_drop",     color=Color3.fromRGB(180, 100, 220), msg="+3 HELL TOKENS"},
}
local TARGET_COUNT = 12
local RESPAWN_S = 30
local MAP_RANGE = 1500  -- spawn within +/- 1500 studs of origin

local folder = Workspace:FindFirstChild("WorldPowerups") or Instance.new("Folder", Workspace)
folder.Name = "WorldPowerups"
folder:ClearAllChildren()

local function applyEffect(player, kindId)
    if not DataHandler then return end
    if kindId == "chaos_boost" then
        DataHandler.modify(player, function(d)
            d.chaosPoints = (d.chaosPoints or 0) + 500
        end)
    elseif kindId == "ht_drop" then
        DataHandler.modify(player, function(d)
            d.hellTokens = (d.hellTokens or 0) + 3
        end)
    elseif kindId == "speed_boost" then
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            local prev = hum.WalkSpeed
            hum.WalkSpeed = prev + 12
            task.delay(20, function()
                if hum.Parent then hum.WalkSpeed = prev end
            end)
        end
    elseif kindId == "chaos_x2" then
        player:SetAttribute("ChaosX2Until", os.clock() + 30)
    end
end

local function makeOrb(kind, position)
    local orb = Instance.new("Part", folder)
    orb.Name = "Powerup_" .. kind.id
    orb.Anchored = true
    orb.CanCollide = false
    orb.Shape = Enum.PartType.Ball
    orb.Size = Vector3.new(2.4, 2.4, 2.4)
    orb.Position = position
    orb.Material = Enum.Material.Neon
    orb.Color = kind.color
    orb.Transparency = 0.15
    orb:SetAttribute("PowerupKind", kind.id)

    -- Glow attachment
    local light = Instance.new("PointLight", orb)
    light.Color = kind.color
    light.Range = 16
    light.Brightness = 1.2

    -- Spin + bob via TweenService (spawn task, lasts until orb destroyed)
    local TS = game:GetService("TweenService")
    task.spawn(function()
        local t0 = os.clock()
        while orb.Parent do
            local elapsed = os.clock() - t0
            orb.CFrame = CFrame.new(position.X, position.Y + math.sin(elapsed * 2) * 0.4, position.Z)
                * CFrame.Angles(0, elapsed * 2, 0)
            task.wait(0.05)
        end
    end)

    -- Touched -> grant on first valid player
    local claimed = false
    orb.Touched:Connect(function(hit)
        if claimed then return end
        local char = hit:FindFirstAncestorOfClass("Model")
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local p = Players:GetPlayerFromCharacter(char)
        if not p then return end
        claimed = true
        applyEffect(p, kind.id)
        if Remotes.NotifyClient then
            Remotes.NotifyClient:FireClient(p, "POWER-UP  -  " .. kind.msg, "good")
        end
        -- Pop animation: scale up + fade out
        TS:Create(orb, TweenInfo.new(0.3, Enum.EasingStyle.Quad),
            {Size = Vector3.new(5, 5, 5), Transparency = 1}):Play()
        task.delay(0.3, function() orb:Destroy() end)
    end)
    return orb
end

local function pickRandomPosition()
    local x = math.random(-MAP_RANGE, MAP_RANGE)
    local z = math.random(-MAP_RANGE, MAP_RANGE)
    return Vector3.new(x, 4, z)
end

-- =====================================================================
-- MANAGER LOOP — keep TARGET_COUNT orbs in the world; respawn replacements
-- =====================================================================
task.spawn(function()
    while true do
        task.wait(2)
        local count = 0
        for _, c in ipairs(folder:GetChildren()) do
            if c:IsA("BasePart") and c:GetAttribute("PowerupKind") then
                count = count + 1
            end
        end
        local need = TARGET_COUNT - count
        for _ = 1, need do
            local kind = KINDS[math.random(1, #KINDS)]
            makeOrb(kind, pickRandomPosition())
        end
        task.wait(RESPAWN_S - 2)
    end
end)

print("[WorldPowerups v1] online — " .. TARGET_COUNT .. " orbs scattered, " .. #KINDS .. " kinds")
