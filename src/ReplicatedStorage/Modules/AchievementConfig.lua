-- AchievementConfig.lua  — definitions for in-game achievements / badges.
-- Each entry has:
--   id             — internal key (also AssetIds.badge_<id> when uploaded)
--   name           — display name
--   description    — what to do
--   trigger        — kind: "first_prank" | "level" | "rebirth" | "boss_defeat" | "ticketed"
--   threshold      — number for level/rebirth thresholds
--   badgeAssetKey  — key in AssetIds.lua (rbxassetid://0 placeholder until you
--                    create the badge in Creator Hub and paste the id)

local AchievementConfig = {}

AchievementConfig.List = {
    { id = "first_prank",  name = "First Prank",        description = "Land your first prank.",
      trigger = "first_prank",  badgeAssetKey = "badge_first_prank" },
    { id = "level_10",     name = "Climbing the Ladder",description = "Reach Level 10.",
      trigger = "level", threshold = 10,  badgeAssetKey = "badge_level_10" },
    { id = "level_25",     name = "Veteran Vandal",     description = "Reach Level 25.",
      trigger = "level", threshold = 25,  badgeAssetKey = "badge_level_25" },
    { id = "level_50",     name = "Half a Hundred",     description = "Reach Level 50.",
      trigger = "level", threshold = 50,  badgeAssetKey = "badge_level_50" },
    { id = "level_100",    name = "Maximum Mayhem",     description = "Reach Level 100.",
      trigger = "level", threshold = 100, badgeAssetKey = "badge_level_100" },
    { id = "first_rebirth",name = "Born Again",         description = "Rebirth for the first time.",
      trigger = "rebirth",  badgeAssetKey = "badge_first_rebirth" },
    { id = "boss_defeat",  name = "Giant Slayer",       description = "Defeat your first boss.",
      trigger = "boss_defeat",  badgeAssetKey = "badge_boss_defeat" },
    { id = "ticketed",     name = "Wanted",             description = "Get caught by a cop (it happens).",
      trigger = "ticketed", badgeAssetKey = "badge_ticketed" },
}

return AchievementConfig
