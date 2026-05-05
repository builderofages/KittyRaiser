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
local UIUtil       = require(ReplicatedStorage.Modules:WaitForChild("UIUtil"))
local AssetIds     = require(ReplicatedStorage.Modules:WaitForChild("AssetIds"))
local AudioGroups  = require(ReplicatedStorage.Modules:WaitForChild("AudioGroups"))
local SoundService = game:GetService("SoundService")
local Debris       = game:GetService("Debris")

local function playSoundIfHas(name, vol)
    if not AssetIds.has(name) then return end
    local s = Instance.new("Sound")
    s.SoundId = AssetIds[name]
    s.Volume = vol or 0.7
    AudioGroups.assign(s, "UI")
    s.Parent = SoundService
    s:Play()
    Debris:AddItem(s, 4)
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("MainHUD", 30)
if not hud then warn("[HUDController] No HUD found"); return end

-- Stack of active toasts so they don't pile on top of each other
local function spawnToast(text, color, duration)
    local toastFrame = hud:FindFirstChild("ToastFrame")
    if not toastFrame then return end
    local existing = 0
    for _, c in ipairs(toastFrame:GetChildren()) do
        if c:IsA("Frame") then existing = existing + 1 end
    end
    local t = UIUtil.makeToast(toastFrame, text, color, duration or 2.5)
    t.Position = UDim2.new(0.5, 0, 0, existing * 56 - 60)
    task.delay(0.05, function()
        TweenService:Create(t, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            {Position = UDim2.new(0.5, 0, 0, existing * 56)}):Play()
    end)
end

local topBar         = hud:WaitForChild("TopBar")
local chaosWrap      = topBar:WaitForChild("ChaosWrap")
local chaosLabel     = chaosWrap:WaitForChild("ChaosLabel")
local hellWrap       = topBar:WaitForChild("HellWrap")
local hellLabel      = hellWrap:WaitForChild("HellLabel")
local levelContainer = topBar:WaitForChild("LevelContainer")
local levelLabel     = levelContainer:WaitForChild("LevelLabel")
local xpBarBg        = levelContainer:WaitForChild("XPBarBG")
local xpFill         = xpBarBg:WaitForChild("XPBarFill")
local xpText         = xpBarBg:WaitForChild("XPText")
local rebirthWrap    = topBar:WaitForChild("RebirthWrap")
local rebirthLabel   = rebirthWrap:WaitForChild("RebirthLabel")

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
    chaosLabel.Text   = formatNum(CurrentData.chaosPoints or 0)
    hellLabel.Text    = formatNum(CurrentData.hellTokens or 0)
    levelLabel.Text   = "Level " .. (CurrentData.level or 1)
    rebirthLabel.Text = tostring(CurrentData.rebirths or 0)
    -- XP bar fill + numeric overlay
    local lvl = CurrentData.level or 1
    local xp  = CurrentData.xp or 0
    local xpReq = GameConfig.xpRequired(lvl)
    local pct = math.clamp(xp / xpReq, 0, 1)
    TweenService:Create(xpFill, TweenInfo.new(0.3), {Size = UDim2.new(pct, 0, 1, 0)}):Play()
    xpText.Text = ("Lv %d  -  %s / %s XP"):format(lvl, formatNum(xp), formatNum(xpReq))
    -- Prank locks
    for _, btn in ipairs(prankCol:GetChildren()) do
        if btn:IsA("TextButton") and btn:GetAttribute("PrankName") then
            local unlock = btn:GetAttribute("UnlockLevel")
            local locked = (CurrentData.level or 1) < unlock
            local overlay = btn:FindFirstChild("LockOverlay")
            if overlay then overlay.Visible = locked end
            -- v3.76: also toggle FallbackLabel (PIE/HAI/ANV ASCII) so unlocked
            -- slots show their prank label, locked slots hide it (LV X overlay reads cleanly)
            local fb = btn:FindFirstChild("FallbackLabel")
            if fb then fb.Visible = not locked end
            btn:SetAttribute("Locked", locked)
        end
    end
end

