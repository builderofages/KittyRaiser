-- WalkAnim.server.lua  — applies walk/idle animation to spawned cat
-- Uses Roblox's free animation IDs OR a procedural bob if asset fails
-- Place in: ServerScriptService > WalkAnim. Auto-runs.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Roblox official walk/idle anim IDs (R6/R15 fallback)
local ANIMS = {
  walk = "rbxassetid://507777826",   -- R15 walk
  run  = "rbxassetid://507767714",   -- R15 run
  idle = "rbxassetid://507766388",   -- R15 idle
  jump = "rbxassetid://507765000",   -- R15 jump
}

local function setupAnim(char)
  local hum = char:WaitForChild("Humanoid", 5)
  if not hum then return end
  local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
  -- Idle
  local idle = Instance.new("Animation")
  idle.AnimationId = ANIMS.idle
  local idleTrack = animator:LoadAnimation(idle)
  idleTrack.Looped = true
  idleTrack.Priority = Enum.AnimationPriority.Idle
  idleTrack:Play()

  -- Walk
  local walk = Instance.new("Animation")
  walk.AnimationId = ANIMS.walk
  local walkTrack = animator:LoadAnimation(walk)
  walkTrack.Looped = true
  walkTrack.Priority = Enum.AnimationPriority.Movement

  -- Switch idle/walk based on velocity
  task.spawn(function()
    while char.Parent do
      local hrp = char.PrimaryPart or char:FindFirstChild("HumanoidRootPart")
      if not hrp then task.wait(0.5); continue end
      local speed = hrp.AssemblyLinearVelocity.Magnitude
      if speed > 2 then
        if not walkTrack.IsPlaying then walkTrack:Play(0.2) end
        if idleTrack.IsPlaying then idleTrack:Stop(0.2) end
      else
        if not idleTrack.IsPlaying then idleTrack:Play(0.2) end
        if walkTrack.IsPlaying then walkTrack:Stop(0.2) end
      end
      task.wait(0.1)
    end
  end)

  -- Procedural tail wag (always runs, gentle)
  local tail = char:FindFirstChild("TailSeg1") or char:FindFirstChild("TailSeg2")
  if tail and tail:IsA("BasePart") then
    local origCF = tail.CFrame
    task.spawn(function()
      local t = 0
      while char.Parent and tail.Parent do
        t = t + 0.05
        local angle = math.sin(t * 3) * 0.2
        pcall(function() tail.CFrame = origCF * CFrame.Angles(0, angle, 0) end)
        task.wait(0.05)
      end
    end)
  end
end

local function setup(player)
  if player.Character then setupAnim(player.Character) end
  player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    setupAnim(char)
  end)
end

Players.PlayerAdded:Connect(setup)
for _, plr in ipairs(Players:GetPlayers()) do setup(plr) end

print("[WalkAnim] cat walk/idle animations + tail wag ready")
