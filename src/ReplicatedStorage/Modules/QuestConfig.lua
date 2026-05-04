-- QuestConfig.lua  — daily quest definitions.
-- A quest is { id, label, target, kind, rewardChaos, rewardHellTokens? }
-- kind = "any_prank" | "specific_prank" | "summon" | "level_up" | "play_time"
-- For specific_prank, the quest table also has prankName.

local QuestConfig = {}

QuestConfig.Daily = {
    {id = "warmup",       label = "Land 5 pranks",                kind = "any_prank",      target = 5,   rewardChaos = 500},
    {id = "pie_master",   label = "Hit 3 pranks with Cream Pie",  kind = "specific_prank", prankName = "Pie",       target = 3,  rewardChaos = 750},
    {id = "summoner",     label = "Summon 8 victims",             kind = "summon",         target = 8,   rewardChaos = 600},
    {id = "anvil_drop",   label = "Drop 2 Anvils",                kind = "specific_prank", prankName = "Anvil",     target = 2,  rewardChaos = 1500, rewardHellTokens = 5},
    {id = "session",      label = "Play for 10 minutes",          kind = "play_time",      target = 600, rewardChaos = 1000},
}

function QuestConfig.byId(id)
    for _, q in ipairs(QuestConfig.Daily) do
        if q.id == id then return q end
    end
    return nil
end

return QuestConfig
