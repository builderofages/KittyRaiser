-- TradePanel.client.lua  v1 — UI for TradingSystem.
-- Trigger: chat-style /trade <PlayerName> OR proximity prompt on other
-- players (we use the proximity path so it's discoverable).
--
-- Modal shows:
--   * Two halves (yours / theirs), each with 5 offer slots + add-from-inventory
--   * READY toggle button per side
--   * Lock countdown bar when both ready
--   * CANCEL / CLOSE button

local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")

local Remotes  = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local UIUtil   = require(ReplicatedStorage.Modules.UIUtil)
local CosmeticConfig = require(ReplicatedStorage.Modules.CosmeticConfig)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RequestStartTrade, RequestOfferItem, RequestSetReady, RequestCancelTrade, TradeStateUpdate
task.spawn(function()
    local f = ReplicatedStorage:WaitForChild("RemoteEventsFolder", 30)
    RequestStartTrade   = f:WaitForChild("RequestStartTrade", 30)
    RequestOfferItem    = f:WaitForChild("RequestOfferItem", 30)
    RequestSetReady     = f:WaitForChild("RequestSetReady", 30)
    RequestCancelTrade  = f:WaitForChild("RequestCancelTrade", 30)
    TradeStateUpdate    = f:WaitForChild("TradeStateUpdate", 30)
    if TradeStateUpdate then
        TradeStateUpdate.OnClientEvent:Connect(function(snap) onState(snap) end)
    end
end)

local cachedData = {}
Remotes.UpdatePlayerData.OnClientEvent:Connect(function(d)
    if typeof(d) == "table" then cachedData = d end
end)

local sg = Instance.new("ScreenGui", playerGui)
sg.Name = "TradePanel"
sg.IgnoreGuiInset = true
sg.ResetOnSpawn = false
sg.DisplayOrder = (UIUtil.DisplayOrder.Modal or 60) + 4
sg.Enabled = false

local backdrop = Instance.new("Frame", sg)
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.5

local modal = Instance.new("Frame", sg)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.Size = UDim2.fromOffset(720, 480)
modal.BackgroundColor3 = Color3.fromRGB(245, 230, 200)
Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 14)
local ms = Instance.new("UIStroke", modal); ms.Thickness = 4; ms.Color = Color3.fromRGB(110, 75, 45)

local title = Instance.new("TextLabel", modal)
title.Size = UDim2.new(1, -40, 0, 44)
title.Position = UDim2.fromOffset(20, 12)
title.BackgroundTransparency = 1
title.Text = "TRADE"
title.Font = Enum.Font.LuckiestGuy
title.TextScaled = true
title.TextColor3 = Color3.fromRGB(80, 40, 20)
title.TextXAlignment = Enum.TextXAlignment.Left
local tc = Instance.new("UITextSizeConstraint", title); tc.MinTextSize = 18; tc.MaxTextSize = 32

local close = Instance.new("TextButton", modal)
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -12, 0, 12)
close.Size = UDim2.fromOffset(36, 36)
close.BackgroundColor3 = Color3.fromRGB(220, 100, 80)
close.Text = "X"
close.Font = Enum.Font.GothamBlack
close.TextColor3 = Color3.fromRGB(255, 248, 230)
close.TextScaled = true
Instance.new("UICorner", close).CornerRadius = UDim.new(1, 0)

