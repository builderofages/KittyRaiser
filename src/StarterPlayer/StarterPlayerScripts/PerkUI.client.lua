-- PerkUI.client.lua
-- Shows perk picker modal when a slot unlocks. Stats UI for allocating points.
-- Place in: StarterPlayer > StarterPlayerScripts > PerkUI (LocalScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local PerkConfig = require(ReplicatedStorage.Modules.PerkConfig)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("MainHUD", 30)
if not hud then return end

local function makeModal(title, color)
    local modal = Instance.new("Frame")
    modal.Name = title
    modal.Size = UDim2.new(0, 700, 0, 480)
    modal.AnchorPoint = Vector2.new(0.5, 0.5)
    modal.Position = UDim2.new(0.5, 0, 0.5, 0)
    modal.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
    modal.BorderSizePixel = 0
    modal.Visible = false
    modal.ZIndex = 50
    Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 16)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 3
    stroke.Color = color
    stroke.Parent = modal
    modal.Parent = hud

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -20, 0, 50)
    titleLbl.Position = UDim2.new(0, 10, 0, 10)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title
    titleLbl.TextColor3 = color
    titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextScaled = true
    titleLbl.Parent = modal

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 40, 0, 40)
    close.Position = UDim2.new(1, -50, 0, 10)
    close.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    close.Text = "X"
    close.TextColor3 = Color3.new(1,1,1)
    close.Font = Enum.Font.GothamBlack
    close.TextScaled = true
    Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
    close.Parent = modal
    close.MouseButton1Click:Connect(function() modal.Visible = false end)

    return modal
end

-- ===== Perk Picker (forced when slot earned) =====
local perkModal = makeModal("PERK_PICKER", Color3.fromRGB(255, 200, 0))
perkModal.Name = "PerkPickerModal"
local perkSubtitle = Instance.new("TextLabel")
perkSubtitle.Size = UDim2.new(1, -20, 0, 30)
perkSubtitle.Position = UDim2.new(0, 10, 0, 60)
perkSubtitle.BackgroundTransparency = 1
perkSubtitle.Text = "Pick 1 perk for this slot"
perkSubtitle.TextColor3 = Color3.fromRGB(220, 220, 220)
perkSubtitle.Font = Enum.Font.Gotham
perkSubtitle.TextScaled = true
perkSubtitle.Parent = perkModal

local perkList = Instance.new("Frame")
perkList.Size = UDim2.new(1, -20, 1, -110)
perkList.Position = UDim2.new(0, 10, 0, 100)
perkList.BackgroundTransparency = 1
perkList.Parent = perkModal
local perkLayout = Instance.new("UIListLayout")
perkLayout.Padding = UDim.new(0, 8)
perkLayout.Parent = perkList

