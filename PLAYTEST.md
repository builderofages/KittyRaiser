# PLAYTEST CHECKLIST — KittyRaiser

Run this end-to-end on Windows + iPhone + iPad + Android. Every item must pass.

## Setup
1. Open Roblox Studio
2. `rojo build --output build.rbxlx default.project.json`
3. Open `build.rbxlx` (or `KittyRaiser_*.rbxlx`)
4. Press **Play (F5)** for solo test, **Play Here (F7)** for spawn-in-place,
   **Test → Local Server** with 4 players for multiplayer

---

## A. SESSION OPEN

- [ ] Loading screen: warm sky-gradient bg, KITTYRAISER LuckiestGuy title,
      spinning paw, rotating tip strip. Fades out after assets load (within
      ~3-5s, never longer than 12s).
- [ ] PreSpawnLobby appears: sky-gradient bg with cartoon clouds + warm
      brownstone silhouette. 24 fur swatches scrollable. Cat preview rotates.
- [ ] Pick a fur color → it tints the preview cat.
- [ ] Tap SPAWN → smooth fade out → cat appears in plaza on grass.

## B. WORLD VISUALS

- [ ] Ground is asphalt grey (not concrete grey). Plaza is cobblestone tan.
- [ ] Plaza has wooden welcome sign with "WELCOME TO KITTYRAISER" in
      LuckiestGuy. Fountain in middle (marble basin + water + spout).
- [ ] 6 trees ring the plaza (warm wood trunks + green grass crowns).
- [ ] Walk **NE** → buildings get TALL and pale-stone (downtown zone).
- [ ] Walk **SW** → buildings are LOW and sandstone (harbor zone).
- [ ] Walk **NW or SE** → buildings are warm brick brownstones (suburbs zone).
- [ ] Buildings have visible window grids (warm yellow lit + dark unlit).
- [ ] Streets have taxis (yellow), hydrants (red), mailboxes (blue),
      trashcans (olive green) — populated with ~60 props total.
- [ ] If `mesh_streetlamp/oak/palm/bench/manhole` are uploaded: visible too.

## C. CAT CHARACTER

- [ ] Cat moves with WASD/joystick at WalkSpeed 18.
- [ ] Spacebar / jump button works.
- [ ] Cat has real ears welded to head (mesh_cat_ear, with pink inner ears).
- [ ] Cat has real tail welded to torso (mesh_cat_tail) that wags when moving.
- [ ] Cat has kitty face (white sclera, green slit pupils, pink nose,
      whisker-mouth) on the head.
- [ ] Floating name tag above head: white text, bounded size, doesn't shrink
      to nothing or balloon.
- [ ] On spawn: spawn_chime sound plays (if uploaded).
- [ ] Walking around: ears occasionally twitch, tail wag speed increases
      with movement.

## D. HUD — TOP BAR

- [ ] Coin icon + "0" chaos counter (left side)
- [ ] Gem icon + "0" hell tokens (next to chaos)
- [ ] Level + XP bar with amber gradient (middle)
- [ ] Trophy icon + "0" rebirth counter (right)
- [ ] All icons have drop shadow underneath
- [ ] Top bar is warm wood-stained brown (not purple)

## E. HUD — RIGHT SIDE PRANK COLUMN

- [ ] 8 prank buttons stacked vertically
- [ ] Each shows the real uploaded icon (paw, pie, fish, anvil, tp, wings,
      scratch, skull) — NOT emoji
- [ ] Locked pranks show dark scrim + "LV N" text (no padlock emoji)
- [ ] Tap an unlocked prank — pop animation + cooldown overlay slides up

## F. HUD — BOTTOM BAR

- [ ] 6 buttons: SHOP / INV / REBIRTH / TOP / STATS / MENU
- [ ] Each has real icon (shop / bag / star / bars / bars / slot) + label
- [ ] Buttons are large enough to tap on phone (≥48 px touch target)
- [ ] On phone, buttons fit on screen without horizontal scroll

## G. SUMMON BUTTON

- [ ] Center-bottom red circle, gold gradient
- [ ] Skull icon centered, "SUMMON" text below
- [ ] Tap it → after 0.5s, a Pixar civilian falls from sky with smoke poof
- [ ] NPC has cartoon proportions (big head, short body), colored shirt
- [ ] NPC is a real R15 with arms + legs (NOT a blue blob)
- [ ] NPC walks around randomly

## H. PRANKS

For each unlocked prank, walk close to NPC, tap prank, verify:

