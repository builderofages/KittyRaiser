local function getOrMake(parent, className, name)
    local existing = parent:FindFirstChild(name)
    if existing and existing.ClassName == className then return existing end
    if existing then existing:Destroy() end
    local obj = Instance.new(className)
    obj.Name = name
    obj.Parent = parent
    return obj
end
local modulesFolder = getOrMake(game.ReplicatedStorage, 'Folder', 'Modules')
do
    local s = getOrMake(modulesFolder, 'ModuleScript', 'GameConfig')
    s.Source = [[
-- GameConfig.lua
-- Central configuration. Edit values here, do not hard-code in scripts.
-- Place in: ReplicatedStorage > Modules > GameConfig (ModuleScript)

local GameConfig = {}

-- ===== ECONOMY =====
GameConfig.STARTING_CHAOS = 0
GameConfig.STARTING_HELLTOKENS = 0
GameConfig.STARTING_LEVEL = 1
GameConfig.LEVEL_CAP = 100  -- Per Grok: ~3 weeks at 8h/day
GameConfig.REBIRTH_REQUIRED_LEVEL = 25
GameConfig.REBIRTH_SOFT_CAP = 25
GameConfig.REBIRTH_MULTIPLIER_PER_REBIRTH = 0.25

-- XP curve
GameConfig.XP_BASE = 100
GameConfig.XP_EXPONENT = 1.4

-- ===== PRANK BASE =====
GameConfig.PRANK_RANGE_STUDS = 18
GameConfig.PRANK_XP_PER_HIT = 10

-- ===== STATS (Fallout-style) =====
GameConfig.STATS_PER_LEVEL = 1
GameConfig.STAT_NAMES = {"Speed", "Jump", "Luck", "Strength", "Agility"}
GameConfig.STAT_MAX = 50
GameConfig.STAT_BASE = 10
GameConfig.STAT_EFFECTS = {
    Speed = {walkSpeedPerPoint = 0.4},     -- 10 base speed -> +0.4/point
    Jump = {jumpPowerPerPoint = 1.2},
    Luck = {chaosBonusPerPoint = 0.01},    -- +1% chaos per point
    Strength = {prankPowerPerPoint = 0.02},
    Agility = {cooldownReducPerPoint = 0.005},
}

-- ===== PERKS =====
GameConfig.PERK_GRANT_EVERY = 5  -- gain a perk slot every 5 levels
GameConfig.PERK_RESET_HELLTOKENS = 100
GameConfig.PERK_RESET_ROBUX_PRODUCT = "PERK_RESET"

-- ===== SURVIVAL =====
GameConfig.SURVIVAL_ENABLED = true
GameConfig.HUNGER_DECAY_PER_MIN = 5    -- 100 -> 0 in 20 min
GameConfig.THIRST_DECAY_PER_MIN = 8    -- 100 -> 0 in ~12 min
GameConfig.SURVIVAL_DEBUFF_AT = 25     -- below 25, slowed
GameConfig.SURVIVAL_DEATH_AT = 0
GameConfig.FOOD_RESTORE = 40
GameConfig.WATER_RESTORE = 50

-- ===== WEATHER =====
GameConfig.WEATHER_CYCLE_MIN = 8       -- a weather state lasts ~8 min
GameConfig.WEATHER_TYPES = {"Sunny", "Rainy", "Foggy", "RedMist"}
GameConfig.WEATHER_WEIGHTS = {Sunny=0.45, Rainy=0.25, Foggy=0.20, RedMist=0.10}
GameConfig.RED_MIST_CHAOS_MULT = 2.0   -- 2x chaos during red mist
GameConfig.RED_MIST_DURATION_MIN = 4

-- ===== EMOTES =====
GameConfig.EMOTES = {"Meow", "Hiss", "Dance", "Laugh", "Sit", "Wave"}

-- ===== ANTI-CHEAT =====
GameConfig.MAX_PRANKS_PER_SECOND = 6
GameConfig.MAX_DISTANCE_TELEPORT = 60
GameConfig.SUSPICIOUS_FLAG_THRESHOLD = 3

-- ===== SAVE =====
GameConfig.DATASTORE_NAME = "KittyRaiserData_v1"
GameConfig.DATASTORE_KEY_PREFIX = "Player_"
GameConfig.AUTOSAVE_INTERVAL = 60
GameConfig.SCHEMA_VERSION = 2  -- bumped: added stats/survival/perks/hellTokens

-- ===== MONETIZATION =====
GameConfig.GAMEPASS_IDS = {
    DEMON_SKIN = 0,
    NEON_SKIN = 0,
    HELLBORN_SKIN = 0,
    VIP = 0,
    GANG_LEADER = 0,
    ULTIMATE_CHAOS = 0,
}

GameConfig.DEVPRODUCT_IDS = {
    CHAOS_5K = 0,
    CHAOS_50K = 0,
    CHAOS_500K = 0,
    HELLTOKENS_100 = 0,
    HELLTOKENS_1000 = 0,
    REBIRTH_SKIP = 0,
    PERK_RESET = 0,
    DAILY_DOUBLE = 0,
}

GameConfig.VIP_CHAOS_MULTIPLIER = 2.0

-- ===== HUD =====
GameConfig.HUD_PRIMARY_COLOR = Color3.fromRGB(150, 50, 200)
GameConfig.HUD_ACCENT_COLOR = Color3.fromRGB(0, 255, 100)
GameConfig.HUD_DANGER_COLOR = Color3.fromRGB(255, 60, 60)
GameConfig.HUD_HELLTOKEN_COLOR = Color3.fromRGB(255, 200, 0)

-- ===== ANALYTICS =====
GameConfig.ANALYTICS_ENABLED = true

-- ===== UTILITY =====
function GameConfig.xpRequired(level)
    return math.floor(GameConfig.XP_BASE * (level ^ GameConfig.XP_EXPONENT))
end

function GameConfig.computeMultiplier(rebirths, hasVIP, luckStat)
    local rebirthMult = 1 + (GameConfig.REBIRTH_MULTIPLIER_PER_REBIRTH * (rebirths or 0))
    local vipMult = hasVIP and GameConfig.VIP_CHAOS_MULTIPLIER or 1
    local luckMult = 1 + ((luckStat or 0) * (GameConfig.STAT_EFFECTS.Luck.chaosBonusPerPoint or 0))
    return rebirthMult * vipMult * luckMult
end

function GameConfig.perkSlotsAtLevel(level)
    return math.floor((level or 1) / GameConfig.PERK_GRANT_EVERY)
end

return GameConfig

]]
end

