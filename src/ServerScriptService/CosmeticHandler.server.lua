-- CosmeticHandler.server.lua
-- Handles skin purchase (Chaos / Hell Tokens) + equip + applies skin to character.
-- Place in: ServerScriptService > CosmeticHandler (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local CosmeticConfig = require(ReplicatedStorage.Modules.CosmeticConfig)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local SharedUtil = require(ReplicatedStorage.Modules.SharedUtil)

local DataHandler = SharedUtil.waitForGlobal("KittyRaiserData", 30)
if not DataHandler then return end

local CosmeticHandler = {}

-- Body parts whose color should match the skin. Eyes/whiskers/decals are
-- intentionally excluded so tinting doesn't paint over facial features.
local BODY_PART_NAMES = {
    Head = "HeadColor", Torso = "TorsoColor",
    ["Left Arm"] = "LeftArmColor", ["Right Arm"] = "RightArmColor",
    ["Left Leg"] = "LeftLegColor", ["Right Leg"] = "RightLegColor",
}

local function applySkinToCharacter(character, skinId)
    if not character then return end
    local skin = CosmeticConfig.getSkin(skinId)
    if not skin or not skin.bodyColors then return end

    local bodyColors = character:FindFirstChildOfClass("BodyColors")
    if not bodyColors then
        bodyColors = Instance.new("BodyColors")
        bodyColors.Parent = character
    end

    local function safeBrick(color3)
        local ok, bc = pcall(BrickColor.new, color3)
        return ok and bc or BrickColor.new("Medium stone grey")
    end

    if skin.bodyColors.HeadColor     then bodyColors.HeadColor     = safeBrick(skin.bodyColors.HeadColor) end
    if skin.bodyColors.TorsoColor    then bodyColors.TorsoColor    = safeBrick(skin.bodyColors.TorsoColor) end
    if skin.bodyColors.LeftArmColor  then bodyColors.LeftArmColor  = safeBrick(skin.bodyColors.LeftArmColor) end
    if skin.bodyColors.RightArmColor then bodyColors.RightArmColor = safeBrick(skin.bodyColors.RightArmColor) end
    if skin.bodyColors.LeftLegColor  then bodyColors.LeftLegColor  = safeBrick(skin.bodyColors.LeftLegColor) end
    if skin.bodyColors.RightLegColor then bodyColors.RightLegColor = safeBrick(skin.bodyColors.RightLegColor) end

    -- Material override (Neon, Metal, etc). Apply only to body parts named
    -- like the standard rig - skip accessories, hats, decals, and any part
    -- with the "NoTint" attribute (used by accessories so they keep their material).
    if skin.material then
        for _, p in ipairs(character:GetChildren()) do
            if p:IsA("BasePart") and BODY_PART_NAMES[p.Name] and not p:GetAttribute("NoTint") then
                p.Material = skin.material
            end
        end
    end

    -- Glow effect: a small PointLight at HRP. Color must be Color3, not BrickColor.
    if skin.glowEffect then
        local existing = character:FindFirstChild("SkinGlow")
        if not existing then
            local light = Instance.new("PointLight")
            light.Name = "SkinGlow"
            light.Brightness = 2
            light.Range = 12
            light.Color = (typeof(skin.bodyColors.TorsoColor) == "Color3")
                and skin.bodyColors.TorsoColor
                or Color3.fromRGB(255, 255, 255)
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then light.Parent = hrp end
        end
    elseif character:FindFirstChild("SkinGlow") then
        character.SkinGlow:Destroy()
    end
end

CosmeticHandler.applySkinToCharacter = applySkinToCharacter

local function applyOnRespawn(player, character)
    local data = DataHandler.getData(player)
    if not data then return end
    character:WaitForChild("Humanoid", 5)
    task.wait(0.1)
    applySkinToCharacter(character, data.equippedSkin or "Default")
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char) applyOnRespawn(player, char) end)
    if player.Character then applyOnRespawn(player, player.Character) end
end)

Remotes.RequestEquipSkin.OnServerInvoke = function(player, skinId)
    if not SharedUtil.checkRate(player, "equipSkin", GameConfig.REMOTE_RATE_LIMIT_SEC) then
        return false, "rate_limited"
    end
    if type(skinId) ~= "string" or #skinId > 64 then return false, "bad_id" end
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end
    if not CosmeticConfig.getSkin(skinId) then return false, "invalid_skin" end
    if not table.find(data.ownedSkins, skinId) then return false, "not_owned" end
    DataHandler.modify(player, function(d) d.equippedSkin = skinId end)
    if player.Character then
        applySkinToCharacter(player.Character, skinId)
    else
        player.CharacterAdded:Once(function(c) task.wait(0.1); applySkinToCharacter(c, skinId) end)
    end
    return true, nil
end

local function purchaseSkin(player, skinId, currency, balanceField)
    if type(skinId) ~= "string" or #skinId > 64 then return false, "bad_id" end
    local skin = CosmeticConfig.getSkin(skinId)
    if not skin then return false, "invalid_skin" end
    if skin.currency ~= currency then return false, "wrong_currency" end
    if skin.eventOnly then return false, "event_only" end
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end
    if not data.ownedSkins then data.ownedSkins = {} end
    if table.find(data.ownedSkins, skinId) then return false, "already_owned" end
    local cost = tonumber(skin.cost) or 0
    if cost < 0 then return false, "invalid_cost" end
    if (data[balanceField] or 0) < cost then return false, "not_enough_currency" end
    DataHandler.modify(player, function(d)
        d[balanceField] = (d[balanceField] or 0) - cost
        table.insert(d.ownedSkins, skinId)
    end)
    return true, nil
end

Remotes.RequestPurchaseSkinChaos.OnServerInvoke = function(player, skinId)
    if not SharedUtil.checkRate(player, "buyChaosSkin", GameConfig.REMOTE_RATE_LIMIT_SEC) then
        return false, "rate_limited"
    end
    return purchaseSkin(player, skinId, "chaos", "chaosPoints")
end

Remotes.RequestPurchaseSkinHellTokens.OnServerInvoke = function(player, skinId)
    if not SharedUtil.checkRate(player, "buyHTSkin", GameConfig.REMOTE_RATE_LIMIT_SEC) then
        return false, "rate_limited"
    end
    return purchaseSkin(player, skinId, "helltokens", "hellTokens")
end

return CosmeticHandler
