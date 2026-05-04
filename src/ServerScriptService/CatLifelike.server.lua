-- CatLifelike.server.lua  v3 — DISABLED for v3.44.
--
-- Previous versions disabled WeldConstraints on CatTail / CatEar parts and
-- drove their CFrames each Heartbeat to simulate twitch / wag. This worked
-- when those parts were welded to UpperTorso / Head. But CatCharacterBuilder
-- v9 now hides R15 entirely and welds the whole cat-shape body to the
-- HumanoidRootPart. Disabling the welds in this version disconnects the
-- tail from the cat body visually.
--
-- For v1.0: the static welded cat looks great and follows the player. We
-- keep this file as a no-op so the project tree doesn't break and so we
-- have a place to re-enable physics-safe micro-animation later.

local Players = game:GetService("Players")
print("[CatLifelike v3] no-op (intentional for v9 cat shape — micro-anim TBD in v1.1)")
return true
