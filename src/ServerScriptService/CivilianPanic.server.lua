-- CivilianPanic.server.lua  v1
-- Makes civilian NPCs run AWAY from the cat when targeted (within radius).
-- Fires per-NPC every 1.5s. NPCs gradually return to wander state when player leaves.
local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local RunService       = game:GetService("RunService")

local PANIC_RADIUS = 18  -- studs
local PANIC_SPEED  = 16
local CALM_SPEED   = 6

local lastTick = 0

RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastTick < 1.5 then return end
    lastTick = now

    -- Collect player positions
    local playerPositions = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character.PrimaryPart then
            table.insert(playerPositions, p.Character.PrimaryPart.Position)
        end
    end
    if #playerPositions == 0 then return end

    -- Per ambient NPC: if any player is within PANIC_RADIUS, run AWAY
    for _, folderName in ipairs({"AmbientCrowd", "PrankNPCs"}) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            for _, npc in ipairs(folder:GetChildren()) do
                if npc:IsA("Model") and not npc:GetAttribute("Pranked") and not npc:GetAttribute("Boss") then
                    local hum = npc:FindFirstChildOfClass("Humanoid")
                    local hrp = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
                    if hum and hrp then
                        -- find nearest player
                        local nearestPos, nearestDist = nil, math.huge
                        for _, pos in ipairs(playerPositions) do
                            local d = (pos - hrp.Position).Magnitude
                            if d < nearestDist then nearestDist = d; nearestPos = pos end
                        end
                        if nearestPos and nearestDist < PANIC_RADIUS then
                            -- run AWAY along the (npc - player) vector
                            local awayDir = (hrp.Position - nearestPos).Unit
                            local target = hrp.Position + awayDir * 18
                            target = Vector3.new(target.X, hrp.Position.Y, target.Z)  -- keep Y
                            hum.WalkSpeed = PANIC_SPEED
                            hum:MoveTo(target)
                            npc:SetAttribute("Panicking", true)
                        elseif npc:GetAttribute("Panicking") then
                            hum.WalkSpeed = CALM_SPEED
                            npc:SetAttribute("Panicking", false)
                        end
                    end
                end
            end
        end
    end
end)

print("[CivilianPanic v1] online — NPCs flee when cat within 18 studs")