do
    local s = getOrMake(modulesFolder, 'ModuleScript', 'PrankConfig')
    s.Source = [[
-- PrankConfig.lua
-- All prank/power types per Grok bible: Cat Scratch (starter), Pie, Hairball, Anvil, Fart, Laser, Whip, Purrgatory
-- Place in: ReplicatedStorage > Modules > PrankConfig (ModuleScript)

local PrankConfig = {}

PrankConfig.Pranks = {
    CatScratch = {
        name = "CatScratch",
        displayName = "Cat Scratch",
        unlockLevel = 1,
        baseChaos = 10,
        cooldown = 0.8,
        rangeStuds = 8,
        soundId = "rbxassetid://9117567259",
        particleColor = Color3.fromRGB(255, 220, 220),
        screenShake = 1,
        animation = "claw_swipe",
        icon = "✊",
    },
    Pie = {
        name = "Pie",
        displayName = "Cream Pie",
        unlockLevel = 2,
        baseChaos = 25,
        cooldown = 1.5,
        rangeStuds = 14,
        soundId = "rbxassetid://517040733",
        particleColor = Color3.fromRGB(255, 240, 180),
        screenShake = 0,
        animation = "throw_pie",
        icon = "🥧",
    },
    Hairball = {
        name = "Hairball",
        displayName = "Hairball Bomb",
        unlockLevel = 5,
        baseChaos = 50,
        cooldown = 3,
        rangeStuds = 16,
        soundId = "rbxassetid://9117568141",
        particleColor = Color3.fromRGB(180, 140, 100),
        screenShake = 2,
        animation = "hairball_pop",
        icon = "🦴",
    },
    Anvil = {
        name = "Anvil",
        displayName = "Anvil Drop",
        unlockLevel = 8,
        baseChaos = 100,
        cooldown = 4,
        rangeStuds = 16,
        soundId = "rbxassetid://5451260445",
        particleColor = Color3.fromRGB(120, 120, 120),
        screenShake = 4,
        animation = "anvil_drop",
        icon = "🔨",
    },
    FartCloud = {
        name = "FartCloud",
        displayName = "Fart Cloud",
        unlockLevel = 12,
        baseChaos = 200,
        cooldown = 6,
        rangeStuds = 12,
        aoeStuds = 8,
        soundId = "rbxassetid://1845015288",
        particleColor = Color3.fromRGB(140, 200, 80),
        screenShake = 2,
        animation = "fart_butt",
        icon = "💨",
    },
    LaserEyes = {
        name = "LaserEyes",
        displayName = "Laser Eyes",
        unlockLevel = 18,
        baseChaos = 350,
        cooldown = 8,
        rangeStuds = 28,
        soundId = "rbxassetid://3820883381",
        particleColor = Color3.fromRGB(255, 50, 50),
        screenShake = 8,
        animation = "laser_glare",
        icon = "👁️",
    },
    Whip = {
        name = "Whip",
        displayName = "Tail Whip",
        unlockLevel = 25,
        baseChaos = 500,
        cooldown = 6,
        rangeStuds = 14,
        soundId = "rbxassetid://9117569015",
        particleColor = Color3.fromRGB(200, 100, 255),
        screenShake = 4,
        animation = "tail_whip",
        icon = "🌀",
    },
    Purrgatory = {
        name = "Purrgatory",
        displayName = "Purrgatory",
        unlockLevel = 35,
        baseChaos = 1000,
        cooldown = 12,
        rangeStuds = 22,
        aoeStuds = 14,
        soundId = "rbxassetid://9117570233",
        particleColor = Color3.fromRGB(255, 0, 200),
        screenShake = 12,
        animation = "soul_stare",
        icon = "👻",
    },
}

PrankConfig.Order = {"CatScratch", "Pie", "Hairball", "Anvil", "FartCloud", "LaserEyes", "Whip", "Purrgatory"}

function PrankConfig.getPrank(name) return PrankConfig.Pranks[name] end
function PrankConfig.isUnlocked(prankName, playerLevel)
    local p = PrankConfig.Pranks[prankName]
    if not p then return false end
    return playerLevel >= p.unlockLevel
end

return PrankConfig

]]
end

