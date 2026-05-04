-- DayNightCycle.server.lua  v1 — natural city lighting that breathes.
--
-- 12-minute real-time cycle. ClockTime cycles 0..24 once per cycle, so the
-- sun and moon move naturally through the sky. Auxiliary Lighting properties
-- (Brightness, OutdoorAmbient, ColorShift, Atmosphere, FogColor) interpolate
-- between four key phases:
--   * DAWN  (5..7):    golden, soft rim
--   * DAY   (7..18):   bright sunny daytime (CLAUDE.md baseline)
--   * DUSK  (18..20):  warm orange, long shadows
--   * NIGHT (20..5):   deep navy, dim ambient, warm window glows
--
-- Per CLAUDE.md art direction: NO neon. Night phase uses warm cream window
-- glow (PointLights on existing streetlamp meshes), not pink/purple synth.
--
-- Place in: ServerScriptService > DayNightCycle (Script). Auto-runs.

local Lighting   = game:GetService("Lighting")
local Workspace  = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local CYCLE_SECONDS = 720  -- 12 real minutes for one in-game day

-- =====================================================================
-- COLOR / VALUE TABLES PER PHASE
-- =====================================================================
local PHASES = {
    -- {hourStart, props}
    {0,  {brightness=0.6, outdoor=Color3.fromRGB(80, 85, 110),  ambient=Color3.fromRGB(50, 55, 75),
          shiftTop=Color3.fromRGB(140, 150, 200), shiftBot=Color3.fromRGB(40, 45, 70),
          atmDensity=0.08, atmDecay=Color3.fromRGB(60, 70, 110), fogColor=Color3.fromRGB(50, 55, 80),
          fogStart=400, fogEnd=2000}},
    {5,  {brightness=1.2, outdoor=Color3.fromRGB(180, 150, 130), ambient=Color3.fromRGB(120, 110, 100),
          shiftTop=Color3.fromRGB(255, 200, 150), shiftBot=Color3.fromRGB(180, 150, 170),
          atmDensity=0.06, atmDecay=Color3.fromRGB(200, 170, 150), fogColor=Color3.fromRGB(220, 200, 180),
          fogStart=600, fogEnd=2400}},
    {7,  {brightness=2.0, outdoor=Color3.fromRGB(170, 170, 170), ambient=Color3.fromRGB(140, 140, 140),
          shiftTop=Color3.fromRGB(255, 210, 160), shiftBot=Color3.fromRGB(140, 130, 180),
          atmDensity=0.05, atmDecay=Color3.fromRGB(190, 205, 220), fogColor=Color3.fromRGB(220, 230, 240),
          fogStart=600, fogEnd=2400}},
    {18, {brightness=1.7, outdoor=Color3.fromRGB(220, 180, 140), ambient=Color3.fromRGB(170, 140, 110),
          shiftTop=Color3.fromRGB(255, 180, 100), shiftBot=Color3.fromRGB(180, 130, 140),
          atmDensity=0.07, atmDecay=Color3.fromRGB(220, 160, 130), fogColor=Color3.fromRGB(240, 200, 170),
          fogStart=500, fogEnd=2200}},
    {20, {brightness=0.9, outdoor=Color3.fromRGB(110, 110, 140), ambient=Color3.fromRGB(75, 75, 100),
          shiftTop=Color3.fromRGB(180, 170, 220), shiftBot=Color3.fromRGB(60, 65, 100),
          atmDensity=0.08, atmDecay=Color3.fromRGB(80, 90, 130), fogColor=Color3.fromRGB(70, 75, 100),
          fogStart=400, fogEnd=2000}},
    {24, {brightness=0.6, outdoor=Color3.fromRGB(80, 85, 110),  ambient=Color3.fromRGB(50, 55, 75),
          shiftTop=Color3.fromRGB(140, 150, 200), shiftBot=Color3.fromRGB(40, 45, 70),
          atmDensity=0.08, atmDecay=Color3.fromRGB(60, 70, 110), fogColor=Color3.fromRGB(50, 55, 80),
          fogStart=400, fogEnd=2000}},
}

local function lerp(a, b, t) return a + (b - a) * t end
local function lerpColor(a, b, t)
    return Color3.new(lerp(a.R, b.R, t), lerp(a.G, b.G, t), lerp(a.B, b.B, t))
end

