-- CopAggro.server.lua  v1
-- Cop NPCs (those tagged with "Cop" attribute) actively chase the nearest player.
-- Damage HRP -5 HP per touch with 1s cooldown. Plays cop_siren on first lock-on.
local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local RunService       = game:GetService("RunService")
local SoundService     = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(ReplicatedStorage.Modules.AssetIds)

local AGGRO_RADIUS = 60
local CATCH_RADIUS = 4
local DAMAGE_PER_HIT = 5
local DAMAGE_COOLDOWN = 1.0

local lastTick = 0
local lastDamage = {}  -- player.UserId -> last hit time

local function playSirenAt(part)
    if not AssetIds.has("cop_siren") then return end
    local s = Instance.new("Sound")
    s.SoundId = AssetIds.cop_siren
    s.Volume = 0.5
    s.Parent = part
    s:Play()
    game:GetService("Debris"):AddItem(s, 5)
end

RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastTick < 0.5 then return end
    lastTick = now

    -- Find all cop NPCs
    local cops = {}
    for _, folderName in ipairs({"PrankNPCs", "Workspace"}) do
        local folder = (folderName == "Workspace") and Workspace or Workspace:FindFirstChild(folderName)
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("Model") and (child:GetAttribute("Cop") or child.Name == "Cop" or child.Name:find("Cop")) then
                    table.insert(cops, child)
                end
            end
        end
    end
    if #cops == 0 then return end

    for _, cop in ipairs(cops) do
        local hum = cop:FindFirstChildOfClass("Humanoid")
        local hrp = cop.PrimaryPart or cop:FindFirstChild("HumanoidRootPart")
        if hum and hrp then
            -- find nearest player within AGGRO_RADIUS
            local target, targetDist = nil, math.huge
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character and p.Character.PrimaryPart then
                    local d = (p.Character.PrimaryPart.Position - hrp.Position).Magnitude
                    if d < targetDist and d < AGGRO_RADIUS then
                        targetDist = d; target = p
                    end
                end
            end
            if target and target.Character then
                local targetHrp = target.Character.PrimaryPart
                hum.WalkSpeed = 22
                hum:MoveTo(targetHrp.Position)
                if not cop:GetAttribute("Aggrod") then
                    cop:SetAttribute("Aggrod", true)
                    playSirenAt(hrp)
                end
                -- catch range damage
                if targetDist < CATCH_RADIUS then
                    local last = lastDamage[target.UserId] or 0
                    if now - last >= DAMAGE_COOLDOWN then
                        lastDamage[target.UserId] = now
                        local pHum = target.Character:FindFirstChildOfClass("Humanoid")
                        if pHum then pHum:TakeDamage(DAMAGE_PER_HIT) end
                    end
                end
            else
                cop:SetAttribute("Aggrod", false)
            end
        end
    end
end)

print("[CopAggro v1] online — cops chase player within 60 studs, deal 5 dmg/sec on touch")
