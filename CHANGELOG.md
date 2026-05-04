# KittyRaiser Changelog

All-in-one log of every commit since the cyberpunk-cleanup sprint.

## v3.29 — settings persistence + cat animations stub
- DataHandler now stores user settings (master/music/sfx/ui volume,
  graphics quality, motion shake) in the player's profile and mirrors
  them to player attributes on load. Settings persist across sessions.
- New `CatAnimations.server.lua` patches the auto-injected Animate
  script's StringValue/Animation children with custom cat anim IDs once
  uploaded (`anim_cat_idle/walk/run/jump/fall` placeholders in
  AssetIds). Falls back to default Roblox animations until uploaded.

## v3.28 — finish all code-side prep so external work is just upload + paste
- 16 new placeholder asset IDs added to AssetIds.lua (rbxassetid://0)
  for cop_siren, boss_warning, quest_complete, city_ambient,
  cat_purr_loop, cat_hiss, ticket_buzz + 9 mesh placeholders.
- Consumer wiring done: CopSystem siren + ticket buzz + parked car;
  SummonSystem boss warning; QuestSystem quest complete chime;
  RagdollOnPrank coin pickup; CatCharacterBuilder city ambient music.
- New `blender_kittyraiser_extras.py` builds 9 low-poly OBJ meshes.
- New `open_cloud_upload.py` wraps Roblox Open Cloud Assets API.
- New `PLAYTEST.md` exhaustive A-Z checklist + 10/10 acceptance.

## v3.27 — AAA pass: zones, cops, bosses, audio mixer, cat lifelike
- Three city zones (downtown / suburbs / harbor) with palette swaps.
- Cop NPCs with chase AI, navy uniform, badge, "STOP RIGHT THERE!".
- 1-in-8 boss prank-targets with floating HP bar, 5 hits, 15× reward.
- Per-platform tutorial text via UIUtil.isMobile().
- Audio mixer: Music/SFX/UI SoundGroups + 4 sliders in Settings.
- CatLifelike v2: physics-safe tail wag + ear twitch via torso-relative
  CFrame each Heartbeat (no welded-CFrame world-space hacks).
- 24 fur skins (was 12).
- Quest cycle refresh every 4 hours.

## v3.26 — Phase D + E: Quests + NPC variety
- QuestConfig + QuestSystem.server + QuestPanel.client (5 quests).
- NpcReactions.server: NPCs panic flee on nearby pranks; skittish 1-in-6.

## v3.25 — Phase B + C: Loading / Death / Settings / Menu
- LoadingScreen with sky gradient + spinner + tip rotation + preload.
- DeathScreen with cause-of-death + 5s countdown + RESPAWN button.
- SettingsMenu modal: volume slider + graphics segmented + motion toggle
  + controls help. MENU button on bottom bar; M key opens.
- CombatFeel + EffectsController honor MotionShake attribute.

## v3.24 — Phase A: UI rewrites
- PerkUI / SurvivalUI / WeatherClient / EmoteWheel rewritten with
  UIUtil tokens, warm palette, responsive sizing.
- DailyRewardUI deleted (duplicate of DailyRewardPopup).

## v3.23 — responsive across phone/tablet/desktop
- UIUtil extended: platform()/modalSize()/Token/TextSize.
- ShopModal/LeaderboardModal/DailyReward width-clamped.
- 48x48 close buttons (Apple HIG).
- KillFeed offset clamped, container right-anchored.
- Minimap responsive sizing per platform; warm palette.
- PreSpawnLobby DisplayOrder = UIUtil registry; color picker wraps.
- Viewport-resize listeners reclamp modals.

## v3.22 — AAA HUD icon polish
- New buildCurrencyCell helper (drop shadow + tinted icon + amount).
- HellWrap added between Chaos and Level (gem icon).
- Summon button: red gradient + skull icon + "SUMMON" label.
- Prank column buttons: drop shadows under icons.
- Bottom bar: icon-led buttons (shop/bag/star/bars).
- HUDController wires HellLabel to data.hellTokens.

## v3.21 — purge ALL emoji
- 30 emoji replaced with real ImageLabel using uploaded icon assets
  or clean ASCII alternatives.
- HUD prank fallbacks → 3-letter abbrevs.
- Lock overlay → dark scrim + "LV N" text.
- Floating coin numbers → coin ImageLabel + "+N" text.
- Daily / KillFeed / HUDController / Onboarding / Tutorial /
  PreSpawnLobby / RagdollOnPrank / EffectsController / DailyRewardSystem
  / PrankConfig — all stripped.

## v3.20 — kill cyberpunk theme, wire ALL real assets
- StrayLighting v3: sunny cartoon-city day.
- CityRebuild v6: warm brownstone palette, asphalt ground, cobblestone
  plaza with marble fountain, wooden welcome sign, trees.
- Real mesh assets wired: mesh_cat_ear/tail (cat decoration),
  mesh_skyscraper/brownstone (skyline), mesh_taxi/hydrant/mailbox/
  trashcan (60 street props), mesh_anvil/pie (prank effects).
- NPCs cartoon-proportioned (BodyHeightScale 0.75, HeadScale 1.55).
- HUD icons wired (coin/trophy/prank icons), warm wood palette.
- HUDPolish updated to warm wood gradients.

## v3.19 — major audit + 10000x polish
- UIUtil module: palette + DisplayOrder registry + boundText +
  polishFrame + makeToast helpers.
- UITextSizeConstraint added to every TextScaled label.
- EffectsController shake: undo-and-restore so doesn't drift; respects
  MotionShake.
- CombatFeel: FOV pulse only, gated by prank.screenShake.
- Soft vignette flash instead of full-white flashbang.
- Toast notifications via UIUtil.makeToast, slide-in/auto-fade, stack.
- Anvil scaled down to humanoid-head height.
- Coin loot: thin disc, spins on Y axis, dark outline + glow.
- City window grid: scale-based, visible at distance.
- Welcome sign: PixelsPerStud 20 + bounded text.
- TutorialFlow disabled (OnboardingFlow is canonical).

## v3.18 — NPCs, HUD polish, prank effect overhaul
- SummonSystem + AmbientCrowd use Players:CreateHumanoidModelFromDescription
  for proper R15 Robloxians (head + arms + legs + face + Animate).
- Tinting maps shirt/pants/skin to correct R15 part names.
- HUDPolish: surgical, not blanket — only TopBar/BottomBar/primary
  buttons/Prank_* get polish.
- Anvil: 4×3×3 cube → real anvil shape (body + horn + waist + base).
- Pie: cream splat ball with Back-Out easing + flash light.
- FartCloud: volumetric (6 offset green spheres + smoke).
- LaserEyes: twin glowing beams + impact orb + sparks.
- Spawn-in: PivotTo drop-in + smoke poof (no more shrink-each-part).

## v3.17 — cat moves + graphics overhaul
- CatCharacterBuilder v5: native R15 character + cat decorations
  (ears welded to head, tail welded to torso, kitty-face SurfaceGui,
  body scales for compact silhouette).
- SpawnEnforcer v2: passive 15s safety net only (no more racing).
- CatLifelike disabled (welded-CFrame hacks were broken).
- WalkAnim v2 defers to Roblox auto Animate.
- StrayLighting v2: single source of truth, no DOF/blur.
- CityRebuild v5: slate ground, neon plaza strips, framed welcome sign.
- PreSpawnLobby: rotating preview cat with proper proportions.
