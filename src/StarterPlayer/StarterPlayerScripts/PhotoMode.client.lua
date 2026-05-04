-- PhotoMode.client.lua  v1 — F1 toggles a free-camera mode that:
--   * Hides the HUD (every PlayerGui top-level except this one)
--   * Sets workspace.CurrentCamera to Scriptable
--   * WASD = move, mouse = look, Q/E = up/down, Shift = fast
--   * F1 again exits, restores HUD + camera
-- Player can use Roblox built-in screenshot key while in photo mode.

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local StarterGui       = game:GetService("StarterGui")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local active = false
local camera = workspace.CurrentCamera

-- Hint UI shown while photo mode is active
local sg = Instance.new("ScreenGui", playerGui)
sg.Name = "PhotoModeHint"
sg.IgnoreGuiInset = true
sg.ResetOnSpawn = false
sg.DisplayOrder = 250
sg.Enabled = false

local hint = Instance.new("TextLabel", sg)
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -20)
hint.Size = UDim2.fromOffset(540, 36)
hint.BackgroundColor3 = Color3.fromRGB(50, 35, 20)
hint.BackgroundTransparency = 0.2
hint.Text = "PHOTO MODE  -  WASD move  -  Q/E up/down  -  Shift fast  -  F1 exit"
hint.TextColor3 = Color3.fromRGB(255, 240, 200)
hint.Font = Enum.Font.GothamBold
hint.TextScaled = true
Instance.new("UICorner", hint).CornerRadius = UDim.new(0, 8)
local hs = Instance.new("UIStroke", hint); hs.Thickness = 2; hs.Color = Color3.fromRGB(110, 75, 40)
local hc = Instance.new("UITextSizeConstraint", hint); hc.MinTextSize = 11; hc.MaxTextSize = 16

local hiddenGuis = {}
local savedCameraType, savedCFrame, savedFOV
local pitch, yaw = 0, 0
local moveConn

local function hideAllHUD()
    hiddenGuis = {}
    for _, child in ipairs(playerGui:GetChildren()) do
        if child:IsA("ScreenGui") and child.Enabled and child ~= sg then
            table.insert(hiddenGuis, child)
            child.Enabled = false
        end
    end
    pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
end

local function restoreHUD()
    for _, g in ipairs(hiddenGuis) do
        if g.Parent then g.Enabled = true end
    end
    hiddenGuis = {}
    pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
end

local function enter()
    if active then return end
    active = true
    sg.Enabled = true
    hideAllHUD()
    camera = workspace.CurrentCamera
    savedCameraType = camera.CameraType
    savedCFrame = camera.CFrame
    savedFOV = camera.FieldOfView
    camera.CameraType = Enum.CameraType.Scriptable
    -- Init pitch/yaw from current orientation
    local rx, ry = camera.CFrame:ToOrientation()
    pitch, yaw = rx, ry

    moveConn = RunService.RenderStepped:Connect(function(dt)
        if not active then return end
        local input = Vector3.zero
        local fast = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 3 or 1
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then input = input + Vector3.new(0, 0, -1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then input = input + Vector3.new(0, 0,  1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then input = input + Vector3.new(-1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then input = input + Vector3.new( 1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then input = input + Vector3.new(0,  1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then input = input + Vector3.new(0, -1, 0) end
        local rot = CFrame.new(camera.CFrame.Position) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
        local move = rot:VectorToWorldSpace(input) * 30 * fast * dt
        camera.CFrame = CFrame.new(camera.CFrame.Position + move) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
    end)
end

local function exit()
    if not active then return end
    active = false
    sg.Enabled = false
    if moveConn then moveConn:Disconnect(); moveConn = nil end
    camera = workspace.CurrentCamera
    if savedCameraType then camera.CameraType = savedCameraType end
    if savedCFrame then camera.CFrame = savedCFrame end
    if savedFOV then camera.FieldOfView = savedFOV end
    restoreHUD()
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        if active then exit() else enter() end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not active then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        yaw   = yaw   - input.Delta.X * 0.005
        pitch = math.clamp(pitch - input.Delta.Y * 0.005, -math.pi / 2 + 0.1, math.pi / 2 - 0.1)
    end
end)

print("[PhotoMode v1] online — F1 to toggle")
