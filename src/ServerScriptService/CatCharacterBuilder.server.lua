-- CatCharacterBuilder.server.lua  v5 — post-spawn upgrade only.
-- SpawnEnforcer is the canonical spawn path; this script asynchronously loads
-- the Toolbox cat rig and, when ready, swaps each player's primitive cat for
-- the better-looking rig (preserving fur color and position).
-- Place in: ServerScriptService > CatCharacterBuilder. Auto-runs.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CAT_RIG_ID = 5896683998

local catTemplatesFolder = ServerStorage:FindFirstChild("CatTemplates")
if not catTemplatesFolder then
    catTemplatesFolder = Instance.new("Folder")
    catTemplatesFolder.Name = "CatTemplates"
    catTemplatesFolder.Parent = ServerStorage
end

local CAT_TEMPLATE
local templateLoaded = false

-- Body parts whose color tracks fur. Eyes, pupils, nose, mouth, decals are
-- explicitly skipped via the "NoTint" attribute or by name.
local TINT_SKIP_NAMES = {
    Pupil = true, Eye = true, Nose = true, Mouth = true,
    Tongue = true, Whisker = true, Tooth = true,
}

local function tintToolboxCat(rig, color)
    for _, p in ipairs(rig:GetDescendants()) do
        if (p:IsA("BasePart") or p:IsA("MeshPart"))
            and not TINT_SKIP_NAMES[p.Name]
            and not p:GetAttribute("NoTint")
        then
            p.Color = color
        end
    end
end

local function tryLoadToolboxCat()
    local ok, model = pcall(function() return InsertService:LoadAsset(CAT_RIG_ID) end)
    if not ok or not model then
        warn("[CatCharacterBuilder] LoadAsset failed: " .. tostring(model))
        return
    end
    local rig
    for _, child in ipairs(model:GetDescendants()) do
        if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
            rig = child; break
        end
    end
    if rig then
        rig.Name = "ToolboxCatTemplate"
        rig.Parent = catTemplatesFolder
        CAT_TEMPLATE = rig
        templateLoaded = true
        print("[CatCharacterBuilder] Toolbox cat rig loaded")
    else
        warn("[CatCharacterBuilder] no Humanoid model in asset " .. CAT_RIG_ID)
    end
    if model.Parent then model:Destroy() end
end

task.spawn(tryLoadToolboxCat)

-- Replace a player's existing character with a tinted clone of the toolbox rig.
local function upgradeCharacter(player)
    if not (templateLoaded and CAT_TEMPLATE) then return end
    if not player.Parent then return end
    local oldChar = player.Character
    if not oldChar then return end
    if oldChar:GetAttribute("ToolboxCat") then return end  -- already upgraded

    local fc = player:GetAttribute("FurColor")
    local color = (typeof(fc) == "Color3") and fc or Color3.fromRGB(220, 130, 50)

    local pivot = oldChar:FindFirstChild("HumanoidRootPart")
        and oldChar.HumanoidRootPart.CFrame
        or CFrame.new(0, 8, 0)

    local cat = CAT_TEMPLATE:Clone()
    cat.Name = player.Name
    cat:SetAttribute("ToolboxCat", true)
    tintToolboxCat(cat, color)
    cat:PivotTo(pivot)

    -- Move floating name billboard if present
    local oldName = oldChar:FindFirstChild("Head") and oldChar.Head:FindFirstChild("BillboardGui")
    if oldName then
        local newHead = cat:FindFirstChild("Head")
        if newHead then oldName:Clone().Parent = newHead end
    end

    cat.Parent = Workspace
    player.Character = cat
    oldChar:Destroy()
end

-- Watch for new players + when template arrives later, upgrade existing
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(2)  -- let SpawnEnforcer finish its primitive cat
        if templateLoaded then upgradeCharacter(player) end
    end)
end)

task.spawn(function()
    -- Once template is loaded, sweep existing players one time.
    while not templateLoaded do task.wait(0.5) end
    for _, p in ipairs(Players:GetPlayers()) do upgradeCharacter(p) end
end)
