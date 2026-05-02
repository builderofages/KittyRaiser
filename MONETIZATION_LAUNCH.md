# KittyRaiser — Monetization Setup Cheat Sheet

Roblox does not let API create GamePasses or DevProducts. You have to make these manually on create.roblox.com. Total time: ~30 min. Then you paste the IDs into MonetizationWiring and ship.

## 7 GamePasses to create

Open create.roblox.com → KittyRaiser → Monetization → Passes → Create a Pass.

For each one: upload an icon (use the marketing/ folder PNGs as placeholders), set a price, copy the resulting GamePass ID into the table below.

| # | Pass Name | Suggested Robux | What it grants in-game | Paste ID here |
|---|---|---|---|---|
| 1 | **Premium Cat** | 499 R$ | 2x chaos earnings, exclusive purple aura cosmetic, premium tag in chat | `0` |
| 2 | **VIP Citizen** | 999 R$ | 1.5x XP, fast respawn, exclusive premium-only spawn pad with extra food | `0` |
| 3 | **Anvil Lord** | 299 R$ | Anvil prank cooldown halved, anvil hits do double impact | `0` |
| 4 | **Pie Master** | 299 R$ | Pies splatter wider, instant reload | `0` |
| 5 | **Wings of Chaos** | 799 R$ | Permanent wings cosmetic + 30s flight ability per minute (long before unlock at lv100) | `0` |
| 6 | **Demon Skin Pack** | 599 R$ | Unlock all demon-themed cat skins (Hellfire, Brimstone, Reaper) | `0` |
| 7 | **Gang Founder** | 199 R$ | Create your own gang for free (normal cost: 5000 chaos), custom gang color | `0` |

## 11 DevProducts to create

Same place, Developer Products tab.

| # | Product Name | Suggested Robux | What user gets | Paste ID here |
|---|---|---|---|---|
| 1 | Chaos Pack: Small | 99 R$ | +5,000 chaos | `0` |
| 2 | Chaos Pack: Medium | 399 R$ | +25,000 chaos (best value!) | `0` |
| 3 | Chaos Pack: Large | 999 R$ | +75,000 chaos | `0` |
| 4 | Chaos Pack: Mega | 2499 R$ | +200,000 chaos | `0` |
| 5 | HellTokens: Small | 199 R$ | +50 HellTokens | `0` |
| 6 | HellTokens: Big | 999 R$ | +300 HellTokens | `0` |
| 7 | Perk Reset | 149 R$ | Reset all perk choices, free re-allocation | `0` |
| 8 | Stat Reset | 99 R$ | Reset all stat allocations | `0` |
| 9 | Skip Animal Control | 49 R$ | Bail out of pound instantly | `0` |
| 10 | Daily Streak Restore | 99 R$ | Restore broken daily streak | `0` |
| 11 | Skin Mystery Box | 199 R$ | Random rare cosmetic skin | `0` |

## After you have the IDs

1. Open `src/ServerScriptService/MonetizationHandler.server.lua` (already in repo)
2. Find `_G.PASSES` table — paste the 7 GamePass IDs by name
3. Find `_G.PRODUCTS` table — paste the 11 DevProduct IDs by name
4. Save → F5 to test purchase flow in Studio
5. Push to GitHub: `git add -A && git commit -m "feat: monetization IDs wired" && git push`

## Pricing rationale

Robux pricing for KittyRaiser was set against Roblox top-30 sim/RP comps (Adopt Me, MeepCity, Tower of Hell, Brookhaven). Sweet spots:
- **49-99 R$** → impulse buys, no thought
- **199-299 R$** → "I really want this thing"
- **499-999 R$** → flagship purchases, must be premium-feeling
- **2499 R$** → whales / endgame

DO NOT price under 49 R$ — Roblox takes a 30% cut and devProducts have a min processing fee that eats sub-49 sales.

DO NOT price over 2499 R$ on launch — wait for whale signal.

## Revenue projection (rough — depends entirely on retention)

Assume 1000 D7-retained players (a real soft-launch milestone).

| Conversion type | % buying | Avg spend | Monthly $ |
|---|---|---|---|
| GamePass buyers | 4% | 600 R$ | $84 |
| DevProduct (chaos packs) | 12% | 250 R$ | $105 |
| Whales (mega buyers) | 0.5% | 4000 R$ | $70 |
| **Total ARPU/month** | | | **~$0.26 per player** |

To make $10K/month → need ~38,000 D7-retained players.
To break even on a $10K ad spend → need ad CPI <$0.26 with 100% conversion (unrealistic), so realistically you need much lower CPI like $0.05 OR much higher ARPU from premium content.

**That math is why I keep saying don't burn $10K on a 60% game.** Your blended ROAS goal needs to be 3x+ for ad spend to pay back. That requires either (a) very polished game with 25-40% D1 retention, or (b) a viral hook that drives organic growth.
