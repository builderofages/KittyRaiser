-- NPCChatter.server.lua  v1 — ambient civilian dialogue.
--
-- Periodically picks a random AmbientCrowd NPC and shows a short speech
-- bubble above their head with a phrase tied to their archetype. Also
-- triggers reaction phrases when ANY NPC nearby gets pranked (servers
-- the "civilians notice each other" feel).

local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local CHATTER_BY_ARCH = {
    BUSINESS = {"Late for a meeting","Stocks are up","Where's my driver","On a call here","Get out of my way"},
    TOURIST  = {"Look honey, a cat","Where's Times Square","I love this city","Take a picture","So many lights"},
    DELIVERY = {"Got a package","Out the way","One more stop","Tracking number please","Sign here"},
    JOGGER   = {"Just pacing","Five more miles","Heart rate good","Power through it","Cardio day"},
    CASUAL   = {"Nice weather","Did you see that","Just walking","This city","Heading home"},
}
local REACTION_PHRASES = {
    "Did you SEE that?!", "Oh my god", "Call the cops", "RUN", "What was that",
    "Not again", "Crazy cat", "Help!", "I saw it", "It came outta nowhere",
}

local function showBubble(npc, text, color)
    local head = npc:FindFirstChild("Head") or npc.PrimaryPart
    if not head then return end
    -- Don't double-bubble if one's already up
    if head:FindFirstChild("ChatterBubble") then return end
    local g = Instance.new("BillboardGui")
    g.Name = "ChatterBubble"
    g.Size = UDim2.new(0, 130, 0, 36)
    g.StudsOffset = Vector3.new(0, 2.4, 0)
    g.AlwaysOnTop = false
    g.MaxDistance = 60
    g.Parent = head
    local bubble = Instance.new("Frame", g)
    bubble.Size = UDim2.fromScale(1, 1)
    bubble.BackgroundColor3 = Color3.fromRGB(255, 250, 230)
    Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", bubble)
    stroke.Thickness = 2; stroke.Color = Color3.fromRGB(60, 35, 18)
    local lbl = Instance.new("TextLabel", bubble)
    lbl.Size = UDim2.new(1, -10, 1, -6)
    lbl.Position = UDim2.fromOffset(5, 3)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextColor3 = color or Color3.fromRGB(60, 35, 18)
    lbl.TextScaled = true
    lbl.TextWrapped = true
    local lc = Instance.new("UITextSizeConstraint", lbl); lc.MinTextSize = 9; lc.MaxTextSize = 13
    game:GetService("Debris"):AddItem(g, 3.0)
end

local function pickRandomNPC()
    local crowd = Workspace:FindFirstChild("AmbientCrowd")
    if not crowd then return nil end
    local kids = crowd:GetChildren()
    if #kids == 0 then return nil end
    return kids[math.random(1, #kids)]
end

-- Ambient chatter loop — every 4-7s pick a random NPC and bubble one of
-- their archetype phrases.
task.spawn(function()
    while true do
        task.wait(math.random(40, 70) / 10)
        local npc = pickRandomNPC()
        if npc then
            local arch = npc:GetAttribute("Archetype") or "CASUAL"
            local pool = CHATTER_BY_ARCH[arch] or CHATTER_BY_ARCH.CASUAL
            showBubble(npc, pool[math.random(1, #pool)])
        end
    end
end)

-- Reaction chatter: listen for NpcHp drops and have NEARBY NPCs react.
task.spawn(function()
    local crowd = Workspace:WaitForChild("AmbientCrowd", 30)
    local pranks = Workspace:WaitForChild("PrankNPCs", 30)
    local function watch(folder)
        if not folder then return end
        local function attach(npc)
            npc:GetAttributeChangedSignal("NpcHp"):Connect(function()
                local hrp = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
                if not hrp then return end
                -- Pick 1-2 NEARBY ambient NPCs to react
                local crowdF = Workspace:FindFirstChild("AmbientCrowd")
                if not crowdF then return end
                local picks = {}
                for _, other in ipairs(crowdF:GetChildren()) do
                    if other ~= npc and other.PrimaryPart then
                        local d = (other.PrimaryPart.Position - hrp.Position).Magnitude
                        if d < 30 then table.insert(picks, other) end
                    end
                    if #picks >= 4 then break end
                end
                for i = 1, math.min(2, #picks) do
                    local other = picks[math.random(1, #picks)]
                    local phrase = REACTION_PHRASES[math.random(1, #REACTION_PHRASES)]
                    showBubble(other, phrase, Color3.fromRGB(220, 70, 60))
                end
            end)
        end
        for _, c in ipairs(folder:GetChildren()) do attach(c) end
        folder.ChildAdded:Connect(attach)
    end
    watch(crowd); watch(pranks)
end)

print("[NPCChatter v1] online — ambient + reaction phrases")