### Pie
- [ ] Real mesh_pie drops from above onto NPC
- [ ] Cream-colored particle burst
- [ ] Coin icon + "+25" floats up from NPC head, fades
- [ ] NPC ragdolls + drops gold coins (with darker outline cylinder + glow)
- [ ] coin_pickup sound plays once per cluster
- [ ] Quest progress bar in left panel ticks up

### Anvil
- [ ] Real mesh_anvil shape drops with quadratic ease-in
- [ ] Smoke + neon shockwave ring
- [ ] Camera FOV pulses subtly (not violent shake)
- [ ] Per-prank flash (toned down, not eye-burning)

### FartCloud
- [ ] Volumetric green cloud (6 spheres + smoke particles)

### LaserEyes
- [ ] Twin red beams from cat's head + glowing impact orb

## I. NPC REACTIONS

- [ ] Pranking one NPC makes nearby NPCs (within 30 studs) flee with "AAH!"
      bubble for 4s
- [ ] Some NPCs (random 1-in-6) are skittish and flee from you when you
      get within 14 studs

## J. BOSS NPC

- [ ] After ~8 summons, one boss appears: bigger body, gold-tinted shirt,
      "PrankBoss" name
- [ ] Floating BOSS HP bar above head (red fill, "BOSS" label)
- [ ] HP bar drains 1/5 per prank hit
- [ ] At HP=0, boss ragdolls + drops EXTRA coins
- [ ] Total chaos awarded ≈ 15× a normal target
- [ ] If `boss_warning` sound uploaded: stinger plays on spawn

## K. COP CHASE

- [ ] After 4-5 pranks in quick succession, a Cop NPC spawns:
  - Navy uniform shirt (not default Roblox)
  - Navy + white police hat (cylinder + ball)
  - Gold badge on chest
  - "STOP RIGHT THERE!" speech bubble
  - If `cop_siren` uploaded: looping siren attached to cop head
  - If `mesh_cop_car` uploaded: parked white squad car beside cop
- [ ] Cop chases you (not straight-line, uses Humanoid:MoveTo)
- [ ] If cop touches you for 2s: -100 chaos, brief WalkSpeed=6 stun,
      "TICKETED!" bubble, cop despawns
- [ ] Cop gives up if you escape 400+ studs

## L. SURVIVAL BARS

- [ ] HUNGER + THIRST bars below TopBar with fish + slushie icons
- [ ] Bars tween smoothly when stat changes
- [ ] At <25, character slows down

## M. QUEST PANEL

- [ ] Left side, under Survival bars, "QUESTS" header with star icon
- [ ] 5 quests with progress bars, current/target counts
- [ ] On phone, panel collapses to single header row, expands on tap
- [ ] Completing a quest: gold toast at top, +chaos credited, progress bar
      fills + glows gold
- [ ] If `quest_complete` sound uploaded: chime plays
- [ ] Quests refresh every 4 hours (UTC bucket)

## N. MODALS

Open each, verify:

### Shop (SHOP button)
- [ ] Modal centers on screen, doesn't overflow on phone
- [ ] Title "COSMETIC SHOP" left-aligned, X close on right (48×48)
- [ ] Scrollable list of skins with name, rarity (color-coded), price
- [ ] Equipping shows "EQUIPPED" green button
- [ ] CHAOS purchase button shows coin icon + price
- [ ] Robux purchase opens MarketplaceService prompt (only works once
      gamepass IDs are filled in GameConfig)

### Leaderboard (TOP button)
- [ ] Top 10 players listed, gold/silver/bronze rows highlighted
- [ ] Bounded text size

### Stats (STATS button)
- [ ] Unspent points displayed
- [ ] 5 stats (Speed/Jump/Luck/Strength/Agility) with + buttons
- [ ] Tapping + actually spends a point + updates stat

### Settings (MENU button or M key)
- [ ] 4 volume sliders: MASTER, MUSIC, SFX, UI
- [ ] Drag knob OR tap track sets value
- [ ] Each slider actually changes audio (test by playing pranks)
- [ ] Graphics LOW/MED/HIGH segmented selector — picking LOW reduces
      Atmosphere density + Bloom
- [ ] Motion FX toggle ON/OFF — toggling OFF disables camera shake +
      FOV pulse on next prank
- [ ] Controls help text visible

### Daily Reward
- [ ] Auto-shows on first spawn each session
- [ ] Gift icon + "DAILY REWARD" title
- [ ] STREAK · N days
- [ ] 7-day strip with current day pulsing
- [ ] CLAIM button works, X dismisses

