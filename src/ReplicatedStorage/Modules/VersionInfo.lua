-- VersionInfo.lua  v1 — single source of truth for what version is built
-- into the rbxlx the Roblox player is running. Bumped on every commit.
-- Read by VersionDisplay.client.lua and shown in the HUD corner so the
-- player can verify at a glance what version they're playing.

local VersionInfo = {}

VersionInfo.tag        = "v3.99.10"
VersionInfo.commitHash = "dc54e1e+v3.99"
VersionInfo.buildDate  = "2026-05-08-3"
VersionInfo.note       = "trade + clan + housing + territory + 4 districts + drivable cars + mounts + race + KOTH + duels + interiors + tutorial + hit-stop + reaction bubbles + landmarks + powerups + collectibles + chatter + boss stinger + fountain particles"

return VersionInfo
