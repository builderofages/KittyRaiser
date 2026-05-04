-- CopSystem.server.lua
-- After a player commits enough pranks in quick succession, a cop NPC spawns
-- and pursues them. If the cop catches the player (within 6 studs for 2s),
-- the player gets a "ticket": a small chaos penalty + brief stun + the cop
-- despawns. Cops are visually distinct (blue uniform, white hat, badge).
--
-- Place in: ServerScriptService > CopSystem (Script). Auto-runs.

local Players       = game:GetService("Players")
local Workspace     = game:GetService("Workspace")
local RunService    = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes     = require(ReplicatedStorage.Modules.RemoteEvents)
local AssetIds    = require(ReplicatedStorage.Modules.AssetIds)
local AudioGroups = require(ReplicatedStorage.Modules:WaitForChild("AudioGroups"))

local function waitForGlobal(name)
    while not _G[name] do task.wait() end
    return _G[name]
end
local DataHandler = waitForGlobal("KittyRaiserData")

-- Helper: attach a looping siren to the cop's head with proper rolloff
local function attachSiren(cop)
    if not AssetIds.has("cop_siren") then return end
    local head = cop:FindFirstChild("Head")
    if not head then return end
    local s = Instance.new("Sound")
    s.Name = "CopSiren"
    s.SoundId = AssetIds.cop_siren
    s.Looped = true
    s.Volume = 0.8
    s.RollOffMode = Enum.RollOffMode.Linear
    s.RollOffMaxDistance = 120
    s.RollOffMinDistance = 5
    AudioGroups.assign(s, "SFX")
    s.Parent = head
    s:Play()
end

-- Helper: short ticket buzz when a player gets caught
local function playTicketBuzz(target)
    if not AssetIds.has("ticket_buzz") then return end
    local s = Instance.new("Sound")
    s.SoundId = AssetIds.ticket_buzz
    s.Volume = 0.9
    AudioGroups.assign(s, "UI")
    s.Parent = target.Character and target.Character:FindFirstChild("Head")
    if s.Parent then s:Play() end
    game:GetService("Debris"):AddItem(s, 4)
end

local copsFolder = Workspace:FindFirstChild("Cops") or Instance.new("Folder", Workspace)
copsFolder.Name = "Cops"

-- =====================================================================
-- HEAT — per player, decays over time
-- =====================================================================
local heat = {}     -- userId -> number 0..100
local activeCops = {}  -- userId -> Model

local HEAT_PER_PRANK   = 18
local HEAT_DECAY_PER_S = 1.5
local SPAWN_THRESHOLD  = 60
local CATCH_RADIUS     = 6
local CATCH_DURATION   = 2
local TICKET_PENALTY   = 100  -- chaos lost when caught

-- =====================================================================
-- BUILD COP MODEL — proper R15 rig + cartoon proportions + uniform tint
-- =====================================================================
local function tintCop(model)
    local UNIFORM = Color3.fromRGB(40, 60, 130)   -- navy blue
    local PANTS   = Color3.fromRGB(30, 40, 80)
    local SKIN    = Color3.fromRGB(245, 205, 160)
    local SKIN_PARTS  = { Head=true, LeftHand=true, RightHand=true, LeftFoot=true, RightFoot=true }
    local SHIRT_PARTS = { UpperTorso=true, LowerTorso=true, Torso=true,
                          LeftUpperArm=true, LeftLowerArm=true,
                          RightUpperArm=true, RightLowerArm=true }
    local PANTS_PARTS = { LeftUpperLeg=true, LeftLowerLeg=true,
                          RightUpperLeg=true, RightLowerLeg=true }
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then
            if SKIN_PARTS[p.Name]    then p.Color = SKIN;    p.Material = Enum.Material.SmoothPlastic
            elseif SHIRT_PARTS[p.Name] then p.Color = UNIFORM; p.Material = Enum.Material.SmoothPlastic
            elseif PANTS_PARTS[p.Name] then p.Color = PANTS;   p.Material = Enum.Material.SmoothPlastic
            end
        end
    end
end

