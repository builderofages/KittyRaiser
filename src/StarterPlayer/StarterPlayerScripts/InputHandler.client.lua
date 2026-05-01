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
