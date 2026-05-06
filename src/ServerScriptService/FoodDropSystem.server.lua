-- FoodDropSystem.server.lua  v1
-- Spawns food (hot dog) and water (milk bottle) drops:
--   1. Around the plaza on a few breakable HotDogStand + Fountain props
--   2. 2% chance to drop on NPC death (markPranked event hook)
-- Picking up a drop fires Remotes.SurvivalDelta with hunger or thirst gain.
local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService     = game:GetService("TweenService")
local Debris           = game:GetService("Debris")
local Remotes  = require(ReplicatedStorage.Modules.RemoteEvents)
local AssetIds = require(ReplicatedStorage.Modules.AssetIds)

local DROP_LIFETIME = 30
local DROP_HOVER_OFFSET = Vector3.new(0, 1.2, 0)
local NPC_DROP_CHANCE = 0.02  -- 2%

local dropsFolder = Workspace:FindFirstChild("Drops") or Instance.new("Folder")
dropsFolder.Name = "Drops"; dropsFolder.Parent = Workspace

local function makeDrop(kind, position)
    local part = Instance.new("Part")
    part.Name = (kind == "food") and "FoodDrop" or "WaterDrop"
    part.Size = Vector3.new(0.9, 0.9, 0.9)
    part.Material = Enum.Material.SmoothPlastic
    part.Color = (kind == "food") and Color3.fromRGB(220, 130, 60) or Color3.fromRGB(220, 230, 255)
    part.Position = position + DROP_HOVER_OFFSET
    part.Anchored = true
    part.CanCollide = false
    part.Parent = dropsFolder
    -- spinning glow effect
    local light = Instance.new("PointLight", part)
    light.Color = part.Color; light.Brightness = 1.5; light.Range = 6
    -- bobbing tween
    local bob = TweenService:Create(part, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        {Position = part.Position + Vector3.new(0, 0.3, 0)})
    bob:Play()
    -- pickup detection
    local conn
    conn = part.Touched:Connect(function(other)
        local char = other:FindFirstAncestorOfClass("Model")
        if not char then return end
        local player = Players:GetPlayerFromCharacter(char)
        if not player then return end
        if Remotes.SurvivalDelta then
            if kind == "food" then
                Remotes.SurvivalDelta:FireClient(player, {hunger = 25})
            else
                Remotes.SurvivalDelta:FireClient(player, {thirst = 25})
            end
        end
        -- pickup feedback
        local pop = TweenService:Create(part, TweenInfo.new(0.2),
            {Size = Vector3.new(2, 2, 2), Transparency = 1})
        pop:Play()
        conn:Disconnect()
        Debris:AddItem(part, 0.25)
    end)
    Debris:AddItem(part, DROP_LIFETIME)
    return part
end

-- ============ Hot Dog Stand + Fountain interactables ============
local function spawnInteractable(kind, position)
    -- Visual prop. If asset mesh available, attach it; otherwise use colored block.
    local stand = Instance.new("Part")
    stand.Name = (kind == "food") and "HotDogStand" or "WaterFountain"
    stand.Size = Vector3.new(3, 3, 3)
    stand.Material = Enum.Material.SmoothPlastic
    stand.Color = (kind == "food") and Color3.fromRGB(200, 60, 50) or Color3.fromRGB(180, 180, 220)
    stand.Position = position
    stand.Anchored = true
    stand.Parent = Workspace
    stand:SetAttribute("MaxHits", 3)
    stand:SetAttribute("Hits", 0)
    -- BillboardGui instructions
    local bb = Instance.new("BillboardGui", stand)
    bb.Size = UDim2.new(0, 120, 0, 30)
    bb.StudsOffset = Vector3.new(0, 2, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 14  -- v3.99.2: only show prompt within 14 studs to dedupe
    local lbl = Instance.new("TextLabel", bb)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 0.4
    lbl.BackgroundColor3 = Color3.new(0,0,0)
    lbl.TextColor3 = Color3.fromRGB(255, 230, 160)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    lbl.Text = (kind == "food") and "BREAK FOR FOOD" or "DRINK FROM FOUNTAIN"
    -- damage hit detection: when a part touches with name PrankProjectile or player gets close + clicks
    -- For now, simple: every player who touches it triggers a hit
    local touchDb = {}
    stand.Touched:Connect(function(other)
        local char = other:FindFirstAncestorOfClass("Model")
        local player = char and Players:GetPlayerFromCharacter(char)
        if not player then return end
        if touchDb[player.UserId] and os.clock() - touchDb[player.UserId] < 1.0 then return end
        touchDb[player.UserId] = os.clock()
        local hits = (stand:GetAttribute("Hits") or 0) + 1
        stand:SetAttribute("Hits", hits)
        -- shake feedback
        local origPos = stand.Position
        TweenService:Create(stand, TweenInfo.new(0.05), {Position = origPos + Vector3.new(0.2, 0, 0)}):Play()
        task.delay(0.1, function() stand.Position = origPos end)
        if hits >= (stand:GetAttribute("MaxHits") or 3) then
            -- Break: spawn 3 drops + destroy stand
            for i = 1, 3 do
                local angle = (i / 3) * math.pi * 2
                local offset = Vector3.new(math.cos(angle) * 2, 0, math.sin(angle) * 2)
                makeDrop(kind, stand.Position + offset)
            end
            stand:Destroy()
            -- respawn after 60s
            task.delay(60, function() spawnInteractable(kind, position) end)
        end
    end)
    return stand
end

-- ============ NPC Drop Hook ============
-- Listen to Pranked attribute changes — when an NPC's Pranked goes true (death),
-- 2% chance to drop food or water at their position.
local function watchNpcDeaths()
    for _, folderName in ipairs({"PrankNPCs", "AmbientCrowd"}) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            folder.ChildAdded:Connect(function(child)
                if child:IsA("Model") then
                    child:GetAttributeChangedSignal("Pranked"):Connect(function()
                        if child:GetAttribute("Pranked") and math.random() < NPC_DROP_CHANCE then
                            local p = child.PrimaryPart or child:FindFirstChild("HumanoidRootPart")
                            if p then
                                local kind = (math.random() < 0.5) and "food" or "water"
                                makeDrop(kind, p.Position)
                                print("[FoodDropSystem] NPC dropped " .. kind)
                            end
                        end
                    end)
                end
            end)
        end
    end
end
task.spawn(watchNpcDeaths)

-- ============ Spawn initial interactables in plaza ============
task.spawn(function()
    task.wait(10)  -- wait for CityRebuild to place plaza
    -- Spawn 2 hot dog stands + 2 fountains around plaza spawn point
    spawnInteractable("food",  Vector3.new(20, 5, 0))
    spawnInteractable("food",  Vector3.new(-20, 5, 0))
    spawnInteractable("water", Vector3.new(0, 5, 25))
    spawnInteractable("water", Vector3.new(0, 5, -25))
    print("[FoodDropSystem] 4 interactables placed in plaza")
end)

print("[FoodDropSystem v1] online — food/water drops + 2% NPC drops + breakable stands")
