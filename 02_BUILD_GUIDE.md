# KittyRaiser — Studio Build Guide

## Pre-flight

1. Roblox Studio installed and logged in.
2. Create a new place: File → New → Baseplate. Save as "KittyRaiser".
3. Enable the following in Game Settings → Security:
   - Allow HTTP Requests: ON (for analytics later)
   - Studio Access to API Services: ON (so DataStores work in Studio testing)
4. Game Settings → Permissions: Public when ready.
5. Game Settings → Avatar: R15.
6. Game Settings → Maturity → label as **Moderate**.

## Folder structure to create in Roblox Studio Explorer

```
ReplicatedStorage
  └── Modules (Folder)
       ├── GameConfig (ModuleScript)
       ├── PrankConfig (ModuleScript)
       ├── CosmeticConfig (ModuleScript)
       └── RemoteEvents (ModuleScript)

ServerScriptService
  ├── DataHandler (Script)
  ├── AntiCheat (Script)
  ├── SummonSystem (Script)
  ├── PrankSystem (Script)
  ├── MonetizationHandler (Script)
  ├── RebirthHandler (Script)
  ├── CosmeticHandler (Script)
  ├── LeaderboardHandler (Script)
  ├── AnalyticsHandler (Script)
  └── MapBuilder (Script)

StarterGui
  └── HUDBuilder (LocalScript)

StarterPlayer
  └── StarterPlayerScripts (Folder, exists by default)
       ├── HUDController (LocalScript)
       ├── InputHandler (LocalScript)
       ├── EffectsController (LocalScript)
       └── TutorialController (LocalScript)
```

## Drop-in order (avoids load-order issues)

Paste files in this order to avoid require-chain errors:

1. **ReplicatedStorage > Modules** (all 4 ModuleScripts first — other scripts depend on them)
2. **ServerScriptService > AnalyticsHandler** (no deps)
3. **ServerScriptService > AntiCheat** (no deps beyond modules)
4. **ServerScriptService > DataHandler** (depends on modules)
5. **ServerScriptService > SummonSystem**
6. **ServerScriptService > PrankSystem**
7. **ServerScriptService > MonetizationHandler**
8. **ServerScriptService > RebirthHandler**
9. **ServerScriptService > CosmeticHandler**
10. **ServerScriptService > LeaderboardHandler**
11. **ServerScriptService > MapBuilder** (builds the map on server start)
12. **StarterGui > HUDBuilder** (LocalScript)
13. **StarterPlayer > StarterPlayerScripts > HUDController, InputHandler, EffectsController, TutorialController** (LocalScripts)

## Fastest way to drop the scripts in

**Option A — Manual (15 minutes):**
For each script in `src/`, in Studio:
- Right-click the destination folder → Insert Object → Script (or LocalScript or ModuleScript)
- Rename to match the file name (without `.server.lua` / `.client.lua` / `.lua`)
- Open the script, paste the file contents

**Option B — Rojo (recommended, 5 minutes once set up):**
- Install Rojo from https://rojo.space (CLI + Studio plugin)
- Use the included `default.project.json` (in this folder) — `rojo serve` then click Connect in Studio.

**Option C — Use Cowork's Roblox automation:**
- In Cowork, ask: "Open Roblox Studio and run the build script in /KittyRaiser/src/. Use the build guide order."

## After scripts are loaded — first test

1. Press F5 (Play in Studio).
2. Watch Output panel:
   - `[MapBuilder] Cat Alley built.`
   - `[DataHandler] Loaded YourName Level 1 Chaos 0`
   - HUD should appear
3. Move with WASD. You should be standing on the purple neon spawn pad in Cat Alley.
4. Press the SUMMON HUMAN button. A blue Robloxian should drop in.
5. Walk near it. Press the 🥧 (Pie) button. Particles + sound + +25 chaos points.
6. Repeat until Level 5. Anvil button unlocks. Continue.
7. At Level 25, walk to the gold cat statue and press REBIRTH bottom button.

## After test passes — set up monetization

See `04_MONETIZATION_SETUP.md`.

## Common issues & fixes

| Symptom | Cause | Fix |
|---|---|---|
| HUD doesn't appear | HUDBuilder didn't run | Check it's in StarterGui as LocalScript |
| "Cannot load module" errors | Module not in ReplicatedStorage > Modules | Move it there |
| Pranks don't register | Server not getting RequestPrank | Check RemoteEvents folder exists in ReplicatedStorage |
| DataStore errors in Studio | API services not enabled | Game Settings → Security → enable |
| Map builds twice | MapBuilder ran twice | It's idempotent now (checks for existing CatAlley model), but if you see dupes, delete extras |
| NPCs fall through floor | Baseplate too thin | Already 4 studs thick; if still happens, check CanCollide is true |
| GamePass doesn't grant | GamePass ID = 0 | Set real ID in GameConfig.GAMEPASS_IDS |

## Performance budget

- Target: 60 FPS on iPhone 11 / mid-range Android.
- Part count budget: 500 in v1 map. MapBuilder produces ~30 parts. Plenty of headroom.
- NPC budget: 5 simultaneous max per server (gate in SummonSystem if you hit issues).

## Publishing v1

1. File → Publish to Roblox.
2. Game Settings → Public → ON.
3. Set Maturity Label: Moderate.
4. Add 3 thumbnails (1280x720): one cat-action, one HUD-shot, one gameplay.
5. Add Game Icon (512x512): cat head with 😈 + game name.
6. Add 1 trailer/video later (15-30s).
7. Title: "KittyRaiser — Prank Sim 🐱"
8. Description: "Spawn humans. Throw pies, drop anvils, fart on them, blast laser eyes. Stack chaos. Rebirth. Be the boss cat. Cartoon prank simulator."

## Soft launch metrics targets (first 24h)

- D1 retention (return next day): >25% = OK, >35% = good, >45% = banger
- Average session length: >5 min = OK, >10 = good
- First-purchase conversion: >2% = OK, >4% = good
- CPI (Cost Per Install) on Roblox Ads: <$0.20 = OK, <$0.10 = good

If any target misses by more than 30%, fix it before scaling ad spend.