local function attachHat(head)
    if not head then return end
    -- Police hat: dark navy cylinder + white top + small badge
    local hat = Instance.new("Part")
    hat.Name = "PoliceHat"
    hat.Shape = Enum.PartType.Cylinder
    hat.Size = Vector3.new(0.4, 1.6, 1.6)
    hat.Color = Color3.fromRGB(28, 38, 80)
    hat.Material = Enum.Material.SmoothPlastic
    hat.CanCollide = false; hat.Massless = true
    hat.CFrame = head.CFrame * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90))
    hat.Parent = head
    local w = Instance.new("WeldConstraint", hat)
    w.Part0 = head; w.Part1 = hat
    -- White top
    local top = Instance.new("Part")
    top.Shape = Enum.PartType.Ball
    top.Size = Vector3.new(1.5, 1.5, 1.5)
    top.Color = Color3.fromRGB(245, 245, 245)
    top.Material = Enum.Material.SmoothPlastic
    top.CanCollide = false; top.Massless = true
    top.CFrame = head.CFrame * CFrame.new(0, 0.95, 0)
    top.Parent = head
    local tw = Instance.new("WeldConstraint", top); tw.Part0 = head; tw.Part1 = top
end

local function attachBadge(torso)
    if not torso then return end
    local badge = Instance.new("Part")
    badge.Name = "Badge"
    badge.Size = Vector3.new(0.5, 0.5, 0.1)
    badge.Color = Color3.fromRGB(255, 215, 80)
    badge.Material = Enum.Material.Metal
    badge.Reflectance = 0.2
    badge.CanCollide = false; badge.Massless = true
    badge.CFrame = torso.CFrame * CFrame.new(0.4, 0.3, -0.6)
    badge.Parent = torso
    local w = Instance.new("WeldConstraint", badge); w.Part0 = torso; w.Part1 = badge
end

local function alertBubble(npc, text, color)
    local head = npc:FindFirstChild("Head")
    if not head then return end
    local g = Instance.new("BillboardGui")
    g.Size = UDim2.new(0, 130, 0, 32)
    g.StudsOffset = Vector3.new(0, 2.4, 0)
    g.AlwaysOnTop = true
    g.Parent = head
    local lbl = Instance.new("TextLabel", g)
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundColor3 = Color3.fromRGB(40, 25, 15)
    lbl.BackgroundTransparency = 0.15
    lbl.Text = text
    lbl.TextColor3 = color or Color3.fromRGB(255, 220, 80)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    lbl.TextStrokeTransparency = 0.4
    lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 8)
    local c = Instance.new("UITextSizeConstraint", lbl); c.MinTextSize = 12; c.MaxTextSize = 20
    task.delay(2.5, function() g:Destroy() end)
end