do
    local s = getOrMake(modulesFolder, 'ModuleScript', 'CosmeticConfig')
    s.Source = [[
-- CosmeticConfig.lua
-- 25 cat skins per Grok bible expansion (full 75 in v2). Mix of Chaos / HellToken / Robux currency.
-- Place in: ReplicatedStorage > Modules > CosmeticConfig (ModuleScript)

local CosmeticConfig = {}

local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local function uniformBody(c)
    return {HeadColor=c, TorsoColor=c, LeftArmColor=c, RightArmColor=c, LeftLegColor=c, RightLegColor=c}
end

CosmeticConfig.Skins = {
    -- COMMON (free / starter)
    Default = {id="Default", displayName="Alley Cat", cost=0, currency="free", bodyColors=uniformBody(rgb(105,64,40)), chaosMultiplier=1.0, rarity="Common"},
    Stripey = {id="Stripey", displayName="Stripey", cost=500, currency="chaos", bodyColors=uniformBody(rgb(245,165,80)), chaosMultiplier=1.05, rarity="Common"},
    Black = {id="Black", displayName="Shadow", cost=750, currency="chaos", bodyColors=uniformBody(rgb(20,20,20)), chaosMultiplier=1.05, rarity="Common"},
    White = {id="White", displayName="Snowball", cost=750, currency="chaos", bodyColors=uniformBody(rgb(245,245,245)), chaosMultiplier=1.05, rarity="Common"},
    Gray = {id="Gray", displayName="Dust", cost=750, currency="chaos", bodyColors=uniformBody(rgb(140,140,140)), chaosMultiplier=1.05, rarity="Common"},

    -- UNCOMMON (chaos)
    Calico = {id="Calico", displayName="Calico", cost=2500, currency="chaos", bodyColors={HeadColor=rgb(255,255,255), TorsoColor=rgb(40,30,25), LeftArmColor=rgb(220,130,50), RightArmColor=rgb(255,255,255), LeftLegColor=rgb(40,30,25), RightLegColor=rgb(220,130,50)}, chaosMultiplier=1.10, rarity="Uncommon"},
    Tuxedo = {id="Tuxedo", displayName="Tuxedo", cost=2500, currency="chaos", bodyColors={HeadColor=rgb(20,20,20), TorsoColor=rgb(20,20,20), LeftArmColor=rgb(245,245,245), RightArmColor=rgb(245,245,245), LeftLegColor=rgb(245,245,245), RightLegColor=rgb(245,245,245)}, chaosMultiplier=1.10, rarity="Uncommon"},
    Ginger = {id="Ginger", displayName="Ginger", cost=2500, currency="chaos", bodyColors=uniformBody(rgb(220,90,30)), chaosMultiplier=1.10, rarity="Uncommon"},
    Mint = {id="Mint", displayName="Mint", cost=4000, currency="chaos", bodyColors=uniformBody(rgb(140,220,180)), chaosMultiplier=1.12, rarity="Uncommon"},
    Lilac = {id="Lilac", displayName="Lilac", cost=4000, currency="chaos", bodyColors=uniformBody(rgb(200,160,255)), chaosMultiplier=1.12, rarity="Uncommon"},

    -- RARE (chaos high cost)
    SiameseRoyal = {id="SiameseRoyal", displayName="Siamese Royal", cost=10000, currency="chaos", bodyColors={HeadColor=rgb(220,200,180), TorsoColor=rgb(50,30,20), LeftArmColor=rgb(50,30,20), RightArmColor=rgb(50,30,20), LeftLegColor=rgb(50,30,20), RightLegColor=rgb(50,30,20)}, chaosMultiplier=1.20, rarity="Rare"},
    Sphinx = {id="Sphinx", displayName="Sphinx", cost=15000, currency="chaos", bodyColors=uniformBody(rgb(240,210,180)), chaosMultiplier=1.25, rarity="Rare"},
    SpacePaws = {id="SpacePaws", displayName="Space Paws", cost=20000, currency="chaos", bodyColors=uniformBody(rgb(40,20,80)), chaosMultiplier=1.25, rarity="Rare", glowEffect=true},
    GoldenTabby = {id="GoldenTabby", displayName="Golden Tabby", cost=25000, currency="chaos", bodyColors=uniformBody(rgb(255,210,80)), chaosMultiplier=1.30, rarity="Rare", material=Enum.Material.Metal},

    -- EPIC (Hell Tokens)
    Skeleton = {id="Skeleton", displayName="Skeleton", cost=50, currency="helltokens", bodyColors=uniformBody(rgb(245,245,235)), chaosMultiplier=1.40, rarity="Epic"},
    Zombie = {id="Zombie", displayName="Zombie Cat", cost=75, currency="helltokens", bodyColors=uniformBody(rgb(120,160,80)), chaosMultiplier=1.40, rarity="Epic"},
    Vampire = {id="Vampire", displayName="Vampire Cat", cost=100, currency="helltokens", bodyColors=uniformBody(rgb(60,0,30)), chaosMultiplier=1.45, rarity="Epic", glowEffect=true},
    Mummy = {id="Mummy", displayName="Mummy Cat", cost=100, currency="helltokens", bodyColors=uniformBody(rgb(220,200,160)), chaosMultiplier=1.45, rarity="Epic"},

    -- LEGENDARY (Robux GamePass)
    Demon = {id="Demon", displayName="Demon Cat", cost=0, currency="robux", gamepassKey="DEMON_SKIN", bodyColors={HeadColor=rgb(120,0,0), TorsoColor=rgb(60,0,0), LeftArmColor=rgb(80,0,0), RightArmColor=rgb(80,0,0), LeftLegColor=rgb(60,0,0), RightLegColor=rgb(60,0,0)}, chaosMultiplier=1.5, rarity="Legendary", glowEffect=true},
    Neon = {id="Neon", displayName="Neon Cat", cost=0, currency="robux", gamepassKey="NEON_SKIN", bodyColors={HeadColor=rgb(0,200,255), TorsoColor=rgb(255,0,200), LeftArmColor=rgb(0,255,100), RightArmColor=rgb(255,200,0), LeftLegColor=rgb(0,200,255), RightLegColor=rgb(255,0,200)}, chaosMultiplier=2.0, rarity="Legendary", glowEffect=true, material=Enum.Material.Neon},
    Hellborn = {id="Hellborn", displayName="Hellborn", cost=0, currency="robux", gamepassKey="HELLBORN_SKIN", bodyColors=uniformBody(rgb(255,40,0)), chaosMultiplier=2.5, rarity="Legendary", glowEffect=true, material=Enum.Material.Neon},

    -- MYTHIC (event-only / season pass — placeholders for v2)
    GalaxyKing = {id="GalaxyKing", displayName="Galaxy King", cost=999999, currency="chaos", bodyColors=uniformBody(rgb(80,40,180)), chaosMultiplier=3.0, rarity="Mythic", glowEffect=true, material=Enum.Material.ForceField, eventOnly=true},
    PhoenixCat = {id="PhoenixCat", displayName="Phoenix Cat", cost=500, currency="helltokens", bodyColors=uniformBody(rgb(255,120,0)), chaosMultiplier=3.0, rarity="Mythic", glowEffect=true, material=Enum.Material.Neon, eventOnly=true},
    VoidCat = {id="VoidCat", displayName="Void Cat", cost=1000, currency="helltokens", bodyColors=uniformBody(rgb(10,0,30)), chaosMultiplier=3.5, rarity="Mythic", glowEffect=true},
    KittyRaiser = {id="KittyRaiser", displayName="The KittyRaiser", cost=999, currency="helltokens", bodyColors={HeadColor=rgb(255,0,80), TorsoColor=rgb(0,0,0), LeftArmColor=rgb(255,0,80), RightArmColor=rgb(255,0,80), LeftLegColor=rgb(0,0,0), RightLegColor=rgb(0,0,0)}, chaosMultiplier=4.0, rarity="Mythic", glowEffect=true, material=Enum.Material.Neon},
}

CosmeticConfig.Order = {
    "Default","Stripey","Black","White","Gray",
    "Calico","Tuxedo","Ginger","Mint","Lilac",
    "SiameseRoyal","Sphinx","SpacePaws","GoldenTabby",
    "Skeleton","Zombie","Vampire","Mummy",
    "Demon","Neon","Hellborn",
    "GalaxyKing","PhoenixCat","VoidCat","KittyRaiser",
}

CosmeticConfig.DEFAULT_OWNED = {"Default"}

function CosmeticConfig.getSkin(id) return CosmeticConfig.Skins[id] end
function CosmeticConfig.getMultiplier(id)
    local s = CosmeticConfig.Skins[id]
    return s and s.chaosMultiplier or 1.0
end

return CosmeticConfig

]]
end

