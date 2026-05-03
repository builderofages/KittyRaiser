-- Minimap.client.lua  — top-right minimap with player dot + nearby NPC dots
-- Place in: StarterPlayer > StarterPlayerScripts > Minimap (LocalScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SIZE = 180
local SCALE = 0.18  -- world studs to pixels

local mm = Instance.new("ScreenGui")
mm.Name = "Minimap"
mm.IgnoreGuiInset = true  -- keep minimap in safe zone (avoid notch overlap)
mm.ResetOnSpawn = false
mm.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, SIZE, 0, SIZE)
frame.Position = UDim2.new(1, -SIZE - 16, 0, 100)
frame.BackgroundColor3 = Color3.fromRGB(15, 5, 30)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Parent = mm
Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)
local stroke = Instance.new("UIStroke", frame)
stroke.Thickness = 3
stroke.Color = Color3.fromRGB(255, 100, 200)

-- Title above
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 18)
title.Position = UDim2.new(0, 0, 0, -22)
title.BackgroundTransparency = 1
title.Text = "MAP"
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(255, 100, 200)
title.Parent = frame

-- Player dot in center
local self_dot = Instance.new("Frame")
self_dot.Size = UDim2.new(0, 8, 0, 8)
self_dot.Position = UDim2.new(0.5, -4, 0.5, -4)
self_dot.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
self_dot.BorderSizePixel = 0
self_dot.Parent = frame
Instance.new("UICorner", self_dot).CornerRadius = UDim.new(1, 0)

local function getOriginPos()
  local char = player.Character
  if char and char.PrimaryPart then return char.PrimaryPart.Position end
  return Vector3.new(0, 0, 0)
end

-- Update entity dots every 0.5s
local entityDots = {}
task.spawn(function()
  while mm.Parent do
    local origin = getOriginPos()
    -- Track NPCs + other players
    local entities = {}
    -- Other players
    for _, p in ipairs(Players:GetPlayers()) do
      if p ~= player and p.Character and p.Character.PrimaryPart then
        table.insert(entities, {pos = p.Character.PrimaryPart.Position, color = Color3.fromRGB(80, 220, 255), name = p.Name})
      end
    end
    -- Nearby NPCs (AmbientCrowd)
    local crowd = Workspace:FindFirstChild("AmbientCrowd")
    if crowd then
      for _, npc in ipairs(crowd:GetChildren()) do
        if npc:IsA("Model") and npc.PrimaryPart then
          local d = (npc.PrimaryPart.Position - origin).Magnitude
          if d < 200 then
            table.insert(entities, {pos = npc.PrimaryPart.Position, color = Color3.fromRGB(80, 200, 90), small = true})
          end
        end
      end
    end
    -- PrankNPCs (summoned)
    local pnpcs = Workspace:FindFirstChild("PrankNPCs")
    if pnpcs then
      for _, npc in ipairs(pnpcs:GetChildren()) do
        if npc:IsA("Model") and npc.PrimaryPart then
          table.insert(entities, {pos = npc.PrimaryPart.Position, color = Color3.fromRGB(255, 80, 80), small = true})
        end
      end
    end
    -- Reuse / create dots
    for i, ent in ipairs(entities) do
      local dot = entityDots[i]
      if not dot then
        dot = Instance.new("Frame")
        dot.BorderSizePixel = 0
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
        dot.Parent = frame
        entityDots[i] = dot
      end
      local relX = (ent.pos.X - origin.X) * SCALE
      local relZ = (ent.pos.Z - origin.Z) * SCALE
      dot.Visible = (math.abs(relX) < SIZE/2 and math.abs(relZ) < SIZE/2)
      local sz = ent.small and 5 or 7
      dot.Size = UDim2.new(0, sz, 0, sz)
      dot.Position = UDim2.new(0.5, relX - sz/2, 0.5, relZ - sz/2)
      dot.BackgroundColor3 = ent.color
    end
    -- Hide unused
    for i = #entities + 1, #entityDots do
      if entityDots[i] then entityDots[i].Visible = false end
    end
    task.wait(0.5)
  end
end)

print("[Minimap] top-right minimap rendering player + NPC dots")
