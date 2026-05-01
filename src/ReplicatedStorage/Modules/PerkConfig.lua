-- PerkConfig.lua
-- Perks granted every 5 levels. Player picks 1 of 5 per slot. Reset costs Hell Tokens or Robux.
-- Place in: ReplicatedStorage > Modules > PerkConfig (ModuleScript)

local PerkConfig = {}

-- Each perk has: id, name, description, effect (data flag the systems read)
PerkConfig.Perks = {
    -- Slot 1 (unlocks at L5)
    QuickPaws = {id = "QuickPaws", name = "Quick Paws", desc = "-10% prank cooldown", slot = 1, effect = {cooldownReduc = 0.10}},
    SharpClaws = {id = "SharpClaws", name = "Sharp Claws", desc = "+15% Cat Scratch chaos", slot = 1, effect = {prankBoost = {CatScratch = 0.15}}},
    LightFeet = {id = "LightFeet", name = "Light Feet", desc = "+15% walk speed", slot = 1, effect = {speedMult = 0.15}},
    KeenEyes = {id = "KeenEyes", name = "Keen Eyes", desc = "+25% prank range", slot = 1, effect = {rangeMult = 0.25}},
    GoldenWhiskers = {id = "GoldenWhiskers", name = "Golden Whiskers", desc = "+10% Chaos on all pranks", slot = 1, effect = {chaosMult = 0.10}},

    -- Slot 2 (L10)
    PieMaster = {id = "PieMaster", name = "Pie Master", desc = "Pies splash 3 nearby targets", slot = 2, effect = {pieSplash = true, splashTargets = 3}},
    HairballHurricane = {id = "HairballHurricane", name = "Hairball Hurricane", desc = "Hairballs ricochet 2x", slot = 2, effect = {hairballRicochet = 2}},
    CatlikeReflex = {id = "CatlikeReflex", name = "Catlike Reflex", desc = "Dodge chance 15% on PvP", slot = 2, effect = {dodgeChance = 0.15}},
    NineLives = {id = "NineLives", name = "Nine Lives", desc = "Auto-revive 1x per session", slot = 2, effect = {autoReviveCount = 1}},
    LuckyTabby = {id = "LuckyTabby", name = "Lucky Tabby", desc = "+5 to Luck stat", slot = 2, effect = {luckBonus = 5}},

    -- Slot 3 (L15)
    AnvilArtisan = {id = "AnvilArtisan", name = "Anvil Artisan", desc = "Anvils crit 25% for 3x damage", slot = 3, effect = {anvilCritChance = 0.25, anvilCritMult = 3}},
    ToxicGas = {id = "ToxicGas", name = "Toxic Gas", desc = "Fart Cloud DOT for 5s", slot = 3, effect = {fartDOT = {dur=5, tickChaos=20}}},
    LaserFocus = {id = "LaserFocus", name = "Laser Focus", desc = "Laser pierces 3 targets", slot = 3, effect = {laserPierce = 3}},
    ChaosFeast = {id = "ChaosFeast", name = "Chaos Feast", desc = "Pranks restore 5 hunger", slot = 3, effect = {prankHungerRestore = 5}},
    ShadowStalker = {id = "ShadowStalker", name = "Shadow Stalker", desc = "Invisible after standing still 2s", slot = 3, effect = {stealthAfter = 2}},

    -- Slot 4 (L20)
    Whirlwind = {id = "Whirlwind", name = "Whirlwind", desc = "Tail Whip hits all in 8 studs", slot = 4, effect = {whipAOE = 8}},
    Vampuss = {id = "Vampuss", name = "Vampuss", desc = "Restore 2 hunger per prank", slot = 4, effect = {prankHungerRestore = 2}},
    HellfireAura = {id = "HellfireAura", name = "Hellfire Aura", desc = "+1 chaos/sec while Red Mist active", slot = 4, effect = {redMistChaosPerSec = 1}},
    Bountybane = {id = "Bountybane", name = "Bountybane", desc = "+50% chaos during PvP", slot = 4, effect = {pvpChaosMult = 0.50}},
    GoldenScratch = {id = "GoldenScratch", name = "Golden Scratch", desc = "5% chance for 10x Cat Scratch", slot = 4, effect = {catScratchJackpot = 0.05}},

    -- Slot 5 (L25 — same level rebirth unlocks)
    DemonForm = {id = "DemonForm", name = "Demon Form", desc = "Toggle: 2x speed, 2x chaos, drains hunger", slot = 5, effect = {demonForm = true}},
    HellHarvester = {id = "HellHarvester", name = "Hell Harvester", desc = "+1 Hell Token per 1000 chaos earned", slot = 5, effect = {hellTokenPerKChaos = 1}},
    Purrgatory_Prime = {id = "Purrgatory_Prime", name = "Purrgatory Prime", desc = "Purrgatory unlocks 10 levels early", slot = 5, effect = {purrgatoryEarly = 10}},
    SoulCollector = {id = "SoulCollector", name = "Soul Collector", desc = "Pranked NPCs drop Soul Shards (cosmetic currency)", slot = 5, effect = {soulShardDropChance = 0.20}},
    KingOfChaos = {id = "KingOfChaos", name = "King of Chaos", desc = "All pranks +25% chaos but cooldown +10%", slot = 5, effect = {chaosMult = 0.25, cooldownPenalty = 0.10}},
}

-- Per slot index, list the 5 options
PerkConfig.SlotOptions = {
    [1] = {"QuickPaws", "SharpClaws", "LightFeet", "KeenEyes", "GoldenWhiskers"},
    [2] = {"PieMaster", "HairballHurricane", "CatlikeReflex", "NineLives", "LuckyTabby"},
    [3] = {"AnvilArtisan", "ToxicGas", "LaserFocus", "ChaosFeast", "ShadowStalker"},
    [4] = {"Whirlwind", "Vampuss", "HellfireAura", "Bountybane", "GoldenScratch"},
    [5] = {"DemonForm", "HellHarvester", "Purrgatory_Prime", "SoulCollector", "KingOfChaos"},
}

function PerkConfig.getPerk(id) return PerkConfig.Perks[id] end
function PerkConfig.optionsForSlot(slot) return PerkConfig.SlotOptions[slot] or {} end

return PerkConfig