-- Two halves: left = YOU, right = OTHER
local function makeHalf(parent, anchorX, label)
    local f = Instance.new("Frame", parent)
    f.AnchorPoint = Vector2.new(anchorX, 0)
    f.Position = (anchorX == 0) and UDim2.fromOffset(20, 64) or UDim2.new(1, -20, 0, 64)
    f.Size = UDim2.fromOffset(330, 380)
    f.BackgroundColor3 = Color3.fromRGB(225, 215, 195)
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
    local fs = Instance.new("UIStroke", f); fs.Thickness = 2; fs.Color = Color3.fromRGB(140, 120, 100)
    local hl = Instance.new("TextLabel", f)
    hl.Size = UDim2.new(1, 0, 0, 26)
    hl.BackgroundTransparency = 1
    hl.Text = label; hl.Font = Enum.Font.GothamBold; hl.TextScaled = true
    hl.TextColor3 = Color3.fromRGB(80, 40, 20)
    local hc = Instance.new("UITextSizeConstraint", hl); hc.MinTextSize = 12; hc.MaxTextSize = 18
    -- 5 offer slots (vertical)
    local slots = {}
    for i = 1, 5 do
        local slot = Instance.new("TextButton", f)
        slot.Size = UDim2.new(1, -16, 0, 40)
        slot.Position = UDim2.fromOffset(8, 32 + (i - 1) * 46)
        slot.BackgroundColor3 = Color3.fromRGB(255, 245, 215)
        slot.Text = "(empty)"
        slot.Font = Enum.Font.GothamMedium
        slot.TextColor3 = Color3.fromRGB(140, 120, 100)
        slot.TextScaled = true
        Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 6)
        local sc = Instance.new("UITextSizeConstraint", slot); sc.MinTextSize = 10; sc.MaxTextSize = 14
        slots[i] = slot
    end
    local readyBtn = Instance.new("TextButton", f)
    readyBtn.Size = UDim2.new(1, -16, 0, 40)
    readyBtn.Position = UDim2.fromOffset(8, 320)
    readyBtn.BackgroundColor3 = Color3.fromRGB(140, 120, 100)
    readyBtn.Text = "NOT READY"
    readyBtn.Font = Enum.Font.GothamBold
    readyBtn.TextColor3 = Color3.fromRGB(255, 248, 230)
    readyBtn.TextScaled = true
    Instance.new("UICorner", readyBtn).CornerRadius = UDim.new(0, 8)
    local rc = Instance.new("UITextSizeConstraint", readyBtn); rc.MinTextSize = 12; rc.MaxTextSize = 16
    return f, slots, readyBtn
end

local _, mySlots, myReady = makeHalf(modal, 0, "YOU")
local _, theirSlots, theirReady = makeHalf(modal, 1, "OPPONENT")

local lockBar = Instance.new("Frame", modal)
lockBar.Size = UDim2.new(1, -40, 0, 16)
lockBar.Position = UDim2.new(0, 20, 1, -28)
lockBar.BackgroundColor3 = Color3.fromRGB(180, 140, 80)
lockBar.Visible = false
Instance.new("UICorner", lockBar).CornerRadius = UDim.new(1, 0)
local lockFill = Instance.new("Frame", lockBar)
lockFill.Size = UDim2.fromScale(0, 1)
lockFill.BackgroundColor3 = Color3.fromRGB(255, 220, 80)
lockFill.BorderSizePixel = 0
Instance.new("UICorner", lockFill).CornerRadius = UDim.new(1, 0)

local currentSnap

