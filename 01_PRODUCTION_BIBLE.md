# KittyRaiser — Production Bible v1

## Identity (locked, no more pivots)

**Name:** KittyRaiser
**Tagline:** Prank humans. Stack chaos. Become the boss cat.
**Genre:** Cartoon Idle Prank Simulator (with active play)
**Maturity Label:** Moderate (cartoon slapstick humor, no gore, no gambling, no torture framing)
**Audience:** 9-16 primary, 13-25 secondary. NOT 17+ Restricted.
**Art direction:** Roblox-native (Toolbox parts + Neon material + ParticleEmitters + simple Tween animations). Looney Tunes color palette.
**Platform priority:** Mobile-first (60% Roblox DAU is mobile), then PC, then console.

## Core loop (one paragraph)

Player spawns as a customizable cartoon cat in Cat Alley. They press SUMMON HUMAN to spawn a Robloxian NPC. They use prank powers (PIE, ANVIL, FART, LASER) to chaos the NPC. Each successful prank earns Chaos Points. Chaos Points buy upgrades (more power, faster cooldown, higher prank tier) and cosmetics. At Level 25 they can REBIRTH — reset progress for a permanent multiplier. Rinse, repeat, unlock new pranks, climb the server leaderboard.

That is the entire v1 game. Everything below serves that loop.

## v1 scope (what we build first — ships in 5-7 days)

### Map
- **One zone:** Cat Alley (200x200 studs, single baseplate, neon signs, alley walls, dumpsters, taco stand, parked cars).
- 4 spawn pads for summoned humans.
- 1 Cosmetic Shop building.
- 1 Rebirth Statue (a glowing cat statue — interact to rebirth).
- 1 Leaderboard pillar showing top 10 Chaos Points on the server.
- Skybox: dusk pink/purple. Ambient: dark purple. Bloom enabled.

### Cat customization
- **5 cat skins:** Default (free), Stripey (free), Calico (free), Demon (399 Robux gamepass), Neon (799 Robux gamepass).
- Skin = recolored R15 cat avatar via accessory bundle OR HumanoidDescription override.
- Saved per-player.

### Prank system
| Prank | Unlock | Damage (Chaos pts) | Cooldown | Effect |
|---|---|---|---|---|
| Pie | Level 1 | 25 | 1.5s | Cream splat particle, "splat" sound |
| Anvil | Level 5 | 75 | 4s | Anvil drops, dust cloud, "bonk" sound |
| Fart Cloud | Level 10 | 150 | 6s | Green smoke AOE 8 studs, "fart" sound |
| Laser Eyes | Level 15 | 300 | 8s | Red beam from cat eyes, screen shake, "zap" sound |

Server validates: cooldown, distance to target, target is a valid human NPC, player level meets unlock.

### Progression
- **XP:** 1 prank = 10 XP. Level cap 50.
- **Level curve:** XP for level N = 100 * N^1.4.
- **Rebirth:** Available at Level 25. Resets level + XP. Grants permanent +25% multiplier per rebirth (stackable). Soft cap at 10 rebirths.
- **Multiplier:** Final = (1 + 0.25 * rebirths) * skin bonus * gamepass bonus.

### Monetization (v1)
**GamePasses (one-time, Robux):**
- Demon Cat Skin — 399 R$
- Neon Cat Skin — 799 R$
- VIP Pass — 599 R$ (2x Chaos Points + exclusive name tag + chat color)

**DevProducts (consumable, Robux):**
- 5,000 Chaos Points — 99 R$
- 50,000 Chaos Points — 499 R$
- Skip 1 Rebirth Requirement — 299 R$

**No loot crates. No slots. No randoms.** v2 only if we go Restricted.

### HUD (mobile-first)
- **TopBar:** Chaos Points (left, neon green, GothamBold 28), Level (center, with progress bar to next level), Rebirths (right, with crown).
- **Center bottom:** Big red SUMMON HUMAN button (180x180 mobile, 120x120 desktop).
- **Right side:** 4 prank power buttons (vertical stack), greyed if locked, cooldown radial overlay when on cooldown.
- **Bottom bar:** Shop, Inventory, Rebirth, Leaderboard buttons.
- **Top right:** Settings cog.
- All buttons: thumb-friendly, TweenService pop on click (scale 1.0 → 1.1 → 1.0 over 0.15s).

### Anti-cheat
- All Chaos Point grants happen server-side only.
- Client sends "I want to prank target X with prank Y" → server validates cooldown/level/distance/NPC validity → server grants points.
- Rate limit: max 1 prank request per cooldown window.
- DataStore writes are session-locked.
- Suspicious activity (>2x expected rate, impossible distances) flags player and stops grants for the session.