do
    local s = getOrMake(modulesFolder, 'ModuleScript', 'PerkConfig')
    s.Source = [[
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

]]
end

do
    local s = getOrMake(modulesFolder, 'ModuleScript', 'RemoteEvents')
    s.Source = [[
-- RemoteEvents.lua
-- Single source of truth for all RemoteEvents and RemoteFunctions.
-- Place in: ReplicatedStorage > Modules > RemoteEvents (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local DEFINITIONS = {
    -- Client -> Server
    RequestSummonHuman = "Event",
    RequestPrank = "Event",
    RequestRebirth = "Function",
    RequestEquipSkin = "Function",
    RequestPurchaseSkinChaos = "Function",
    RequestPurchaseSkinHellTokens = "Function",
    RequestUseDevProduct = "Event",
    RequestEquipPerk = "Function",
    RequestResetPerks = "Function",
    RequestAllocStat = "Function",
    RequestEatFood = "Event",
    RequestDrinkWater = "Event",
    RequestEmote = "Event",
    RequestClaimDaily = "Function",
    RequestSpawnCustomization = "Event",  -- pre-spawn cat color/skin
    RequestAdminCommand = "Function",     -- admin only

    -- Server -> Client
    UpdatePlayerData = "Event",
    PrankRegistered = "Event",
    PrankFailed = "Event",
    LevelUp = "Event",
    PerkSlotEarned = "Event",  -- present picker
    RebirthCompleted = "Event",
    NotifyClient = "Event",
    LeaderboardUpdated = "Event",
    TutorialStep = "Event",
    WeatherChanged = "Event",  -- ("Sunny" | "Rainy" | "Foggy" | "RedMist")
    EventBroadcast = "Event",  -- server-wide event (eg "RedMistHour" with payload)
    EmoteBroadcast = "Event",  -- announce other player emote
    SurvivalUpdate = "Event",  -- (hunger, thirst)
    DailyAvailable = "Event",  -- (day#, reward)
}

local FOLDER_NAME = "KittyRaiserRemotes"

local function getOrCreateFolder()
    local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
    if not folder and RunService:IsServer() then
        folder = Instance.new("Folder")
        folder.Name = FOLDER_NAME
        folder.Parent = ReplicatedStorage
    elseif not folder then
        folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 10)
    end
    return folder
end

local folder = getOrCreateFolder()

local function getOrCreate(name, kind)
    local existing = folder:FindFirstChild(name)
    if existing then return existing end
    if RunService:IsServer() then
        local className = kind == "Event" and "RemoteEvent" or "RemoteFunction"
        local r = Instance.new(className)
        r.Name = name
        r.Parent = folder
        return r
    else
        return folder:WaitForChild(name, 10)
    end
end

for name, kind in pairs(DEFINITIONS) do
    Remotes[name] = getOrCreate(name, kind)
end

return Remotes

]]
end

do
    local s = getOrMake(game.ServerScriptService, 'Script', 'AnalyticsHandler')
    s.Source = [[
-- AnalyticsHandler.server.lua
-- Centralized analytics event firing. Uses Roblox AnalyticsService where possible,
-- falls back to print() in studio. External adapters (PlayFab, etc.) can hook here.
-- Place in: ServerScriptService > AnalyticsHandler (Script)

local Players = game:GetService("Players")
local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local Analytics = {}

local sessionStart = {}  -- userId -> os.time()

local function emit(eventName, player, props)
    if not GameConfig.ANALYTICS_ENABLED then return end
    local userId = player and player.UserId or 0
    local payload = {
        event = eventName,
        userId = userId,
        ts = os.time(),
        props = props or {},
    }
    if RunService:IsStudio() then
        print(string.format("[Analytics] %s userId=%d %s",
            eventName, userId, game:GetService("HttpService"):JSONEncode(props or {})))
    end
    -- Roblox built-in funnel tracking (when applicable)
    pcall(function()
        if eventName == "level_up" and props and props.newLevel then
            AnalyticsService:LogProgressionEvent(
                player,
                "MainProgression",
                Enum.AnalyticsProgressionStatus.Complete,
                props.newLevel
            )
        end
    end)
end

function Analytics.sessionStart(player)
    sessionStart[player.UserId] = os.time()
    emit("session_start", player)
end

function Analytics.sessionEnd(player)
    local start = sessionStart[player.UserId]
    local duration = start and (os.time() - start) or 0
    emit("session_end", player, {duration = duration})
    sessionStart[player.UserId] = nil
end

function Analytics.firstSummon(player)
    emit("first_summon", player)
end

function Analytics.firstPrank(player, prankName)
    emit("first_prank", player, {prank = prankName})
end

function Analytics.levelUp(player, newLevel)
    emit("level_up", player, {newLevel = newLevel})
end

function Analytics.rebirth(player, rebirths)
    emit("rebirth_completed", player, {rebirths = rebirths})
end

function Analytics.gamepassPurchased(player, gamepassId)
    emit("gamepass_purchased", player, {gamepassId = gamepassId})
end

function Analytics.devProductPurchased(player, productId)
    emit("devproduct_purchased", player, {productId = productId})
end

Players.PlayerAdded:Connect(function(p) Analytics.sessionStart(p) end)
Players.PlayerRemoving:Connect(function(p) Analytics.sessionEnd(p) end)

_G.KittyRaiserAnalytics = Analytics
return Analytics

]]
end

do
    local s = getOrMake(game.ServerScriptService, 'Script', 'AntiCheat')
    s.Source = [[
-- AntiCheat.server.lua
-- Server-side rate limiting + sanity checks. Anti-cheat is server-authoritative.
-- Place in: ServerScriptService > AntiCheat (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local AntiCheat = {}

-- Per-player rolling window: { [userId] = { lastPrankTime, prankCount, windowStart, lastPos, lastPosTime } }
local State = {}

local function getState(userId)
    if not State[userId] then
        State[userId] = {
            lastPrankTime = {},  -- per prank type
            prankWindow = {},    -- list of recent prank times
            lastPos = nil,
            lastPosTime = 0,
            flagCount = 0,
        }
    end
    return State[userId]
end

-- ===== Cooldown check =====
function AntiCheat.checkPrankCooldown(player, prankName, cooldownSec)
    local s = getState(player.UserId)
    local now = os.clock()
    local last = s.lastPrankTime[prankName] or 0
    if (now - last) < cooldownSec then
        return false, "cooldown"
    end
    s.lastPrankTime[prankName] = now
    return true, nil
end

-- ===== Rate limit (global pranks/sec) =====
function AntiCheat.checkRateLimit(player)
    local s = getState(player.UserId)
    local now = os.clock()
    -- Clean window
    local cutoff = now - 1
    local cleaned = {}
    for _, t in ipairs(s.prankWindow) do
        if t > cutoff then table.insert(cleaned, t) end
    end
    s.prankWindow = cleaned
    if #s.prankWindow >= GameConfig.MAX_PRANKS_PER_SECOND then
        AntiCheat.flag(player, "rate_limit_exceeded")
        return false, "rate_limited"
    end
    table.insert(s.prankWindow, now)
    return true, nil
end

-- ===== Distance check =====
function AntiCheat.checkPrankDistance(player, targetPart, maxStuds)
    local char = player.Character
    if not char then return false, "no_character" end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false, "no_root" end
    if not targetPart or not targetPart:IsA("BasePart") then return false, "invalid_target" end
    local dist = (hrp.Position - targetPart.Position).Magnitude
    if dist > maxStuds then
        return false, "out_of_range"
    end
    return true, nil
end

-- ===== Teleport detection =====
function AntiCheat.checkTeleport(player)
    local char = player.Character
    if not char then return true end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return true end
    local s = getState(player.UserId)
    local now = os.clock()
    if s.lastPos then
        local dt = math.max(now - s.lastPosTime, 0.001)
        local dist = (hrp.Position - s.lastPos).Magnitude
        local speed = dist / dt
        -- Roblox max running speed ~24 studs/sec; allow 3x for jumps/lag
        if speed > 80 and dist > GameConfig.MAX_DISTANCE_TELEPORT then
            AntiCheat.flag(player, "teleport_detected")
            return false
        end
    end
    s.lastPos = hrp.Position
    s.lastPosTime = now
    return true
end

-- ===== Validate target NPC =====
function AntiCheat.isValidNPC(targetModel)
    if not targetModel or not targetModel:IsA("Model") then return false end
    if not targetModel:GetAttribute("KittyRaiserNPC") then return false end
    if targetModel:GetAttribute("Pranked") then return false end -- already pranked, prevent double-grant
    return true
end

-- ===== Flag a suspicious event =====
function AntiCheat.flag(player, reason)
    local s = getState(player.UserId)
    s.flagCount = s.flagCount + 1
    warn("[AntiCheat] FLAG", player.Name, reason, "total flags:", s.flagCount)
    if s.flagCount >= GameConfig.SUSPICIOUS_FLAG_THRESHOLD then
        warn("[AntiCheat] Player", player.Name, "exceeded flag threshold - chaos grants suspended for session")
    end
end

function AntiCheat.isSuspended(player)
    local s = getState(player.UserId)
    return s.flagCount >= GameConfig.SUSPICIOUS_FLAG_THRESHOLD
end

-- Cleanup on leave
Players.PlayerRemoving:Connect(function(player)
    State[player.UserId] = nil
end)

-- Heartbeat teleport check
game:GetService("RunService").Heartbeat:Connect(function()
    for _, player in ipairs(Players:GetPlayers()) do
        AntiCheat.checkTeleport(player)
    end
end)

_G.KittyRaiserAntiCheat = AntiCheat
return AntiCheat

]]
end

do
    local s = getOrMake(game.ServerScriptService, 'Script', 'DataHandler')
    s.Source = [[
-- DataHandler.server.lua
-- Session-locked DataStore wrapper. Schema v2 (adds Hell Tokens, perks, stats, survival, daily streak).
-- Place in: ServerScriptService > DataHandler (Script)

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))
local CosmeticConfig = require(ReplicatedStorage.Modules.CosmeticConfig)
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local store = DataStoreService:GetDataStore(GameConfig.DATASTORE_NAME)

local PlayerData = {}
local LastSave = {}
local LoadingPlayers = {}

local DataHandler = {}

local function defaultData()
    return {
        version = GameConfig.SCHEMA_VERSION,
        chaosPoints = GameConfig.STARTING_CHAOS,
        hellTokens = GameConfig.STARTING_HELLTOKENS,
        level = GameConfig.STARTING_LEVEL,
        xp = 0,
        rebirths = 0,
        equippedSkin = "Default",
        ownedSkins = table.clone(CosmeticConfig.DEFAULT_OWNED),
        soulShards = 0,        -- secondary cosmetic currency
        totalPranks = 0,
        totalRobuxSpent = 0,
        firstPlayDate = os.time(),
        lastPlayDate = os.time(),
        flagCount = 0,
        settingsMusicOn = true,
        settingsSFXOn = true,
        purchasedDevProductIds = {},
        -- Stats (Fallout style)
        stats = {Speed=0, Jump=0, Luck=0, Strength=0, Agility=0},
        unspentStatPoints = 0,
        -- Perks (slot -> perkId)
        perks = {},  -- {[1]="QuickPaws", [2]="PieMaster", ...}
        -- Survival
        hunger = 100,
        thirst = 100,
        -- Daily reward
        dailyStreak = 0,
        lastDailyClaim = 0,
        -- Pre-spawn customization (custom color override)
        customSpawnColor = nil,
        customSpawnSkin = nil,
        -- Tutorial flags
        seenTutorial = false,
    }
end

local function migrate(data)
    if not data then data = defaultData() end
    if not data.version then data.version = 1 end
    if data.version < 2 then
        data.hellTokens = data.hellTokens or 0
        data.soulShards = data.soulShards or 0
        data.stats = data.stats or {Speed=0, Jump=0, Luck=0, Strength=0, Agility=0}
        data.unspentStatPoints = data.unspentStatPoints or 0
        data.perks = data.perks or {}
        data.hunger = data.hunger or 100
        data.thirst = data.thirst or 100
        data.dailyStreak = data.dailyStreak or 0
        data.lastDailyClaim = data.lastDailyClaim or 0
        data.version = 2
    end
    -- Backfill any new keys
    local def = defaultData()
    for k, v in pairs(def) do
        if data[k] == nil then data[k] = v end
    end
    return data
end

local function key(userId)
    return GameConfig.DATASTORE_KEY_PREFIX .. tostring(userId)
end

local function attemptSessionLock(userId)
    local jobId = game.JobId == "" and "studio_" .. tostring(os.time()) or game.JobId
    local acquired = false
    local existingData = nil
    local ok, err = pcall(function()
        store:UpdateAsync(key(userId), function(old)
            old = old or defaultData()
            old = migrate(old)
            if old.activeJobId and old.activeJobId ~= jobId then
                local lockTime = old.lockTime or 0
                if (os.time() - lockTime) < 120 then
                    return nil
                end
            end
            old.activeJobId = jobId
            old.lockTime = os.time()
            existingData = old
            acquired = true
            return old
        end)
    end)
    if not ok then warn("[DataHandler] Lock acquire failed:", err); return false, nil end
    return acquired, existingData
end

local function releaseLock(userId, finalData)
    finalData.activeJobId = nil
    finalData.lockTime = nil
    finalData.lastPlayDate = os.time()
    local ok, err = pcall(function()
        store:UpdateAsync(key(userId), function(_) return finalData end)
    end)
    if not ok then warn("[DataHandler] Release lock failed:", err) end
end

function DataHandler.getData(player) return PlayerData[player.UserId] end
function DataHandler.setData(player, data)
    PlayerData[player.UserId] = data
    DataHandler.replicateToClient(player)
end

function DataHandler.modify(player, modifierFn)
    local data = PlayerData[player.UserId]
    if not data then return false end
    modifierFn(data)
    DataHandler.replicateToClient(player)
    return true
end

function DataHandler.replicateToClient(player)
    local data = PlayerData[player.UserId]
    if not data then return end
    local copy = {}
    for k, v in pairs(data) do
        if k ~= "activeJobId" and k ~= "lockTime" then copy[k] = v end
    end
    Remotes.UpdatePlayerData:FireClient(player, copy)
end

function DataHandler.save(player, releaseSessionLock)
    local data = PlayerData[player.UserId]
    if not data then return end
    if releaseSessionLock then
        releaseLock(player.UserId, data)
    else
        local ok, err = pcall(function()
            store:UpdateAsync(key(player.UserId), function(_)
                data.lastPlayDate = os.time()
                return data
            end)
        end)
        if not ok then warn("[DataHandler] Save failed:", player.Name, err) end
    end
    LastSave[player.UserId] = os.time()
end

local function onPlayerAdded(player)
    LoadingPlayers[player.UserId] = true
    local acquired, data = attemptSessionLock(player.UserId)
    LoadingPlayers[player.UserId] = nil
    if not acquired then
        player:Kick("Could not load your save data. Please rejoin.")
        return
    end
    PlayerData[player.UserId] = migrate(data)
    DataHandler.replicateToClient(player)
    print("[DataHandler] Loaded", player.Name, "L"..data.level, "Chaos="..data.chaosPoints, "HT="..data.hellTokens)
end

local function onPlayerRemoving(player)
    if PlayerData[player.UserId] then
        DataHandler.save(player, true)
        PlayerData[player.UserId] = nil
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(onPlayerAdded, player) end

task.spawn(function()
    while true do
        task.wait(GameConfig.AUTOSAVE_INTERVAL)
        for userId, _ in pairs(PlayerData) do
            local player = Players:GetPlayerByUserId(userId)
            if player then DataHandler.save(player, false) end
        end
    end
end)

game:BindToClose(function()
    if RunService:IsStudio() then return end
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(function() DataHandler.save(player, true) end)
    end
    task.wait(3)
end)

_G.KittyRaiserData = DataHandler
return DataHandler

]]
end

print('[KittyRaiser] chunk 1/5 loaded - 8 scripts')
