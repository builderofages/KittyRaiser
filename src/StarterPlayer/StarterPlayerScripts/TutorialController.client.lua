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