## O. DEATH

- [ ] Dying (test: wait at world edge, fall) shows DEATH overlay
- [ ] "YOU DIED" headline + cause-of-death sub-line + 5s countdown +
      RESPAWN NOW button
- [ ] Tapping RESPAWN respawns instantly; otherwise auto-respawns at 0s

## P. EMOTES

- [ ] B key (PC) or EMO button (mobile) opens radial wheel
- [ ] Wheel size scales with platform (280 / 340 / 380)
- [ ] Click an emote → server fires EmoteBroadcast → other players see
      "*emote*" tag above your head

## Q. MOBILE-SPECIFIC

Run on iPhone SE (375px) AND iPad (1024px):
- [ ] No HUD elements clip off-screen
- [ ] All buttons ≥44×44 px
- [ ] All text bounded (no microscopic / monstrous text)
- [ ] Modals fit within viewport with 24px margin
- [ ] KillFeed sits beside prank column without overlap
- [ ] Touch wheel for movement works (Roblox default)
- [ ] Rotation (portrait → landscape) re-clamps modals correctly

## R. TUTORIAL TEXT

- [ ] On PC: "Click SUMMON HUMAN", "Click a glowing prank"
- [ ] On mobile: "Tap SUMMON HUMAN", "Tap a glowing prank"

## S. WEATHER

- [ ] Wait ~8 minutes (or trigger via admin command)
- [ ] Banner appears top-center: warm wood bg, weather-color stroke
- [ ] Each weather (Sunny/Rainy/Foggy/RedMist) has its FX
- [ ] RedMist: 2× chaos multiplier active

## T. AUDIO MIXER

- [ ] Drop MASTER to 0 → all sound silent
- [ ] Drop MUSIC to 0, others up → city_ambient stops, SFX/UI continue
- [ ] Drop SFX to 0 → pranks silent, level-up sound still plays
- [ ] Drop UI to 0 → level-up + spawn chime silent

## U. NO-EMOJI CHECK

```sh
cd /home/user/KittyRaiser
grep -rn --include="*.lua" -P \
  '[\x{1F300}-\x{1F9FF}]|[\x{2600}-\x{27BF}]|[\x{2B50}]' src/
# MUST PRINT NOTHING
```

## V. NO-NEON-CYBERPUNK CHECK

Walk around the city. Verify:
- [ ] Sky is BLUE (warm horizon), not purple
- [ ] No glowing pink neon strokes
- [ ] No depth-of-field smudge
- [ ] Buildings are warm browns/tans, not cool purples
- [ ] Welcome sign is wooden, not pink-neon

## W. PERFORMANCE

- [ ] Run on lowest-end iPhone you have (iPhone SE 2020 if possible)
- [ ] Frame rate stays ≥30 fps in plaza with 14 ambient NPCs
- [ ] Frame rate stays ≥24 fps when boss + cop are simultaneously chasing
- [ ] Memory steady (no leak after 10 minutes of play)

## X. MULTIPLAYER

Test with 2-4 players:
- [ ] Each player sees others' cats with correct fur colors
- [ ] EmoteBroadcast: emoting on one player shows on the others
- [ ] Pranks fired by one player register on the server, FX broadcast
      to nearby players via PrankRegistered
- [ ] Leaderboard updates with all players' chaos counts

## Y. PUBLISH READINESS

- [ ] All gamepass IDs in GameConfig are non-zero (or you accept the
      "purchase failed: not configured" message)
- [ ] All dev product IDs in GameConfig are non-zero
- [ ] Place icon set in Creator Hub
- [ ] Game name + description set in Creator Hub
- [ ] Genre / age rating configured

## Z. FINAL SIGN-OFF

If all A-Y pass: PUBLISH.

If any FAIL: open a GitHub issue with:
- The failing checklist letter (e.g., "G")
- Screenshot
- Device + Roblox version
- Steps to reproduce

---

## What "10/10" looks like (acceptance criteria)

A new player connects, sees the warm sunny city, picks a fur, spawns into
a sunlit plaza, walks around with a cat that actually moves, summons a
cartoon Pixar civilian, taps a prank icon, sees a real pie/anvil/laser
effect, gets +chaos with coin icon + sound, levels up, opens shop, buys
a skin, opens settings, mutes music, changes graphics quality, kills a
boss for 15× reward, gets chased by a cop, dies, respawns from death
screen, completes a quest, sees the toast, and never once thinks the
game looks broken or feels unfinished.
