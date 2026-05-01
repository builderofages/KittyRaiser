# Monetization Setup — Step by Step

After your smoke test passes, set up the GamePasses and DevProducts.

## 1. Create GamePasses (Creator Dashboard)

Go to https://create.roblox.com → your KittyRaiser experience → Monetization → Passes.

Create 3 passes:

| Pass Name | Price (Robux) | Description |
|---|---|---|
| Demon Cat | 399 | Unlock the Demon Cat skin — 1.5x Chaos multiplier and red glow effect. |
| Neon Cat | 799 | Unlock the Neon Cat skin — 2x Chaos multiplier and rainbow glow. |
| VIP | 599 | 2x Chaos points on every prank, exclusive name tag, exclusive chat color. |

For each pass, upload an icon (512x512 PNG) showing the cat skin. AI-generate or commission later. For day 1, simple solid-color cat icons work.

After creating each, copy its **GamePass ID** (the number in the URL).

## 2. Update GameConfig.lua with the IDs

Open `ReplicatedStorage > Modules > GameConfig` in Studio. Replace:

```lua
GameConfig.GAMEPASS_IDS = {
    DEMON_SKIN = 0,    -- replace with Demon Cat pass ID
    NEON_SKIN = 0,     -- replace with Neon Cat pass ID
    VIP = 0,           -- replace with VIP pass ID
}
```

with the real IDs from the dashboard.

## 3. Create DevProducts

Same dashboard area → Developer Products. Create 3:

| Product Name | Price (Robux) | Description |
|---|---|---|
| 5,000 Chaos Points | 99 | Instant 5,000 Chaos Points |
| 50,000 Chaos Points | 499 | Instant 50,000 Chaos Points |
| Skip Rebirth Requirement | 299 | Jump straight to Rebirth-eligible level |

Copy each product ID.

## 4. Update GameConfig with DevProduct IDs

```lua
GameConfig.DEVPRODUCT_IDS = {
    CHAOS_5K = 0,      -- replace
    CHAOS_50K = 0,     -- replace
    REBIRTH_SKIP = 0,  -- replace
}
```

## 5. Test purchases

In Studio (the Studio robux purchase flow simulates with test currency):
1. Open the in-game shop
2. Click "Robux" on the Demon Cat
3. Confirm the prompt appears with the right pass name and price
4. (You can't actually buy in Studio, but the prompt should show)

In live game (after publish):
1. Use a test account or your own
2. Buy the lowest tier (99 R$ Chaos pack)
3. Confirm Chaos points increase
4. Confirm receipts work — buy the same product twice quickly, only get one grant

## 6. (Optional) Set up Premium Payouts

Premium Payouts pay you per minute Premium subscribers spend in your game. Toggle it on in the Monetization tab. Worth ~5-15% of revenue at scale — set and forget.

## 7. Pricing strategy notes

- 99 R$ ≈ $1.25 USD — impulse purchase tier, must convert at >5%
- 499 R$ ≈ $6.25 USD — committed-player tier, target 1% conversion
- 1299 R$ ≈ $16 USD — whale tier, target 0.1% conversion (but high LTV)

These are healthy ratios for a Roblox sim. Don't go above 1,299 in v1.

## 8. What NOT to add

- **Loot boxes / random crates with paid keys.** Roblox's "Transparent Paid Random Items" policy requires odds disclosure and 17+ Restricted tag. v1 is Moderate. Skip until v2 if ever.
- **Slot machines / spinners with Robux.** Same risk. Skip.
- **Real-money "trade-in" or skin gambling.** Banned, will get game taken down.
- **Pay-to-win PvP.** Cosmetic-only purchases keep your community. Pay-to-win drives churn and review bombs.

## 9. Revenue forecast (rough, calibrated against Roblox sims of similar scope)

If v1 ships and gets to 500 CCU (concurrent users) average:
- ~10,000 DAU
- 3-5% paying conversion = 300-500 paying players
- ARPPU (avg revenue per paying user) ~$8/month
- Monthly revenue: $2,400-$4,000

Roblox takes 30%, you keep 70% = $1,680-$2,800/mo at 500 CCU.

To hit $100k/mo you need ~10,000-20,000 CCU sustained. That's the v3+ goal, not v1.

v1 target: prove the loop works and ARPPU is healthy. Scale comes from updates + ad spend after metrics validate.
