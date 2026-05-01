# Claude Cowork Handoff Prompt

Paste the entire block below into Claude Cowork. It will execute the build inside Roblox Studio for you.

---

You are operating Roblox Studio for me. The complete KittyRaiser v1 game is in `/KittyRaiser/`. Your job is to load every script into Studio in the correct order, build the map, and run a smoke test.

## Workspace context
- Game name: KittyRaiser
- Place: new baseplate, R15 avatars, Maturity = Moderate
- Goal: shipping a v1 cartoon prank simulator

## Files you must load (read each, then create the matching Studio object with that exact source)

### Step 1 — ReplicatedStorage > Modules (4 ModuleScripts)
1. `src/ReplicatedStorage/Modules/GameConfig.lua` → ModuleScript named `GameConfig`
2. `src/ReplicatedStorage/Modules/PrankConfig.lua` → ModuleScript named `PrankConfig`
3. `src/ReplicatedStorage/Modules/CosmeticConfig.lua` → ModuleScript named `CosmeticConfig`
4. `src/ReplicatedStorage/Modules/RemoteEvents.lua` → ModuleScript named `RemoteEvents`

### Step 2 — ServerScriptService (10 Scripts in this order)
1. `src/ServerScriptService/AnalyticsHandler.server.lua` → Script `AnalyticsHandler`
2. `src/ServerScriptService/AntiCheat.server.lua` → Script `AntiCheat`
3. `src/ServerScriptService/DataHandler.server.lua` → Script `DataHandler`
4. `src/ServerScriptService/SummonSystem.server.lua` → Script `SummonSystem`
5. `src/ServerScriptService/PrankSystem.server.lua` → Script `PrankSystem`
6. `src/ServerScriptService/MonetizationHandler.server.lua` → Script `MonetizationHandler`
7. `src/ServerScriptService/RebirthHandler.server.lua` → Script `RebirthHandler`
8. `src/ServerScriptService/CosmeticHandler.server.lua` → Script `CosmeticHandler`
9. `src/ServerScriptService/LeaderboardHandler.server.lua` → Script `LeaderboardHandler`
10. `src/Workspace/MapBuilder.server.lua` → Script `MapBuilder` (place in ServerScriptService — it builds the map at runtime, not at edit time)

### Step 3 — StarterGui (1 LocalScript)
1. `src/StarterGui/HUDBuilder.client.lua` → LocalScript `HUDBuilder`

### Step 4 — StarterPlayer > StarterPlayerScripts (4 LocalScripts)
1. `src/StarterPlayer/StarterPlayerScripts/HUDController.client.lua` → LocalScript `HUDController`
2. `src/StarterPlayer/StarterPlayerScripts/InputHandler.client.lua` → LocalScript `InputHandler`
3. `src/StarterPlayer/StarterPlayerScripts/EffectsController.client.lua` → LocalScript `EffectsController`
4. `src/StarterPlayer/StarterPlayerScripts/TutorialController.client.lua` → LocalScript `TutorialController`

### Step 5 — Game Settings
- File → Game Settings → Security → "Allow HTTP Requests" ON, "Studio Access to API Services" ON
- Avatar → R15
- Permissions → Public when ready
- Maturity → Moderate

### Step 6 — Smoke test (you do this)
1. Press F5 to play in Studio
2. Verify Output shows:
   - `[MapBuilder] Cat Alley built.`
   - `[DataHandler] Loaded ...`
3. Click SUMMON HUMAN button — confirm an NPC spawns on a pink pad
4. Walk near it, click the Pie button — confirm particles + sound + chaos points increase
5. Stop play. Report results to me.

## What you do NOT do
- Do not modify any source code unless I tell you to.
- Do not publish to Roblox — I will publish manually after testing.
- Do not set GamePass IDs to anything other than 0 — I will create the GamePasses on the Creator Dashboard and update GameConfig manually.

## What to do if a script errors
- Copy the exact error from Output
- Tell me which script + line
- Wait for instruction. Do not patch on your own.

## Reporting
When done, report:
- Which steps completed
- Any errors hit
- Studio test result (did NPC spawn? did prank register?)
- Time to complete

That's it. Execute now.
