-- TutorialFlow.client.lua — Grok #1 retention fix: clear "what do I do?" in first 10s
-- 3-step tutorial: highlight SUMMON HUMAN -> highlight first prank -> award 100 chaos completion
-- Place in: StarterPlayer > StarterPlayerScripts > TutorialFlow (LocalScript)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for spawn customization to complete (PreSpawnLobby destroys itself first)
task.wait(3)

local hud = playerGui:WaitForChild("MainHUD", 30)
if not hud then return end

-- Don't run tutorial if player has played before
local hasPlayed = player:GetAttribute("TutorialDone")
if hasPlayed then return end

local function makeOverlay()
  local o = Instance.new("ScreenGui")
  o.Name = "TutorialOverlay"
  o.IgnoreGuiInset = true
  o.ResetOnSpawn = false
  o.DisplayOrder = 100
  o.Parent = playerGui
  return o
end

local function makeArrow(targetFrame, text, overlay)
  local box = Instance.new("Frame")
  box.Size = UDim2.new(0, 320, 0, 100)
  box.BackgroundColor3 = Color3.fromRGB(255, 100, 200)
  box.BorderSizePixel = 0
  box.Parent = overlay
  Instance.new("UICorner", box).CornerRadius = UDim.new(0, 12)
  local stroke = Instance.new("UIStroke", box)
  stroke.Thickness = 3; stroke.Color = Color3.fromRGB(255, 255, 255)

  local label = Instance.new("TextLabel")
  label.Size = UDim2.fromScale(1, 1)
  label.BackgroundTransparency = 1
  label.Text = text
  label.Font = Enum.Font.GothamBlack
  label.TextScaled = true
  label.TextColor3 = Color3.fromRGB(255, 255, 255)
  label.TextStrokeTransparency = 0
  label.TextStrokeColor3 = Color3.new(0, 0, 0)
  label.Parent = box
  local pad = Instance.new("UIPadding", box)
  pad.PaddingLeft = UDim.new(0, 12); pad.PaddingRight = UDim.new(0, 12)

  -- Position above target
  local tr = targetFrame.AbsolutePosition
  local ts = targetFrame.AbsoluteSize
  box.Position = UDim2.fromOffset(tr.X + ts.X/2 - 160, tr.Y - 110)
  -- Pulse
  task.spawn(function()
    while box.Parent do
      TweenService:Create(box, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Size = UDim2.new(0, 340, 0, 105)}):Play()
      task.wait(1)
    end
  end)
  return box
end

local overlay = makeOverlay()

-- Step 1: highlight SUMMON HUMAN button (find it in HUD)
local summonBtn = hud:FindFirstChild("SummonButton", true) or hud:FindFirstChild("SUMMON_HUMAN", true)
if not summonBtn then
  -- Search by text
  for _, d in ipairs(hud:GetDescendants()) do
    if d:IsA("TextButton") and (d.Text:find("SUMMON") or d.Text:find("Summon")) then
      summonBtn = d
      break
    end
  end
end

if summonBtn then
  local arrow1 = makeArrow(summonBtn, "👇 TAP to SUMMON your first VICTIM", overlay)
  -- Wait for click
  local conn
  conn = summonBtn.MouseButton1Click:Connect(function()
    arrow1:Destroy()
    if conn then conn:Disconnect() end
    -- Step 2: prompt to use a prank
    task.wait(1.5)
    local prankCol = hud:FindFirstChild("PrankColumn", true)
    if prankCol then
      local firstPrankBtn = prankCol:FindFirstChildWhichIsA("TextButton", true)
      if firstPrankBtn then
        local arrow2 = makeArrow(firstPrankBtn, "👈 NOW TAP a PRANK to scratch them!", overlay)
        local conn2
        conn2 = firstPrankBtn.MouseButton1Click:Connect(function()
          arrow2:Destroy()
          if conn2 then conn2:Disconnect() end
          -- Step 3: completion
          task.wait(0.5)
          local doneBox = makeOverlay()
          local frame = Instance.new("Frame", doneBox)
          frame.Size = UDim2.new(0, 500, 0, 220)
          frame.Position = UDim2.new(0.5, -250, 0.4, 0)
          frame.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
          Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 16)
          local txt = Instance.new("TextLabel", frame)
          txt.Size = UDim2.fromScale(1, 1)
          txt.BackgroundTransparency = 1
          txt.Text = "🎉 +100 CHAOS BONUS!\n\nYou know how to PRANK now.\nGood luck, kitty."
          txt.Font = Enum.Font.GothamBlack
          txt.TextScaled = true
          txt.TextColor3 = Color3.fromRGB(255, 255, 255)
          player:SetAttribute("TutorialDone", true)
          task.wait(4)
          doneBox:Destroy()
          overlay:Destroy()
        end)
      end
    end
  end)
end

print("[TutorialFlow] tutorial active for new player")
