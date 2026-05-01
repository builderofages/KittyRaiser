-- SurvivalSystem.server.lua
-- Hunger/thirst decay over time. Below 25 = slow. At 0 = ragdoll respawn.
-- Place in: ServerScriptService > SurvivalSystem (Script)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local function waitFor(g) while not _G[g] do task.wait() end return _G[g] end
local DataHandler = waitFor("KittyRaiserData")

if not GameConfig.SURVIVAL_ENABLED then
    print("[SurvivalSystem] Disabled in config")
    return
end

local TICK = 5  -- decay every 5 sec
local hungerPerTick = (GameConfig.HUNGER_DECAY_PER_MIN / 60) * TICK
local thirstPerTick = (GameConfig.THIRST_DECAY_PER_MIN / 60) * TICK

task.spawn(function()
    while true do
        task.wait(TICK)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = DataHandler.getData(player)
            if data then
                DataHandler.modify(player, function(d)
                    d.hunger = math.clamp((d.hunger or 100) - hungerPerTick, 0, 100)
                    d.thirst = math.clamp((d.thirst or 100) - thirstPerTick, 0, 100)
                end)
                Remotes.SurvivalUpdate:FireClient(player, data.hunger, data.thirst)
                -- Apply slow if low
                local char = player.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        if data.hunger < GameConfig.SURVIVAL_DEBUFF_AT or data.thirst < GameConfig.SURVIVAL_DEBUFF_AT then
                            hum.WalkSpeed = math.max(8, hum.WalkSpeed - 4)
                        end
                        if data.hunger <= 0 or data.thirst <= 0 then
                            hum.Health = 0  -- respawn
                            DataHandler.modify(player, function(d)
                                d.hunger = 50
                                d.thirst = 50
                            end)
                        end
                    end
                end
            end
        end
    end
end)

-- Food/water sources detection: parts with attribute "FoodSource" or "WaterSource"
local function setupFoodPart(part)
    if not part:IsA("BasePart") then return end
    if not part:GetAttribute("FoodSource") and not part:GetAttribute("WaterSource") then return end
    part.Touched:Connect(function(hit)
        local char = hit and hit.Parent
        if not char then return end
        local player = Players:GetPlayerFromCharacter(char)
        if not player then return end
        local now = os.clock()
        local lastUse = part:GetAttribute("LastUse_"..player.UserId) or 0
        if (now - lastUse) < 5 then return end
        part:SetAttribute("LastUse_"..player.UserId, now)
        DataHandler.modify(player, function(d)
            if part:GetAttribute("FoodSource") then
                d.hunger = math.min(100, (d.hunger or 0) + GameConfig.FOOD_RESTORE)
            end
            if part:GetAttribute("WaterSource") then
                d.thirst = math.min(100, (d.thirst or 0) + GameConfig.WATER_RESTORE)
            end
        end)
        Remotes.NotifyClient:FireClient(player, part:GetAttribute("FoodSource") and "+Food" or "+Water", "success")
    end)
end

for _, p in ipairs(Workspace:GetDescendants()) do setupFoodPart(p) end
Workspace.DescendantAdded:Connect(setupFoodPart)

-- Direct request remotes (used by interaction prompts)
Remotes.RequestEatFood.OnServerEvent:Connect(function(player, sourceModel)
    if sourceModel and sourceModel:GetAttribute("FoodSource") then
        DataHandler.modify(player, function(d)
            d.hunger = math.min(100, (d.hunger or 0) + GameConfig.FOOD_RESTORE)
        end)
    end
end)
Remotes.RequestDrinkWater.OnServerEvent:Connect(function(player, sourceModel)
    if sourceModel and sourceModel:GetAttribute("WaterSource") then
        DataHandler.modify(player, function(d)
            d.thirst = math.min(100, (d.thirst or 0) + GameConfig.WATER_RESTORE)
        end)
    end
end)

return true
