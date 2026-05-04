-- ReactionBubbles.client.lua  v1 — speech bubble feedback above NPCs
-- when they get pranked. Listens to Remotes.PrankRegistered and pops a
-- short BillboardGui ("OW!" / "AH!" / "OOF!" / etc) above the target's
-- head that fades after ~1.4s. Pure juice — makes pranks feel like they
-- LANDED on something that reacts.

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris           = game:GetService("Debris")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local REACTIONS_BY_PRANK = {
    Pie        = {"OW MY PIE!", "GAH!", "AH FACE!", "MY EYES!", "WHY?!"},
    Anvil      = {"WAGH!", "ACME?!", "CRUSHED!", "OOF!", "SEE STARS"},
    FartCloud  = {"P-U!", "STINKY!", "EW!", "GROSS!", "AGH!"},
    LaserEyes  = {"AAAH!", "MY EYES!", "BURNED!", "SHOCK!", "SAVE ME!"},
    Hairball   = {"ICK!", "FUR!", "BLEH!", "GROSS!", "AHH!"},
    Whip       = {"OUCH!", "WHACK!", "OWWIE!", "AYE!", "STING!"},
    CatScratch = {"YEOWCH!", "OUCH!", "OW!", "SCRATCH!", "AAA!"},
    Purrgatory = {"NO!", "MY SOUL!", "AAAGH!", "WHY?!", "DOOM!"},
}
local DEFAULT_REACT = {"OW!", "AH!", "OOF!", "WHY?!", "WAH!"}

local function popReaction(npc, prankName)
    if not npc or not npc.Parent then return end
    local head = npc:FindFirstChild("Head")
    if not head then return end
    local pool = REACTIONS_BY_PRANK[prankName] or DEFAULT_REACT
    local text = pool[math.random(1, #pool)]

    local g = Instance.new("BillboardGui")
    g.Size = UDim2.new(0, 140, 0, 40)
    g.StudsOffset = Vector3.new(0, 2.6, 0)
    g.AlwaysOnTop = true
    g.Parent = head

    -- White rounded "speech bubble" with thick black stroke for cartoon feel.
    local bubble = Instance.new("Frame", g)
    bubble.Size = UDim2.fromScale(1, 1)
    bubble.BackgroundColor3 = Color3.fromRGB(255, 250, 230)
    bubble.BorderSizePixel = 0
    Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", bubble)
    stroke.Thickness = 3
    stroke.Color = Color3.fromRGB(40, 25, 10)

    local lbl = Instance.new("TextLabel", bubble)
    lbl.Size = UDim2.new(1, -16, 1, -8)
    lbl.Position = UDim2.fromOffset(8, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.LuckiestGuy
    lbl.TextScaled = true
    lbl.TextColor3 = Color3.fromRGB(220, 50, 40)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)
    local c = Instance.new("UITextSizeConstraint", lbl); c.MinTextSize = 12; c.MaxTextSize = 22

    -- Pop in: scale 0 -> 1 with Back-out ease. Float up slightly. Then fade.
    bubble.Size = UDim2.fromScale(0.3, 0.3)
    TweenService:Create(bubble, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {Size = UDim2.fromScale(1, 1)}):Play()
    TweenService:Create(g, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {StudsOffset = Vector3.new(0, 4.2, 0)}):Play()
    task.delay(0.9, function()
        TweenService:Create(lbl, TweenInfo.new(0.5),
            {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
        TweenService:Create(bubble, TweenInfo.new(0.5),
            {BackgroundTransparency = 1}):Play()
        TweenService:Create(stroke, TweenInfo.new(0.5),
            {Transparency = 1}):Play()
    end)
    Debris:AddItem(g, 1.6)
end

Remotes.PrankRegistered.OnClientEvent:Connect(function(prankName, target, chaosGained, fxPayload)
    -- target is the pranked Model. fxPayload.targetCFrame is fallback.
    if target and target:IsA("Model") then
        popReaction(target, prankName)
    end
end)

print("[ReactionBubbles v1] online")
