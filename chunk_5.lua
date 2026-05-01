do
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local function shake(intensity)
    if intensity <= 0 then return end
    task.spawn(function()
        local steps = 10
        for i = 1, steps do
            local off = CFrame.new(
                (math.random()-0.5) * intensity * 0.1,
                (math.random()-0.5) * intensity * 0.1,
                0
            )
            camera.CFrame = camera.CFrame * off
            task.wait(0.02)
        end
    end)
end

local function spawnParticleBurst(cf, color, count)
    local emitterPart = Instance.new("Part")
    emitterPart.Anchored = true
    emitterPart.CanCollide = false
    emitterPart.Transparency = 1
    emitterPart.Size = Vector3.new(1,1,1)
    emitterPart.CFrame = cf
    emitterPart.Parent = Workspace

    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    emitter.Color = ColorSequence.new(color)
    emitter.Lifetime = NumberRange.new(0.5, 1.0)
    emitter.Rate = 0
    emitter.Speed = NumberRange.new(8, 18)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Size = NumberSequence.new(1.5, 0.2)
    emitter.Parent = emitterPart
    emitter:Emit(count)
    Debris:AddItem(emitterPart, 2)
end

local function playSound(soundId, parent)
    if not soundId or soundId == "" then return end
    local s = Instance.new("Sound")
    s.SoundId = soundId
    s.Volume = 1
    s.Parent = parent or SoundService
    s:Play()
    Debris:AddItem(s, 5)
end

local function chaosFlyUp(amount, atCFrame)
    if amount <= 0 then return end
    local b = Instance.new("BillboardGui")
    b.Size = UDim2.new(0, 120, 0, 50)
    b.AlwaysOnTop = true
    b.StudsOffset = Vector3.new(0, 4, 0)
    -- attach to a temp part
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.Transparency = 1
    p.Size = Vector3.new(0.1,0.1,0.1)
    p.CFrame = atCFrame
    p.Parent = Workspace
    b.Parent = p

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "+" .. amount .. " 💚"
    lbl.TextColor3 = GameConfig.HUD_ACCENT_COLOR
    lbl.TextStrokeTransparency = 0
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    lbl.Parent = b

    TweenService:Create(p, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = atCFrame * CFrame.new(0, 6, 0)}):Play()
    TweenService:Create(lbl, TweenInfo.new(1.2), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    Debris:AddItem(p, 1.5)
end

-- ===== Prank effect dispatch =====
local function effectFor(prankName, cf, color)
    if prankName == "Pie" then
        spawnParticleBurst(cf, color, 35)
    elseif prankName == "Anvil" then
        -- Spawn a fake anvil that drops from sky
        local anvil = Instance.new("Part")
        anvil.Size = Vector3.new(4, 3, 3)
        anvil.Color = Color3.fromRGB(80, 80, 80)
        anvil.Material = Enum.Material.Metal
        anvil.Anchored = true
        anvil.CanCollide = false
        anvil.CFrame = cf * CFrame.new(0, 30, 0)
        anvil.Parent = Workspace
        TweenService:Create(anvil, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {CFrame = cf * CFrame.new(0, 1.5, 0)}):Play()
        task.delay(0.4, function()
            spawnParticleBurst(cf, Color3.fromRGB(150, 150, 150), 50)
            Debris:AddItem(anvil, 1)
        end)
    elseif prankName == "FartCloud" then
        -- AOE green smoke
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Size = Vector3.new(8, 4, 8)
        part.Material = Enum.Material.SmoothPlastic
        part.Color = Color3.fromRGB(140, 200, 80)
        part.Transparency = 0.4
        part.CFrame = cf
        part.Parent = Workspace
        TweenService:Create(part, TweenInfo.new(1.2), {Transparency = 1, Size = Vector3.new(16, 8, 16)}):Play()
        Debris:AddItem(part, 1.5)
        spawnParticleBurst(cf, color, 80)
    elseif prankName == "LaserEyes" then
        -- Beam from player char head to target
        local char = player.Character
        if char and char:FindFirstChild("Head") then
            local origin = char.Head.Position
            local target = cf.Position
            local mid = (origin + target) / 2
            local dist = (origin - target).Magnitude
            local beam = Instance.new("Part")
            beam.Anchored = true
            beam.CanCollide = false
            beam.Size = Vector3.new(0.5, 0.5, dist)
            beam.Color = Color3.fromRGB(255, 50, 50)
            beam.Material = Enum.Material.Neon
            beam.CFrame = CFrame.new(mid, target)
            beam.Parent = Workspace
            TweenService:Create(beam, TweenInfo.new(0.4), {Transparency = 1}):Play()
            Debris:AddItem(beam, 0.5)
        end
        spawnParticleBurst(cf, color, 60)
    end
end

Remotes.PrankRegistered.OnClientEvent:Connect(function(prankName, target, chaosGained, fxPayload)
    local prank = PrankConfig.getPrank(prankName)
    if not prank then return end
    local cf = fxPayload and fxPayload.targetCFrame or (target and target.PrimaryPart and target.PrimaryPart.CFrame) or CFrame.new()
    effectFor(prankName, cf, prank.particleColor)
    playSound(prank.soundId)
    if chaosGained and chaosGained > 0 then
        chaosFlyUp(chaosGained, cf)
        shake(prank.screenShake or 0)
    end
end)

return true

]]
end

