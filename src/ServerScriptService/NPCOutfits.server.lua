-- NPCOutfits.server.lua  v1
-- Per-archetype outfit colors so OFFICE/TOURIST/JOGGER/etc. NPCs visually
-- distinguish themselves instead of all looking like grey humanoids.
local Workspace = game:GetService("Workspace")

local ARCHETYPE_OUTFITS = {
    OFFICE   = {shirt = Color3.fromRGB(20, 30, 60),   pants = Color3.fromRGB(20, 30, 50),   skin = Color3.fromRGB(220, 180, 140)},  -- navy suit
    TOURIST  = {shirt = Color3.fromRGB(255, 80, 80),  pants = Color3.fromRGB(80, 100, 180), skin = Color3.fromRGB(240, 200, 160)},  -- red shirt + blue jeans
    JOGGER   = {shirt = Color3.fromRGB(80, 200, 80),  pants = Color3.fromRGB(40, 40, 40),   skin = Color3.fromRGB(225, 175, 130)},  -- green tank + black shorts
    DELIVERY = {shirt = Color3.fromRGB(200, 130, 50), pants = Color3.fromRGB(80, 60, 30),   skin = Color3.fromRGB(220, 180, 140)},  -- orange uniform
    LOCAL    = {shirt = Color3.fromRGB(140, 100, 180),pants = Color3.fromRGB(120, 80, 60),  skin = Color3.fromRGB(230, 195, 155)},  -- purple shirt
    BANKER   = {shirt = Color3.fromRGB(50, 50, 50),   pants = Color3.fromRGB(30, 30, 30),   skin = Color3.fromRGB(225, 185, 145)},  -- black suit
}

local function applyOutfit(npc)
    local archKey = npc:GetAttribute("Archetype")
    if not archKey then return end
    local outfit = ARCHETYPE_OUTFITS[archKey:upper()]
    if not outfit then return end
    -- Find torso, arms, legs, head and color them
    for _, part in ipairs(npc:GetDescendants()) do
        if part:IsA("BasePart") then
            local n = part.Name
            if n == "UpperTorso" or n == "LowerTorso" or n == "Torso" then
                part.Color = outfit.shirt
            elseif n == "LeftUpperLeg" or n == "RightUpperLeg" or n == "LeftLowerLeg" or n == "RightLowerLeg"
                or n == "LeftFoot" or n == "RightFoot" or n == "Left Leg" or n == "Right Leg" then
                part.Color = outfit.pants
            elseif n == "Head" or n:find("Arm") or n:find("Hand") then
                part.Color = outfit.skin
            end
        end
    end
end

local function watchFolder(folderName)
    local folder = Workspace:FindFirstChild(folderName)
    if not folder then return end
    folder.ChildAdded:Connect(function(child)
        if child:IsA("Model") then
            task.delay(0.3, function() applyOutfit(child) end)
        end
    end)
    -- existing children
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("Model") then
            task.delay(0.5, function() applyOutfit(child) end)
        end
    end
end

task.spawn(function()
    task.wait(4)
    watchFolder("AmbientCrowd")
    watchFolder("PrankNPCs")
    print("[NPCOutfits v1] online — colored OFFICE/TOURIST/JOGGER/etc archetype outfits")
end)
