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
        icon = "scratch",
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
        icon = "pie",
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
        icon = "fish",
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
        icon = "anvil",
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
        icon = "tp",
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
        icon = "wings",
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
        icon = "paw",
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
        icon = "skull",
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
