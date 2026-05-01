# KittyRaiser — SHIP NOW

The whole game is in this folder. 22 files. ~2000 lines of Luau. Read in this order:

1. `README.md` — orientation
2. `00_RATING_AND_GAPS.md` — what was wrong with the Grok thread + 22 specific gaps closed
3. `01_PRODUCTION_BIBLE.md` — locked v1 spec, v2-v4 roadmap
4. `02_BUILD_GUIDE.md` — Studio setup + drop-in order + smoke test
5. `03_CLAUDE_HANDOFF.md` — paste this into Claude Cowork to execute the build
6. `04_MONETIZATION_SETUP.md` — GamePass + DevProduct setup
7. `05_ASSET_LIST.md` — Toolbox sounds, icons, thumbnails
8. `06_MARKETING_AND_BENCHMARKS.md` — thumbnail variants, retention targets, ad playbook (Grok-sourced)

## Source code (in `src/`)

**ReplicatedStorage > Modules:**
- GameConfig.lua — central config, edit values here only
- PrankConfig.lua — 4 prank types, sound IDs already wired in
- CosmeticConfig.lua — 5 cat skins
- RemoteEvents.lua — single source of truth for all RemoteEvents/Functions

**ServerScriptService:** (10 scripts)
- DataHandler — session-locked DataStore wrapper, no external deps
- AntiCheat — server-authoritative cooldown/distance/teleport/rate-limit checks
- SummonSystem — programmatically builds Robloxian NPCs to prank
- PrankSystem — server-validated prank handling, awards Chaos + XP
- MonetizationHandler — ProcessReceipt with deduplication, GamePass listener
- RebirthHandler — prestige loop with soft cap
- CosmeticHandler — skin equip + Chaos-currency purchase
- LeaderboardHandler — live per-server top 10 every 5s
- AnalyticsHandler — funnel events (session_start, first_summon, first_prank, level_up, rebirth, monetization)
- MapBuilder — procedurally builds Cat Alley (200x200) with shop, rebirth statue, leaderboard pillar, neon signs

**StarterGui:** HUDBuilder.client.lua — programmatically builds the entire HUD ScreenGui (mobile-first)

**StarterPlayer > StarterPlayerScripts:**
- HUDController — state binding to player data updates
- InputHandler — button taps + 1/2/3/4 keyboard shortcuts + nearest-NPC targeting
- EffectsController — particle bursts, falling anvil, AOE smoke, laser beam, screen shake
- TutorialController — first-session tooltips

## Three ways to ship

**Fastest (Cowork):** Paste `03_CLAUDE_HANDOFF.md` into Claude Cowork. It opens Studio and executes.

**Rojo (5 min):** Install Rojo, `rojo serve` from this folder, click Connect in the Studio plugin. Done.

**Manual (15 min):** Open Studio, follow `02_BUILD_GUIDE.md` drop-in order.

## What's not done that you'll need to do

1. **Create GamePasses + DevProducts on Creator Dashboard** (10 min). Update IDs in GameConfig.lua. See `04_MONETIZATION_SETUP.md`.
2. **Verify the 5 sound asset IDs** in Studio Toolbox. If any are delisted, search the keyword and replace in PrankConfig.lua. See `06_MARKETING_AND_BENCHMARKS.md`.
3. **Pick a thumbnail** and game icon. See `05_ASSET_LIST.md` for AI prompts and tools.
4. **Smoke test** as the build guide describes — summon, pie, anvil, level up, rebirth.
5. **Soft launch** to public, watch metrics 24h, then ad spend.

## Honest timeline

- Studio scripts loaded + smoke test: 2-4 hours
- Map polish + sounds verified: 3-4 hours
- GamePass + DevProduct setup + receipt test: 2 hours
- Tutorial polish + analytics check: 3 hours
- QA pass: 3 hours
- Soft launch + iteration: 1-2 days

Total: 5-7 days of focused work. Not tonight.

## Revenue reality

v1 break-even: ~50-100 CCU sustained
v1 profitable: 200+ CCU
$1k/mo: ~500 CCU (one viral TikTok or moderate ad spend)
$10k/mo: ~3,000 CCU (sustained updates required)
$100k/mo: ~20,000+ CCU (this is v3+ territory, not v1 — that's the $100k/mo dream Grok promised on day one. It comes later, after this v1 proves the loop works.)

## What I'd do next

Run the smoke test, then come back. I'll write whatever's missing — extra cat skins, the daily reward system for v2, server events, whatever's blocking the next ship.