-- StarterPlayer/StarterPlayerScripts/TutorialController.client.lua
do
    local s = getOrMake(game.StarterPlayer:WaitForChild('StarterPlayerScripts'), 'LocalScript', 'TutorialController')
    s.Source = [[
-- TutorialController.client.lua
-- First-session tutorial: 3 step tooltips on first summon + first prank.
-- Place in: StarterPlayer > StarterPlayerScripts > TutorialController (LocalScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("MainHUD", 30)
if not hud then return end

local tooltip = hud:WaitForChild("TutorialTooltip")
local txt = tooltip:WaitForChild("Text")

local seenSummon = false
local seenPrank = false

local function show(message, ms)
    txt.Text = message
    tooltip.Visible = true
    if ms then
        task.delay(ms / 1000, function() tooltip.Visible = false end)
    end
end

-- Initial step
task.delay(2, function()
    if not seenSummon then
        show("Tap SUMMON HUMAN to spawn your first victim 😈")
    end
end)

-- After first summon, show next tip
local function onPlayerData()
    -- Listen once when summons happen
end

-- Register hooks via remotes
local origConnect
Remotes.UpdatePlayerData.OnClientEvent:Connect(function(data)
    if data.totalPranks and data.totalPranks > 0 and not seenPrank then
        seenPrank = true
        show("Nice! Get to Level 5 to unlock Anvil. Press SHOP to see cosmetics.", 5000)
    end
end)

-- Detect first summon by watching workspace
task.spawn(function()
    local Workspace = game:GetService("Workspace")
    while not seenSummon do
        task.wait(0.5)
        local folder = Workspace:FindFirstChild("PrankNPCs")
        if folder then
            for _, m in ipairs(folder:GetChildren()) do
                if m:GetAttribute("SummonedBy") == player.UserId then
                    seenSummon = true
                    show("Walk close, then tap PIE 🥧 to throw a pie!", 6000)
                    return
                end
            end
        end
    end
end)

return true

]]
end

-- StarterPlayer/StarterPlayerScripts/PerkUI.client.lua
do
    local s = getOrMake(game.StarterPlayer:WaitForChild('StarterPlayerScripts'), 'LocalScript', 'PerkUI')
    s.Source = [[
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
                local ok = Remotes.RequestEquipPerk:InvokeServer(slot, perkId)
                if ok then perkModal.Visible = false end
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

]]
end

-- StarterPlayer/StarterPlayerScripts/SurvivalUI.client.lua
do
    local s = getOrMake(game.StarterPlayer:WaitForChild('StarterPlayerScripts'), 'LocalScript', 'SurvivalUI')
    s.Source = [[
-- SurvivalUI.client.lua
-- Hunger + thirst bars on HUD. Listens to SurvivalUpdate events.
-- Place in: StarterPlayer > StarterPlayerScripts > SurvivalUI (LocalScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
if not hud then return end

local function makeBar(name, color, posY)
    local container = Instance.new("Frame")
    container.Name = name .. "BarContainer"
    container.Size = UDim2.new(0, 220, 0, 22)
    container.Position = UDim2.new(0, 12, 0, posY)
    container.BackgroundTransparency = 1
    container.Parent = hud

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 60, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = color
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextStrokeTransparency = 0
    lbl.Parent = container

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 150, 0.7, 0)
    bg.Position = UDim2.new(0, 65, 0.15, 0)
    bg.BackgroundColor3 = Color3.fromRGB(40, 20, 60)
    bg.BorderSizePixel = 0
    bg.Parent = container
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = color
    fill.BorderSizePixel = 0
    fill.Parent = bg
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    return fill
end

local hungerFill = makeBar("HUNGER", Color3.fromRGB(255, 150, 60), 90)
local thirstFill = makeBar("THIRST", Color3.fromRGB(60, 180, 255), 116)

Remotes.SurvivalUpdate.OnClientEvent:Connect(function(hunger, thirst)
    TweenService:Create(hungerFill, TweenInfo.new(0.4), {Size = UDim2.new(math.clamp(hunger/100,0,1), 0, 1, 0)}):Play()
    TweenService:Create(thirstFill, TweenInfo.new(0.4), {Size = UDim2.new(math.clamp(thirst/100,0,1), 0, 1, 0)}):Play()
end)

Remotes.UpdatePlayerData.OnClientEvent:Connect(function(d)
    TweenService:Create(hungerFill, TweenInfo.new(0.4), {Size = UDim2.new(math.clamp((d.hunger or 100)/100,0,1), 0, 1, 0)}):Play()
    TweenService:Create(thirstFill, TweenInfo.new(0.4), {Size = UDim2.new(math.clamp((d.thirst or 100)/100,0,1), 0, 1, 0)}):Play()
end)

return true

]]
end

-- StarterPlayer/StarterPlayerScripts/EmoteWheel.client.lua
do
    local s = getOrMake(game.StarterPlayer:WaitForChild('StarterPlayerScripts'), 'LocalScript', 'EmoteWheel')
    s.Source = [[
-- EmoteWheel.client.lua
-- B key opens emote wheel. Click an emote to play.
-- Place in: StarterPlayer > StarterPlayerScripts > EmoteWheel (LocalScript)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
if not hud then return end

local wheel = Instance.new("Frame")
wheel.Name = "EmoteWheel"
wheel.Size = UDim2.new(0, 360, 0, 360)
wheel.AnchorPoint = Vector2.new(0.5, 0.5)
wheel.Position = UDim2.new(0.5, 0, 0.5, 0)
wheel.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
wheel.BackgroundTransparency = 0.2
wheel.BorderSizePixel = 0
wheel.Visible = false
wheel.Parent = hud
Instance.new("UICorner", wheel).CornerRadius = UDim.new(1, 0)
local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.Color = Color3.fromRGB(150, 50, 200)
stroke.Parent = wheel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.Position = UDim2.new(0, 0, 0, 10)
title.BackgroundTransparency = 1
title.Text = "EMOTES"
title.TextColor3 = Color3.fromRGB(150, 50, 200)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.Parent = wheel

local center = Vector2.new(180, 180)
for i, emoteName in ipairs(GameConfig.EMOTES) do
    local angle = (i - 1) * (2 * math.pi / #GameConfig.EMOTES) - math.pi / 2
    local r = 130
    local x = center.X + math.cos(angle) * r - 35
    local y = center.Y + math.sin(angle) * r - 25
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 70, 0, 50)
    btn.Position = UDim2.new(0, x, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(60, 30, 90)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBlack
    btn.Text = emoteName
    btn.TextScaled = true
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.Parent = wheel
    btn.MouseButton1Click:Connect(function()
        Remotes.RequestEmote:FireServer(emoteName)
        wheel.Visible = false
    end)
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.B then
        wheel.Visible = not wheel.Visible
    elseif input.KeyCode == Enum.KeyCode.Escape and wheel.Visible then
        wheel.Visible = false
    end
end)

-- Listen to other players' emotes -> show floating tag above their head
Remotes.EmoteBroadcast.OnClientEvent:Connect(function(userId, emoteName)
    local target = Players:GetPlayerByUserId(userId)
    if not target or not target.Character then return end
    local head = target.Character:FindFirstChild("Head")
    if not head then return end
    local b = Instance.new("BillboardGui")
    b.Size = UDim2.new(0, 100, 0, 36)
    b.StudsOffset = Vector3.new(0, 3, 0)
    b.AlwaysOnTop = true
    b.Parent = head
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
    lbl.BackgroundTransparency = 0.3
    lbl.Text = "*" .. emoteName .. "*"
    lbl.TextColor3 = Color3.fromRGB(255, 200, 0)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 8)
    lbl.Parent = b
    task.delay(2, function() b:Destroy() end)
end)

return true

]]
end

