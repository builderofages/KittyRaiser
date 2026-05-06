-- ClanPanel.client.lua  v1 — UI for ClanSystem.
-- 'CLAN' button anchored top-right (under existing PASS pill).
-- Modal lists clan info or create-form. Invite dialog pops on receive.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIUtil = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIUtil"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local RequestCreateClan, RequestInviteClan, RequestAcceptInvite, RequestLeaveClan
local RequestKickFromClan, RequestClanInfo, RequestDonateClan, ClanInviteEvent
task.spawn(function()
    local f = ReplicatedStorage:WaitForChild("RemoteEventsFolder", 30)
    RequestCreateClan = f:WaitForChild("RequestCreateClan", 30)
    RequestInviteClan = f:WaitForChild("RequestInviteClan", 30)
    RequestAcceptInvite = f:WaitForChild("RequestAcceptClanInvite", 30)
    RequestLeaveClan = f:WaitForChild("RequestLeaveClan", 30)
    RequestKickFromClan = f:WaitForChild("RequestKickFromClan", 30)
    RequestClanInfo = f:WaitForChild("RequestClanInfo", 30)
    RequestDonateClan = f:WaitForChild("RequestDonateClan", 30)
    ClanInviteEvent = f:WaitForChild("ClanInviteEvent", 30)
    if ClanInviteEvent then
        ClanInviteEvent.OnClientEvent:Connect(showInvite)
    end
end)

-- Trigger pill
local triggerSG = Instance.new("ScreenGui", playerGui)
triggerSG.Name = "ClanTrigger"
triggerSG.IgnoreGuiInset = false
triggerSG.ResetOnSpawn = false
triggerSG.DisplayOrder = (UIUtil.DisplayOrder.HUD or 10) + 6
local btn = Instance.new("TextButton", triggerSG)
btn.AnchorPoint = Vector2.new(1, 0)
btn.Size = UDim2.fromOffset(80, 32)
btn.Position = UDim2.new(1, -16, 0, 370)  -- under PASS pill
btn.BackgroundColor3 = Color3.fromRGB(120, 100, 200)
btn.Text = "CLAN"
btn.Font = Enum.Font.LuckiestGuy
btn.TextScaled = true
btn.TextColor3 = Color3.fromRGB(255, 240, 200)
btn.TextStrokeTransparency = 0.3
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
local bs = Instance.new("UIStroke", btn); bs.Thickness = 2; bs.Color = Color3.fromRGB(60, 50, 110)
local bc = Instance.new("UITextSizeConstraint", btn); bc.MinTextSize = 12; bc.MaxTextSize = 18

-- Modal
local modalSG = Instance.new("ScreenGui", playerGui)
modalSG.Name = "ClanModal"
modalSG.IgnoreGuiInset = true
modalSG.ResetOnSpawn = false
modalSG.DisplayOrder = (UIUtil.DisplayOrder.Modal or 60) + 5
modalSG.Enabled = false
local backdrop = Instance.new("Frame", modalSG)
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.5

local modal = Instance.new("Frame", modalSG)
modal.AnchorPoint = Vector2.new(0.5, 0.5)
modal.Position = UDim2.fromScale(0.5, 0.5)
modal.Size = UDim2.fromOffset(560, 480)
modal.BackgroundColor3 = Color3.fromRGB(245, 230, 200)
Instance.new("UICorner", modal).CornerRadius = UDim.new(0, 14)
local ms = Instance.new("UIStroke", modal); ms.Thickness = 4; ms.Color = Color3.fromRGB(110, 75, 45)

local title = Instance.new("TextLabel", modal)
title.Size = UDim2.new(1, -56, 0, 44)
title.Position = UDim2.fromOffset(16, 12)
title.BackgroundTransparency = 1
title.Text = "CLAN"
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

local content = Instance.new("Frame", modal)
content.Size = UDim2.new(1, -32, 1, -76)
content.Position = UDim2.fromOffset(16, 64)
content.BackgroundTransparency = 1

local function clearContent()
    for _, c in ipairs(content:GetChildren()) do c:Destroy() end
end

