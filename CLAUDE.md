# KittyRaiser — Hard Rules

## Absolute rules (do not break)

1. **NO EMOJI.** Anywhere. In strings, comments, commit messages, tutorial text,
   button labels, toasts, killfeed, prank icons, onboarding flow — none. If you
   need a visual symbol, use a real ImageLabel pointing at an uploaded asset in
   `src/ReplicatedStorage/Modules/AssetIds.lua`. If no asset exists, use plain
   ASCII text. Never `🥧`, `🔨`, `💚`, `🎉`, `🔥`, `✨`, `🔓`, `👑`, `▶`, `◀`,
   `✕`, `✦`, `⭐` — never.

2. **NO neon cyberpunk theme.** The art direction is sunny daytime cartoon city
   with warm wood / brick / sandstone palette. Lighting lives in
   `StrayLighting.server.lua` (single source of truth). Don't reintroduce
   purple ambient, pink neon strokes, hazy fog, depth of field, or "noir"
   anything.

3. **Use the uploaded mesh + texture + sound + icon assets** in
   `AssetIds.lua` and `_G.KittyRaiserMeshes` (populated by
   `MeshLoader.server.lua`) before falling back to procedural primitives.
   13 mesh assets (cat body/head/ear/leg/tail, anvil, brownstone, skyscraper,
   taxi, hydrant, mailbox, trashcan, pie), 7 texture assets, 16 sound assets,
   19 HUD icon assets are already wired in. Use them.

4. **NPCs are not Robloxian.** Both `AmbientCrowd.buildPed` and
   `SummonSystem.buildHumanNPC` apply cartoon body scales (BodyHeightScale
   0.75, HeadScale 1.55, BodyWidthScale 1.20) after spawning via
   `Players:CreateHumanoidModelFromDescription`. Don't remove these scales.

5. **Cat character uses Roblox default R15 + decorations.** Movement is
   guaranteed by the standard Roblox character pipeline. Cat ears, tail,
   face, name tag are accessories welded on top. Don't return to custom
   welded rigs.

6. **Single DisplayOrder registry** in `UIUtil.DisplayOrder`. Don't hardcode
   magic numbers like `DisplayOrder = 80`.

7. **All TextScaled labels need UITextSizeConstraint** via `UIUtil.boundText`.
   No bare TextScaled — text balloons or shrinks to illegible without bounds.

## File entry points

- `src/ServerScriptService/CatCharacterBuilder.server.lua` — player cat
- `src/ServerScriptService/SummonSystem.server.lua` — prank target NPCs
- `src/ServerScriptService/AmbientCrowd.server.lua` — wandering pedestrian NPCs
- `src/ServerScriptService/CityRebuild.server.lua` — world geometry
- `src/ServerScriptService/StrayLighting.server.lua` — lighting (single source)
- `src/ServerScriptService/MeshLoader.server.lua` — loads custom meshes into
  `_G.KittyRaiserMeshes`
- `src/StarterGui/HUDBuilder.client.lua` — HUD construction
- `src/StarterPlayer/StarterPlayerScripts/EffectsController.client.lua` —
  prank visuals (anvil drop, pie splatter, laser beams, etc.)
- `src/ReplicatedStorage/Modules/UIUtil.lua` — shared UI helpers
- `src/ReplicatedStorage/Modules/AssetIds.lua` — uploaded asset IDs
- `src/ReplicatedStorage/Modules/PrankConfig.lua` — prank tuning + icon keys

## Verifying no emoji slipped back in

```sh
grep -rn --include="*.lua" -P '[\x{1F300}-\x{1F9FF}]|[\x{2600}-\x{27BF}]|[\x{1F000}-\x{1F2FF}]|[\x{2700}-\x{27FF}]|[\x{1F100}-\x{1F1FF}]|[\x{1F900}-\x{1F9FF}]|[\x{2B50}]' src/
```

Should print nothing. If it prints anything, fix immediately.