-- StarterPlayer/StarterPlayerScripts/DailyRewardUI.client.lua
do
    local s = getOrMake(game.StarterPlayer:WaitForChild('StarterPlayerScripts'), 'LocalScript', 'DailyRewardUI')
    s.Source = [[
-- DailyRewardUI.client.lua
-- Shows daily reward popup when DailyAvailable fires.
-- Place in: StarterPlayer > StarterPlayerScripts > DailyRewardUI (LocalScript)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
if not hud then return end

local modal = Instance.new("Frame")
modal.Name = "DailyRewardModal"
modal.Size = UDim2.new(0, 380, 0, 280)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.new(0.5, 0, 0.5, 0)
modal.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
modal.BorderSizePixel = 0
modal.Visible = false
modal.ZIndex = 100
Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 16)
local s = Instance.new("UIStroke") s.Thickness = 3 s.Color = Color3.fromRGB(255, 200, 0) s.Parent = modal
modal.Parent = hud

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 50)
title.Position = UDim2.new(0, 10, 0, 10)
title.BackgroundTransparency = 1
title.Text = "DAILY REWARD"
title.TextColor3 = Color3.fromRGB(255, 200, 0)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true
title.Parent = modal

local streakLbl = Instance.new("TextLabel")
streakLbl.Size = UDim2.new(1, -20, 0, 30)
streakLbl.Position = UDim2.new(0, 10, 0, 60)
streakLbl.BackgroundTransparency = 1
streakLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
streakLbl.Font = Enum.Font.Gotham
streakLbl.TextScaled = true
streakLbl.Parent = modal

