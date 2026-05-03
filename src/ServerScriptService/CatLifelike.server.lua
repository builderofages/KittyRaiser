-- CatLifelike.server.lua  — DISABLED.
-- The previous implementation manipulated CFrames on welded body parts using
-- world-space values captured at spawn time. As the cat moved, the tail/ears
-- got pinned to the spawn position, which made the cat look broken and
-- fought the physics engine. Replaced by the cleaner v5 character pipeline
-- in CatCharacterBuilder.server.lua. This file is intentionally a no-op so
-- it can be deleted later without breaking the project tree.

print("[CatLifelike] disabled (replaced by v5 character pipeline)")
