-- SpectateSystem.client.lua
-- Spectate mode: clicking the leaderboard button toggles a "spectate top
-- player" overlay. While spectating, camera follows the #1 chaos earner.
-- Press B or click the X to exit.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 60)
if not hud then return end

local lastTop = {}
Remotes.LeaderboardUpdated.OnClientEvent:Connect(function(top) lastTop = top end)

local spectating = nil  -- target Player
local cam = Workspace.CurrentCamera
local conn

local overlay = Instance.new("Frame", hud)
overlay.Name = "SpectateOverlay"
overlay.Size = UDim2.new(1, 0, 0, 60)
overlay.Position = UDim2.new(0, 0, 0, 80)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.3
overlay.Visible = false
overlay.ZIndex = 60

local lbl = Instance.new("TextLabel", overlay)
lbl.Size = UDim2.new(1, -120, 1, 0)
lbl.Position = UDim2.new(0, 60, 0, 0)
lbl.BackgroundTransparency = 1
lbl.Font = Enum.Font.GothamBlack
lbl.TextScaled = true
lbl.TextColor3 = Color3.fromRGB(255, 215, 0)

local exitBtn = Instance.new("TextButton", overlay)
exitBtn.AnchorPoint = Vector2.new(1, 0.5)
exitBtn.Position = UDim2.new(1, -10, 0.5, 0)
exitBtn.Size = UDim2.new(0, 100, 0, 40)
exitBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
exitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
exitBtn.Font = Enum.Font.GothamBlack
exitBtn.TextScaled = true
exitBtn.Text = "EXIT"
Instance.new("UICorner", exitBtn).CornerRadius = UDim.new(0, 8)

local function stopSpectate()
    if conn then conn:Disconnect(); conn = nil end
    spectating = nil
    cam.CameraType = Enum.CameraType.Custom
    cam.CameraSubject = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    overlay.Visible = false
end

local function startSpectate(target)
    if not target or target == player then return end
    spectating = target
    overlay.Visible = true
    lbl.Text = "Watching " .. (target.DisplayName or target.Name)
    cam.CameraType = Enum.CameraType.Custom
    if target.Character and target.Character:FindFirstChildOfClass("Humanoid") then
        cam.CameraSubject = target.Character:FindFirstChildOfClass("Humanoid")
    end
    conn = RunService.Heartbeat:Connect(function()
        if not spectating or not spectating.Parent then stopSpectate(); return end
        if spectating.Character and spectating.Character:FindFirstChildOfClass("Humanoid") then
            cam.CameraSubject = spectating.Character:FindFirstChildOfClass("Humanoid")
        end
    end)
end

exitBtn.MouseButton1Click:Connect(stopSpectate)
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.B and spectating then stopSpectate() end
end)

-- Add a "WATCH TOP" button to the leaderboard modal
task.spawn(function()
    task.wait(2)
    local lbModal = hud:FindFirstChild("LeaderboardModal")
    if not lbModal then return end
    if lbModal:FindFirstChild("WatchTopButton") then return end
    local btn = Instance.new("TextButton", lbModal)
    btn.Name = "WatchTopButton"
    btn.AnchorPoint = Vector2.new(0.5, 1)
    btn.Position = UDim2.new(0.5, 0, 1, -10)
    btn.Size = UDim2.new(0, 220, 0, 44)
    btn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    btn.TextColor3 = Color3.fromRGB(0, 0, 0)
    btn.Font = Enum.Font.GothamBlack
    btn.TextScaled = true
    btn.Text = "WATCH #1"
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(function()
        local top = lastTop[1]
        if not top then return end
        local target = Players:GetPlayerByUserId(top.userId)
        if target and target ~= player then
            lbModal.Visible = false
            startSpectate(target)
        end
    end)
end)
