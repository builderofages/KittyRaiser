# KittyRaiser — 2-Account Smoke Test

Run this before every public push. ~30 minutes with 2 accounts (yours + 1 test).
Treat any FAIL as ship-blocking unless explicitly noted.

## 0. Pre-flight (5 min)

- [ ] Branch `claude/codebase-audit-Dl1Cq` is synced to Studio (Rojo) **or**
      `build/install_part_1.lua` + `install_part_2.lua` were pasted into the
      command bar in order.
- [ ] `GameConfig.GAMEPASS_IDS` and `GameConfig.DEVPRODUCT_IDS` have **real**
      IDs (server boot logs `[GameConfig]` warnings if any are still 0).
- [ ] Server output shows, in order, with no red text:
      `[RemotesBootstrap] N remotes registered`
      `[DataHandler] Loaded <name>` for each player
      `[SafetyGuard] core systems online`
      `[StrayLighting] cyberpunk noir tuning applied (canonical)`
      `[CityRebuild v5] DONE`
      `[PerfOptimize] StreamingEnabled, Box collision`
- [ ] No `[SafetyGuard] CORE SYSTEMS DID NOT INITIALIZE` warning.

## 1. First-spawn flow (Account A) (3 min)

- [ ] Lobby ScreenGui (`PreSpawnLobby`) shows; cat preview rotates smoothly.
- [ ] Color picker: tapping a card moves the white selection ring to that exact
      card (regression: was off-by-one because the UIListLayout was counted as
      a card).
- [ ] Tap **SPAWN INTO CHAOS** → lobby fades, character spawns at MainSpawn,
      not in the void, not under the map.
- [ ] Floating name tag visible above your head.
- [ ] Within ~3 seconds the primitive cat is replaced by the toolbox rig
      **once** (CatCharacterBuilder upgrade). Rig should be tinted to your
      chosen fur color but eyes/pupils/nose remain their original colors
      (regression: tinting used to paint over facial features).
- [ ] `TutorialController` tooltip appears: "Tap SUMMON HUMAN to spawn your
      first victim". No second tooltip from a different ScreenGui appears
      (regression: TutorialFlow + OnboardingFlow used to fire concurrently).

## 2. HUD layout (mobile-critical) (5 min)

Test in Studio device emulator at **iPhone 12 (390×844)** AND **Galaxy S20 (360×800)**.

- [ ] Top bar shows chaos / level + XP bar / rebirth count, no clipping at the
      notch.
- [ ] Summon button is centered, fully visible, not overlapping the iOS home
      indicator (regression: `1, -(180+30)` pushed it into the notch on tall
      phones; now uses `safeBottom` helper).
- [ ] All 4 prank buttons stack on the right with no overflow.
- [ ] Bottom bar (SHOP / INV / REBIRTH / TOP) renders inside safe area.
- [ ] Minimap top-right is visible and **not under the notch** (Minimap
      regression: `IgnoreGuiInset = false` used to put it under the camera
      cutout).
- [ ] KillFeed entries on the right side are inside the screen (regression:
      hardcoded `1, -340` clipped on 360px-wide screens).
- [ ] Tap **B** (or open emote wheel button if added) — emote buttons are at
      least 80×60 px (was 70×50, below mobile minimum).

## 3. Pranks + economy (Account A) (5 min)

- [ ] Tap **SUMMON HUMAN** — pedestrian spawns within ~5s. No spawn-on-top-of-
      another-NPC stacking.
- [ ] Walk close. Tap **PIE**. Expect:
      - Cat scratch / pie sound plays
      - Camera FOV pulse (no stutter; regression: `task.wait` block was
        stalling the thread)
      - Screen flash + particle burst
      - "+N" damage number floats up
      - Coins spray (and **bounce** on the ground; regression: coins used to
        fall through with `CanCollide = false`)
      - NPC ragdolls then despawns after ~3s
- [ ] Top bar chaos count goes up.
- [ ] Try to **prank the same NPC twice in 1ms** (open the dev console and
      double-fire the remote). Expect: only ONE chaos award. (Race fix.)
- [ ] Try to prank an NPC summoned by Account B. Expect: PrankFailed reason
      "not_owner". Ambient pedestrians, however, **should** be prankable by
      anyone (no SummonedBy attribute set).
- [ ] Spam-press the prank button 10 times in 1 second. Expect:
      "rate_limited" PrankFailed after the 6th hit (sliding window).
- [ ] Reach Level 5. Expect:
      - LevelUp toast
      - PerkSlotEarned modal forces a slot-1 pick
      - Picking a perk closes the modal **once**, no retry button (regression:
        InvokeServer had no timeout fallback).
- [ ] Try to claim a slot-2 perk before slot 1 is filled. Expect failure
      (sequential rule).
- [ ] Reach Level 25, accumulate enough chaos to afford rebirth cost (50K
      base). REBIRTH button: confirms cost, applies, level resets to 1, stat
      points reset, perks reset.

## 4. Daily reward (1 min)

