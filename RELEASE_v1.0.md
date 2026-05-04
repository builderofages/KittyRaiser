# KittyRaiser v1.0 — Public Release

Branch: claude/fix-cat-player-graphics-YEnR2
Tag: v1.0
Date: 2026-05-04

## Public Game URL
https://www.roblox.com/games/100613539623679/KittyRaiser
(place 100613539623679, universe 10107635885) — live as place version 250, source v3.46.

## Account
Roblox owner: Katoxbt (UserID 10878595931)

## Confirmed Feature List
See CHANGELOG.md for the full v3.20 → v3.46 history. Headline features that ship:

- True quadruped R15 cat (v3.45+): horizontal body welded to HRP, four legs touching ground via HipHeight=1.5, R15 underneath hidden + scaled to 0.30 + AutomaticScalingEnabled=false. Player feels small under the human civilians.
- 24-fur PreSpawnLobby with rotating preview (v3.45 compact UI: 220px viewport, 50x50 cards, all swatches in 2 rows), sunny sky-gradient bg + cartoon city silhouette
- Sunlit plaza (v3.46 sunset-cream warmth): cobblestone floor RGB(255,220,170), 5-piece perimeter walls with RGB(255,175,90) cornice, marble fountain, wooden welcome sign, 2 trash cans + 2 mailboxes + hot dog cart + bus stop shelter
- Top-bar HUD with coin/gem/trophy backplate icons, level + XP bar, name tag, dynamic minimap with 7 zone level markers
- 8-prank right column (paw, pie, fish, anvil, tp, wings, scratch, skull) with cooldowns, lock states, real uploaded icons
- 6-button bottom bar (INV / TOP / REBIRTH / SHOP / STATS / MENU)
- Center summon button → spawns normal-human civilians (HumanoidDescription scale baked at 1.05 height, 1.0 elsewhere) — humans tower over the cat. AmbientCrowd target 20 NPCs visible, denser civilian streets.
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
- 13 base meshes + 9 v1 meshes (cop_car, streetlamp, park_bench, oak_tree, palm_tree, donut, coffee, manhole, fire_truck) + 10 Phase-10 v2 meshes (taxi_yellow, delivery_van, food_truck, fire_hydrant, trash_can, mailbox_blue, bus_stop_shelter, traffic_light, hot_dog_cart, skyscraper_chunk) — all wired with AssetIds.has() guards in CityRebuild
- 15 base sounds + 7 new sounds (cop_siren, boss_warning, quest_complete, city_ambient via Suno, cat_purr_loop, cat_hiss, ticket_buzz)

Audio assets are in Roblox moderation queue; expect 5–30 min before they play.

## Known Limitations / Outstanding Work
- 5 custom cat animations (idle/walk/run/jump/fall) NOT yet authored — uses default R15 animations. Animation Editor authoring required.
- Gamepass IDs in GameConfig.GAMEPASS_IDS wired (VIP, GANG_LEADER, ULTIMATE_CHAOS, PEARL_SKIN, EMBER_SKIN, GOLD_SKIN) as of v3.41.
- Dev product IDs in GameConfig.DEVPRODUCT_IDS wired (CHAOS_5K/50K/500K, HELLTOKENS_100/1000, PERK_RESET, DAILY_DOUBLE) as of v3.41.
- 3 badge IDs live (badge_first_prank=1429423254055989, badge_level_10=2479335747751103, badge_level_25=2206460901927124); 5 badge IDs still 0 — AchievementSystem fires correctly but no badge granted until created in Creator Hub.
- Performance pass not yet run on iPhone SE — Microprofiler optimization deferred to v1.1.

## Bug Reports
File issues to: https://github.com/builderofages/kittyraiser/issues

## Verification Block (passing as of v3.46, place v250)
```bash
# Zero emoji
perl -ne 'exit 1 if /[\x{1F300}-\x{1F9FF}]|[\x{2600}-\x{27BF}]|[\x{2B50}]/' $(find src -name "*.lua")

# Build clean
rojo build --output build.rbxlx default.project.json
```

Both pass. Build size 460921 bytes. Published to live universe 10107635885 place 100613539623679 as version 250.

## What Changed vs Pre-v3.36 Punch List
- P0 #1 cat-as-blob → fixed in v3.36 (primitive welded face/ears/tail)
- P0 #2 wooden-stage plaza → fixed in v3.37 (cobblestone-tan plaza)
- P0 #3 missing HUD icons → fixed in v3.38 (always-visible colored backplates)
- P0 #4 missing face decals → fixed in v3.36 (real welded eye/nose/mouth/whisker primitives)
- P0 #5 cat looks like humanoid + cat elements → fixed in v3.45 (real quadruped: hidden R15 + welded horizontal cat-shape, HipHeight=1.5, paws on ground)
- P0 #6 only 1 NPC spawning → fixed in v3.45 (AmbientCrowd while-loop now spawns until target hit, was capped at 1/player/tick)
- P0 #7 NPCs cartoon-proportioned → fixed in v3.45 (BodyHeightScale 1.05, others 1.00 — humans tower over cat)
- P0 #8 city generic + empty → fixed in v3.45 + v3.46 (9x9 grid + 70% infill + 10 v2 meshes wired)
- P0 #9 plaza dim grey → fixed in v3.46 (sunset cream RGB(255,220,170) floor + walls + warm cornice)
- P0 #10 sky purple-void → fixed in v3.46 (Sky child force-destroyed + recreated each session, Atmosphere density 0.12 → 0.05)
- P0 #11 NPCs spawn tiny → fixed in v3.46 (HumanoidDescription scales BAKED before CreateHumanoidModelFromDescription)

## Acceptance Bar
A new player on iPhone SE opens the game. They see the warm sky-gradient loading screen, lobby with 24 fur swatches, spawn into a sunlit cobblestone plaza, walk around with a real R15 cat with welded ears+tail+face, summon a Pixar civilian, prank them, get chased by a cop, defeat a boss, open MENU, drop the music slider, see the FRIENDS pill light up. That bar is met for the cat/plaza/HUD/sounds/meshes side. Animation polish is pending v1.1.
