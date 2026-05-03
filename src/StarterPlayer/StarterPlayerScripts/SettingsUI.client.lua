-- SettingsUI.client.lua
-- Settings menu: music/SFX volume sliders + camera mode + redeem code.
-- Opens via a small gear icon top-left of the HUD.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("MainHUD", 60)
if not hud then return end

-- Gear button on top bar
local topBar = hud:WaitForChild("TopBar")
local gear = Instance.new("TextButton")
gear.Name = "SettingsGear"
gear.Size = UDim2.new(0, 36, 0, 36)
gear.Position = UDim2.new(1, -44, 0, 4)
gear.BackgroundColor3 = Color3.fromRGB(60, 30, 90)
gear.TextColor3 = Color3.fromRGB(255, 255, 255)
gear.Font = Enum.Font.GothamBold
gear.TextScaled = true
gear.Text = "⚙"
gear.Parent = topBar
Instance.new("UICorner", gear).CornerRadius = UDim.new(1, 0)

-- Modal
local modal = Instance.new("Frame")
modal.Name = "SettingsModal"
modal.Size = UDim2.new(0, 480, 0, 460)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.new(0.5, 0, 0.5, 0)
modal.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
modal.BorderSizePixel = 0
modal.Visible = false
modal.ZIndex = 50
modal.Parent = hud
Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 16)
local stroke = Instance.new("UIStroke", modal); stroke.Thickness = 3; stroke.Color = Color3.fromRGB(150, 50, 200)

local title = Instance.new("TextLabel", modal)
title.Size = UDim2.new(1, -20, 0, 50)
title.Position = UDim2.new(0, 10, 0, 10)
title.BackgroundTransparency = 1
title.Text = "SETTINGS"
title.TextColor3 = Color3.fromRGB(255, 100, 200)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true

local close = Instance.new("TextButton", modal)
close.Size = UDim2.new(0, 40, 0, 40)
close.Position = UDim2.new(1, -50, 0, 10)
close.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
close.Text = "X"
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.Font = Enum.Font.GothamBlack
close.TextScaled = true
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
close.MouseButton1Click:Connect(function() modal.Visible = false end)

local function makeSlider(label, posY, settingKey, defaultValue)
    local row = Instance.new("Frame", modal)
    row.Size = UDim2.new(1, -40, 0, 50)
    row.Position = UDim2.new(0, 20, 0, posY)
    row.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0.4, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = true
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local bg = Instance.new("Frame", row)
    bg.Size = UDim2.new(0.55, 0, 0.5, 0)
    bg.Position = UDim2.new(0.42, 0, 0.25, 0)
    bg.BackgroundColor3 = Color3.fromRGB(40, 25, 60)
    bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame", bg)
    fill.Size = UDim2.new(defaultValue or 0.5, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(150, 50, 200)
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local btn = Instance.new("TextButton", bg)
    btn.Size = UDim2.fromScale(1, 1)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.MouseButton1Click:Connect(function()
        local mouse = UserInputService:GetMouseLocation()
        local relX = mouse.X - bg.AbsolutePosition.X
        local pct = math.clamp(relX / math.max(1, bg.AbsoluteSize.X), 0, 1)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        Remotes.RequestSettingChange:InvokeServer(settingKey, pct)
    end)
    return fill
end

makeSlider("Music",     80,  "settingsMusicVolume", 0.5)
makeSlider("SFX",       140, "settingsSFXVolume",   0.7)

-- Camera mode toggle
local camRow = Instance.new("Frame", modal)
camRow.Size = UDim2.new(1, -40, 0, 50)
camRow.Position = UDim2.new(0, 20, 0, 200)
camRow.BackgroundTransparency = 1

local camLbl = Instance.new("TextLabel", camRow)
camLbl.Size = UDim2.new(0.4, 0, 1, 0)
camLbl.BackgroundTransparency = 1
camLbl.Text = "Camera"
camLbl.Font = Enum.Font.GothamBold
camLbl.TextScaled = true
camLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
camLbl.TextXAlignment = Enum.TextXAlignment.Left

local thirdBtn = Instance.new("TextButton", camRow)
thirdBtn.Size = UDim2.new(0.27, 0, 0.7, 0)
thirdBtn.Position = UDim2.new(0.42, 0, 0.15, 0)
thirdBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 200)
thirdBtn.Text = "3rd"
thirdBtn.Font = Enum.Font.GothamBold
thirdBtn.TextScaled = true
thirdBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", thirdBtn).CornerRadius = UDim.new(0, 8)
thirdBtn.MouseButton1Click:Connect(function()
    Remotes.RequestSettingChange:InvokeServer("settingsCameraMode", "third")
end)