local function renderCreate()
    clearContent()
    local nameInput = Instance.new("TextBox", content)
    nameInput.Size = UDim2.new(1, 0, 0, 40)
    nameInput.Position = UDim2.fromOffset(0, 0)
    nameInput.BackgroundColor3 = Color3.fromRGB(255, 245, 215)
    nameInput.PlaceholderText = "Clan name (3-18 chars)"
    nameInput.Text = ""
    nameInput.Font = Enum.Font.GothamBold
    nameInput.TextColor3 = Color3.fromRGB(80, 40, 20)
    nameInput.TextScaled = true
    nameInput.ClearTextOnFocus = false
    Instance.new("UICorner", nameInput).CornerRadius = UDim.new(0, 6)
    local nc = Instance.new("UITextSizeConstraint", nameInput); nc.MinTextSize = 12; nc.MaxTextSize = 18

    local tagInput = Instance.new("TextBox", content)
    tagInput.Size = UDim2.new(1, 0, 0, 40)
    tagInput.Position = UDim2.fromOffset(0, 50)
    tagInput.BackgroundColor3 = Color3.fromRGB(255, 245, 215)
    tagInput.PlaceholderText = "Tag (2-5 chars, e.g. CATS)"
    tagInput.Text = ""
    tagInput.Font = Enum.Font.GothamBold
    tagInput.TextColor3 = Color3.fromRGB(80, 40, 20)
    tagInput.TextScaled = true
    tagInput.ClearTextOnFocus = false
    Instance.new("UICorner", tagInput).CornerRadius = UDim.new(0, 6)
    local tcs = Instance.new("UITextSizeConstraint", tagInput); tcs.MinTextSize = 12; tcs.MaxTextSize = 18

    local cost = Instance.new("TextLabel", content)
    cost.Size = UDim2.new(1, 0, 0, 24)
    cost.Position = UDim2.fromOffset(0, 100)
    cost.BackgroundTransparency = 1
    cost.Text = "Cost: 2,000 chaos"
    cost.Font = Enum.Font.GothamMedium
    cost.TextColor3 = Color3.fromRGB(120, 70, 40)
    cost.TextScaled = true
    local cc = Instance.new("UITextSizeConstraint", cost); cc.MinTextSize = 11; cc.MaxTextSize = 14

    local createBtn = Instance.new("TextButton", content)
    createBtn.Size = UDim2.new(1, 0, 0, 50)
    createBtn.Position = UDim2.fromOffset(0, 140)
    createBtn.BackgroundColor3 = Color3.fromRGB(110, 165, 95)
    createBtn.Text = "CREATE CLAN"
    createBtn.Font = Enum.Font.LuckiestGuy
    createBtn.TextColor3 = Color3.fromRGB(255, 248, 230)
    createBtn.TextScaled = true
    Instance.new("UICorner", createBtn).CornerRadius = UDim.new(0, 8)
    local crc = Instance.new("UITextSizeConstraint", createBtn); crc.MinTextSize = 14; crc.MaxTextSize = 22
    createBtn.MouseButton1Click:Connect(function()
        if not RequestCreateClan then return end
        createBtn.Active = false; createBtn.Text = "..."
        task.spawn(function()
            local ok, res = pcall(function() return RequestCreateClan:InvokeServer(nameInput.Text, tagInput.Text) end)
            createBtn.Active = true; createBtn.Text = "CREATE CLAN"
            renderRoot()
        end)
    end)
end

local function renderInClan(clanData)
    clearContent()
    local info = Instance.new("TextLabel", content)
    info.Size = UDim2.new(1, 0, 0, 70)
    info.Position = UDim2.fromOffset(0, 0)
    info.BackgroundColor3 = Color3.fromRGB(255, 220, 170)
    info.Text = ("[%s] %s\nLv %d  -  XP %d  -  Treasury %d  -  Members %d"):format(
        clanData.tag, clanData.name, clanData.level or 1, clanData.xp or 0,
        clanData.treasury or 0, clanData.memberCount or 0)
    info.Font = Enum.Font.GothamBold
    info.TextColor3 = Color3.fromRGB(80, 40, 20)
    info.TextScaled = true
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.TextWrapped = true
    Instance.new("UICorner", info).CornerRadius = UDim.new(0, 6)
    local ic = Instance.new("UITextSizeConstraint", info); ic.MinTextSize = 11; ic.MaxTextSize = 16

    local inviteInput = Instance.new("TextBox", content)
    inviteInput.Size = UDim2.new(0.7, -8, 0, 40)
    inviteInput.Position = UDim2.fromOffset(0, 80)
    inviteInput.BackgroundColor3 = Color3.fromRGB(255, 245, 215)
    inviteInput.PlaceholderText = "Player name to invite"
    inviteInput.Text = ""
    inviteInput.Font = Enum.Font.GothamBold
    inviteInput.TextColor3 = Color3.fromRGB(80, 40, 20)
    inviteInput.TextScaled = true
    inviteInput.ClearTextOnFocus = false
    Instance.new("UICorner", inviteInput).CornerRadius = UDim.new(0, 6)
    local iic = Instance.new("UITextSizeConstraint", inviteInput); iic.MinTextSize = 12; iic.MaxTextSize = 18

    local inviteBtn = Instance.new("TextButton", content)
    inviteBtn.Size = UDim2.new(0.3, 0, 0, 40)
    inviteBtn.Position = UDim2.new(0.7, 0, 0, 80)
    inviteBtn.BackgroundColor3 = Color3.fromRGB(85, 130, 175)
    inviteBtn.Text = "INVITE"
    inviteBtn.Font = Enum.Font.LuckiestGuy
    inviteBtn.TextColor3 = Color3.fromRGB(255, 248, 230)
    inviteBtn.TextScaled = true
    Instance.new("UICorner", inviteBtn).CornerRadius = UDim.new(0, 6)
    local ibc = Instance.new("UITextSizeConstraint", inviteBtn); ibc.MinTextSize = 11; ibc.MaxTextSize = 16
    inviteBtn.MouseButton1Click:Connect(function()
        if not RequestInviteClan then return end
        local target = Players:FindFirstChild(inviteInput.Text)
        if not target then return end
        pcall(function() RequestInviteClan:InvokeServer(target.UserId) end)
    end)

    local leaveBtn = Instance.new("TextButton", content)
    leaveBtn.Size = UDim2.new(1, 0, 0, 40)
    leaveBtn.Position = UDim2.fromOffset(0, 130)
    leaveBtn.BackgroundColor3 = Color3.fromRGB(220, 100, 80)
    leaveBtn.Text = "LEAVE CLAN"
    leaveBtn.Font = Enum.Font.LuckiestGuy
    leaveBtn.TextColor3 = Color3.fromRGB(255, 248, 230)
    leaveBtn.TextScaled = true
    Instance.new("UICorner", leaveBtn).CornerRadius = UDim.new(0, 6)
    local lc = Instance.new("UITextSizeConstraint", leaveBtn); lc.MinTextSize = 12; lc.MaxTextSize = 18
    leaveBtn.MouseButton1Click:Connect(function()
        if RequestLeaveClan then
            pcall(function() RequestLeaveClan:InvokeServer() end)
            renderRoot()
        end
    end)
