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
GameConfig.SCHEMA_VERSION = 3  -- bumped: added settings table + seenTutorial

-- ===== MONETIZATION =====
GameConfig.GAMEPASS_IDS = {
    VIP = 1822889201,
    GANG_LEADER = 1822837259,
    ULTIMATE_CHAOS = 1823014838,
    PEARL_SKIN = 1823218389,
    EMBER_SKIN = 1822895103,
    GOLD_SKIN = 1822763618,
    -- Legacy keys (kept for backward compat with existing PrankSystem hasVIP check)
    DEMON_SKIN = 0,
    NEON_SKIN = 0,
    HELLBORN_SKIN = 0,
}

GameConfig.DEVPRODUCT_IDS = {
    CHAOS_5K = 3586477154,
    CHAOS_50K = 3586477328,
    CHAOS_500K = 3586477334,
    HELLTOKENS_100 = 3586477337,
    HELLTOKENS_1000 = 3586477342,
    REBIRTH_SKIP = 0,
    PERK_RESET = 3586477346,
    DAILY_DOUBLE = 3586477352,
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
