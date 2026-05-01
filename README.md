# KittyRaiser — v1 Build Package

A complete, shippable Roblox game build. Cartoon prank simulator. Mobile-first. Moderate maturity label. ~2000 lines of Luau across 14 scripts.

## What's in this folder

```
KittyRaiser/
├── README.md                    ← you are here
├── 00_RATING_AND_GAPS.md        ← honest review of the Grok thread + 22 gaps
├── 01_PRODUCTION_BIBLE.md       ← v1 spec, locked identity, v2-v4 roadmap
├── 02_BUILD_GUIDE.md            ← Studio setup + drop-in order + smoke test
├── 03_CLAUDE_HANDOFF.md         ← prompt to give Claude Cowork to execute the build
├── 04_MONETIZATION_SETUP.md     ← GamePass + DevProduct setup steps
├── 05_ASSET_LIST.md             ← Toolbox sounds, icons, thumbnails
├── default.project.json         ← Rojo config (optional, for fast sync)
└── src/
    ├── ReplicatedStorage/Modules/
    │   ├── GameConfig.lua
    │   ├── PrankConfig.lua
    │   ├── CosmeticConfig.lua
    │   └── RemoteEvents.lua
    ├── ServerScriptService/
    │   ├── DataHandler.server.lua       ← session-locked DataStore wrapper
    │   ├── AntiCheat.server.lua         ← rate limit + distance + teleport checks
    │   ├── SummonSystem.server.lua      ← spawns NPCs to prank
    │   ├── PrankSystem.server.lua       ← server-validated prank handling
    │   ├── MonetizationHandler.server.lua  ← ProcessReceipt + GamePass grants
    │   ├── RebirthHandler.server.lua    ← prestige loop
    │   ├── CosmeticHandler.server.lua   ← skin equip + Chaos purchase
    │   ├── LeaderboardHandler.server.lua  ← live top 10 broadcast
    │   ├── AnalyticsHandler.server.lua  ← funnel events
    ├── Workspace/
    │   └── MapBuilder.server.lua        ← procedurally builds Cat Alley
    ├── StarterGui/
    │   └── HUDBuilder.client.lua        ← programmatic ScreenGui
    └── StarterPlayer/StarterPlayerScripts/
        ├── HUDController.client.lua     ← state binding
        ├── InputHandler.client.lua      ← button + keyboard input
        ├── EffectsController.client.lua ← prank visual + audio FX
        └── TutorialController.client.lua  ← first-session tooltips
```

## How to ship

**5-minute path (Rojo)**: install Rojo, `rojo serve` from this folder, click Connect in Studio plugin. Done.

**15-minute path (manual)**: open `02_BUILD_GUIDE.md`, follow the drop-in order. Copy each .lua into a matching Studio Script object.

**0-minute path (Claude Cowork)**: paste `03_CLAUDE_HANDOFF.md` into Cowork. It executes the build inside Studio.

## What's working in v1

- 4 prank types with unlock gates (Pie L1, Anvil L5, Fart L10, Laser L15)
- Level 1-50, rebirth at 25, soft cap at 10 rebirths
- 5 cat skins (3 free progression, 2 GamePass)
- 3 GamePasses + 3 DevProducts wired up
- Server-authoritative anti-cheat (cooldown, distance, teleport detection, rate limiting)
- Session-locked DataStore (no dupe, no lost saves)
- Mobile-first HUD (large thumb-friendly buttons, TweenService animations)
- Procedural map (200x200 Cat Alley with shop, rebirth statue, leaderboard pillar)
- Live per-server leaderboard
- 60-second tutorial
- Analytics hooks for the full funnel

## What's NOT in v1 (and that's the point)

- 2000x2000 city — v3
- 75 cosmetics — v2
- Gangs / PvP — v3
- Slots / loot crates — Restricted-only, probably never
- Weather / red mist / NPC ecosystem — v4
- Daily systems / season pass — v2
- Animal catcher / bounty — v3
- Food/water survival — v4

The Grok thread had all of these on Day 1. They're not on Day 1. They're on Days 30, 60, 90+ if v1 hits.

## Reality check

This won't ship "tonight." Realistic timeline:
- Day 1: scripts loaded + smoke test passes (2-4 hours with Cowork)
- Day 2: map polish + sound assets imported (3-4 hours)
- Day 3: GamePass + DevProduct setup + receipt testing (2 hours)
- Day 4: tutorial polish + analytics verification + leaderboard tuning (3 hours)
- Day 5: QA with 2 test accounts + edge case fixes (3 hours)
- Day 6: soft launch, watch metrics
- Day 7: ship to public after fixing top bugs

Roughly 15-20 hours of focused work. Not 2 hours. Stop saying tonight.

## Revenue path

- v1 break-even: 50-100 CCU sustained pays Roblox hosting
- v1 profitable: 200+ CCU
- $1k/mo: ~500 CCU (very achievable with one viral TikTok)
- $10k/mo: ~3,000 CCU (requires sustained content updates)
- $100k/mo: ~20,000+ CCU (this is the v3+ goal — probably not from v1)

## Open this first

`00_RATING_AND_GAPS.md` then `01_PRODUCTION_BIBLE.md` then `02_BUILD_GUIDE.md`.

## Questions for Grok (if you want to use it)

I noted you said I can also talk to Grok. Useful targeted questions to ask it:
1. "What are 5 free Roblox Toolbox sound asset IDs for: pie splat, anvil drop, fart, laser zap, level up sparkle?"
2. "What's the average D1 retention for cartoon sims on Roblox in 2026?"
3. "Generate 10 thumbnail copy variants for KittyRaiser, max 4 words each."

Ask it those, paste the answers back here, and I'll wire them into the right config files.

Don't ask it to validate the game again. It will just say 10000% positive.