local rewardLbl = Instance.new("TextLabel")
rewardLbl.Size = UDim2.new(1, -20, 0, 80)
rewardLbl.Position = UDim2.new(0, 10, 0, 95)
rewardLbl.BackgroundTransparency = 1
rewardLbl.TextColor3 = Color3.fromRGB(0, 255, 100)
rewardLbl.Font = Enum.Font.GothamBlack
rewardLbl.TextScaled = true
rewardLbl.Parent = modal

local claimBtn = Instance.new("TextButton")
claimBtn.Size = UDim2.new(0, 240, 0, 60)
claimBtn.AnchorPoint = Vector2.new(0.5, 1)
claimBtn.Position = UDim2.new(0.5, 0, 1, -16)
claimBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
claimBtn.TextColor3 = Color3.new(0,0,0)
claimBtn.Font = Enum.Font.GothamBlack
claimBtn.TextScaled = true
claimBtn.Text = "CLAIM"
Instance.new("UICorner", claimBtn).CornerRadius = UDim.new(0, 12)
claimBtn.Parent = modal

Remotes.DailyAvailable.OnClientEvent:Connect(function(streak, reward)
    streakLbl.Text = "Day " .. streak .. " of 7 streak"
    rewardLbl.Text = reward.msg
    modal.Visible = true
end)

