-- SpawnProtection.server.lua
-- Gives a 5-second ForceField on every character spawn to prevent
-- spawn-camping from stealing kills / pranks before the player gets bearings.

local Players = game:GetService("Players")

local PROTECT_SECONDS = 5

local function protect(character)
    -- A ForceField makes the humanoid invulnerable until removed.
    local existing = character:FindFirstChildOfClass("ForceField")
    if existing then existing:Destroy() end
    local ff = Instance.new("ForceField")
    ff.Name = "SpawnProtection"
    ff.Visible = true
    ff.Parent = character
    task.delay(PROTECT_SECONDS, function()
        if ff and ff.Parent then ff:Destroy() end
    end)
end

local function attach(player)
    if player.Character then protect(player.Character) end
    player.CharacterAdded:Connect(protect)
end

Players.PlayerAdded:Connect(attach)
for _, p in ipairs(Players:GetPlayers()) do attach(p) end

print("[SpawnProtection] online — " .. PROTECT_SECONDS .. "s ForceField on respawn")
