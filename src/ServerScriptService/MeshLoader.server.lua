-- MeshLoader.server.lua
-- Loads each Open Cloud Model asset, extracts the inner MeshPart, and exposes
-- a global table other scripts use to construct MeshParts directly.
-- Place in: ServerScriptService > MeshLoader (Script). Auto-runs.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait with a timeout instead of indefinitely; if AssetIds isn't replicated,
-- we want to fail loud rather than hang the whole server boot.
local Modules = ReplicatedStorage:WaitForChild("Modules", 15)
if not Modules then warn("[MeshLoader] ReplicatedStorage.Modules missing"); return end
local AssetIds = Modules:WaitForChild("AssetIds", 15)
if not AssetIds then warn("[MeshLoader] AssetIds module missing"); return end
AssetIds = require(AssetIds)

local CACHE = {}
_G.KittyRaiserMeshes = CACHE

local function extractFromModelAsset(modelAssetId)
    if not modelAssetId or modelAssetId == 0 or modelAssetId == "" then return nil end
    local id = tonumber(string.match(tostring(modelAssetId), "%d+"))
    if not id or id == 0 then return nil end
    local ok, model = pcall(function() return InsertService:LoadAsset(id) end)
    if not ok or not model then
        warn("[MeshLoader] LoadAsset failed for", id, model)
        return nil
    end
    -- Find the first MeshPart inside the loaded Model.
    local mp
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("MeshPart") then mp = d; break end
    end
    if not mp then
        warn("[MeshLoader] no MeshPart in model", id)
        model:Destroy()
        return nil
    end
    -- Clone the MeshPart and any descendants (decals, surface gui, etc.) so we
    -- don't lose ancillary visuals attached to it.
    local cloned = mp:Clone()
    local result = {
        meshAssetId = id,
        meshTemplate = cloned,
    }
    model:Destroy()
    return result
end

local NAMES = {
    "mesh_cat_body", "mesh_cat_head", "mesh_cat_ear", "mesh_cat_leg", "mesh_cat_tail",
    "mesh_anvil", "mesh_brownstone", "mesh_skyscraper", "mesh_taxi",
    "mesh_trashcan", "mesh_hydrant", "mesh_mailbox", "mesh_pie",
}

-- Compare against a stringified zero placeholder; the previous code compared a
-- string sentinel to a number (always-true bug).
local function isPlaceholder(v)
    if v == nil then return true end
    local n = tonumber(string.match(tostring(v), "%d+"))
    return not n or n == 0
end

local loaded = 0
for _, name in ipairs(NAMES) do
    local id = AssetIds[name]
    if not isPlaceholder(id) then
        local r = extractFromModelAsset(id)
        if r then
            CACHE[name] = r
            loaded = loaded + 1
            print("[MeshLoader] cached", name, "->", r.meshTemplate.Name)
        end
    end
end

print(("[MeshLoader] %d/%d meshes loaded and cached"):format(loaded, #NAMES))
