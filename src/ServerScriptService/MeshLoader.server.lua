-- MeshLoader.server.lua
-- Open Cloud uploaded our FBX as Model assets (folders containing MeshParts).
-- This script loads each Model via InsertService at server boot, extracts the inner
-- MeshPart, and exposes a global table of raw Mesh asset IDs that other scripts can
-- use to construct MeshParts directly.
-- Place in: ServerScriptService > MeshLoader (Script). Auto-runs.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("AssetIds"))

local CACHE = {}
_G.KittyRaiserMeshes = CACHE  -- exposed for CatCharacterBuilder + CityRebuild

local function extractFromModelAsset(modelAssetId)
    if not modelAssetId or modelAssetId == 0 or modelAssetId == "" then return nil end
    local id = tonumber(string.match(tostring(modelAssetId), "%d+"))
    if not id or id == 0 then return nil end
    local ok, model = pcall(function() return InsertService:LoadAsset(id) end)
    if not ok or not model then
        warn("[MeshLoader] LoadAsset failed for", id, model)
        return nil
    end
    -- Find the MeshPart inside (Open Cloud Model contains 1+ MeshParts)
    local mp
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("MeshPart") then mp = d; break end
    end
    if not mp then
        warn("[MeshLoader] no MeshPart in model", id)
        model:Destroy()
        return nil
    end
    local result = {
        meshAssetId = id,        -- the parent Model asset id
        meshTemplate = mp:Clone(),  -- pre-extracted MeshPart, clone-ready
    }
    model:Destroy()
    return result
end

local NAMES = {
    -- Cat
    "mesh_cat_body", "mesh_cat_head", "mesh_cat_ear", "mesh_cat_leg", "mesh_cat_tail",
    -- Pranks
    "mesh_anvil", "mesh_pie",
    -- World props
    "mesh_brownstone", "mesh_skyscraper",
    "mesh_taxi", "mesh_trashcan", "mesh_hydrant", "mesh_mailbox",
    -- New (will silently skip if AssetIds entry is "rbxassetid://0")
    "mesh_cop_car", "mesh_streetlamp", "mesh_park_bench",
    "mesh_oak_tree", "mesh_palm_tree", "mesh_donut", "mesh_coffee",
    "mesh_manhole", "mesh_fire_truck",
    -- v2 city meshes (Higgsfield Blender batch, uploaded May 4)
    "mesh_taxi_yellow", "mesh_delivery_van", "mesh_food_truck",
    "mesh_fire_hydrant", "mesh_trash_can", "mesh_mailbox_blue",
    "mesh_bus_stop_shelter", "mesh_traffic_light", "mesh_hot_dog_cart",
    "mesh_skyscraper_chunk",
}

local loaded = 0
for _, name in ipairs(NAMES) do
    local id = AssetIds[name]
    if id and id ~= "rbxassetid://0" then
        local r = extractFromModelAsset(id)
        if r then
            CACHE[name] = r
            loaded = loaded + 1
            print("[MeshLoader] cached", name, "->", r.meshTemplate.Name)
        end
    end
end

print(("[MeshLoader] %d/%d meshes loaded and cached"):format(loaded, #NAMES))
