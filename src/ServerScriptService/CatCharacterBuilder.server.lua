-- CatCharacterBuilder.server.lua  v4 — uses Grok's recommended Toolbox cat rig
-- Loads asset 5896683998 ("rigged cartoon cat R15") into ServerStorage.CatTemplates,
-- clones it for each player on spawn, applies fur color tint.
-- Falls back to primitive-built cat if asset load fails.
-- Place in: ServerScriptService > CatCharacterBuilder. Auto-runs.

local Players       = game:GetService("Players")
local Workspace     = game:GetService("Workspace")
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- CRITICAL: disable auto character spawn at script load (before any player joins)
Players.CharacterAutoLoads = false

local AssetIds
do
  local mods = ReplicatedStorage:FindFirstChild("Modules")
  local m = mods and mods:FindFirstChild("AssetIds")
  if m then
    local ok, mod = pcall(require, m)
    if ok then AssetIds = mod end
  end
  if not AssetIds then
    AssetIds = setmetatable({}, {__index = function() return "rbxassetid://0" end})
    AssetIds.has = function() return false end
  end
end

local CAT_RIG_ID = 5896683998  -- Grok's recommended cartoon cat rig
local FUR_COLORS = {
  Color3.fromRGB(220, 130, 50),  -- orange tabby
  Color3.fromRGB(80, 60, 50),    -- brown
  Color3.fromRGB(40, 40, 40),    -- black
  Color3.fromRGB(220, 220, 215), -- white
  Color3.fromRGB(140, 130, 120), -- grey tabby
  Color3.fromRGB(255, 200, 180), -- cream
}

-- Load the cat template once into ServerStorage
local catTemplatesFolder = ServerStorage:FindFirstChild("CatTemplates") or Instance.new("Folder", ServerStorage)
catTemplatesFolder.Name = "CatTemplates"

local CAT_TEMPLATE
local templateLoaded = false

local function tryLoadToolboxCat()
  local ok, model = pcall(function() return InsertService:LoadAsset(CAT_RIG_ID) end)
  if ok and model then
    -- Find the actual rig model (could be wrapped)
    local rig
    for _, child in ipairs(model:GetDescendants()) do
      if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
        rig = child
        break
      end
    end
    if rig then
      rig.Name = "ToolboxCatTemplate"
      rig.Parent = catTemplatesFolder
      CAT_TEMPLATE = rig
      templateLoaded = true
      print("[CatCharacterBuilder v4] Toolbox cat rig loaded successfully")
    else
      warn("[CatCharacterBuilder v4] no Humanoid model in asset " .. CAT_RIG_ID)
    end
    if model.Parent then model:Destroy() end
  else
    warn("[CatCharacterBuilder v4] LoadAsset failed: " .. tostring(model))
  end
end

task.spawn(tryLoadToolboxCat)

