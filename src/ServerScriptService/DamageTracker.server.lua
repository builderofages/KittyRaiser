-- DamageTracker.server.lua  v1 — sets LastDamageT attribute on player when
-- their Humanoid takes damage. Used by TradingSystem (damage gate),
-- AchievementSystem (caught/ticketed badges), and any future PvP gate.
--
-- Watches player.Character.Humanoid.HealthChanged. If health DECREASED,
-- player:SetAttribute("LastDamageT", os.clock()).

local Players = game:GetService("Players")

local function watchPlayer(player)
    local function onChar(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        local prev = hum.Health
        hum.HealthChanged:Connect(function(newHealth)
            if newHealth < prev then
                player:SetAttribute("LastDamageT", os.clock())
            end
            prev = newHealth
        end)
    end
    if player.Character then onChar(player.Character) end
    player.CharacterAdded:Connect(onChar)
end

Players.PlayerAdded:Connect(watchPlayer)
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end

print("[DamageTracker v1] online")
