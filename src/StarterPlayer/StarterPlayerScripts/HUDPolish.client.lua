-- HUDPolish.client.lua — adds UIGradient + UIStroke to all HUD frames per Grok's spec
-- Place in: StarterPlayer > StarterPlayerScripts > HUDPolish (LocalScript). Auto-runs.

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function polish(frame)
  if (frame:IsA("Frame") or frame:IsA("TextButton") or frame:IsA("ImageButton")) then
    if not frame:FindFirstChildOfClass("UIGradient") then
      local g = Instance.new("UIGradient")
      g.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 40, 180)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 20, 100)),
      }
      g.Rotation = 90
      g.Transparency = NumberSequence.new(0.5)
      g.Parent = frame
    end
    if not frame:FindFirstChildOfClass("UIStroke") then
      local s = Instance.new("UIStroke")
      s.Thickness = 2
      s.Color = Color3.fromRGB(255, 100, 200)
      s.Transparency = 0.2
      s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
      s.Parent = frame
    end
  end
end

local function polishHUD()
  local hud = playerGui:WaitForChild("MainHUD", 30)
  if not hud then return end
  for _, frame in ipairs(hud:GetDescendants()) do polish(frame) end
  hud.DescendantAdded:Connect(polish)
end

task.spawn(polishHUD)
print("[HUDPolish] applied UIGradient + UIStroke per Grok recommendation")
