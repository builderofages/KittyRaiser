# KittyRaiser

A sunny cartoon prank simulator for Roblox. Mobile + tablet + desktop friendly.
Warm wood-and-brick city. No emoji, no neon cyberpunk, no garbage.

**~6,500 lines of Luau across 60 source files.**

## Hard rules
See `CLAUDE.md` at the repo root. The short list:
1. Never an emoji in source. Use `AssetIds.lua` ImageLabel or ASCII text.
2. Warm sunny daytime cartoon city. Lighting is `StrayLighting.server.lua`.
3. Use uploaded mesh/texture/sound/icon assets before procedurals.
4. NPCs are not stiff Robloxians — cartoon body scales.
5. Cat is Roblox R15 + ear/tail/face accessories.
6. Single DisplayOrder registry in `UIUtil.DisplayOrder`.
7. Every TextScaled label needs `UIUtil.boundText`.

## Repo layout
```
KittyRaiser/
├── README.md                ← you are here
├── CLAUDE.md                ← hard rules for any AI coder
├── CHANGELOG.md             ← v3.20 → v3.29 history
├── PLAYTEST.md              ← exhaustive A-Z playtest checklist
├── default.project.json     ← Rojo config
├── blender_kittyraiser_cat.py     ← Blender script for cat meshes (already uploaded)
├── blender_kittyraiser_props.py   ← Blender script for original props (already uploaded)
├── blender_kittyraiser_extras.py  ← Blender script for 9 NEW props (run + upload)
├── open_cloud_upload.py     ← bulk upload helper for Open Cloud Assets API
└── src/
    ├── ReplicatedStorage/Modules/
    │   ├── GameConfig.lua            ← economy, stats, weather, gamepass IDs
    │   ├── PrankConfig.lua           ← 8 prank definitions (icon = AssetIds key)
    │   ├── CosmeticConfig.lua        ← skins
    │   ├── PerkConfig.lua            ← perk slots
    │   ├── QuestConfig.lua           ← daily quests (4-hour cycle)
    │   ├── RemoteEvents.lua          ← single source of truth for all RemoteEvents
    │   ├── AssetIds.lua              ← every uploaded asset id (60+ wired, ~16 placeholders)
    │   ├── AudioGroups.lua           ← Music/SFX/UI SoundGroup mixer
    │   └── UIUtil.lua                ← palette / DisplayOrder / TextSize / makeToast / modalSize
    ├── ServerScriptService/    (29 scripts)
    │   Core gameplay:
    │     DataHandler, PrankSystem, SummonSystem, RebirthHandler,
    │     CosmeticHandler, PerkSystem, SurvivalSystem, MonetizationHandler,
    │     LeaderboardHandler, EmoteSystem, DailyRewardSystem, AnalyticsHandler,
    │     AdminSystem, AntiCheat
    │   World + characters:
    │     CityRebuild, StrayLighting, MeshLoader, CatCharacterBuilder,
    │     CatLifelike, CatAnimations, AmbientCrowd, RagdollOnPrank,
    │     SpawnEnforcer, RemotesBootstrap, SafetyGuard
    │   Reactions + AI:
    │     NpcReactions, CopSystem, QuestSystem
    │   Other:
    │     PerfOptimize, DiagnosticDump, WeatherSystem, WalkAnim
    └── StarterPlayer/StarterPlayerScripts/    (19 scripts)
        HUDController, HUDPolish, InputHandler, EffectsController,
        CombatFeel, KillFeed, Minimap, EmoteWheel,
        OnboardingFlow, TutorialController, TutorialFlow,
        PreSpawnLobby, LoadingScreen, DeathScreen,
        SettingsMenu, QuestPanel, PerkUI, SurvivalUI,
        DailyRewardPopup, WeatherClient
        StarterGui/HUDBuilder.client.lua  ← builds the entire MainHUD ScreenGui
```

## How to run
```sh
# 1. Build the Roblox place file via Rojo:
rojo build --output build.rbxlx default.project.json

# 2. Open build.rbxlx in Roblox Studio
# 3. Press F5 (Play) — solo session
# 4. Walk through PLAYTEST.md A-Z to verify
```

## Verification one-liners
```sh
# Zero emoji in source (must print nothing):
grep -rn --include="*.lua" -P '[\x{1F300}-\x{1F9FF}]|[\x{2600}-\x{27BF}]|[\x{2B50}]' src/

# Every src/*.lua is referenced in default.project.json:
python3 - <<'PY'
import json, os
with open('default.project.json') as f: d = json.load(f)
ref = set()
def walk(n):
    if isinstance(n, dict):
        for k, v in n.items():
            if k == '$path': ref.add(v)
            elif isinstance(v, dict): walk(v)
walk(d['tree'])
for r, _, fs in os.walk('src'):
    for f in fs:
        if f.endswith('.lua'):
            p = os.path.join(r, f)
            if p not in ref: print('UNREF:', p)
PY
```

## Where to find things

| Want to … | Open |
|---|---|
| Add a new prank | `PrankConfig.lua` + `EffectsController.client.lua:effectFor` |
| Add a new fur skin | `PreSpawnLobby.client.lua:FUR_OPTIONS` |
| Add a HUD currency | `HUDBuilder:buildCurrencyCell` + `HUDController:refresh` |
| Tune cop chase | `CopSystem.server.lua:HEAT_PER_PRANK / SPAWN_THRESHOLD` |
| Tune boss difficulty | `SummonSystem.server.lua:BOSS_HP / BOSS_REWARD_MULT` |
| Tune quest definitions | `QuestConfig.Daily` |
| Change palette | `UIUtil.Palette` (single source) |
| Change overlay z-order | `UIUtil.DisplayOrder` |
| Add a sound | Upload via `open_cloud_upload.py sound`, paste id into `AssetIds.lua`, route via `AudioGroups.assign(sound, "SFX|UI|Music")` |
| Add a mesh | Upload via `open_cloud_upload.py mesh`, paste id, add name to `MeshLoader.NAMES`, use `_G.KittyRaiserMeshes[name].meshTemplate:Clone()` |

## Production readiness
- [x] All systems wired
- [x] No emoji
- [x] Warm cartoon theme
- [x] Responsive across phone/tablet/desktop
- [x] Settings persist across sessions
- [ ] Custom assets uploaded (mesh_cop_car, cop_siren, boss_warning, etc.)  ← see PLAYTEST.md
- [ ] Gamepass + dev product IDs configured in Creator Hub
- [ ] Custom cat animations uploaded
- [ ] Place icon + thumbnails set in Creator Hub
- [ ] Playtested A-Z per PLAYTEST.md
