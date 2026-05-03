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
local hud = playerGui:WaitForChild("MainHUD", 60)
if not hud then
    -- Surface failure visibly instead of silently disabling all input.
    local fallback = Instance.new("ScreenGui", playerGui)
    fallback.Name = "InputHandlerError"
    local lbl = Instance.new("TextLabel", fallback)
    lbl.Size = UDim2.new(0, 320, 0, 60)
    lbl.Position = UDim2.new(0.5, -160, 0, 20)
    lbl.BackgroundColor3 = Color3.fromRGB(80, 0, 0)
    lbl.TextColor3 = Color3.fromRGB(255, 200, 200)
    lbl.Text = "HUD failed to load. Rejoin."
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    return
end

local summonBtn = hud:WaitForChild("SummonButton")
local prankCol = hud:WaitForChild("PrankColumn")

local function nearestNPC(maxRange)
    local char = player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local closest, dist = nil, math.huge
    -- Search BOTH summoned NPCs and ambient pedestrians.
    for _, folderName in ipairs({"PrankNPCs", "AmbientCrowd"}) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            for _, m in ipairs(folder:GetChildren()) do
                if m:IsA("Model") and m:GetAttribute("KittyRaiserNPC") and not m:GetAttribute("Pranked") then
                    local p = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
                    if p then
                        local d = (p.Position - hrp.Position).Magnitude
                        if d < dist and d <= maxRange then
                            dist = d; closest = m
                        end
                    end
                end
            end
        end
    end
    return closest
end

local function pop(btn)
    local origSize = btn.Size
    local big = UDim2.new(origSize.X.Scale, origSize.X.Offset + 8, origSize.Y.Scale, origSize.Y.Offset + 8)
    TweenService:Create(btn, TweenInfo.new(0.08), {Size = big}):Play()
    task.delay(0.08, function()
        TweenService:Create(btn, TweenInfo.new(0.1), {Size = origSize}):Play()
    end)
end

summonBtn.MouseButton1Click:Connect(function()
    pop(summonBtn)
    Remotes.RequestSummonHuman:FireServer()
end)

local prankBtnCooldowns = {}
local function tryPrank(prankName, btn)
    if not btn or btn:GetAttribute("Locked") then return end
    if prankBtnCooldowns[prankName] and os.clock() < prankBtnCooldowns[prankName] then return end
    local prank = PrankConfig.Pranks[prankName]
    if not prank then return end
    local npc = nearestNPC(prank.rangeStuds)
    if not npc then return end
    pop(btn)
    Remotes.RequestPrank:FireServer(prankName, npc)
    prankBtnCooldowns[prankName] = os.clock() + prank.cooldown
    local cdOverlay = btn:FindFirstChild("CooldownOverlay")
    if cdOverlay then
        cdOverlay.Visible = true
        cdOverlay.Size = UDim2.new(1, 0, 1, 0)
        local tween = TweenService:Create(cdOverlay,
            TweenInfo.new(prank.cooldown, Enum.EasingStyle.Linear),
            {Size = UDim2.new(1, 0, 0, 0)})
        tween:Play()
        tween.Completed:Connect(function() cdOverlay.Visible = false end)
    end
end

for _, btn in ipairs(prankCol:GetChildren()) do
    if btn:IsA("TextButton") and btn:GetAttribute("PrankName") then
        local prankName = btn:GetAttribute("PrankName")
        btn.MouseButton1Click:Connect(function() tryPrank(prankName, btn) end)
    end
end

-- Keyboard shortcuts. Skip if player is typing in chat (gp = true means
-- another GUI consumed the input).
local KEY_TO_PRANK = {
    [Enum.KeyCode.One]   = "Pie",
    [Enum.KeyCode.Two]   = "Anvil",
    [Enum.KeyCode.Three] = "FartCloud",
    [Enum.KeyCode.Four]  = "LaserEyes",
}
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.E then
        Remotes.RequestSummonHuman:FireServer()
        return
    end
    local prankName = KEY_TO_PRANK[input.KeyCode]
    if prankName then
        local btn = prankCol:FindFirstChild("Prank_" .. prankName)
        tryPrank(prankName, btn)
    end
end)

return true
