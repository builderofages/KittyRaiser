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

-- v3.60 fix: click-to-attack. Players didn't realize they could prank, so
-- mouse-click anywhere fires the strongest UNLOCKED prank against the
-- nearest valid NPC. Falls through to default click behavior if no NPC
-- in range. ButtonOrder priority: latest unlocked = strongest.
local function bestUnlockedPrank()
    -- Read from actual UI state so we match what the player sees. Iterate
    -- highest-tier first; first unlocked button wins.
    for i = #PrankConfig.Order, 1, -1 do
        local name = PrankConfig.Order[i]
        local b = prankCol:FindFirstChild("Prank_" .. name)
        if b and not b:GetAttribute("Locked") then return name end
    end
    return nil
end
local lastMouseFire = 0
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        local now = os.clock()
        if now - lastMouseFire < 0.3 then return end
        local prankName = bestUnlockedPrank()
        if not prankName then return end
        local prank = PrankConfig.Pranks[prankName]
        local npc = nearestNPC(prank.rangeStuds)
        if npc then
            lastMouseFire = now
            Remotes.RequestPrank:FireServer(prankName, npc)
        else
            -- Click missed: brief toast so player knows nothing's in range.
            -- Throttle the toast itself separately so spam-clicking doesn't flood.
            if now - lastMouseFire > 1.5 then
                lastMouseFire = now
                local hud = playerGui:FindFirstChild("MainHUD")
                local toastFrame = hud and hud:FindFirstChild("ToastFrame")
                if toastFrame then
                    pcall(function()
                        local UIUtil = require(ReplicatedStorage.Modules.UIUtil)
                        UIUtil.makeToast(toastFrame,
                            "MOVE CLOSER  -  no target in range",
                            Color3.fromRGB(180, 130, 60), 1.6)
                    end)
                end
            end
        end
        return
    end
    if input.KeyCode == Enum.KeyCode.E then
        Remotes.RequestSummonHuman:FireServer()
        return
    end
    -- Hotkeys 1..8 map to PrankConfig.Order slot index (matches the bar
    -- left-to-right + the on-button '1'..'8' badge added in v3.63).
    local NUM_TO_SLOT = {
        [Enum.KeyCode.One]   = 1, [Enum.KeyCode.Two]   = 2,
        [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four]  = 4,
        [Enum.KeyCode.Five]  = 5, [Enum.KeyCode.Six]   = 6,
        [Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8,
    }
    local slot = NUM_TO_SLOT[input.KeyCode]
    if slot then
        local prankName = PrankConfig.Order[slot]
        if not prankName then return end
        local b = prankCol:FindFirstChild("Prank_" .. prankName)
        if not b or b:GetAttribute("Locked") then return end
        local prank = PrankConfig.Pranks[prankName]
        local npc = nearestNPC(prank.rangeStuds)
        if npc then Remotes.RequestPrank:FireServer(prankName, npc) end
    end
end)

return true
