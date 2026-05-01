# Asset List — what to grab from Roblox Toolbox

Everything in v1 is built programmatically except sounds and (optional) icons. The map and HUD don't need any imported models.

## Sounds (replace placeholder IDs in PrankConfig.lua)

Search Toolbox → Audio for each. Pick free ones with high download counts.

| Use | Search term | Suggested |
|---|---|---|
| Pie splat | "pie splat" or "cream splash" | rbxassetid://9117567259 (placeholder — verify) |
| Anvil bonk | "anvil drop" or "metal clang" | rbxassetid://9117568141 (placeholder) |
| Fart cloud | "fart cartoon" | rbxassetid://9117569015 (placeholder) |
| Laser zap | "laser zap" or "energy blast" | rbxassetid://9117570233 (placeholder) |
| UI button click | "button click" | (find one) |
| Level up | "level up sparkle" | (find one) |
| Cash collect | "coin collect" | (find one) |

After picking real assets in Toolbox:
1. Copy the asset ID (right-click → Copy Asset ID)
2. Paste into `PrankConfig.lua` → replace the placeholder rbxassetid:// values
3. Test in Studio

## Game Icon (512x512)

Create or AI-generate:
- A cartoon hellcat head with horns + sparkly green eyes
- Bold "KITTYRAISER" text below
- Purple/black/neon green color palette
- Tools: Canva free template, or Bing Image Creator with prompt:
  > "Roblox game icon, 512x512, cartoon evil cat with small purple horns, big green eyes, hellfire background, neon purple and green, bold text 'KITTYRAISER' below"

## Thumbnails (1280x720, up to 10 allowed)

Three minimum:
1. Cat throwing a pie at a Robloxian — action shot
2. HUD UI overlay screenshot
3. Multiple cats on the map (lobby vibe)

Take in-Studio screenshots after the game is built. Crop to 1280x720.

## Trailer (15-30s, optional but +30% CTR)

Record gameplay:
1. Spawn → summon → throw pies → anvil drop → laser eyes → rebirth flash
2. Add captions: "PRANK HUMANS", "STACK CHAOS", "BE THE BOSS CAT"
3. Music: free Roblox-licensed track from Toolbox audio (search "upbeat sim")
4. Tools: OBS Studio for capture, CapCut free for editing

## Cat avatar accessories (optional — for v2 polish)

For v1 we use BodyColors only. For v2 polish, search Toolbox → Models for:
- Cat ears (free)
- Cat tail (free)
- Demon horns (for Demon skin)
- Halo (for special events)

Add them as accessories in `CosmeticConfig.lua` → `accessoryIds = {1234567, 8901234}`.

## Music

In Studio: Insert SoundService > Sound. Set SoundId to a Toolbox royalty-free track. Set Looped = true, Volume = 0.5. Don't use copyrighted music — Roblox will mute or take down your game.

Suggested moods: upbeat synthwave, retrowave, lofi cartoon. Search "lofi" or "synthwave" in Toolbox audio.

## Decals (storefront polish — v2)

- Brookhaven-style billboard images of in-game cats
- Neon "OPEN" signs
- Splat decals for the alley walls

All can be Toolbox decals. Search "neon sign", "graffiti splat".

## What you do NOT need

- 3D modeled cats — we use R15 with BodyColors
- Custom rigs — R15 default works
- Animations — TweenService handles all v1 motion
- Custom music — free Toolbox tracks are fine
- Voice acting — text and sound effects only in v1
