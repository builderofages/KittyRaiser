-- CosmeticHandler.server.lua
-- Handles skin purchase (Chaos currency) + equip + applies skin to character.
-- Place in: ServerScriptService > CosmeticHandler (Script)

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local CosmeticConfig = require(ReplicatedStorage.Modules.CosmeticConfig)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local function waitFor(globalName)
    while not _G[globalName] do task.wait() end
    return _G[globalName]
end
local DataHandler = waitFor("KittyRaiserData")

local CosmeticHandler = {}

local function applySkinToCharacter(character, skinId)
    if not character then return end
    local skin = CosmeticConfig.getSkin(skinId)
    if not skin then return end

    local bodyColors = character:FindFirstChildOfClass("BodyColors")
    if not bodyColors then
        bodyColors = Instance.new("BodyColors")
        bodyColors.Parent = character
    end

    -- Apply colors via BrickColor (BodyColors uses BrickColor)
    local function toBrick(c) return BrickColor.new(c) end
    if skin.bodyColors.HeadColor then bodyColors.HeadColor = toBrick(skin.bodyColors.HeadColor) end
    if skin.bodyColors.TorsoColor then bodyColors.TorsoColor = toBrick(skin.bodyColors.TorsoColor) end
    if skin.bodyColors.LeftArmColor then bodyColors.LeftArmColor = toBrick(skin.bodyColors.LeftArmColor) end
    if skin.bodyColors.RightArmColor then bodyColors.RightArmColor = toBrick(skin.bodyColors.RightArmColor) end
    if skin.bodyColors.LeftLegColor then bodyColors.LeftLegColor = toBrick(skin.bodyColors.LeftLegColor) end
    if skin.bodyColors.RightLegColor then bodyColors.RightLegColor = toBrick(skin.bodyColors.RightLegColor) end

    -- Material override for Neon
    if skin.material then
        for _, p in ipairs(character:GetDescendants()) do
            if p:IsA("BasePart") then
                p.Material = skin.material
            end
        end
    end

    -- Glow effect
    if skin.glowEffect then
        local existing = character:FindFirstChild("SkinGlow")
        if not existing then
            local light = Instance.new("PointLight")
            light.Name = "SkinGlow"
            light.Brightness = 2
            light.Range = 12
            light.Color = skin.bodyColors.TorsoColor or Color3.new(1,1,1)
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then light.Parent = hrp end
        end
    end
end

local function applyOnRespawn(player, character)
    -- Wait for DataHandler to finish loading (race-safe). It returns nil
    -- during the load window. Retry up to 3s before giving up.
    local data
    for _ = 1, 30 do
        data = DataHandler.getData(player)
        if data then break end
        task.wait(0.1)
    end
    if not data then
        warn("[CosmeticHandler] DataHandler.getData still nil after 3s for " .. player.Name)
        return
    end
    -- Wait for body parts
    character:WaitForChild("Humanoid")
    task.wait(0.1)
    applySkinToCharacter(character, data.equippedSkin or "Default")
    -- Tell CatCharacterBuilder which multi-color skin (if any) is equipped so
    -- it can skip the single-fur-color tint that would otherwise overwrite us.
    local skin = CosmeticConfig.getSkin(data.equippedSkin or "Default")
    if skin and skin.bodyColors then
        local c = skin.bodyColors
        local multiColor =
            c.HeadColor   and c.TorsoColor   and c.LeftArmColor and
            c.RightArmColor and c.LeftLegColor and c.RightLegColor
            and not (c.HeadColor == c.TorsoColor and c.TorsoColor == c.LeftArmColor)
        character:SetAttribute("MultiColorSkin", multiColor or false)
    else
        character:SetAttribute("MultiColorSkin", false)
    end
end

local function setupPlayer(player)
    -- If character already auto-loaded before we hooked, apply skin now
    if player.Character then
        task.spawn(applyOnRespawn, player, player.Character)
    end
    player.CharacterAdded:Connect(function(char) applyOnRespawn(player, char) end)
end
Players.PlayerAdded:Connect(setupPlayer)
for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end

-- Equip
Remotes.RequestEquipSkin.OnServerInvoke = function(player, skinId)
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end
    if not table.find(data.ownedSkins, skinId) then return false, "not_owned" end
    DataHandler.modify(player, function(d) d.equippedSkin = skinId end)
    if player.Character then applySkinToCharacter(player.Character, skinId) end
    return true, nil
end

-- Purchase with Chaos
Remotes.RequestPurchaseSkinChaos.OnServerInvoke = function(player, skinId)
    local skin = CosmeticConfig.getSkin(skinId)
    if not skin then return false, "invalid_skin" end
    if skin.currency ~= "chaos" then return false, "wrong_currency" end
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end
    if table.find(data.ownedSkins, skinId) then return false, "already_owned" end
    if (data.chaosPoints or 0) < skin.cost then return false, "not_enough_chaos" end
    DataHandler.modify(player, function(d)
        d.chaosPoints = d.chaosPoints - skin.cost
        table.insert(d.ownedSkins, skinId)
    end)
    return true, nil
end

return CosmeticHandler