end

function renderRoot()
    if not RequestClanInfo then clearContent(); return end
    local ok, clanData = pcall(function() return RequestClanInfo:InvokeServer() end)
    if ok and clanData then renderInClan(clanData)
    else renderCreate() end
end

btn.MouseButton1Click:Connect(function()
    renderRoot()
    modalSG.Enabled = true
end)
close.MouseButton1Click:Connect(function() modalSG.Enabled = false end)
backdrop.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
       or input.UserInputType == Enum.UserInputType.Touch then
        modalSG.Enabled = false
    end
end)

-- Invite popup
function showInvite(payload)
    if not payload then return end
    local popupSG = Instance.new("ScreenGui", playerGui)
    popupSG.IgnoreGuiInset = true
    popupSG.DisplayOrder = 220
    local pop = Instance.new("Frame", popupSG)
    pop.AnchorPoint = Vector2.new(0.5, 0)
    pop.Position = UDim2.new(0.5, 0, 0, 80)
    pop.Size = UDim2.fromOffset(420, 110)
    pop.BackgroundColor3 = Color3.fromRGB(245, 230, 200)
    Instance.new("UICorner", pop).CornerRadius = UDim.new(0, 12)
    local ps = Instance.new("UIStroke", pop); ps.Thickness = 3; ps.Color = Color3.fromRGB(110, 75, 45)
    local lbl = Instance.new("TextLabel", pop)
    lbl.Size = UDim2.new(1, -16, 0, 50)
    lbl.Position = UDim2.fromOffset(8, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = ("CLAN INVITE\n%s -> [%s] %s"):format(payload.fromName, payload.clanTag, payload.clanName)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextColor3 = Color3.fromRGB(80, 40, 20)
    lbl.TextScaled = true
    lbl.TextWrapped = true
    local accept = Instance.new("TextButton", pop)
    accept.Size = UDim2.new(0.45, -8, 0, 36)
    accept.Position = UDim2.new(0, 8, 1, -44)
    accept.BackgroundColor3 = Color3.fromRGB(110, 165, 95)
    accept.Text = "ACCEPT"
    accept.Font = Enum.Font.LuckiestGuy
    accept.TextColor3 = Color3.fromRGB(255, 248, 230)
    accept.TextScaled = true
    Instance.new("UICorner", accept).CornerRadius = UDim.new(0, 6)
    local decline = Instance.new("TextButton", pop)
    decline.Size = UDim2.new(0.45, -8, 0, 36)
    decline.Position = UDim2.new(0.5, 0, 1, -44)
    decline.BackgroundColor3 = Color3.fromRGB(140, 120, 100)
    decline.Text = "DECLINE"
    decline.Font = Enum.Font.LuckiestGuy
    decline.TextColor3 = Color3.fromRGB(255, 248, 230)
    decline.TextScaled = true
    Instance.new("UICorner", decline).CornerRadius = UDim.new(0, 6)
    accept.MouseButton1Click:Connect(function()
        if RequestAcceptInvite then
            pcall(function() RequestAcceptInvite:InvokeServer(payload.clanId) end)
        end
        popupSG:Destroy()
    end)
    decline.MouseButton1Click:Connect(function() popupSG:Destroy() end)
    task.delay(30, function() if popupSG then popupSG:Destroy() end end)
end

print("[ClanPanel v1] online")
