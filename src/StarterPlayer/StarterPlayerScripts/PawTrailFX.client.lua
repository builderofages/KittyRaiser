-- PawTrailFX.client.lua
-- Spawns a small footstep particle on the ground every ~0.3s while the local
-- character is moving. Cheap; runs only locally.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer

local SPACING_STUDS = 4
local lastFootprint = nil
local lastSide = 1

local function tryFootprint(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char.PrimaryPart
    if not hum or not hrp then return end
    if hum.MoveDirection.Magnitude < 0.1 then return end

    if lastFootprint and (hrp.Position - lastFootprint).Magnitude < SPACING_STUDS then
        return
    end
    lastFootprint = hrp.Position

    local print_ = Instance.new("Part")
    print_.Anchored = true
    print_.CanCollide = false
    print_.Size = Vector3.new(0.4, 0.05, 0.6)
    print_.Material = Enum.Material.SmoothPlastic
    print_.Color = Color3.fromRGB(255, 100, 200)
    print_.Transparency = 0.4
    -- Side-to-side offset to alternate left/right paws
    local side = lastSide; lastSide = -side
    local rightVec = hrp.CFrame.RightVector * (0.7 * side)
    local downVec = Vector3.new(0, -2.7, 0)
    print_.CFrame = CFrame.new(hrp.Position + rightVec + downVec) * CFrame.Angles(0, hrp.Orientation.Y * math.pi / 180, 0)
    print_.Parent = Workspace
    Debris:AddItem(print_, 1.5)
    -- fade-out via heartbeat (cheap)
    local t0 = os.clock()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not print_.Parent then conn:Disconnect(); return end
        local age = os.clock() - t0
        print_.Transparency = 0.4 + math.min(0.6, age * 0.6)
        if age > 1.4 then conn:Disconnect() end
    end)
end

RunService.Heartbeat:Connect(function()
    local char = player.Character
    if char then tryFootprint(char) end
end)
