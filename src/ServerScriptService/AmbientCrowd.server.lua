-- AmbientCrowd.server.lua v3 — Grok-tuned single-manager, 12-15 visible NPCs, distance-based
-- Place in: ServerScriptService > AmbientCrowd. Auto-runs.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TARGET_VISIBLE = 14   -- Grok said 12-15
local NEAR_RADIUS = 80
local FAR_RADIUS = 200
local DESPAWN_RADIUS = 350
local TICK_INTERVAL = 4

local crowdFolder = Workspace:FindFirstChild("AmbientCrowd")
if not crowdFolder then
  crowdFolder = Instance.new("Folder")
  crowdFolder.Name = "AmbientCrowd"
  crowdFolder.Parent = Workspace
end

local SHIRT = {Color3.fromRGB(200,50,50),Color3.fromRGB(60,130,200),Color3.fromRGB(80,200,90),Color3.fromRGB(220,200,80),Color3.fromRGB(180,80,200),Color3.fromRGB(60,60,80),Color3.fromRGB(240,240,240),Color3.fromRGB(220,130,60),Color3.fromRGB(255,80,130),Color3.fromRGB(50,50,50)}
local SKIN = {Color3.fromRGB(245,205,160),Color3.fromRGB(200,165,130),Color3.fromRGB(160,110,80),Color3.fromRGB(120,80,55),Color3.fromRGB(95,65,45),Color3.fromRGB(80,50,35)}
local LEG = {Color3.fromRGB(40,40,80),Color3.fromRGB(80,50,30),Color3.fromRGB(50,50,50),Color3.fromRGB(100,100,110),Color3.fromRGB(60,80,50)}

local SKIN_PARTS = { Head=true, LeftHand=true, RightHand=true, LeftFoot=true, RightFoot=true }
local SHIRT_PARTS = { UpperTorso=true, LowerTorso=true, Torso=true,
                       LeftUpperArm=true, LeftLowerArm=true,
                       RightUpperArm=true, RightLowerArm=true,
                       ["Left Arm"]=true, ["Right Arm"]=true }
local PANTS_PARTS = { LeftUpperLeg=true, LeftLowerLeg=true,
                       RightUpperLeg=true, RightLowerLeg=true,
                       ["Left Leg"]=true, ["Right Leg"]=true }

local function tintPed(model, shirtColor, skinColor, legColor)
  for _, p in ipairs(model:GetDescendants()) do
    if p:IsA("BasePart") then
      if SKIN_PARTS[p.Name] then
        p.Color = skinColor; p.Material = Enum.Material.SmoothPlastic
      elseif SHIRT_PARTS[p.Name] then
        p.Color = shirtColor; p.Material = Enum.Material.SmoothPlastic
      elseif PANTS_PARTS[p.Name] then
        p.Color = legColor; p.Material = Enum.Material.SmoothPlastic
      end
    end
  end
end