local function spawnCop(targetPlayer)
    if activeCops[targetPlayer.UserId] and activeCops[targetPlayer.UserId].Parent then return end
    local char = targetPlayer.Character
    if not char or not char.PrimaryPart then return end

    local ok, model = pcall(function()
        local desc = Instance.new("HumanoidDescription")
        return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
    end)
    if not ok or not model then return end

    model.Name = "Cop"
    model:SetAttribute("KittyRaiserNPC", true)
    model:SetAttribute("Cop", true)
    model:SetAttribute("ChasingUserId", targetPlayer.UserId)

    -- Strip default clothes/accessories
    for _, c in ipairs(model:GetChildren()) do
        if c:IsA("Shirt") or c:IsA("Pants") or c:IsA("ShirtGraphic") or c:IsA("Accessory") then
            c:Destroy()
        end
    end

    -- Cartoon proportions
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = 18  -- slightly faster than civilians
        hum.MaxHealth = 200; hum.Health = 200
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        for sname, sval in pairs({
            BodyDepthScale=0.95, BodyWidthScale=1.20, BodyHeightScale=0.85,
            HeadScale=1.40, BodyTypeScale=0.0, ProportionScale=0.10,
        }) do
            local nv = hum:FindFirstChild(sname)
            if nv and nv:IsA("NumberValue") then nv.Value = sval end
        end
    end

    pcall(tintCop, model)
    pcall(attachHat, model:FindFirstChild("Head"))
    pcall(attachBadge, model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso"))
    pcall(attachSiren, model)

    -- Optional parked cop car beside the cop, ONLY if the mesh has been
    -- uploaded (AssetIds.mesh_cop_car != 0). Falls back to no car.
    if AssetIds.has("mesh_cop_car") and _G.KittyRaiserMeshes
       and _G.KittyRaiserMeshes.mesh_cop_car
       and _G.KittyRaiserMeshes.mesh_cop_car.meshTemplate then
        local car = _G.KittyRaiserMeshes.mesh_cop_car.meshTemplate:Clone()
        car.Anchored = true; car.CanCollide = true
        car.Size = Vector3.new(4, 2.5, 8)
        car.Material = Enum.Material.SmoothPlastic
        car.Color = Color3.fromRGB(245, 245, 245)
        local copPos = model.PrimaryPart and model.PrimaryPart.Position or origin + offset
        car:PivotTo(CFrame.new(copPos + Vector3.new(6, 0, 0)) * CFrame.Angles(0, math.rad(90), 0))
        car.Parent = model
    end

    -- Spawn behind / near player but offset
    local origin = char.PrimaryPart.Position
    local offset = Vector3.new(math.random(-30, 30), 6, math.random(-30, 30))
    if offset.Magnitude < 18 then offset = offset.Unit * 22 end
    model:PivotTo(CFrame.new(origin + offset))
    model.Parent = copsFolder

    alertBubble(model, "STOP RIGHT THERE!")

    activeCops[targetPlayer.UserId] = model

    -- Chase loop
    task.spawn(function()
        local closeStart = nil
        local lastMoveTime = 0
        while model.Parent do
            local target = Players:GetPlayerByUserId(targetPlayer.UserId)
            if not target then break end
            local tchar = target.Character
            local thrp  = tchar and tchar.PrimaryPart
            local mhrp  = model.PrimaryPart
            local mhum  = model:FindFirstChildOfClass("Humanoid")
            if not (thrp and mhrp and mhum) then break end
            -- Re-issue MoveTo periodically
            if os.clock() - lastMoveTime > 0.5 then
                mhum:MoveTo(thrp.Position)
                lastMoveTime = os.clock()
            end
            local d = (mhrp.Position - thrp.Position).Magnitude
            if d < CATCH_RADIUS then
                if not closeStart then closeStart = os.clock() end
                if os.clock() - closeStart >= CATCH_DURATION then
                    -- TICKET
                    DataHandler.modify(target, function(dd)
                        dd.chaosPoints = math.max(0, (dd.chaosPoints or 0) - TICKET_PENALTY)
                    end)
                    Remotes.NotifyClient:FireClient(target, "TICKETED  -  -" .. TICKET_PENALTY .. " CHAOS", "warn")
                    pcall(playTicketBuzz, target)
                    -- Tag so LifecycleSystem skips respawn-at-last (player goes to spawn instead)
                    target:SetAttribute("RecentlyTicketed", true)
                    task.delay(8, function() target:SetAttribute("RecentlyTicketed", false) end)
                    -- Brief stun: drop walk speed
                    if tchar then
                        local thum = tchar:FindFirstChildOfClass("Humanoid")
                        if thum then
                            local prev = thum.WalkSpeed
                            thum.WalkSpeed = 6
                            task.delay(2, function() if thum.Parent then thum.WalkSpeed = prev end end)
                        end
                    end
                    alertBubble(model, "TICKETED!", Color3.fromRGB(255, 180, 80))
                    heat[target.UserId] = 0
                    task.wait(1)
                    model:Destroy()
                    return
                end
            else
                closeStart = nil
            end
            -- Give up after 25s of chasing or if too far
            if d > 400 then break end
            task.wait(0.2)
        end
        if model.Parent then model:Destroy() end
        activeCops[targetPlayer.UserId] = nil
    end)
end

-- =====================================================================
-- HEAT TRACKING
-- =====================================================================
_G.KittyRaiserAddHeat = function(player)
    if not player then return end
    heat[player.UserId] = (heat[player.UserId] or 0) + HEAT_PER_PRANK
    if heat[player.UserId] >= SPAWN_THRESHOLD and not activeCops[player.UserId] then
        task.spawn(function()
            spawnCop(player)
            heat[player.UserId] = SPAWN_THRESHOLD * 0.4  -- partial reset
        end)
    end
end

-- Decay
task.spawn(function()
    while true do
        task.wait(1)
        for uid, v in pairs(heat) do
            heat[uid] = math.max(0, v - HEAT_DECAY_PER_S)
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    heat[p.UserId] = nil
    local cop = activeCops[p.UserId]
    if cop then cop:Destroy() end
    activeCops[p.UserId] = nil
end)

print("[CopSystem v1] online — pranks build heat; at threshold a cop chases you")
