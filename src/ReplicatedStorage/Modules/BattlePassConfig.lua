-- BattlePassConfig.lua  v1 — 10-tier progression track tied to lifetime
-- prank count. Free track grants chaos at each tier; Premium track (gated
-- by the ULTIMATE_CHAOS gamepass) doubles the reward and adds hell tokens
-- + cosmetic skins.

local BattlePassConfig = {}

-- Threshold == required totalPranks count to unlock the tier.
BattlePassConfig.Tiers = {
    { tier=1,  threshold=10,    free={chaos=500},                    premium={chaos=1000,  hellTokens=2,  skinId=nil} },
    { tier=2,  threshold=25,    free={chaos=1500},                   premium={chaos=3000,  hellTokens=4,  skinId=nil} },
    { tier=3,  threshold=50,    free={chaos=4000},                   premium={chaos=8000,  hellTokens=8,  skinId="RussianBlue"} },
    { tier=4,  threshold=100,   free={chaos=10000},                  premium={chaos=20000, hellTokens=15, skinId=nil} },
    { tier=5,  threshold=200,   free={chaos=25000,  hellTokens=10},  premium={chaos=50000, hellTokens=25, skinId="MaineCoon"} },
    { tier=6,  threshold=400,   free={chaos=60000,  hellTokens=20},  premium={chaos=120000,hellTokens=50, skinId=nil} },
    { tier=7,  threshold=750,   free={chaos=150000, hellTokens=40},  premium={chaos=300000,hellTokens=80, skinId="Persian"} },
    { tier=8,  threshold=1500,  free={chaos=400000, hellTokens=80},  premium={chaos=800000,hellTokens=150,skinId="MidnightVelvet"} },
    { tier=9,  threshold=3000,  free={chaos=1000000,hellTokens=150}, premium={chaos=2000000,hellTokens=250,skinId="Sapphire"} },
    { tier=10, threshold=6000,  free={chaos=2500000,hellTokens=300}, premium={chaos=5000000,hellTokens=500,skinId="RoseChampagne"} },
}

return BattlePassConfig
