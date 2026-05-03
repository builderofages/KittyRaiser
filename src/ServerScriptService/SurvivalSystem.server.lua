-- SurvivalSystem.server.lua
-- Hunger/thirst decay over time. Below 25 = slow. At 0 = ragdoll respawn.
-- Place in: ServerScriptService > SurvivalSystem (Script)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local SharedUtil = require(ReplicatedStorage.Modules.SharedUtil)

local DataHandler = SharedUtil.waitForGlobal("KittyRaiserData", 30)
if not DataHandler then return end

if not GameConfig.SURVIVAL_ENABLED then
    print("[SurvivalSystem] Disabled in config")
    return
end

local TICK = 5
local hungerPerTick = (GameConfig.HUNGER_DECAY_PER_MIN / 60) * TICK
local thirstPerTick = (GameConfig.THIRST_DECAY_PER_MIN / 60) * TICK

-- Stash original walkspeed per character so debuff can be reverted cleanly
local function setBaseSpeedAttribute(character)
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum and not character:GetAttribute("BaseWalkSpeed") then
        character:SetAttribute("BaseWalkSpeed", hum.WalkSpeed)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(setBaseSpeedAttribute)
end)
for _, p in ipairs(Players:GetPlayers()) do
    if p.Character then setBaseSpeedAttribute(p.Character) end
end

task.spawn(function()
    while true do
        task.wait(TICK)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = DataHandler.getData(player)
            if data then
                DataHandler.modify(player, function(d)
                    -- math.max preserves the float (math.clamp truncates to int via implicit
                    -- conversion in some places); 0.4/tick decay was being floored to 0.
                    d.hunger = math.max(0, math.min(100, (d.hunger or 100) - hungerPerTick))
                    d.thirst = math.max(0, math.min(100, (d.thirst or 100) - thirstPerTick))
                end)
                Remotes.SurvivalUpdate:FireClient(player, data.hunger, data.thirst)

                local char = player.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        local base = char:GetAttribute("BaseWalkSpeed") or 16
                        local lowVitals = data.hunger < GameConfig.SURVIVAL_DEBUFF_AT
                            or data.thirst < GameConfig.SURVIVAL_DEBUFF_AT
                        -- Set, don't subtract — old code chained subtractions making the slow permanent.
                        hum.WalkSpeed = lowVitals and math.max(8, base * 0.5) or base

                        if data.hunger <= 0 or data.thirst <= 0 then
                            hum.Health = 0
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

-- Food/water sources detection. Connections are tracked so we can disconnect
-- when a part is destroyed (previous code leaked connections).
local sourceConns = {}
local function setupFoodPart(part)
    if not part:IsA("BasePart") then return end
    if not part:GetAttribute("FoodSource") and not part:GetAttribute("WaterSource") then return end
    if sourceConns[part] then return end

    local touchedConn
    touchedConn = part.Touched:Connect(function(hit)
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
        Remotes.NotifyClient:FireClient(player,
            part:GetAttribute("FoodSource") and "+Food" or "+Water", "success")
    end)
    local destroyConn
    destroyConn = part.AncestryChanged:Connect(function()
        if not part:IsDescendantOf(workspace) then
            if touchedConn then touchedConn:Disconnect() end
            if destroyConn then destroyConn:Disconnect() end
            sourceConns[part] = nil
        end
    end)
    sourceConns[part] = {touched = touchedConn, ancestry = destroyConn}
end

for _, p in ipairs(Workspace:GetDescendants()) do setupFoodPart(p) end
Workspace.DescendantAdded:Connect(setupFoodPart)

-- Direct request remotes (used by interaction prompts). Now validate proximity
-- so the client can't eat infinitely without being near a source.
local function nearSource(player, sourceModel, maxStuds)
    if not sourceModel or not sourceModel.Parent then return false end
    if not sourceModel:IsDescendantOf(workspace) then return false end
    local char = player.Character
    if not char or not char.PrimaryPart then return false end
    local pivot = nil
    if sourceModel:IsA("Model") then
        pivot = sourceModel.PrimaryPart and sourceModel.PrimaryPart.Position
            or sourceModel:GetPivot().Position
    elseif sourceModel:IsA("BasePart") then
        pivot = sourceModel.Position
    end
    if not pivot then return false end
    return (char.PrimaryPart.Position - pivot).Magnitude <= maxStuds
end

Remotes.RequestEatFood.OnServerEvent:Connect(function(player, sourceModel)
    if not SharedUtil.checkRate(player, "eat", 0.5) then return end
    if not (sourceModel and sourceModel:GetAttribute("FoodSource")) then return end
    if not nearSource(player, sourceModel, 12) then return end
    DataHandler.modify(player, function(d)
        d.hunger = math.min(100, (d.hunger or 0) + GameConfig.FOOD_RESTORE)
    end)
end)

Remotes.RequestDrinkWater.OnServerEvent:Connect(function(player, sourceModel)
    if not SharedUtil.checkRate(player, "drink", 0.5) then return end
    if not (sourceModel and sourceModel:GetAttribute("WaterSource")) then return end
    if not nearSource(player, sourceModel, 12) then return end
    DataHandler.modify(player, function(d)
        d.thirst = math.min(100, (d.thirst or 0) + GameConfig.WATER_RESTORE)
    end)
end)

return true
