-- AssetIds.lua
-- Single source of truth for uploaded Roblox asset IDs.
-- Place in: ReplicatedStorage > Modules > AssetIds (ModuleScript)
--
-- After bulk-uploading via Studio Asset Manager:
--   1. In Asset Manager, right-click each asset -> Copy Asset ID
--   2. Paste the numeric portion below (replace the 0 after rbxassetid://)
--
-- Any value left as "rbxassetid://0" falls back to the procedural Frame icon
-- via ModernHUD's smartIcon() helper. So missing IDs don't crash anything.

local AssetIds = {}

-- ===================== HUD ICONS (256x256 PNG) =====================
AssetIds.coin     = "rbxassetid://0"
AssetIds.gem      = "rbxassetid://0"
AssetIds.robux    = "rbxassetid://0"
AssetIds.paw      = "rbxassetid://0"
AssetIds.scratch  = "rbxassetid://0"
AssetIds.pie      = "rbxassetid://0"
AssetIds.fish     = "rbxassetid://0"
AssetIds.slushie  = "rbxassetid://0"
AssetIds.tp       = "rbxassetid://0"
AssetIds.anvil    = "rbxassetid://0"
AssetIds.skull    = "rbxassetid://0"
AssetIds.wings    = "rbxassetid://0"
AssetIds.shop     = "rbxassetid://0"
AssetIds.bag      = "rbxassetid://0"
AssetIds.bars     = "rbxassetid://0"
AssetIds.gift     = "rbxassetid://0"
AssetIds.slot     = "rbxassetid://0"
AssetIds.star     = "rbxassetid://0"
AssetIds.trophy   = "rbxassetid://0"

-- ===================== TEXTURES (512x512 seamless) =====================
AssetIds.asphalt           = "rbxassetid://0"
AssetIds.brick             = "rbxassetid://0"
AssetIds.concrete          = "rbxassetid://0"
AssetIds.fur_orange        = "rbxassetid://0"
AssetIds.grass             = "rbxassetid://0"
AssetIds.neon_sign         = "rbxassetid://0"
AssetIds.skyscraper_windows = "rbxassetid://0"

-- ===================== SOUNDS (mono WAV @ 44.1kHz) =====================
AssetIds.anvil_clang    = "rbxassetid://0"
AssetIds.cat_scratch    = "rbxassetid://0"
AssetIds.coin_pickup    = "rbxassetid://0"
AssetIds.fish_slap      = "rbxassetid://0"
AssetIds.flight_whoosh  = "rbxassetid://0"
AssetIds.ko_sound       = "rbxassetid://0"
AssetIds.level_up       = "rbxassetid://0"
AssetIds.meow_1         = "rbxassetid://0"
AssetIds.meow_2         = "rbxassetid://0"
AssetIds.meow_3         = "rbxassetid://0"
AssetIds.pie_splat      = "rbxassetid://0"
AssetIds.purrgatory     = "rbxassetid://0"
AssetIds.slushie_freeze = "rbxassetid://0"
AssetIds.spawn_chime    = "rbxassetid://0"
AssetIds.tp_unroll      = "rbxassetid://0"

-- ===================== MESHES (OBJ -> MeshPart.MeshId) =====================
AssetIds.mesh_anvil       = "rbxassetid://0"
AssetIds.mesh_brownstone  = "rbxassetid://0"
AssetIds.mesh_cat_body    = "rbxassetid://0"
AssetIds.mesh_cat_ear     = "rbxassetid://0"
AssetIds.mesh_cat_head    = "rbxassetid://0"
AssetIds.mesh_cat_leg     = "rbxassetid://0"
AssetIds.mesh_cat_tail    = "rbxassetid://0"
AssetIds.mesh_hydrant     = "rbxassetid://0"
AssetIds.mesh_mailbox     = "rbxassetid://0"
AssetIds.mesh_pie         = "rbxassetid://0"
AssetIds.mesh_skyscraper  = "rbxassetid://0"
AssetIds.mesh_taxi        = "rbxassetid://0"
AssetIds.mesh_trashcan    = "rbxassetid://0"

-- ===================== MARKETING (icon + thumbnails) =====================
-- These are uploaded via Creator Dashboard, not Asset Manager.
-- Put their IDs here only if you also want them referenced from in-game UI.
AssetIds.game_icon = "rbxassetid://0"
AssetIds.thumb_pie_throw  = "rbxassetid://0"
AssetIds.thumb_anvil_drop = "rbxassetid://0"
AssetIds.thumb_city_night = "rbxassetid://0"
AssetIds.thumb_lobby      = "rbxassetid://0"

-- ===================== HELPERS =====================

-- Returns true if the alias has a real (non-zero) asset ID.
function AssetIds.has(name)
    local v = AssetIds[name]
    return type(v) == "string" and v ~= "rbxassetid://0" and v ~= ""
end

-- Returns the asset ID string, or nil if unset.
function AssetIds.get(name)
    if AssetIds.has(name) then return AssetIds[name] end
    return nil
end

return AssetIds