-- Build a primitive cat fallback (welded Parts in cat shape)
local function buildPrimitiveCat(color)
  local model = Instance.new("Model")

  local hrp = Instance.new("Part")
  hrp.Name = "HumanoidRootPart"
  hrp.Size = Vector3.new(2, 1, 4)
  hrp.Transparency = 1; hrp.CanCollide = false; hrp.Massless = true
  hrp.Parent = model

  local body = Instance.new("Part")
  body.Name = "Torso"
  body.Size = Vector3.new(3, 2.5, 4.5)
  body.Color = color
  body.Material = Enum.Material.SmoothPlastic
  body.CFrame = hrp.CFrame
  body.Parent = model
  if AssetIds.has("fur_orange") then
    for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Front, Enum.NormalId.Back}) do
      local d = Instance.new("Decal", body)
      d.Face = face; d.Texture = AssetIds.fur_orange
    end
  end

  local head = Instance.new("Part")
  head.Name = "Head"
  head.Shape = Enum.PartType.Ball
  head.Size = Vector3.new(2.2, 2.2, 2.2)
  head.Color = color
  head.Material = Enum.Material.SmoothPlastic
  head.CanCollide = false; head.Massless = true
  head.CFrame = hrp.CFrame * CFrame.new(0, 0.4, -2.6)
  head.Parent = model

  for _, off in ipairs({Vector3.new(-0.5, 0.3, -0.85), Vector3.new(0.5, 0.3, -0.85)}) do
    local eye = Instance.new("Part")
    eye.Shape = Enum.PartType.Ball
    eye.Size = Vector3.new(0.45, 0.45, 0.45)
    eye.Color = Color3.fromRGB(255, 255, 255)
    eye.Material = Enum.Material.Neon
    eye.CanCollide = false; eye.Massless = true
    eye.CFrame = head.CFrame * CFrame.new(off)
    eye.Parent = model
    local w = Instance.new("WeldConstraint"); w.Part0 = head; w.Part1 = eye; w.Parent = head
    local pupil = Instance.new("Part")
    pupil.Shape = Enum.PartType.Ball
    pupil.Size = Vector3.new(0.25, 0.4, 0.25)
    pupil.Color = Color3.fromRGB(50, 220, 100)
    pupil.Material = Enum.Material.Neon
    pupil.CanCollide = false; pupil.Massless = true
    pupil.CFrame = eye.CFrame * CFrame.new(0, 0, -0.15)
    pupil.Parent = model
    local w2 = Instance.new("WeldConstraint"); w2.Part0 = eye; w2.Part1 = pupil; w2.Parent = eye
  end

  for _, off in ipairs({Vector3.new(-0.7, 1.0, 0), Vector3.new(0.7, 1.0, 0)}) do
    local ear = Instance.new("Part")
    ear.Size = Vector3.new(0.6, 0.9, 0.5)
    ear.Color = color
    ear.Material = Enum.Material.SmoothPlastic
    ear.CanCollide = false; ear.Massless = true
    ear.CFrame = head.CFrame * CFrame.new(off) * CFrame.Angles(math.rad(-15), 0, 0)
    ear.Parent = model
    local w = Instance.new("WeldConstraint"); w.Part0 = head; w.Part1 = ear; w.Parent = head
  end

  for _, lp in ipairs({
    {off=Vector3.new(-0.8, -1.2, -1.6)},
    {off=Vector3.new( 0.8, -1.2, -1.6)},
    {off=Vector3.new(-0.8, -1.2,  1.5)},
    {off=Vector3.new( 0.8, -1.2,  1.5)},
  }) do
    local leg = Instance.new("Part")
    leg.Size = Vector3.new(0.6, 1.5, 0.6)
    leg.Color = color
    leg.Material = Enum.Material.SmoothPlastic
    leg.CanCollide = false; leg.Massless = true
    leg.CFrame = hrp.CFrame * CFrame.new(lp.off)
    leg.Parent = model
    local w = Instance.new("WeldConstraint"); w.Part0 = body; w.Part1 = leg; w.Parent = body
  end

  for i = 1, 5 do
    local seg = Instance.new("Part")
    seg.Size = Vector3.new(0.5 - i*0.06, 0.5 - i*0.06, 0.7)
    seg.Color = color
    seg.Material = Enum.Material.SmoothPlastic
    seg.CanCollide = false; seg.Massless = true
    local angle = math.rad(20 + i*5)
    seg.CFrame = body.CFrame * CFrame.new(0, 0.3 + i*0.25, 1.9 + i*0.55) * CFrame.Angles(angle, 0, 0)
    seg.Parent = model
    local w = Instance.new("WeldConstraint"); w.Part0 = body; w.Part1 = seg; w.Parent = body
  end

  local hw = Instance.new("WeldConstraint"); hw.Part0 = hrp; hw.Part1 = head; hw.Parent = hrp
  local bw = Instance.new("WeldConstraint"); bw.Part0 = hrp; bw.Part1 = body; bw.Parent = hrp

  local hum = Instance.new("Humanoid")
  hum.RigType = Enum.HumanoidRigType.R6
  hum.WalkSpeed = 16; hum.JumpPower = 50
  hum.Health = 100; hum.MaxHealth = 100
  hum.HipHeight = 0
  hum.Parent = model

  model.PrimaryPart = hrp
  return model
end

local function tintToolboxCat(rig, color)
  for _, p in ipairs(rig:GetDescendants()) do
    if p:IsA("BasePart") and p.Name ~= "Head" then
      p.Color = color
    elseif p:IsA("MeshPart") then
      p.Color = color
    end
  end
end

local function spawnCat(player)
  local fc = player:GetAttribute("FurColor")
  local color
  if fc and type(fc) == "table" then
    color = Color3.fromRGB(fc[1] or 220, fc[2] or 130, fc[3] or 50)
  else
    color = FUR_COLORS[math.random(1, #FUR_COLORS)]
    player:SetAttribute("FurColor", {math.floor(color.R*255), math.floor(color.G*255), math.floor(color.B*255)})
  end

  local sp = Workspace:FindFirstChild("MainSpawn") or Workspace:FindFirstChildOfClass("SpawnLocation")
  local cf = sp and (sp.CFrame * CFrame.new(0, 5, 0)) or CFrame.new(0, 8, 0)

  if player.Character then player.Character:Destroy() end

  local cat
  if templateLoaded and CAT_TEMPLATE then
    cat = CAT_TEMPLATE:Clone()
    cat.Name = player.Name
    tintToolboxCat(cat, color)
    cat:PivotTo(cf)
  else
    cat = buildPrimitiveCat(color)
    cat.Name = player.Name
    cat:PivotTo(cf)
  end
  cat.Parent = Workspace
  player.Character = cat

  -- Floating name
  local head = cat:FindFirstChild("Head")
  if head and head:IsA("BasePart") then
    local g = Instance.new("BillboardGui")
    g.Size = UDim2.new(0, 200, 0, 50)
    g.StudsOffset = Vector3.new(0, 3, 0)
    g.AlwaysOnTop = true
    g.Parent = head
    local l = Instance.new("TextLabel")
    l.Size = UDim2.fromScale(1, 1)
    l.BackgroundTransparency = 1
    l.Text = player.DisplayName
    l.Font = Enum.Font.GothamBlack
    l.TextScaled = true
    l.TextColor3 = Color3.fromRGB(255, 255, 255)
    l.TextStrokeTransparency = 0
    l.TextStrokeColor3 = Color3.new(0, 0, 0)
    l.Parent = g
  end
end

local function setup(player)
  -- Wait a sec for Toolbox load to complete on first spawn
  task.spawn(function()
    task.wait(2.5)
    spawnCat(player)
  end)
  player.CharacterRemoving:Connect(function()
    task.wait(2)
    if player.Parent then spawnCat(player) end
  end)
end

Players.PlayerAdded:Connect(setup)
for _, plr in ipairs(Players:GetPlayers()) do setup(plr) end

print("[CatCharacterBuilder v4] CharacterAutoLoads OFF, Toolbox cat rig pending load")