Remotes.UpdatePlayerData.OnClientEvent:Connect(function(data)
    CurrentData = data
    refresh()
end)

Remotes.LevelUp.OnClientEvent:Connect(function(newLevel, unlocked)
    spawnToast("LEVEL UP!  " .. newLevel, Color3.fromRGB(50, 220, 100), 2.5)
    playSoundIfHas("level_up", 0.8)
    -- v3.76: refresh slot lock UI immediately on level up (don't wait for UpdatePlayerData race)
    if CurrentData then
        CurrentData.level = newLevel
        refresh()
    end
    if unlocked and #unlocked > 0 then
        for _, prankName in ipairs(unlocked) do
            spawnToast("NEW PRANK UNLOCKED:  " .. prankName, Color3.fromRGB(255, 200, 0), 3.5)
            -- Visual flash on the unlocked slot
            local btn = prankCol:FindFirstChild("Prank_" .. prankName)
            if btn then
                local flash = Instance.new("Frame", btn)
                flash.Size = UDim2.fromScale(1, 1); flash.BackgroundColor3 = Color3.fromRGB(255, 230, 80)
                flash.BackgroundTransparency = 0.3; flash.ZIndex = 10
                Instance.new("UICorner", flash).CornerRadius = UDim.new(0, 8)
                game:GetService("TweenService"):Create(flash, TweenInfo.new(0.8),
                    {BackgroundTransparency = 1}):Play()
                game:GetService("Debris"):AddItem(flash, 1.0)
            end
        end
    end
end)

Remotes.NotifyClient.OnClientEvent:Connect(function(message, severity)
    local color = severity == "success" and Color3.fromRGB(50, 200, 100) or
                  severity == "warn"    and Color3.fromRGB(255, 200, 0)   or
                                           Color3.fromRGB(255, 90, 100)
    spawnToast(message, color, 2.0)
end)

Remotes.RebirthCompleted.OnClientEvent:Connect(function(newRebirths, newMult)
    spawnToast("REBIRTH  ·  " .. newRebirths .. "  ·  x" .. string.format("%.2f", newMult),
               Color3.fromRGB(255, 200, 0), 3.0)
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
                              or i == 2 and Color3.fromRGB(190, 190, 195)
                              or i == 3 and Color3.fromRGB(180, 100, 50)
                              or Color3.fromRGB(40, 30, 60)
        row.TextColor3 = i <= 3 and Color3.new(0,0,0) or Color3.new(1,1,1)
        row.Font = Enum.Font.GothamBlack
        row.TextScaled = true
        row.LayoutOrder = i
        row.Text = string.format("%d. %s — %s", i, entry.name, formatNum(entry.chaos))
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
        row.Parent = list
        UIUtil.boundText(row, 14, 20)
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
            print("[HUDController] REBIRTH clicked")
            local ok, result = pcall(function() return Remotes.RequestRebirth:InvokeServer() end)
            if not ok then
                warn("[HUDController] RequestRebirth failed:", result)
            end
        end)
    end
    if lbBtn then
        lbBtn.MouseButton1Click:Connect(function()
            print("[HUDController] TOP/Leaderboard clicked")
            toggle("LeaderboardModal")
        end)
    end
    -- v3.65: add console logs to verify wiring at runtime
    if shopBtn then print("[HUDController] SHOP wired") end
    if invBtn then print("[HUDController] INV wired") end
    if rebirthBtn then print("[HUDController] REBIRTH wired") end
    if lbBtn then print("[HUDController] TOP wired") end
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
            UIUtil.boundText(nameLabel, 14, 22)

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
            UIUtil.boundText(rarityLabel, 12, 18)

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
                    btn.Text = formatNum(skin.cost) .. "  CHAOS"
                    btn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
                    -- Coin icon inside the button
                    if AssetIds.has("coin") then
                        local ic = Instance.new("ImageLabel")
                        ic.Size = UDim2.new(0, 22, 0, 22)
                        ic.Position = UDim2.new(0, 6, 0.5, -11)
                        ic.BackgroundTransparency = 1
                        ic.Image = AssetIds.coin
                        ic.Parent = btn
                    end
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
