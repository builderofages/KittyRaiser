-- CatLifelike.server.lua — Grok's micro-animations: ear twitch, blink, breathing, tail dynamics
-- Place in: ServerScriptService > CatLifelike (Script). Auto-runs.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local function setupCat(char)
  local hum = char:FindFirstChildOfClass("Humanoid")
  if not hum then return end

  -- Find body parts by name
  local body = char:FindFirstChild("Torso")
  local head = char:FindFirstChild("Head")
  local ears = {}
  for _, c in ipairs(char:GetChildren()) do
    if c:IsA("BasePart") and c.Name == "Ear" then
      table.insert(ears, {part = c, origCFrame = c.CFrame})
    end
  end
  local pupils = {}
  for _, c in ipairs(char:GetChildren()) do
    if c:IsA("BasePart") and c.Name == "Pupil" then
      table.insert(pupils, {part = c, origSize = c.Size})
    end
  end
  local tailSegs = {}
  for i = 1, 5 do
    local seg = char:FindFirstChild("TailSeg" .. i)
    if seg then table.insert(tailSegs, {part = seg, origCFrame = seg.CFrame, idx = i}) end
  end

  -- Idle micro-animation: ear twitch every 8-15 sec
  task.spawn(function()
    while char.Parent do
      task.wait(math.random(8, 15))
      for _, e in ipairs(ears) do
        TweenService:Create(e.part, TweenInfo.new(0.08, Enum.EasingStyle.Quad), {
          CFrame = e.origCFrame * CFrame.Angles(math.rad(math.random(-12, 12)), 0, 0)
        }):Play()
        task.wait(0.1)
        TweenService:Create(e.part, TweenInfo.new(0.15), {CFrame = e.origCFrame}):Play()
      end
    end
  end)

  -- Blink every 4-7 sec
  task.spawn(function()
    while char.Parent do
      task.wait(math.random(4, 7))
      for _, p in ipairs(pupils) do
        local origSize = p.origSize
        TweenService:Create(p.part, TweenInfo.new(0.08), {Size = Vector3.new(origSize.X, 0.05, origSize.Z)}):Play()
        task.wait(0.12)
        TweenService:Create(p.part, TweenInfo.new(0.1), {Size = origSize}):Play()
      end
    end
  end)

  -- Breathing torso scale (subtle)
  if body then
    task.spawn(function()
      local origSize = body.Size
      while char.Parent do
        TweenService:Create(body, TweenInfo.new(2.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
          Size = origSize + Vector3.new(0.05, 0.05, 0)
        }):Play()
        task.wait(2.5)
      end
    end)
  end

  -- Tail dynamic whip — respond to character velocity
  if #tailSegs > 0 then
    local hrp = char.PrimaryPart
    task.spawn(function()
      while char.Parent and hrp do
        local v = hrp.AssemblyLinearVelocity
        local speed = Vector3.new(v.X, 0, v.Z).Magnitude
        for _, seg in ipairs(tailSegs) do
          local sway = math.sin(os.clock() * 4 + seg.idx * 0.5) * (0.1 + speed * 0.005) * seg.idx
          pcall(function()
            seg.part.CFrame = seg.origCFrame * CFrame.Angles(0, sway, 0)
          end)
        end
        task.wait(0.05)
      end
    end)
  end

  print("[CatLifelike] applied to " .. (char.Name or "?"))
end

local function setup(player)
  if player.Character then setupCat(player.Character) end
  player.CharacterAdded:Connect(function(char) task.wait(0.5); setupCat(char) end)
end

Players.PlayerAdded:Connect(setup)
for _, plr in ipairs(Players:GetPlayers()) do setup(plr) end

print("[CatLifelike] ready — ear twitch, blink, breathing, tail dynamics")