local function showPerkPicker(slot, options)
    perkSubtitle.Text = "SLOT " .. slot .. " — pick 1 perk"
    for _, c in ipairs(perkList:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    for _, perkId in ipairs(options) do
        local p = PerkConfig.getPerk(perkId)
        if p then
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 64)
            row.BackgroundColor3 = Color3.fromRGB(40, 25, 60)
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
            row.Parent = perkList
            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(0.55, 0, 0.5, 0)
            nameLbl.Position = UDim2.new(0.02, 0, 0, 0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = p.name
            nameLbl.TextColor3 = Color3.fromRGB(255, 200, 0)
            nameLbl.Font = Enum.Font.GothamBlack
            nameLbl.TextScaled = true
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Parent = row
            local descLbl = Instance.new("TextLabel")
            descLbl.Size = UDim2.new(0.55, 0, 0.5, 0)
            descLbl.Position = UDim2.new(0.02, 0, 0.5, 0)
            descLbl.BackgroundTransparency = 1
            descLbl.Text = p.desc
            descLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
            descLbl.Font = Enum.Font.Gotham
            descLbl.TextScaled = true
            descLbl.TextXAlignment = Enum.TextXAlignment.Left
            descLbl.Parent = row
            local pickBtn = Instance.new("TextButton")
            pickBtn.Size = UDim2.new(0.35, 0, 0.8, 0)
            pickBtn.Position = UDim2.new(0.62, 0, 0.1, 0)
            pickBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
            pickBtn.TextColor3 = Color3.new(0,0,0)
            pickBtn.Font = Enum.Font.GothamBlack
            pickBtn.Text = "PICK"
            pickBtn.TextScaled = true
            Instance.new("UICorner", pickBtn).CornerRadius = UDim.new(0, 8)
            pickBtn.Parent = row
            pickBtn.MouseButton1Click:Connect(function()
                pickBtn.Active = false
                pickBtn.Text = "..."
                task.spawn(function()
                    local ok, err = Remotes.RequestEquipPerk:InvokeServer(slot, perkId)
                    if ok then
                        perkModal.Visible = false
                    else
                        pickBtn.Active = true
                        pickBtn.Text = "PICK"
                        warn("[PerkUI] equip failed:", err)
                    end
                end)
                -- Re-enable after 5s if no response (server hung)
                task.delay(5, function()
                    if pickBtn.Text == "..." then
                        pickBtn.Active = true
                        pickBtn.Text = "PICK (retry)"
                    end
                end)
            end)
        end
    end
    perkModal.Visible = true
end

Remotes.PerkSlotEarned.OnClientEvent:Connect(showPerkPicker)

-- ===== Stats Screen =====
local statsModal = makeModal("STATS", Color3.fromRGB(0, 200, 255))
statsModal.Name = "StatsModal"
local statsSubtitle = Instance.new("TextLabel")
statsSubtitle.Size = UDim2.new(1, -20, 0, 30)
statsSubtitle.Position = UDim2.new(0, 10, 0, 60)
statsSubtitle.BackgroundTransparency = 1
statsSubtitle.TextColor3 = Color3.fromRGB(220, 220, 220)
statsSubtitle.Font = Enum.Font.Gotham
statsSubtitle.TextScaled = true
statsSubtitle.Text = "Allocate stat points each level"
statsSubtitle.Parent = statsModal

local statsList = Instance.new("Frame")
statsList.Size = UDim2.new(1, -20, 1, -110)
statsList.Position = UDim2.new(0, 10, 0, 100)
statsList.BackgroundTransparency = 1
statsList.Parent = statsModal
local statsLayout = Instance.new("UIListLayout")
statsLayout.Padding = UDim.new(0, 8)
statsLayout.Parent = statsList

local function rebuildStats(data)
    statsSubtitle.Text = "Unspent points: " .. (data.unspentStatPoints or 0)
    for _, c in ipairs(statsList:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    for _, statName in ipairs(GameConfig.STAT_NAMES) do
        local current = (data.stats and data.stats[statName]) or 0
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 50)
        row.BackgroundColor3 = Color3.fromRGB(40, 25, 60)
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
        row.Parent = statsList
        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(0.4, 0, 1, 0)
        nameLbl.Position = UDim2.new(0.02, 0, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = statName .. ": " .. current
        nameLbl.TextColor3 = Color3.fromRGB(0, 200, 255)
        nameLbl.Font = Enum.Font.GothamBlack
        nameLbl.TextScaled = true
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.Parent = row
        local plus = Instance.new("TextButton")
        plus.Size = UDim2.new(0, 50, 0.8, 0)
        plus.Position = UDim2.new(1, -60, 0.1, 0)
        plus.Text = "+"
        plus.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        plus.TextColor3 = Color3.new(1,1,1)
        plus.Font = Enum.Font.GothamBlack
        plus.TextScaled = true
        Instance.new("UICorner", plus).CornerRadius = UDim.new(0, 6)
        plus.Parent = row
        plus.MouseButton1Click:Connect(function()
            local ok = Remotes.RequestAllocStat:InvokeServer(statName)
            if not ok then return end
        end)
    end
end

local cachedData
Remotes.UpdatePlayerData.OnClientEvent:Connect(function(d)
    cachedData = d
    if statsModal.Visible then rebuildStats(d) end
end)

-- ===== Hook bottom-bar Stats button (added when MainHUD adds stats button)
local function hookStatsButton()
    local botBar = hud:FindFirstChild("BottomBar")
    if not botBar then return end
    -- Create stats button if not exists
    if botBar:FindFirstChild("StatsButton") then return end
    local statsBtn = Instance.new("TextButton")
    statsBtn.Name = "StatsButton"
    statsBtn.Size = UDim2.new(0, 70, 0, 44)
    statsBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    statsBtn.TextColor3 = Color3.new(1,1,1)
    statsBtn.Font = Enum.Font.GothamBlack
    statsBtn.TextScaled = true
    statsBtn.Text = "STATS"
    statsBtn.LayoutOrder = 5
    Instance.new("UICorner", statsBtn).CornerRadius = UDim.new(0, 12)
    statsBtn.Parent = botBar
    statsBtn.MouseButton1Click:Connect(function()
        statsModal.Visible = not statsModal.Visible
        if statsModal.Visible and cachedData then rebuildStats(cachedData) end
    end)
end
hookStatsButton()
hud.ChildAdded:Connect(function() task.wait(0.5); hookStatsButton() end)

return true
