-- TutorialController.client.lua
-- First-session tutorial: short tooltips on first summon and first prank.
-- This is now the ONLY tutorial script (TutorialFlow + OnboardingFlow deleted
-- to eliminate competing ScreenGuis and conflicting attribute flags).
-- Place in: StarterPlayer > StarterPlayerScripts > TutorialController (LocalScript)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud = playerGui:WaitForChild("MainHUD", 60)
if not hud then return end

local tooltip = hud:WaitForChild("TutorialTooltip")
local txt = tooltip:WaitForChild("Text")

local seenSummon = false
local seenPrank = false

local function show(message, ms)
    txt.Text = message
    tooltip.Visible = true
    if ms then
        task.delay(ms / 1000, function()
            if tooltip then tooltip.Visible = false end
        end)
    end
end

task.delay(2, function()
    if not seenSummon then
        show("Tap SUMMON HUMAN to spawn your first victim", 6000)
    end
end)

Remotes.UpdatePlayerData.OnClientEvent:Connect(function(data)
    if data.totalPranks and data.totalPranks > 0 and not seenPrank then
        seenPrank = true
        show("Nice! Reach Level 5 to unlock Anvil. Tap SHOP for cosmetics.", 5000)
    end
    if data.seenTutorial then
        seenSummon = true; seenPrank = true
    end
end)

task.spawn(function()
    while not seenSummon do
        task.wait(0.5)
        for _, folderName in ipairs({"PrankNPCs"}) do
            local folder = Workspace:FindFirstChild(folderName)
            if folder then
                for _, m in ipairs(folder:GetChildren()) do
                    if m:GetAttribute("SummonedBy") == player.UserId then
                        seenSummon = true
                        show("Walk close, then tap PIE to throw a pie!", 6000)
                        return
                    end
                end
            end
        end
    end
end)

return true
