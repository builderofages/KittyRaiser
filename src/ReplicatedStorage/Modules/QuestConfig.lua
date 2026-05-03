-- QuestConfig.lua
-- Daily quest pool. Each day at UTC midnight, the server picks 3 quests for
-- the player from this pool. Each quest has: id, label, target counter, the
-- counter key they tick (must match a key written by gameplay code), and reward.

local QuestConfig = {}

QuestConfig.Pool = {
    {id="prank10",      label="Prank 10 NPCs",            counter="totalPranks",         target=10,  chaos=2500,  hellTokens=0},
    {id="prank50",      label="Prank 50 NPCs",            counter="totalPranks",         target=50,  chaos=10000, hellTokens=1},
    {id="summon20",     label="Summon 20 NPCs",           counter="totalSummons",        target=20,  chaos=5000,  hellTokens=0},
    {id="emote5",       label="Use 5 emotes",             counter="totalEmotes",         target=5,   chaos=1500,  hellTokens=0},
    {id="anvil5",       label="Drop 5 Anvils",            counter="prank_Anvil",         target=5,   chaos=4000,  hellTokens=0},
    {id="pie10",        label="Throw 10 Pies",            counter="prank_Pie",           target=10,  chaos=3000,  hellTokens=0},
    {id="laser5",       label="Zap 5 with Laser Eyes",    counter="prank_LaserEyes",     target=5,   chaos=4500,  hellTokens=0},
    {id="combo5",       label="Reach a 5x combo",         counter="bestComboToday",      target=5,   chaos=3500,  hellTokens=0},
    {id="combo10",      label="Reach a 10x combo",        counter="bestComboToday",      target=10,  chaos=8000,  hellTokens=1},
    {id="rebirth1",     label="Complete 1 rebirth",       counter="rebirthsToday",       target=1,   chaos=15000, hellTokens=2},
    {id="walk1000",     label="Walk 1000 studs",          counter="distanceTraveled",    target=1000, chaos=2000, hellTokens=0},
    {id="diff_pranks",  label="Use 4 different pranks",   counter="distinctPranksToday", target=4,   chaos=4000,  hellTokens=0},
}

QuestConfig.PER_DAY = 3

-- Deterministic per-day picker so all servers on the same day pick the same set.
function QuestConfig.pickForDay(dayKey)
    local pool = QuestConfig.Pool
    local seed = 0
    for i = 1, #dayKey do seed = (seed * 31 + dayKey:byte(i)) % 2^31 end
    local rng = Random.new(seed)
    -- Fisher–Yates a copy
    local indices = {}
    for i = 1, #pool do indices[i] = i end
    for i = #indices, 2, -1 do
        local j = rng:NextInteger(1, i)
        indices[i], indices[j] = indices[j], indices[i]
    end
    local picked = {}
    for i = 1, math.min(QuestConfig.PER_DAY, #indices) do
        table.insert(picked, pool[indices[i]])
    end
    return picked
end

function QuestConfig.dayKey(now)
    -- UTC day in YYYYMMDD form, ignoring sub-day time
    return os.date("!%Y%m%d", now or os.time())
end

return QuestConfig
