local function getOrMake(parent, className, name)
    local existing = parent:FindFirstChild(name)
    if existing and existing.ClassName == className then return existing end
    if existing then existing:Destroy() end
    local obj = Instance.new(className)
    obj.Name = name
    obj.Parent = parent
    return obj
end
local modulesFolder = getOrMake(game.ReplicatedStorage, 'Folder', 'Modules')
do
    local s = getOrMake(game.StarterPlayer:WaitForChild('StarterPlayerScripts'), 'LocalScript', 'HUDController')
    s.Source = [[
-- HUDController.client.lua
-- Subscribes to player data updates and refreshes HUD state.
-- Place in: StarterPlayer > StarterPlayerScripts > HUDController (LocalScript)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PrankConfig = require(ReplicatedStorage.Modules.PrankConfig)
local CosmeticConfig = require(ReplicatedStorage.Modules.CosmeticConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("MainHUD", 30)
if not hud then warn("[HUDController] No HUD found"); return end

local topBar = hud:WaitForChild("TopBar")
local chaosLabel = topBar:WaitForChild("ChaosLabel")
local levelContainer = topBar:WaitForChild("LevelContainer")
local levelLabel = levelContainer:WaitForChild("LevelLabel")
local xpFill = levelContainer:WaitForChild("XPBarBG"):WaitForChild("XPBarFill")
local rebirthLabel = topBar:WaitForChild("RebirthLabel")

local prankCol = hud:WaitForChild("PrankColumn")

local CurrentData = {}
local CurrentLBData = {}

local function formatNum(n)
    if n >= 1e9 then return string.format("%.2fB", n/1e9) end
    if n >= 1e6 then return string.format("%.2fM", n/1e6) end
    if n >= 1e3 then return string.format("%.1fK", n/1e3) end
    return tostring(math.floor(n))
end

local function refresh()
    if not CurrentData then return end
    chaosLabel.Text = "💚 " .. formatNum(CurrentData.chaosPoints or 0)
    levelLabel.Text = "Level " .. (CurrentData.level or 1)
    rebirthLabel.Text = "👑 " .. (CurrentData.rebirths or 0)
    -- XP bar fill
    local lvl = CurrentData.level or 1
    local xpReq = GameConfig.xpRequired(lvl)
    local pct = math.clamp((CurrentData.xp or 0) / xpReq, 0, 1)
    TweenService:Create(xpFill, TweenInfo.new(0.3), {Size = UDim2.new(pct, 0, 1, 0)}):Play()
    -- Prank locks
    for _, btn in ipairs(prankCol:GetChildren()) do
        if btn:IsA("TextButton") and btn:GetAttribute("PrankName") then
            local unlock = btn:GetAttribute("UnlockLevel")
            local locked = (CurrentData.level or 1) < unlock
            local overlay = btn:FindFirstChild("LockOverlay")
            if overlay then overlay.Visible = locked end
            btn:SetAttribute("Locked", locked)
        end
    end
end

Remotes.UpdatePlayerData.OnClientEvent:Connect(function(data)
    CurrentData = data
    refresh()
end)

Remotes.LevelUp.OnClientEvent:Connect(function(newLevel, unlocked)
    -- Toast
    local toast = hud:FindFirstChild("ToastFrame")
    if toast then
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 0.2
        label.BackgroundColor3 = GameConfig.HUD_ACCENT_COLOR
        label.TextColor3 = Color3.new(0,0,0)
        label.TextScaled = true
        label.Font = Enum.Font.GothamBlack
        label.Text = "LEVEL UP! " .. newLevel
        Instance.new("UICorner", label).CornerRadius = UDim.new(0, 12)
        label.Parent = toast
        task.delay(2.5, function()
            TweenService:Create(label, TweenInfo.new(0.5), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
            task.wait(0.6)
            label:Destroy()
        end)
    end
    if unlocked and #unlocked > 0 then
        for _, prankName in ipairs(unlocked) do
            print("[HUDController] Unlocked prank:", prankName)
        end
    end
end)

Remotes.NotifyClient.OnClientEvent:Connect(function(message, severity)
    local toast = hud:FindFirstChild("ToastFrame")
    if not toast then return end
    local color = severity == "success" and GameConfig.HUD_ACCENT_COLOR or
                  severity == "warn" and Color3.fromRGB(255, 200, 0) or
                  Color3.fromRGB(255, 100, 100)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 0.2
    lbl.BackgroundColor3 = color
    lbl.TextColor3 = Color3.new(0,0,0)
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBlack
    lbl.Text = message
    Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 12)
    lbl.Parent = toast
    task.delay(2.0, function()
        TweenService:Create(lbl, TweenInfo.new(0.5), {BackgroundTransparency = 1, TextTransparency = 1}):Play()
        task.wait(0.6)
        lbl:Destroy()
    end)
end)

Remotes.RebirthCompleted.OnClientEvent:Connect(function(newRebirths, newMult)
    local toast = hud:FindFirstChild("ToastFrame")
    if toast then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
        lbl.TextColor3 = Color3.new(0,0,0)
        lbl.TextScaled = true
        lbl.Font = Enum.Font.GothamBlack
        lbl.Text = "REBIRTH! 👑 " .. newRebirths .. "  x" .. string.format("%.2f", newMult)
        Instance.new("UICorner", lbl).CornerRadius = UDim.new(0, 12)
        lbl.Parent = toast
        task.delay(3, function() lbl:Destroy() end)
    end
end)

Remotes.LeaderboardUpdated.OnClientEvent:Connect(function(top)
    CurrentLBData = top
    local lbModal = hud:FindFirstChild("LeaderboardModal")
    if not lbModal then return end
    local list = lbModal:FindFirstChild("LBList")
    if not list then return end
    -- Clear
    for _, c in ipairs(list:GetChildren()) do
        if c:IsA("TextLabel") then c:Destroy() end
    end
    for i, entry in ipairs(top) do
        local row = Instance.new("TextLabel")
        row.Size = UDim2.new(1, 0, 0, 32)
        row.BackgroundColor3 = i == 1 and Color3.fromRGB(255, 200, 0)
                              or i == 2 and Color3.fromRGB(180, 180, 180)
                              or i == 3 and Color3.fromRGB(180, 100, 50)
                              or Color3.fromRGB(40, 30, 60)
        row.TextColor3 = i <= 3 and Color3.new(0,0,0) or Color3.new(1,1,1)
        row.Font = Enum.Font.GothamBlack
        row.TextScaled = true
        row.LayoutOrder = i
        row.Text = string.format("%d. %s — %s", i, entry.name, formatNum(entry.chaos))
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
        row.Parent = list
    end
end)

-- ===== Modal toggles =====
local function toggle(modalName)
    local m = hud:FindFirstChild(modalName)
    if m then m.Visible = not m.Visible end
end

local botBar = hud:FindFirstChild("BottomBar")
if botBar then
    local shopBtn = botBar:FindFirstChild("ShopButton")
    local invBtn = botBar:FindFirstChild("InventoryButton")
    local rebirthBtn = botBar:FindFirstChild("RebirthButton")
    local lbBtn = botBar:FindFirstChild("LeaderboardButton")

    if shopBtn then shopBtn.MouseButton1Click:Connect(function() toggle("ShopModal"); buildShopList() end) end
    if invBtn then invBtn.MouseButton1Click:Connect(function() toggle("ShopModal"); buildShopList(true) end) end
    if rebirthBtn then
        rebirthBtn.MouseButton1Click:Connect(function()
            local ok, result = Remotes.RequestRebirth:InvokeServer()
            if not ok then
                Remotes.NotifyClient:FireClient -- not callable client-side; instead show toast directly
            end
        end)
    end
    if lbBtn then lbBtn.MouseButton1Click:Connect(function() toggle("LeaderboardModal") end) end
end

-- Close buttons
for _, m in ipairs({hud:FindFirstChild("ShopModal"), hud:FindFirstChild("LeaderboardModal")}) do
    if m then
        local close = m:FindFirstChild("CloseButton")
        if close then close.MouseButton1Click:Connect(function() m.Visible = false end) end
    end
end

-- ===== Shop list builder =====
function buildShopList(inventoryMode)
    local modal = hud:FindFirstChild("ShopModal")
    if not modal then return end
    local list = modal:FindFirstChild("ShopList")
    if not list then return end
    -- Clear
    for _, c in ipairs(list:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
    end
    for _, skinId in ipairs(CosmeticConfig.Order) do
        local skin = CosmeticConfig.Skins[skinId]
        local owned = CurrentData.ownedSkins and table.find(CurrentData.ownedSkins, skinId)
        if inventoryMode and not owned then
            -- inventory mode hides unowned
        else
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -16, 0, 70)
            row.BackgroundColor3 = Color3.fromRGB(40, 25, 60)
            row.BorderSizePixel = 0
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
            row.Parent = list

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(0.4, 0, 0.5, 0)
            nameLabel.Position = UDim2.new(0.02, 0, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = skin.displayName
            nameLabel.TextColor3 = Color3.new(1,1,1)
            nameLabel.Font = Enum.Font.GothamBlack
            nameLabel.TextScaled = true
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.Parent = row

            local rarityLabel = Instance.new("TextLabel")
            rarityLabel.Size = UDim2.new(0.4, 0, 0.5, 0)
            rarityLabel.Position = UDim2.new(0.02, 0, 0.5, 0)
            rarityLabel.BackgroundTransparency = 1
            rarityLabel.Text = skin.rarity .. "  x" .. string.format("%.2f", skin.chaosMultiplier)
            rarityLabel.TextColor3 = skin.rarity == "Legendary" and Color3.fromRGB(255, 200, 0)
                                    or skin.rarity == "Epic" and Color3.fromRGB(200, 50, 255)
                                    or skin.rarity == "Rare" and Color3.fromRGB(80, 150, 255)
                                    or Color3.fromRGB(180, 180, 180)
            rarityLabel.Font = Enum.Font.Gotham
            rarityLabel.TextScaled = true
            rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
            rarityLabel.Parent = row

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0.35, 0, 0.8, 0)
            btn.Position = UDim2.new(0.6, 0, 0.1, 0)
            btn.Font = Enum.Font.GothamBlack
            btn.TextScaled = true
            btn.TextColor3 = Color3.new(1,1,1)
            btn.BorderSizePixel = 0
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            btn.Parent = row

            if owned then
                if CurrentData.equippedSkin == skinId then
                    btn.Text = "EQUIPPED"
                    btn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
                else
                    btn.Text = "EQUIP"
                    btn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
                    btn.MouseButton1Click:Connect(function()
                        Remotes.RequestEquipSkin:InvokeServer(skinId)
                    end)
                end
            else
                if skin.currency == "chaos" then
                    btn.Text = "💚 " .. formatNum(skin.cost)
                    btn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
                    btn.MouseButton1Click:Connect(function()
                        local ok, err = Remotes.RequestPurchaseSkinChaos:InvokeServer(skinId)
                        if not ok then
                            print("Purchase failed:", err)
                        end
                    end)
                else
                    btn.Text = "ROBUX"
                    btn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
                    btn.MouseButton1Click:Connect(function()
                        local gpKey = string.upper(skinId) .. "_SKIN"
                        local gpId = GameConfig.GAMEPASS_IDS[gpKey]
                        if gpId and gpId ~= 0 then
                            MarketplaceService:PromptGamePassPurchase(player, gpId)
                        else
                            print("Gamepass ID not configured for", skinId)
                        end
                    end)
                end
            end
        end
    end
end

return true

]]
end

do
    local s = getOrMake(game.StarterPlayer:WaitForChild('StarterPlayerScripts'), 'LocalScript', 'InputHandler')
    s.Source = [[
-- InputHandler.client.lua
-- Wires HUD buttons (Summon, Pranks) to RemoteEvents. Also handles auto-target finding.
-- Place in: StarterPlayer > StarterPlayerScripts > InputHandler (LocalScript)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local PrankConfig = require(ReplicatedStorage.Modules.PrankConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("MainHUD", 30)
if not hud then return end

local summonBtn = hud:WaitForChild("SummonButton")
local prankCol = hud:WaitForChild("PrankColumn")

-- ===== Find nearest valid NPC =====
local function nearestNPC(maxRange)
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local folder = Workspace:FindFirstChild("PrankNPCs")
    if not folder then return nil end
    local closest, dist = nil, math.huge
    for _, m in ipairs(folder:GetChildren()) do
        if m:IsA("Model") and m:GetAttribute("KittyRaiserNPC") and not m:GetAttribute("Pranked") then
            local p = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
            if p then
                local d = (p.Position - hrp.Position).Magnitude
                if d < dist and d <= maxRange then
                    dist = d
                    closest = m
                end
            end
        end
    end
    return closest
end

-- ===== Button pop animation =====
local function pop(btn)
    local origSize = btn.Size
    local big = UDim2.new(origSize.X.Scale, origSize.X.Offset + 8, origSize.Y.Scale, origSize.Y.Offset + 8)
    TweenService:Create(btn, TweenInfo.new(0.08), {Size = big}):Play()
    task.delay(0.08, function()
        TweenService:Create(btn, TweenInfo.new(0.1), {Size = origSize}):Play()
    end)
end

-- ===== Summon =====
summonBtn.MouseButton1Click:Connect(function()
    pop(summonBtn)
    Remotes.RequestSummonHuman:FireServer()
end)

-- ===== Prank buttons =====
local prankBtnCooldowns = {} -- visual cooldown only
for _, btn in ipairs(prankCol:GetChildren()) do
    if btn:IsA("TextButton") and btn:GetAttribute("PrankName") then
        local prankName = btn:GetAttribute("PrankName")
        local prank = PrankConfig.Pranks[prankName]
        btn.MouseButton1Click:Connect(function()
            if btn:GetAttribute("Locked") then
                return
            end
            if prankBtnCooldowns[prankName] and os.clock() < prankBtnCooldowns[prankName] then
                return
            end
            local npc = nearestNPC(prank.rangeStuds)
            if not npc then
                -- nothing in range
                return
            end
            pop(btn)
            Remotes.RequestPrank:FireServer(prankName, npc)
            -- Visual cooldown overlay
            prankBtnCooldowns[prankName] = os.clock() + prank.cooldown
            local cdOverlay = btn:FindFirstChild("CooldownOverlay")
            if cdOverlay then
                cdOverlay.Visible = true
                cdOverlay.Size = UDim2.new(1, 0, 1, 0)
                local tween = TweenService:Create(cdOverlay, TweenInfo.new(prank.cooldown, Enum.EasingStyle.Linear), {Size = UDim2.new(1, 0, 0, 0)})
                tween:Play()
                tween.Completed:Connect(function() cdOverlay.Visible = false end)
            end
        end)
    end
end

-- Keyboard shortcuts (PC) for power users
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.E then
        Remotes.RequestSummonHuman:FireServer()
    elseif input.KeyCode == Enum.KeyCode.One then
        local b = prankCol:FindFirstChild("Prank_Pie")
        if b and not b:GetAttribute("Locked") then
            local npc = nearestNPC(PrankConfig.Pranks.Pie.rangeStuds)
            if npc then Remotes.RequestPrank:FireServer("Pie", npc) end
        end
    elseif input.KeyCode == Enum.KeyCode.Two then
        local b = prankCol:FindFirstChild("Prank_Anvil")
        if b and not b:GetAttribute("Locked") then
            local npc = nearestNPC(PrankConfig.Pranks.Anvil.rangeStuds)
            if npc then Remotes.RequestPrank:FireServer("Anvil", npc) end
        end
    elseif input.KeyCode == Enum.KeyCode.Three then
        local b = prankCol:FindFirstChild("Prank_FartCloud")
        if b and not b:GetAttribute("Locked") then
            local npc = nearestNPC(PrankConfig.Pranks.FartCloud.rangeStuds)
            if npc then Remotes.RequestPrank:FireServer("FartCloud", npc) end
        end
    elseif input.KeyCode == Enum.KeyCode.Four then
        local b = prankCol:FindFirstChild("Prank_LaserEyes")
        if b and not b:GetAttribute("Locked") then
            local npc = nearestNPC(PrankConfig.Pranks.LaserEyes.rangeStuds)
            if npc then Remotes.RequestPrank:FireServer("LaserEyes", npc) end
        end
    end
end)

return true

]]
end

do
    local s = getOrMake(game.StarterPlayer:WaitForChild('StarterPlayerScripts'), 'LocalScript', 'EffectsController')
    s.Source = [[
-- EffectsController.client.lua
-- Plays prank visual + audio effects on PrankRegistered events.
-- Place in: StarterPlayer > StarterPlayerScripts > EffectsController (LocalScript)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local PrankConfig = require(ReplicatedStorage.Modules.PrankConfig)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

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

print('[KittyRaiser] chunk 4/5 loaded - 5 scripts')