claimBtn.MouseButton1Click:Connect(function()
    local ok = Remotes.RequestClaimDaily:InvokeServer()
    if ok then modal.Visible = false end
end)

return true

]]
end

-- StarterPlayer/StarterPlayerScripts/WeatherClient.client.lua
do
    local s = getOrMake(game.StarterPlayer:WaitForChild('StarterPlayerScripts'), 'LocalScript', 'WeatherClient')
    s.Source = [[
-- WeatherClient.client.lua
-- Reacts to weather changes: spawns rain/fog/red mist particles, shows banner.
-- Place in: StarterPlayer > StarterPlayerScripts > WeatherClient (LocalScript)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 30)
if not hud then return end

local banner = Instance.new("TextLabel")
banner.Size = UDim2.new(0, 300, 0, 50)
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 90)
banner.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
banner.BackgroundTransparency = 0.2
banner.TextColor3 = Color3.fromRGB(255, 200, 0)
banner.Font = Enum.Font.GothamBlack
banner.TextScaled = true
banner.Visible = false
banner.Text = ""
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 12)
banner.Parent = hud

local activeFX = nil

local function clearFX()
    if activeFX then activeFX:Destroy(); activeFX = nil end
end

local function rainFX()
    local model = Instance.new("Model")
    model.Name = "RainFX"
    model.Parent = Workspace
    -- Rain emitter attached to camera
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.Transparency = 1
    p.Size = Vector3.new(60, 1, 60)
    p.Parent = model
    local cam = Workspace.CurrentCamera
    -- Track camera
    local conn
    conn = game:GetService("RunService").Heartbeat:Connect(function()
        if not p.Parent then conn:Disconnect() return end
        p.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 30, 0))
    end)
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
    emitter.Color = ColorSequence.new(Color3.fromRGB(150, 180, 220))
    emitter.Lifetime = NumberRange.new(0.6, 0.9)
    emitter.Rate = 200
    emitter.Speed = NumberRange.new(40, 60)
    emitter.SpreadAngle = Vector2.new(5, 5)
    emitter.Size = NumberSequence.new(0.3, 0.1)
    emitter.Acceleration = Vector3.new(0, -50, 0)
    emitter.Parent = p
    return model
end

local function fogFX()
    -- Lighting handles fog mostly; just intensify with a screen overlay
    local frame = Instance.new("Frame")
    frame.Name = "FogOverlay"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
    frame.BackgroundTransparency = 0.85
    frame.BorderSizePixel = 0
    frame.ZIndex = 0
    frame.Parent = hud
    return frame
end

local function redMistFX()
    local model = Instance.new("Model")
    model.Name = "RedMistFX"
    model.Parent = Workspace
    -- Screen tint
    local frame = Instance.new("Frame")
    frame.Name = "RedMistOverlay"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    frame.BackgroundTransparency = 0.92
    frame.BorderSizePixel = 0
    frame.ZIndex = 0
    frame.Parent = hud
    return model
end

Remotes.WeatherChanged.OnClientEvent:Connect(function(weather)
    clearFX()
    banner.Text = weather:upper()
    banner.TextColor3 = ({
        Sunny = Color3.fromRGB(255, 220, 80),
        Rainy = Color3.fromRGB(120, 180, 255),
        Foggy = Color3.fromRGB(220, 220, 220),
        RedMist = Color3.fromRGB(255, 50, 50),
    })[weather] or Color3.fromRGB(255, 200, 0)
    banner.Visible = true
    task.delay(4, function() banner.Visible = false end)

    if weather == "Rainy" then activeFX = rainFX()
    elseif weather == "Foggy" then activeFX = fogFX()
    elseif weather == "RedMist" then activeFX = redMistFX() end
end)

Remotes.EventBroadcast.OnClientEvent:Connect(function(message)
    banner.Text = message
    banner.Visible = true
    task.delay(5, function() banner.Visible = false end)
end)

return true

]]
end

print('[KittyRaiser] Loader done. Press F5 to play.')
end
print('[Loader] chunk 5/5 loaded')