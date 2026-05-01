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
