-- MultiplayerFeel.client.lua  v1 — Phase-12 social glue.
--   * Floating "Player pranked Civilian!" text above the actor's head when ANY
--     nearby player pranks.
--   * Squad-combo subtitle banner when 2+ cats prank within 3s/80 studs.
--   * Friends-in-server avatar ribbon: up to 5 friend headshots under the
--     existing FriendsPill, click to teleport-to-friend.

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local UIUtil  = require(ReplicatedStorage.Modules.UIUtil)

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local hud       = playerGui:WaitForChild("MainHUD", 30)
if not hud then return end

-- =====================================================================
-- 1) FLOATING PRANK TEXT — BillboardGui above actor
-- =====================================================================
local function showFloatingPrankText(actorName, prankName, targetCFrame)
    -- Find any model in workspace whose Player matches actorName, attach gui
    -- to its head; if not found (actor is the local player or just unloaded),
    -- attach to a freestanding emitter at targetCFrame instead.
    local anchor
    for _, p in ipairs(Players:GetPlayers()) do
        if p.DisplayName == actorName and p.Character then
            anchor = p.Character:FindFirstChild("Head") or p.Character.PrimaryPart
            break
        end
    end
    if not anchor then
        local part = Instance.new("Part")
        part.Anchored = true; part.CanCollide = false
        part.Transparency = 1; part.Size = Vector3.new(1, 1, 1)
        part.CFrame = targetCFrame and (targetCFrame * CFrame.new(0, 4, 0)) or CFrame.new(0, 30, 0)
        part.Parent = workspace
        anchor = part
        game:GetService("Debris"):AddItem(part, 3)
    end
    local g = Instance.new("BillboardGui", anchor)
    g.Size = UDim2.new(0, 220, 0, 36)
    g.StudsOffset = Vector3.new(0, 4, 0)
    g.AlwaysOnTop = true
    local lbl = Instance.new("TextLabel", g)
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text = actorName .. " pranked " .. prankName .. "!"
    lbl.TextColor3 = Color3.fromRGB(255, 245, 200)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(80, 30, 10)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    local c = Instance.new("UITextSizeConstraint", lbl); c.MinTextSize = 12; c.MaxTextSize = 18
    -- Float up + fade
    local goal = {StudsOffset = Vector3.new(0, 7, 0)}
    TweenService:Create(g, TweenInfo.new(2.0, Enum.EasingStyle.Quad), goal):Play()
    task.delay(1.2, function()
        TweenService:Create(lbl, TweenInfo.new(0.7),
            {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    end)
    game:GetService("Debris"):AddItem(g, 2.2)
end

-- Listen on PrankRegistered (server fires for actor + nearby clients).
Remotes.PrankRegistered.OnClientEvent:Connect(function(prankName, targetModel, chaos, fx)
    if not fx or not fx.actorName then return end
    -- Skip our own — it would float above our own head, redundant with combo HUD.
    if fx.actorUserId and fx.actorUserId == player.UserId then return end
    showFloatingPrankText(fx.actorName, prankName, fx.targetCFrame)
end)

-- =====================================================================
-- 2) SQUAD COMBO SUBTITLE
-- =====================================================================
local squadBanner = Instance.new("Frame", hud)
squadBanner.Name = "SquadComboBanner"
squadBanner.AnchorPoint = Vector2.new(0.5, 0)
squadBanner.Position = UDim2.new(0.5, 0, 0, 220)
squadBanner.Size = UDim2.new(0, 360, 0, 56)
squadBanner.BackgroundColor3 = Color3.fromRGB(255, 175, 60)
squadBanner.BackgroundTransparency = 0.05
squadBanner.Visible = false
Instance.new("UICorner", squadBanner).CornerRadius = UDim.new(0, 14)
local sbStroke = Instance.new("UIStroke", squadBanner)
sbStroke.Thickness = 3; sbStroke.Color = Color3.fromRGB(110, 60, 20)
local sbLbl = Instance.new("TextLabel", squadBanner)
sbLbl.Size = UDim2.fromScale(1, 1)
sbLbl.BackgroundTransparency = 1
sbLbl.Font = Enum.Font.LuckiestGuy
sbLbl.TextColor3 = Color3.fromRGB(80, 30, 10)
sbLbl.TextScaled = true
local sbC = Instance.new("UITextSizeConstraint", sbLbl); sbC.MinTextSize = 18; sbC.MaxTextSize = 32

Remotes.EventBroadcast.OnClientEvent:Connect(function(kind, payload)
    if kind ~= "squad_combo" then return end
    sbLbl.Text = "SQUAD COMBO x" .. (payload.count or 2) .. "!  +50% chaos"
    squadBanner.Visible = true
    squadBanner.BackgroundTransparency = 0.05
    sbLbl.TextTransparency = 0
    -- Pop in
    squadBanner.Size = UDim2.new(0, 320, 0, 50)
    TweenService:Create(squadBanner, TweenInfo.new(0.25, Enum.EasingStyle.Back),
        {Size = UDim2.new(0, 380, 0, 60)}):Play()
    task.delay(1.6, function()
        TweenService:Create(squadBanner, TweenInfo.new(0.5),
            {BackgroundTransparency = 1}):Play()
        TweenService:Create(sbLbl, TweenInfo.new(0.5),
            {TextTransparency = 1}):Play()
        task.wait(0.55)
        squadBanner.Visible = false
    end)
end)

-- =====================================================================
-- 3) FRIENDS AVATAR RIBBON (5 headshots)
-- =====================================================================
local pill = hud:WaitForChild("FriendsPill", 10)
if pill then
    local ribbon = Instance.new("Frame", hud)
    ribbon.Name = "FriendsRibbon"
    ribbon.AnchorPoint = Vector2.new(0, 1)
    ribbon.Position = UDim2.new(0, 12, 1, -50)  -- under the pill
    ribbon.Size = UDim2.new(0, 240, 0, 36)
    ribbon.BackgroundTransparency = 1
    local layout = Instance.new("UIListLayout", ribbon)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 4)

    local function buildRibbon()
        for _, c in ipairs(ribbon:GetChildren()) do
            if c:IsA("ImageButton") then c:Destroy() end
        end
        local count = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and count < 5 then
                local ok, isF = pcall(function() return player:IsFriendsWith(p.UserId) end)
                if ok and isF then
                    local btn = Instance.new("ImageButton", ribbon)
                    btn.Size = UDim2.new(0, 32, 0, 32)
                    btn.BackgroundColor3 = Color3.fromRGB(255, 235, 200)
                    btn.LayoutOrder = count
                    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
                    local stk = Instance.new("UIStroke", btn)
                    stk.Thickness = 2; stk.Color = Color3.fromRGB(255, 215, 120)
                    -- Headshot. GetUserThumbnailAsync returns (content, isReady)
                    -- but inside pcall they shift positions to (ok, content, isReady).
                    task.spawn(function()
                        local ok, url = pcall(function()
                            return Players:GetUserThumbnailAsync(
                                p.UserId,
                                Enum.ThumbnailType.HeadShot,
                                Enum.ThumbnailSize.Size48x48)
                        end)
                        if ok and typeof(url) == "string" and #url > 0 then
                            btn.Image = url
                        end
                    end)
                    btn.MouseButton1Click:Connect(function()
                        if p.Character and p.Character.PrimaryPart
                           and player.Character and player.Character.PrimaryPart then
                            player.Character:PivotTo(p.Character.PrimaryPart.CFrame
                                + Vector3.new(0, 0, 6))
                        end
                    end)
                    count = count + 1
                end
            end
        end
        ribbon.Visible = count > 0
    end

    Players.PlayerAdded:Connect(function() task.wait(2); buildRibbon() end)
    Players.PlayerRemoving:Connect(buildRibbon)
    task.spawn(function() task.wait(4); buildRibbon() end)
end

print("[MultiplayerFeel v1] online — floating text + squad combo + friends ribbon")