- [ ] On join, `DailyRewardPopup` only appears if the server fires
      `DailyAvailable`. Streak day shown matches what the server has stored.
- [ ] CLAIM grants the listed reward. Closing the popup cancels pulse tween
      loops (no orphan tweens; check via dev console: tween count stable).

## 5. Anti-cheat (Account A, Studio dev console) (3 min)

- [ ] Set HRP `CFrame = CFrame.new(2000, 50, 0)`. Output should log
      `[AntiCheat] FLAG <name> teleport_detected`. Player snaps back.
- [ ] Repeat 3+ times. Expect persisted `flagCount` in player data
      (`game.Players.<name>:GetAttribute(...)` is not where it lives — check
      with `print(_G.KittyRaiserData.getData(p).flagCount)`).
- [ ] Disconnect, rejoin. `flagCount` is restored from DataStore (regression:
      used to reset to 0 on rejoin).

## 6. Survival (5 min)

- [ ] Watch hunger bar over 1 minute. It should drop ~5 points (regression: it
      previously stayed at 100 forever because `math.clamp` truncated the
      ~0.4/tick decay to 0).
- [ ] Below 25 hunger, walk speed drops to 50% of base.
- [ ] Eat (or admin command `/chaos 0` then manually set hunger=100 via dev
      console) — walk speed restores to base (regression: used to stay slow
      forever because old code subtracted 4 each tick instead of setting).
- [ ] Equip ChaosFeast (slot 3) AND Vampuss (slot 4). Hunger restore per
      prank should be 5 + 1 = 6, not 5 + 2 = 7. (Vampuss was nerfed to keep
      survival from being trivially circumvented.)

## 7. Two-player interactions (Account A + B) (5 min)

- [ ] Both players can see each other's names + skin tints correctly.
- [ ] Account B opens emote wheel, plays Wave. Account A within ~80 studs
      sees a "Wave" tag float above B's head. (`EmoteBroadcast` remote.)
- [ ] Leaderboard updates: both players' chaos counts appear, sorted, in
      `LeaderboardModal` (open via TOP button).
- [ ] Verify the leaderboard does **not** broadcast every 5s if nothing
      changed (signature dedup) — watch network traffic in Studio Output's
      networking panel.
- [ ] Account B claims a daily reward. Account A's daily popup is unaffected.

## 8. Monetization (REAL ROBUX — do this last, $0.05 per test) (5 min)

> Skip if you are not ready to spend a few cents.
> Test once per product type (DevProduct + GamePass), not all 14 IDs.

- [ ] **DevProduct** (CHAOS_5K): purchase. Expect:
      - +5000 chaos, exactly once
      - "+5000 Chaos!" toast
      - Server log: receipt key written as "granted" in
        `KittyRaiserReceipts_v2`
- [ ] Force a server crash mid-purchase (admin /kick yourself with extreme
      prejudice during the prompt) — Roblox retries on next join. Expect:
      receipt is processed exactly once across the retry. **No duplicate
      grant.** (This is the ProcessReceipt fix.)
- [ ] **GamePass** (DEMON_SKIN if filled in): purchase. Expect:
      - "Demon Cat unlocked!" toast
      - "Demon" appears in inventory
      - Equipping it: cat tints red, glow effect on, eyes/pupils stay correct
- [ ] Rejoin. Demon is still in `ownedSkins`. Toolbox-rig upgrade preserves
      tint after upgrade.

## 9. Shutdown (1 min)

- [ ] Studio "Stop" → server output shows `[DataHandler]` save messages
      complete BEFORE the server exits (BindToClose barrier).
- [ ] No "save failed" warnings.
- [ ] Rejoin in fresh server: chaos / level / skin / streak all match what
      they were at shutdown.

## 10. Performance (run with 2 accounts present, leave running 5 min)

- [ ] Server FPS stays > 30 in Studio (Microprofiler).
- [ ] Heartbeat task list: `AntiCheat` should be ~4 Hz (not 60 Hz; regression).
- [ ] AmbientCrowd: number of pedestrians stays in 12–15 range; no runaway
      spawning, no overlap (regression).
- [ ] CatLifelike: tail update rate ~12 Hz (regression: was 20 Hz × 5
      segments × N players = killer).
- [ ] No accumulating tweens (regression: breathing tween used to leak one
      per cycle; now uses `repeatCount = -1`).

## When this passes

You're ready for soft launch. Open the game to ~10 invited testers, watch
the first 30 minutes of telemetry, then decide on public push.

## Known caveats — non-blocking

- Streaming radius is 1500 studs. If you grow the map past 3000 studs in any
  direction, increase `StreamingTargetRadius` proportionally.
- HellTokens skin purchase is wired but no client UI exposes the price for
  HellTokens-currency skins yet — the shop UI now distinguishes them, but
  test the actual click path.
- Admin `/reset` is full-reset. There is no `/partial-reset`. Use audit log
  in `KittyRaiserAdminAudit_v1` to recover.