local function buildPed()
  -- Try to spawn a real Roblox R15 character (proper rig + animations + face)
  local ok, m = pcall(function()
    local desc = Instance.new("HumanoidDescription")
    return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
  end)

  if not ok or not m then
    -- Fallback: clean welded rig (better than a single legs-block)
    m = Instance.new("Model")
    local size = 1.0
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2*size, 2*size, 1*size)
    hrp.Transparency = 1; hrp.CanCollide = false
    hrp.Parent = m
    local torso = Instance.new("Part")
    torso.Name = "Torso"; torso.Size = Vector3.new(2*size, 2*size, 1*size)
    torso.Color = SHIRT[math.random(1, #SHIRT)]; torso.Material = Enum.Material.SmoothPlastic
    torso.Position = hrp.Position; torso.Parent = m
    local tw = Instance.new("WeldConstraint"); tw.Part0 = hrp; tw.Part1 = torso; tw.Parent = torso
    local head = Instance.new("Part")
    head.Name = "Head"; head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(1.5*size, 1.5*size, 1.5*size)
    head.Color = SKIN[math.random(1, #SKIN)]; head.Material = Enum.Material.SmoothPlastic
    head.Position = torso.Position + Vector3.new(0, 1.75*size, 0); head.Parent = m
    local hw = Instance.new("WeldConstraint"); hw.Part0 = torso; hw.Part1 = head; hw.Parent = head
    local face = Instance.new("Decal"); face.Texture = "rbxasset://textures/face.png"
    face.Face = Enum.NormalId.Front; face.Parent = head
    local hum = Instance.new("Humanoid"); hum.Parent = m
    m.PrimaryPart = hrp
  end

  m.Name = "Pedestrian"
  m:SetAttribute("KittyRaiserNPC", true)
  m:SetAttribute("Pranked", false)
  m:SetAttribute("AmbientNPC", true)
  m:SetAttribute("LastWanderTime", os.clock())

  -- Strip clothing/accessories so the tint shows
  for _, c in ipairs(m:GetChildren()) do
    if c:IsA("Shirt") or c:IsA("Pants") or c:IsA("ShirtGraphic") or c:IsA("Accessory") then
      c:Destroy()
    end
  end

  local shirtColor = SHIRT[math.random(1, #SHIRT)]
  local skinColor  = SKIN[math.random(1, #SKIN)]
  local legColor   = LEG[math.random(1, #LEG)]
  pcall(tintPed, m, shirtColor, skinColor, legColor)

  local hum = m:FindFirstChildOfClass("Humanoid")
  if hum then
    hum.WalkSpeed = math.random(8, 14)
    hum.MaxHealth = 100; hum.Health = 100
    hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
  end

  return m
end

local function spawnNearPlayer(player)
  local char = player.Character
  if not char or not char.PrimaryPart then return nil end
  local origin = char.PrimaryPart.Position
  local angle = math.random() * math.pi * 2
  local r = math.random(NEAR_RADIUS, FAR_RADIUS)
  local pos = origin + Vector3.new(math.cos(angle) * r, 5, math.sin(angle) * r)
  local npc = buildPed()
  npc:PivotTo(CFrame.new(pos))
  npc.Parent = crowdFolder
  return npc
end

-- SINGLE MANAGER COROUTINE (Grok said: don't per-NPC spawn)
task.spawn(function()
  while true do
    task.wait(TICK_INTERVAL)
    -- Tick all NPCs
    local npcs = {}
    for _, c in ipairs(crowdFolder:GetChildren()) do
      if c:IsA("Model") and c:GetAttribute("AmbientNPC") and not c:GetAttribute("Pranked") then
        table.insert(npcs, c)
      end
    end
    -- Despawn those too far from any player
    for _, npc in ipairs(npcs) do
      local hrp = npc.PrimaryPart
      if hrp then
        local closest = math.huge
        for _, p in ipairs(Players:GetPlayers()) do
          if p.Character and p.Character.PrimaryPart then
            local d = (p.Character.PrimaryPart.Position - hrp.Position).Magnitude
            if d < closest then closest = d end
          end
        end
        if closest > DESPAWN_RADIUS then
          npc:Destroy()
        else
          -- Wander
          local hum = npc:FindFirstChildOfClass("Humanoid")
          if hum then
            local d = Vector3.new(math.random(-20, 20), 0, math.random(-20, 20))
            hum:MoveTo(hrp.Position + d)
          end
        end
      end
    end
    -- Top up
    local count = 0
    for _, c in ipairs(crowdFolder:GetChildren()) do
      if c:GetAttribute("AmbientNPC") and not c:GetAttribute("Pranked") then count = count + 1 end
    end
    local need = TARGET_VISIBLE - count
    if need > 0 then
      for _, p in ipairs(Players:GetPlayers()) do
        if need <= 0 then break end
        spawnNearPlayer(p)
        need = need - 1
      end
    end
  end
end)

print("[AmbientCrowd v3] single-manager mode, target " .. TARGET_VISIBLE .. " NPCs visible")