### Tutorial (first 60 seconds)
1. Player spawns. Voiceover line + tooltip: "Tap SUMMON HUMAN to spawn your first victim."
2. Player taps. Human spawns. Tooltip: "Walk close and tap PIE to throw a pie."
3. Player throws pie. Chaos Points +25 fly up animation. Tooltip: "Nice! Get to Level 5 to unlock Anvil."
4. Auto-dismisses after first prank.

### Analytics events (PlayFab or Roblox AnalyticsService)
- session_start
- first_summon (timing from session_start)
- first_prank (which prank type, timing)
- level_up (level, time-to-level)
- rebirth_completed (rebirth #, total session time)
- gamepass_prompt_shown (which pass, where in flow)
- gamepass_purchased (which pass, R$ amount)
- devproduct_purchased (which product, R$ amount)
- session_end (duration, max chaos)

### Save data schema (versioned)
```lua
{
    version = 1,
    chaosPoints = 500,
    level = 1,
    xp = 0,
    rebirths = 0,
    multiplier = 1.0,
    equippedSkin = "Default",
    ownedSkins = {"Default", "Stripey", "Calico"},
    totalPranks = 0,
    totalRobuxSpent = 0,
    firstPlayDate = os.time(),
    lastPlayDate = os.time(),
    settingsMusicOn = true,
    settingsSFXOn = true,
}
```

## v2 roadmap (post-launch, if v1 hits 1k+ DAU)

- Zone 2: City Park (new map, new humans to prank, level 30+ gate)
- 15 more cat skins via Chaos Points + Robux
- Cosmetic Shop building with full equip/preview UI
- Daily reward streak (7-day cycle)
- Friend system + party play
- Server-wide events (Red Mist Hour: 2x Chaos for 60 min)

## v3 roadmap (only if v2 ships)

- Gangs / cat clans (8-player parties)
- Light PvP duels (consent-based, cosmetic-only stakes)
- Custom cat designer (color picker + accessory mixer)
- 3rd zone, more pranks
- Voice chat opt-in
- Season pass (90-day rotating cosmetics)

## v4+ (this is where the Grok bible's bigger ideas live)

- 2000x2000 city
- Animal catcher PvE
- Weather system
- Food/water survival mechanics
- Perks / Fallout-style stats
- Sub-power trees

**These do not exist in v1 and will not block v1 from shipping.** Grok wanted these on day one. That was the mistake.

## Build order

1. **Day 1:** Set up place, write all server scripts (Data, Pranks, Summon, Anti-cheat, Monetization), test in Studio with print logs.
2. **Day 2:** Build map (Cat Alley, 200x200) + place spawn pads + neon signs.
3. **Day 3:** Build HUD ScreenGui programmatically (HUDBuilder script handles this), wire client controllers.
4. **Day 4:** Add cosmetic skins (5 HumanoidDescriptions), wire shop UI, set up GamePasses + DevProducts in Creator Dashboard.
5. **Day 5:** Tutorial + analytics + leaderboard. QA pass with 2 test accounts.
6. **Day 6:** Soft launch — Moderate label, English-only, no ads. Watch metrics for 24h.
7. **Day 7:** Fix top 3 bugs from soft launch. Then run first ad spend ($500-$1000, NOT $10k).

## Ad spend reality check

Grok told you to "place 10k ads behind it today." Don't. First $1k tells you if CPI < $0.20 and D1 retention > 30%. If yes, scale. If no, fix retention before more spend. $10k on a v1 with broken retention is $10k lit on fire.

## Files in this build

```
/KittyRaiser/
  00_RATING_AND_GAPS.md           — read first
  01_PRODUCTION_BIBLE.md          — this file
  02_BUILD_GUIDE.md               — Studio setup + build order
  03_CLAUDE_HANDOFF.md            — prompt for Claude Cowork to execute
  04_MONETIZATION_SETUP.md        — exact GamePass/DevProduct setup steps
  05_ASSET_LIST.md                — what to grab from Toolbox
  src/
    ServerScriptService/
      DataHandler.server.lua
      PrankSystem.server.lua
      SummonSystem.server.lua
      MonetizationHandler.server.lua
      AntiCheat.server.lua
      RebirthHandler.server.lua
      LeaderboardHandler.server.lua
      AnalyticsHandler.server.lua
    ReplicatedStorage/
      Modules/
        GameConfig.lua
        PrankConfig.lua
        CosmeticConfig.lua
        RemoteEvents.lua
    StarterPlayer/
      StarterPlayerScripts/
        HUDController.client.lua
        InputHandler.client.lua
        EffectsController.client.lua
        TutorialController.client.lua
    StarterGui/
      HUDBuilder.client.lua
    Workspace/
      MapBuilder.server.lua
```

Next: read 02_BUILD_GUIDE.md, then start at src/.
