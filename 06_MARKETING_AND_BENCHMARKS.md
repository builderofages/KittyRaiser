# Marketing & Performance Benchmarks

Sourced from Grok's research pass (cited 217 sources, May 2026 Roblox data). Use with the rest of the build pack.

## Thumbnail copy variants (test these)

A/B test 3-4 of these in your first 7 days. Roblox lets you swap thumbnails freely.

1. CAT PRANK CHAOS
2. PIE ANVIL LASER
3. CHAOS CAT SIM
4. THROW PIES NOW
5. EVIL CAT PRANKS
6. ANVIL DROP CHAOS
7. LASER HUMAN MAYHEM
8. PRANK CAT EMPIRE
9. CARTOON CHAOS HUB
10. SUMMON PRANK CHAOS

**My pick for first thumbnail:** "PIE ANVIL LASER" — concrete verbs, lists three power-ups, players know what they're doing in the game. "CAT PRANK CHAOS" is the safe second-tier test.

**Avoid:** "EVIL" framing on a Moderate label can hurt parental safety filters in feeds. Test it but be ready to swap.

## D1 retention benchmarks (cartoon idle sims, Roblox May 2026)

| Tier | D1 Retention | Action |
|---|---|---|
| Bad | <25% | Fix retention before any ad spend. Tutorial, first-prank dopamine, level pacing all suspect. |
| Average | 30-40% | Healthy. Spend on ads cautiously. Iterate first-session UX. |
| Good | 45%+ | Scale ad spend confidently. Ship updates weekly. |
| Top tier | 50%+ (Grow-a-Garden range) | You have a banger. Push hard, ship updates twice weekly. |

If you launch and D1 is below 25%, the playbook is:
1. Cut tutorial wait time (player should prank by second 30, not minute 2)
2. Increase first-3-pranks chaos reward by 3x (instant power feel)
3. Add a "Welcome bonus: 500 chaos" toast at session start
4. Reduce Anvil unlock from L5 to L3 (feel of progression earlier)

## NPC asset for spawn target

- Toolbox search: **"Robloxian"**
- Top result: **"R15 Robloxian"** (free, public domain)
- Alternative: search "NPC dummy" or "Test Dummy" if Robloxian results are stale
- The MapBuilder script in this pack programmatically builds a simple humanoid NPC, so no Toolbox dep is required, but if you want a polished R15 model, drop one in `ServerStorage > Templates > HumanNPC` and update `SummonSystem.server.lua` `buildHumanNPC()` to clone instead of build.

## Sound asset IDs (verify in Studio Toolbox before shipping)

These came from Grok's data pull. Verify each plays correctly in Studio — asset IDs can be delisted or moderated. If any fail to load, search Toolbox audio for the keyword and replace.

| Use | Asset ID | Keyword to re-search |
|---|---|---|
| Pie splat | `rbxassetid://517040733` | "pie splat" / "cream splash" |
| Anvil bonk | `rbxassetid://5451260445` | "anvil drop" / "metal bonk" |
| Cartoon fart | `rbxassetid://1845015288` | "cartoon fart" |
| Laser beam | `rbxassetid://3820883381` | "laser zap" / "energy beam" |
| Level-up sparkle | `rbxassetid://3292075199` | "level up" / "achievement sparkle" |

Already wired into `src/ReplicatedStorage/Modules/PrankConfig.lua`. If verification fails, replace there.

## Ad spend playbook (first $1k)

Day 1 (soft launch, no ads): watch metrics for 24h. Need >25% D1 to proceed.

Day 2-3 ($100/day Roblox Ads test):
- Target: "cartoon games", "simulator", "prank games"
- Audience: ages 9-16, all regions
- Format: skip-only banner + Sponsored Game

Day 4 (analyze): if CPI < $0.20 AND D1 retention > 30%, scale to $300/day.
Day 5-7: $300-500/day at the best-performing creative.

Total first-week: ~$1,500-2,500 ad spend. NOT the $10k Grok suggested. Validate before scaling.

## Update cadence (post-launch)

Roblox sims live on weekly updates. Bad cadence = death.

| Week | Update |
|---|---|
| 1 | 2 new cat skins (Chaos currency), bug fixes |
| 2 | New prank type (e.g. Banana Peel slip — Level 20) |
| 3 | First server-wide event (Red Mist Hour: 2x Chaos for 60 min) |
| 4 | New zone teaser (locked door in alley) |

Each update gets a thumbnail update and a forum post. Players smell stale games and bounce.

## Where to NOT put energy in v1

- **Discord server:** waste of time at <500 CCU. Do at v2.
- **YouTube videos:** burn time, low ROI early. Just take screenshots for thumbnails.
- **Trading economy:** out of scope, breaks economy without careful design. Never v1.
- **Cross-platform marketing:** Twitter/TikTok for kids' games has rules. Stay on Roblox feeds + paid Ads.
