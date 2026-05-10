-- UIScaler.client.lua  v3.99.13 — adapts HUD to screen size for mobile/tablet/desktop
local Players       = game:GetService("Players")
local UserInput     = game:GetService("UserInputService")
local GuiService    = game:GetService("GuiService")
local player        = Players.LocalPlayer
local playerGui     = player:WaitForChild("PlayerGui")

print("[UIScaler v3.99.13] starting")

local function applyScale()
    local hud = playerGui:FindFirstChild("MainHUD")
    if not hud then return end

    -- Determine screen size + platform
    local cam = workspace.CurrentCamera
    local size = cam and cam.ViewportSize or Vector2.new(1920, 1080)
    local isMobile = UserInput.TouchEnabled and not UserInput.MouseEnabled
    local isTablet = isMobile and size.X >= 1024
    local isPhone  = isMobile and not isTablet

    -- Calculate scale factor
    local scale = 1.0
    if isPhone then
        scale = math.min(size.X / 1280, size.Y / 720) * 1.15  -- bump up for readability
    elseif isTablet then
        scale = math.min(size.X / 1280, size.Y / 720)
    else  -- desktop
        scale = math.min(size.X / 1920, size.Y / 1080)
    end
    scale = math.clamp(scale, 0.7, 1.4)

    -- Apply UIScale to HUD root
    local existing = hud:FindFirstChildOfClass("UIScale")
    if not existing then
        existing = Instance.new("UIScale", hud)
    end
    existing.Scale = scale

    -- Make TouchEnabled buttons bigger (min 44px target per Apple HIG / 48dp Material)
    if isMobile then
        for _, c in ipairs(hud:GetDescendants()) do
            if c:IsA("GuiButton") then
                local s = c.Size
                if s.X.Offset > 0 and s.X.Offset < 44 then
                    c.Size = UDim2.new(s.X.Scale, math.max(s.X.Offset, 44), s.Y.Scale, math.max(s.Y.Offset, 44))
                end
            end
        end
    end

    print(string.format("[UIScaler] viewport %dx%d, mobile=%s, scale=%.2f", size.X, size.Y, tostring(isMobile), scale))
end

-- Apply on spawn + viewport changes
applyScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)

-- Watch for HUD recreation
playerGui.ChildAdded:Connect(function(c)
    if c.Name == "MainHUD" then task.wait(0.5); applyScale() end
end)

print("[UIScaler v3.99.13] online")
