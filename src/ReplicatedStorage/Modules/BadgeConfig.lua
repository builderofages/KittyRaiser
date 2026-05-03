-- BadgeConfig.lua
-- Internal achievement system. Each entry is awarded by the server once the
-- player meets a condition (checked via 'check' field). Badges are stored in
-- DataHandler.awardedBadges and visualized in the Achievements UI.
--
-- Optional: if `robloxBadgeId` is set to a non-zero number, the server will
-- also call BadgeService:AwardBadge so the badge appears on the player's
-- public Roblox profile. Create badges at create.roblox.com → Inventory →
-- Badges, then paste IDs here. Leave at 0 to keep them internal-only.

local BadgeConfig = {}

BadgeConfig.Badges = {
    {id="first_prank",     name="First Prank",          desc="Land your first prank",          robloxBadgeId=0,
        check=function(d) return (d.totalPranks or 0) >= 1 end},
    {id="prank_100",       name="Pranking Pro",         desc="Land 100 pranks",                 robloxBadgeId=0,
        check=function(d) return (d.totalPranks or 0) >= 100 end},
    {id="prank_1k",        name="Chaos Causer",         desc="Land 1,000 pranks",               robloxBadgeId=0,
        check=function(d) return (d.totalPranks or 0) >= 1000 end},
    {id="prank_10k",       name="Mythic Prankster",     desc="Land 10,000 pranks",              robloxBadgeId=0,
        check=function(d) return (d.totalPranks or 0) >= 10000 end},
    {id="level_25",        name="Quarter Century",      desc="Reach level 25",                  robloxBadgeId=0,
        check=function(d) return (d.level or 1) >= 25 end},
    {id="level_50",        name="Halfway",              desc="Reach level 50",                  robloxBadgeId=0,
        check=function(d) return (d.level or 1) >= 50 end},
    {id="level_100",       name="Maxed Out",            desc="Reach level 100",                 robloxBadgeId=0,
        check=function(d) return (d.level or 1) >= 100 end},
    {id="rebirth_1",       name="Reborn",               desc="Complete your first rebirth",     robloxBadgeId=0,
        check=function(d) return (d.rebirths or 0) >= 1 end},
    {id="rebirth_10",      name="Eternally Reborn",     desc="Reach 10 rebirths",               robloxBadgeId=0,
        check=function(d) return (d.rebirths or 0) >= 10 end},
    {id="rebirth_25",      name="Soft Cap Survivor",    desc="Reach the rebirth soft cap",      robloxBadgeId=0,
        check=function(d) return (d.rebirths or 0) >= 25 end},
    {id="chaos_100k",      name="100K Chaos",            desc="Earn 100K chaos points (lifetime)", robloxBadgeId=0,
        check=function(d) return (d.totalRobuxSpent or 0) + (d.chaosPoints or 0) >= 100000 end},
    {id="hellTokens_50",   name="Hell-Bound",            desc="Hold 50 Hell Tokens",             robloxBadgeId=0,
        check=function(d) return (d.hellTokens or 0) >= 50 end},
    {id="rare_skin",       name="Fashionable",           desc="Own a Rare skin",                 robloxBadgeId=0,
        check=function(d, ctx)
            if not d.ownedSkins then return false end
            for _, sid in ipairs(d.ownedSkins) do
                local skin = ctx.CosmeticConfig.Skins[sid]
                if skin and skin.rarity == "Rare" then return true end
            end
            return false
        end},
    {id="all_pranks",      name="Master of Pranks",      desc="Unlock every prank type",         robloxBadgeId=0,
        check=function(d, ctx)
            local maxLvl = 1
            for _, p in pairs(ctx.PrankConfig.Pranks) do
                if p.unlockLevel > maxLvl then maxLvl = p.unlockLevel end
            end
            return (d.level or 1) >= maxLvl
        end},
    {id="combo_10",        name="Combo Master",          desc="Reach a 10x prank combo",         robloxBadgeId=0,
        check=function(d) return (d.bestComboEver or 0) >= 10 end},
    {id="dedicated",       name="Dedicated",             desc="7-day daily reward streak",       robloxBadgeId=0,
        check=function(d) return (d.dailyStreak or 0) >= 7 end},
}

return BadgeConfig
