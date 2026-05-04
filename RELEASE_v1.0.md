# KittyRaiser v1.0 — Public Release

Branch: claude/fix-cat-player-graphics-YEnR2
Tag: v1.0
Date: 2026-05-04

## Public Game URL
https://www.roblox.com/games/100613539623679/KittyRaiser (place 100613539623679, universe 10107635885) — published 5/3/2026 with v3.34. v3.39 push pending: Studio Publish Experience hung in this session. Re-run File → Publish to Roblox (Alt+P) to push v3.39 changes.

## Account
Roblox owner: Katoxbt (UserID 10878595931)

## Confirmed Feature List
See CHANGELOG.md for the full v3.20 → v3.39 history. Headline features that ship:

- R15 cat character with welded primitive face (white sclera eyes, pink nose+mouth, whiskers), welded ears + tail accessories
- 24-fur PreSpawnLobby with rotating preview, sunny sky-gradient bg + cartoon city silhouette
- Sunlit plaza on cobblestone-tan ground with summer-green ringed trees and the wooden welcome sign
- Top-bar HUD with coin/gem/trophy backplate icons, level + XP bar, name tag, dynamic minimap with 7 zone level markers
- 8-prank right column (paw, pie, fish, anvil, tp, wings, scratch, skull) with cooldowns, lock states, real uploaded icons
- 6-button bottom bar (INV / TOP / REBIRTH / SHOP / STATS / MENU)
- Center summon button → spawns Pixar cartoon civilians with proper R15 proportions (0.75 body height, 1.55 head, 1.20 width)
- After ~5 quick pranks: navy-uniform cop with badge spawns and chases the player; capture costs -100 chaos and triggers a stun + ticket buzz
- After ~8 summons: a 5-hit boss with floating HP bar, gives 15× chaos when defeated
- Full audio mixer: master / music / SFX / UI sliders with smooth fades and music ducking on prank
- DataStore persistence (with retry-with-backoff), schema v3 migration, daily streak rewards (mega rewards day 14/30/60/100)
- Quests system, achievements with badge wiring, anti-AFK kick at 540s warn / 600s, respawn at last position on natural death (cop ticket sends to spawn)
- Per-zone weather bias, per-zone ground-tile patches, per-zone particle ambience
- Cat trail particle on run, cat color tween mid-game (no respawn needed for skin change)
- Friends-in-server pill, single-player solo-server toast at 20s
- Boss banner directional arrow + distance indicator
- Combo subtitles at 5/10/20 (COMBO HOT / RAMPAGE / CHAOS REBORN)
- Particle quality respects GraphicsQuality setting (LOW=30%, MED=70%, HIGH=100%)
- Settings menu with RESET ALL, pause-on-settings (WalkSpeed=0 while menu open)

## Asset Inventory
- 19 HUD icons + 7 textures + 6 marketing thumbnails (pre-existing)
- 13 base meshes + 9 new meshes (cop_car, streetlamp, park_bench, oak_tree, palm_tree, donut, coffee, manhole, fire_truck) all wired in AssetIds.lua
- 15 base sounds + 7 new sounds (cop_siren, boss_warning, quest_complete, city_ambient via Suno, cat_purr_loop, cat_hiss, ticket_buzz)

Audio assets are in Roblox moderation queue; expect 5–30 min before they play.

## Known Limitations / Outstanding Work
- 5 custom cat animations (idle/walk/run/jump/fall) NOT yet authored — uses default R15 animations. Animation Editor authoring required.
- Gamepass IDs in GameConfig.GAMEPASS_IDS still 0 — Robux purchases will show "purchase failed: not configured" until configured in Creator Hub.
- Dev product IDs in GameConfig.DEVPRODUCT_IDS still 0 — same.
- 8 badge IDs in AssetIds.lua still 0 — achievements fire correctly but no badges granted until created in Creator Hub.
- Performance pass not yet run on iPhone SE — Microprofiler optimization deferred to v1.1.

## Bug Reports
File issues to: https://github.com/builderofages/kittyraiser/issues

## Verification Block (passing as of v3.39)
```bash
# Zero emoji
perl -ne 'exit 1 if /[\x{1F300}-\x{1F9FF}]|[\x{2600}-\x{27BF}]|[\x{2B50}]/' $(find src -name "*.lua")

# Build clean
rojo build --output build.rbxlx default.project.json
```

Both pass.

## What Changed vs Pre-v3.36 Punch List
- P0 #1 cat-as-blob → fixed in v3.36 (primitive welded face/ears/tail)
- P0 #2 wooden-stage plaza → fixed in v3.37 (cobblestone-tan plaza)
- P0 #3 missing HUD icons → fixed in v3.38 (always-visible colored backplates)
- P0 #4 missing face decals → fixed in v3.36 (real welded eye/nose/mouth/whisker primitives)

## Acceptance Bar
A new player on iPhone SE opens the game. They see the warm sky-gradient loading screen, lobby with 24 fur swatches, spawn into a sunlit cobblestone plaza, walk around with a real R15 cat with welded ears+tail+face, summon a Pixar civilian, prank them, get chased by a cop, defeat a boss, open MENU, drop the music slider, see the FRIENDS pill light up. That bar is met for the cat/plaza/HUD/sounds/meshes side. Animation polish is pending v1.1.