local firstBtn = Instance.new("TextButton", camRow)
firstBtn.Size = UDim2.new(0.27, 0, 0.7, 0)
firstBtn.Position = UDim2.new(0.71, 0, 0.15, 0)
firstBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 90)
firstBtn.Text = "1st"
firstBtn.Font = Enum.Font.GothamBold
firstBtn.TextScaled = true
firstBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", firstBtn).CornerRadius = UDim.new(0, 8)
firstBtn.MouseButton1Click:Connect(function()
    Remotes.RequestSettingChange:InvokeServer("settingsCameraMode", "first")
end)

-- Redeem code section
local codeLbl = Instance.new("TextLabel", modal)
codeLbl.Size = UDim2.new(1, -40, 0, 30)
codeLbl.Position = UDim2.new(0, 20, 0, 280)
codeLbl.BackgroundTransparency = 1
codeLbl.Text = "Redeem Code"
codeLbl.Font = Enum.Font.GothamBold
codeLbl.TextScaled = true
codeLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
codeLbl.TextXAlignment = Enum.TextXAlignment.Left

local codeInput = Instance.new("TextBox", modal)
codeInput.Size = UDim2.new(1, -180, 0, 50)
codeInput.Position = UDim2.new(0, 20, 0, 320)
codeInput.BackgroundColor3 = Color3.fromRGB(40, 25, 60)
codeInput.TextColor3 = Color3.fromRGB(255, 255, 255)
codeInput.PlaceholderText = "Enter code…"
codeInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
codeInput.Font = Enum.Font.Gotham
codeInput.TextScaled = true
codeInput.ClearTextOnFocus = false
codeInput.Text = ""
Instance.new("UICorner", codeInput).CornerRadius = UDim.new(0, 8)

local redeemBtn = Instance.new("TextButton", modal)
redeemBtn.Size = UDim2.new(0, 140, 0, 50)
redeemBtn.Position = UDim2.new(1, -160, 0, 320)
redeemBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
redeemBtn.Text = "REDEEM"
redeemBtn.Font = Enum.Font.GothamBlack
redeemBtn.TextScaled = true
redeemBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
Instance.new("UICorner", redeemBtn).CornerRadius = UDim.new(0, 8)
redeemBtn.MouseButton1Click:Connect(function()
    redeemBtn.Active = false
    redeemBtn.Text = "..."
    task.spawn(function()
        local ok, msg = Remotes.RequestRedeemCode:InvokeServer(codeInput.Text)
        codeInput.Text = ""
        redeemBtn.Active = true
        redeemBtn.Text = "REDEEM"
    end)
end)

local helpLbl = Instance.new("TextLabel", modal)
helpLbl.Size = UDim2.new(1, -40, 0, 60)
helpLbl.Position = UDim2.new(0, 20, 0, 380)
helpLbl.BackgroundTransparency = 1
helpLbl.Text = "Try LAUNCH for a welcome gift!\nCodes are case-insensitive."
helpLbl.Font = Enum.Font.Gotham
helpLbl.TextScaled = true
helpLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
helpLbl.TextWrapped = true

gear.MouseButton1Click:Connect(function()
    modal.Visible = not modal.Visible
end)
