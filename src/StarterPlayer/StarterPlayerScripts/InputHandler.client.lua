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

-- v291 hotfix: SummonButton was nuked from HUD. Use 2sec timeout, optional.
local summonBtn = hud:WaitForChild("SummonButton", 2)
local prankCol = hud:WaitForChild("PrankColumn")

-- ===== Find nearest valid NPC =====
local function nearestNPC(maxRange)
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    -- v3.65 fix: check BOTH PrankNPCs (summoned) AND AmbientCrowd (ambient pedestrians)
    -- so player click works on any visible NPC. Previously only summoned ones counted.
    local folders = {Workspace:FindFirstChild("PrankNPCs"), Workspace:FindFirstChild("AmbientCrowd")}
    local closest, dist = nil, math.huge
    for _, folder in ipairs(folders) do
        if folder then
            for _, m in ipairs(folder:GetChildren()) do
                if m:IsA("Model") and (m:GetAttribute("KittyRaiserNPC") or m:GetAttribute("AmbientNPC")) and not m:GetAttribute("Pranked") then
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
        end
    end
    return closest
end

-- v3.95: raycast from camera to exact click/tap position for precise NPC targeting
local camera = workspace.CurrentCamera
local function rayCastForNPC(screenPos)
    local unitRay = camera:ScreenPointToRay(screenPos.X, screenPos.Y)
    local params  = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local char = player.Character
    if char then params.FilterDescendantsInstances = {char} end
    local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 80, params)
    if not result then return nil end
    -- Check model at hit point
    local model = result.Instance:FindFirstAncestorOfClass('Model')
    if model and (model:GetAttribute('KittyRaiserNPC') or model:GetAttribute('AmbientNPC'))
        and not model:GetAttribute('Pranked') then
        _G.KR_LastTarget = model
        return model
    end
    -- Sphere fallback for HitZone parts
    local op = OverlapParams.new()
    op.FilterType = Enum.RaycastFilterType.Exclude
    if char then op.FilterDescendantsInstances = {char} end
    for _, part in ipairs(workspace:GetPartBoundsInRadius(result.Position, 4, op)) do
        local m = part:FindFirstAncestorOfClass('Model')
        if m and (m:GetAttribute('KittyRaiserNPC') or m:GetAttribute('AmbientNPC'))
            and not m:GetAttribute('Pranked') then
            _G.KR_LastTarget = m
            return m
        end
    end
    return nil
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

-- ===== Summon (button optional in v291+; press E key as primary) =====
if summonBtn then
    summonBtn.MouseButton1Click:Connect(function()
        pop(summonBtn)
        Remotes.RequestSummonHuman:FireServer()
    end)
end
-- E key always summons regardless of button presence
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.E then
        Remotes.RequestSummonHuman:FireServer()
    end
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
        print("[InputHandler] click detected")
        local now = os.clock()
        if now - lastMouseFire < 0.3 then return end
        local prankName = bestUnlockedPrank()
        if not prankName then return end
        local prank = PrankConfig.Pranks[prankName]
        local npc = rayCastForNPC(input.Position) or nearestNPC(prank.rangeStuds)
        if npc then
            _G.KR_LastTarget = npc
            lastMouseFire = now
            Remotes.RequestPrank:FireServer(prankName, npc)
        else
            -- v3.64: click with no target -> auto-summon a civilian and
            -- queue the attack for when it lands. Player click ALWAYS does
            -- something; no more dead clicks early-game.
            if now - lastMouseFire > 1.0 then
                lastMouseFire = now
                Remotes.RequestSummonHuman:FireServer()
                task.delay(1.2, function()
                    local n = nearestNPC(prank.rangeStuds * 1.6)
                    if n then Remotes.RequestPrank:FireServer(prankName, n) end
                end)
            end
        end
        return
    end
    if input.KeyCode == Enum.KeyCode.E then
        -- v3.99.11: don't fire summon if a car/mount ProximityPrompt is in range
        local Workspace = game:GetService("Workspace")
        local char = player.Character
        if char and char.PrimaryPart then
            local pos = char.PrimaryPart.Position
            for _, folder in ipairs({Workspace:FindFirstChild("DrivableVehicles"), Workspace:FindFirstChild("Mounts")}) do
                if folder then
                    for _, m in ipairs(folder:GetChildren()) do
                        local seat = m:FindFirstChildOfClass("VehicleSeat") or m:FindFirstChildOfClass("Seat")
                        if seat and (seat.Position - pos).Magnitude < 14 then
                            return  -- let ProximityPrompt handle E
                        end
                    end
                end
            end
        end
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
