-- CatAnimations.server.lua
-- Swaps the default Roblox Animate script's animation IDs for our custom
-- cat animations once they're uploaded to AssetIds (anim_cat_idle/walk/run/
-- jump/fall). The Animate script Roblox auto-injects has named StringValue
-- children for each animation; we just rewrite their .Value.
--
-- If a cat animation isn't uploaded yet (AssetIds entry == "rbxassetid://0"),
-- the default Roblox animation is left in place so movement still works.
--
-- Place in: ServerScriptService > CatAnimations (Script). Auto-runs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetIds = require(ReplicatedStorage.Modules.AssetIds)

-- Map: name in Animate script -> AssetIds key
local ANIM_MAP = {
    idle = "anim_cat_idle",
    walk = "anim_cat_walk",
    run  = "anim_cat_run",
    jump = "anim_cat_jump",
    fall = "anim_cat_fall",
}

local function patch(animateScript)
    if not animateScript then return end
    for animName, assetKey in pairs(ANIM_MAP) do
        if not AssetIds.has(assetKey) then continue end
        local container = animateScript:FindFirstChild(animName)
        if not container then continue end
        -- Roblox's Animate script structure: each anim has child StringValue
        -- "<name>Anim" with the asset url. There may be multiple variants.
        for _, c in ipairs(container:GetChildren()) do
            if c:IsA("StringValue") then
                c.Value = AssetIds[assetKey]
            elseif c:IsA("Animation") then
                c.AnimationId = AssetIds[assetKey]
            end
        end
    end
    -- Force the script to reload its anim cache by toggling Disabled
    animateScript.Disabled = true
    task.wait()
    animateScript.Disabled = false
end

local function onCharacter(char)
    local animate = char:WaitForChild("Animate", 5)
    if animate then patch(animate) end
end

local function onPlayer(player)
    if player.Character then onCharacter(player.Character) end
    player.CharacterAdded:Connect(onCharacter)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

print("[CatAnimations] online — will swap Animate IDs when AssetIds anim_cat_* are uploaded")