local function interpolatedProps(hour)
    -- Find the bracketing phases
    local lo, hi = PHASES[1], PHASES[#PHASES]
    for i = 1, #PHASES - 1 do
        if hour >= PHASES[i][1] and hour < PHASES[i+1][1] then
            lo, hi = PHASES[i], PHASES[i+1]
            break
        end
    end
    local span = hi[1] - lo[1]
    local t = span > 0 and (hour - lo[1]) / span or 0
    local A, B = lo[2], hi[2]
    return {
        brightness = lerp(A.brightness, B.brightness, t),
        outdoor    = lerpColor(A.outdoor, B.outdoor, t),
        ambient    = lerpColor(A.ambient, B.ambient, t),
        shiftTop   = lerpColor(A.shiftTop, B.shiftTop, t),
        shiftBot   = lerpColor(A.shiftBot, B.shiftBot, t),
        atmDensity = lerp(A.atmDensity, B.atmDensity, t),
        atmDecay   = lerpColor(A.atmDecay, B.atmDecay, t),
        fogColor   = lerpColor(A.fogColor, B.fogColor, t),
        fogStart   = lerp(A.fogStart, B.fogStart, t),
        fogEnd     = lerp(A.fogEnd, B.fogEnd, t),
    }
end

-- =====================================================================
-- WINDOW LIGHTS — pre-build PointLights on every existing streetlamp mesh
-- (and a few generic city props) so the city has natural lit windows at
-- night. Cheap: PointLights cull when off.
-- =====================================================================
local cityFolder = Workspace:WaitForChild("CartoonCity", 60)
local lampLights = {}

local function attachLights()
    if not cityFolder then return end
    -- Find streetlamp-ish parts (downtown lampMesh placements). Tag any
    -- BasePart that's tall+thin in the city folder as a candidate.
    for _, p in ipairs(cityFolder:GetDescendants()) do
        if p:IsA("BasePart") and p.Size.Y < 8 and p.Size.X < 3 and p.Size.Z < 3
           and p:GetAttribute("Zone") == "downtown" and not p:FindFirstChildOfClass("PointLight") then
            local pl = Instance.new("PointLight", p)
            pl.Name = "NightGlow"
            pl.Color = Color3.fromRGB(255, 215, 150)  -- warm cream
            pl.Range = 22
            pl.Brightness = 0  -- driven by the cycle
            table.insert(lampLights, pl)
        end
    end
    -- Also add a small light to each downtown TALL building's top (window
    -- bands lit at night, dim during day).
    local count = 0
    for _, p in ipairs(cityFolder:GetChildren()) do
        if count >= 24 then break end
        if p:IsA("BasePart") and p.Size.Y > 80 and p:GetAttribute("Zone") == "downtown" then
            local pl = Instance.new("PointLight", p)
            pl.Name = "NightGlow"
            pl.Color = Color3.fromRGB(255, 220, 160)
            pl.Range = 50
            pl.Brightness = 0
            table.insert(lampLights, pl)
            count = count + 1
        end
    end
    print("[DayNightCycle v1] " .. #lampLights .. " window/lamp lights attached")
end

-- Wait for CityRebuild to finish placing buildings before tagging lights.
task.spawn(function()
    task.wait(8)
    attachLights()
end)

-- =====================================================================
-- MAIN CYCLE LOOP — advance ClockTime + interpolate properties + drive
-- night-glow brightness. Runs at 4Hz (cheap).
-- =====================================================================
local startT = os.clock()
local atm = Lighting:FindFirstChildOfClass("Atmosphere")

task.spawn(function()
    while true do
        task.wait(0.25)
        local elapsed = (os.clock() - startT) % CYCLE_SECONDS
        local hour = (elapsed / CYCLE_SECONDS) * 24
        Lighting.ClockTime = hour
        local p = interpolatedProps(hour)
        Lighting.Brightness        = p.brightness
        Lighting.OutdoorAmbient    = p.outdoor
        Lighting.Ambient           = p.ambient
        Lighting.ColorShift_Top    = p.shiftTop
        Lighting.ColorShift_Bottom = p.shiftBot
        Lighting.FogColor          = p.fogColor
        Lighting.FogStart          = p.fogStart
        Lighting.FogEnd            = p.fogEnd
        if atm then
            atm.Density = p.atmDensity
            atm.Decay   = p.atmDecay
        end
        -- Stars only show during night
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if sky then
            sky.StarCount = (hour < 5 or hour > 20) and 3000 or 0
        end
        -- Night glow ramp: 0 during 7-18, full during 20-5, ease in/out
        local glowB
        if hour >= 7 and hour <= 18 then glowB = 0
        elseif hour > 18 and hour < 20 then glowB = (hour - 18) / 2 * 1.5
        elseif hour < 7 and hour >= 5 then glowB = (7 - hour) / 2 * 1.5
        else glowB = 1.5 end
        for _, pl in ipairs(lampLights) do pl.Brightness = glowB end
    end
end)

print("[DayNightCycle v1] online — " .. CYCLE_SECONDS .. "s real time = 24 in-game hours")
