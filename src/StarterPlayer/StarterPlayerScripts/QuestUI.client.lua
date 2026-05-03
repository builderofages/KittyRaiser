-- QuestUI.client.lua
-- Bottom-bar quests button → modal showing today's 3 quests with progress bars
-- and claim buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local QuestConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("QuestConfig"))

local player = Players.LocalPlayer
local hud = player:WaitForChild("PlayerGui"):WaitForChild("MainHUD", 60)
if not hud then return end

local POOL_BY_ID = {}
for _, q in ipairs(QuestConfig.Pool) do POOL_BY_ID[q.id] = q end

local CurrentData = nil
Remotes.UpdatePlayerData.OnClientEvent:Connect(function(d) CurrentData = d end)

local modal = Instance.new("Frame")
modal.Name = "QuestModal"
modal.Size = UDim2.new(0, 480, 0, 440)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.new(0.5, 0, 0.5, 0)
modal.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
modal.BorderSizePixel = 0
modal.Visible = false
modal.ZIndex = 50
modal.Parent = hud
Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 16)
local stroke = Instance.new("UIStroke", modal); stroke.Thickness = 3; stroke.Color = Color3.fromRGB(255, 200, 0)

local title = Instance.new("TextLabel", modal)
title.Size = UDim2.new(1, -20, 0, 50)
title.Position = UDim2.new(0, 10, 0, 10)
title.BackgroundTransparency = 1
title.Text = "DAILY QUESTS"
title.TextColor3 = Color3.fromRGB(255, 200, 0)
title.Font = Enum.Font.GothamBlack
title.TextScaled = true

local close = Instance.new("TextButton", modal)
close.Size = UDim2.new(0, 40, 0, 40)
close.Position = UDim2.new(1, -50, 0, 10)
close.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
close.Text = "X"
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.Font = Enum.Font.GothamBlack
close.TextScaled = true
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
close.MouseButton1Click:Connect(function() modal.Visible = false end)

local list = Instance.new("Frame", modal)
list.Size = UDim2.new(1, -20, 1, -80)
list.Position = UDim2.new(0, 10, 0, 70)
list.BackgroundTransparency = 1
local layout = Instance.new("UIListLayout", list)
layout.Padding = UDim.new(0, 10)

local function rebuild()
    if not CurrentData then return end
    for _, c in ipairs(list:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    local assigned = CurrentData.questAssigned or {}
    if #assigned == 0 then
        local lbl = Instance.new("TextLabel", list)
        lbl.Size = UDim2.new(1, 0, 0, 50)
        lbl.BackgroundTransparency = 1
        lbl.Text = "Today's quests are loading…"
        lbl.TextColor3 = Color3.fromRGB(180, 180, 180)
        lbl.Font = Enum.Font.Gotham
        lbl.TextScaled = true
        return
    end
    for _, qid in ipairs(assigned) do
        local q = POOL_BY_ID[qid]
        if q then
            local row = Instance.new("Frame", list)
            row.Size = UDim2.new(1, 0, 0, 90)
            row.BackgroundColor3 = Color3.fromRGB(40, 25, 60)
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

            local label = Instance.new("TextLabel", row)
            label.Size = UDim2.new(0.65, 0, 0.4, 0)
            label.Position = UDim2.new(0.02, 0, 0.05, 0)
            label.BackgroundTransparency = 1
            label.Text = q.label
            label.Font = Enum.Font.GothamBlack
            label.TextScaled = true
            label.TextColor3 = Color3.fromRGB(255, 200, 0)
            label.TextXAlignment = Enum.TextXAlignment.Left

            local progressVal = (CurrentData.questCounters and CurrentData.questCounters[q.counter]) or 0
            local pct = math.clamp(progressVal / q.target, 0, 1)

            local progLabel = Instance.new("TextLabel", row)
            progLabel.Size = UDim2.new(0.65, 0, 0.3, 0)
            progLabel.Position = UDim2.new(0.02, 0, 0.45, 0)
            progLabel.BackgroundTransparency = 1
            progLabel.Text = ("%d / %d"):format(math.min(progressVal, q.target), q.target)
            progLabel.Font = Enum.Font.Gotham
            progLabel.TextScaled = true
            progLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
            progLabel.TextXAlignment = Enum.TextXAlignment.Left

            local barBg = Instance.new("Frame", row)
            barBg.Size = UDim2.new(0.65, 0, 0.18, 0)
            barBg.Position = UDim2.new(0.02, 0, 0.78, 0)
            barBg.BackgroundColor3 = Color3.fromRGB(20, 10, 30)
            barBg.BorderSizePixel = 0
            Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
            local fill = Instance.new("Frame", barBg)
            fill.Size = UDim2.new(pct, 0, 1, 0)
            fill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
            fill.BorderSizePixel = 0
            Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

            local rewardLbl = Instance.new("TextLabel", row)
            rewardLbl.Size = UDim2.new(0.3, 0, 0.4, 0)
            rewardLbl.Position = UDim2.new(0.69, 0, 0.05, 0)
            rewardLbl.BackgroundTransparency = 1
            rewardLbl.Text = ("%d ⚡%s"):format(q.chaos or 0,
                (q.hellTokens or 0) > 0 and ("\n" .. q.hellTokens .. " 🔥") or "")
            rewardLbl.Font = Enum.Font.GothamBold
            rewardLbl.TextScaled = true
            rewardLbl.TextColor3 = Color3.fromRGB(50, 220, 100)

            local btn = Instance.new("TextButton", row)
            btn.Size = UDim2.new(0.3, 0, 0.4, 0)
            btn.Position = UDim2.new(0.69, 0, 0.5, 0)
            btn.Font = Enum.Font.GothamBlack
            btn.TextScaled = true
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            local claimed = CurrentData.questClaimed and CurrentData.questClaimed[qid]
            if claimed then
                btn.Text = "CLAIMED"
                btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                btn.AutoButtonColor = false
            elseif progressVal >= q.target then
                btn.Text = "CLAIM"
                btn.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
                btn.MouseButton1Click:Connect(function()
                    btn.Active = false; btn.Text = "..."
                    task.spawn(function()
                        Remotes.RequestQuestClaim:InvokeServer(qid)
                    end)
                end)
            else
                btn.Text = "LOCKED"
                btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
                btn.AutoButtonColor = false
            end
        end
    end
end

Remotes.UpdatePlayerData.OnClientEvent:Connect(function(d)
    CurrentData = d
    if modal.Visible then rebuild() end
end)

-- Hook into bottom bar (or create button)
local botBar = hud:FindFirstChild("BottomBar")
local function ensureButton()
    if not botBar then return end
    if botBar:FindFirstChild("QuestsButton") then return end
    local btn = Instance.new("TextButton")
    btn.Name = "QuestsButton"
    btn.Size = UDim2.new(0, 70, 0, 44)
    btn.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    btn.TextColor3 = Color3.fromRGB(0, 0, 0)
    btn.Font = Enum.Font.GothamBlack
    btn.Text = "QUESTS"
    btn.TextScaled = true
    btn.LayoutOrder = 6
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
    btn.Parent = botBar
    btn.MouseButton1Click:Connect(function()
        modal.Visible = not modal.Visible
        if modal.Visible then rebuild() end
    end)
end
ensureButton()
hud.ChildAdded:Connect(function() task.wait(0.5); ensureButton() end)