function onState(snap)
    currentSnap = snap
    if snap.state == "ended" then
        sg.Enabled = false
        return
    end
    sg.Enabled = true
    title.Text = "TRADE  -  " .. (snap.state or "")
    -- Render YOUR offers
    local myOffers = snap.offers and snap.offers[player.UserId] or {}
    for i = 1, 5 do
        local s = mySlots[i]
        local id = myOffers[i]
        if id then
            local skin = CosmeticConfig.Skins[id]
            s.Text = skin and skin.displayName or id
            s.BackgroundColor3 = Color3.fromRGB(110, 165, 95)
            s.TextColor3 = Color3.fromRGB(255, 248, 230)
        else
            s.Text = "+ ADD ITEM"
            s.BackgroundColor3 = Color3.fromRGB(255, 245, 215)
            s.TextColor3 = Color3.fromRGB(140, 120, 100)
        end
    end
    -- Render THEIR offers
    local theirUid = (snap.p1Name and Players.LocalPlayer.DisplayName ~= snap.p1Name) and "p1" or "p2"
    -- Find their offers by iterating
    local theirOffers = {}
    if snap.offers then
        for uid, offers in pairs(snap.offers) do
            if uid ~= player.UserId then theirOffers = offers; break end
        end
    end
    for i = 1, 5 do
        local s = theirSlots[i]
        local id = theirOffers[i]
        if id then
            local skin = CosmeticConfig.Skins[id]
            s.Text = skin and skin.displayName or id
            s.BackgroundColor3 = Color3.fromRGB(110, 165, 95)
            s.TextColor3 = Color3.fromRGB(255, 248, 230)
        else
            s.Text = "(empty)"
            s.BackgroundColor3 = Color3.fromRGB(255, 245, 215)
            s.TextColor3 = Color3.fromRGB(140, 120, 100)
        end
    end
    -- Ready buttons
    local myR = snap.ready and snap.ready[player.UserId]
    myReady.Text = myR and "READY" or "NOT READY"
    myReady.BackgroundColor3 = myR and Color3.fromRGB(110, 165, 95) or Color3.fromRGB(140, 120, 100)
    local theirR
    if snap.ready then
        for uid, r in pairs(snap.ready) do
            if uid ~= player.UserId then theirR = r; break end
        end
    end
    theirReady.Text = theirR and "READY" or "NOT READY"
    theirReady.BackgroundColor3 = theirR and Color3.fromRGB(110, 165, 95) or Color3.fromRGB(140, 120, 100)
    -- Lock countdown
    if snap.state == "locked" and snap.lockStartIn then
        lockBar.Visible = true
        local pct = math.clamp(snap.lockStartIn / 5, 0, 1)
        lockFill.Size = UDim2.fromScale(pct, 1)
    else
        lockBar.Visible = false
    end
end

-- Slot click: add owned skin (cycle) — picks the first un-offered owned non-equipped skin
local function pickAddable()
    if not cachedData.ownedSkins then return nil end
    local current = currentSnap and currentSnap.offers and currentSnap.offers[player.UserId] or {}
    for _, skinId in ipairs(cachedData.ownedSkins) do
        if cachedData.equippedSkin ~= skinId and not table.find(current, skinId) then
            return skinId
        end
    end
    return nil
end
for i, s in ipairs(mySlots) do
    s.MouseButton1Click:Connect(function()
        if not currentSnap or currentSnap.state ~= "offering" then return end
        local existing = currentSnap.offers and currentSnap.offers[player.UserId] or {}
        local existingId = existing[i]
        if existingId and RequestOfferItem then
            -- Click to remove
            pcall(function() RequestOfferItem:InvokeServer(existingId, false) end)
        else
            local toAdd = pickAddable()
            if toAdd and RequestOfferItem then
                pcall(function() RequestOfferItem:InvokeServer(toAdd, true) end)
            end
        end
    end)
end
myReady.MouseButton1Click:Connect(function()
    if not RequestSetReady then return end
    local cur = currentSnap and currentSnap.ready and currentSnap.ready[player.UserId]
    pcall(function() RequestSetReady:InvokeServer(not cur) end)
end)
close.MouseButton1Click:Connect(function()
    if RequestCancelTrade then pcall(function() RequestCancelTrade:InvokeServer() end) end
    sg.Enabled = false
end)

-- /trade chat command + proximity-based start
local function tryStartWithNearestPlayer()
    local char = player.Character
    if not char or not char.PrimaryPart then return end
    local nearest, nd = nil, 25
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character and p.Character.PrimaryPart then
            local d = (p.Character.PrimaryPart.Position - char.PrimaryPart.Position).Magnitude
            if d < nd then nd = d; nearest = p end
        end
    end
    if nearest and RequestStartTrade then
        pcall(function() RequestStartTrade:InvokeServer(nearest.UserId) end)
    end
end

-- Hotkey T to start trade with nearest player
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.T then
        tryStartWithNearestPlayer()
    end
end)

print("[TradePanel v1] online - press T near another player to start a trade")
