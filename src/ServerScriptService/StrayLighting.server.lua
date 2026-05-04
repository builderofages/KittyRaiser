-- StrayLighting.server.lua  v3 — sunny cartoon-city daytime.
-- The previous neon-cyberpunk-noir theme was actively disliked. This is now a
-- warm, bright, friendly Saturday-morning-cartoon city: clear blue sky, golden
-- sunlight, soft shadows, a hint of haze. No purple, no DOF, no fog smudge.

local Lighting = game:GetService("Lighting")

Lighting.Technology = Enum.Technology.Future
Lighting.Brightness = 2.6
Lighting.Ambient = Color3.fromRGB(140, 130, 110)        -- warm light gray
Lighting.OutdoorAmbient = Color3.fromRGB(180, 175, 160) -- bright daylight
Lighting.EnvironmentDiffuseScale = 0.65
Lighting.EnvironmentSpecularScale = 0.50
Lighting.ClockTime = 13.0          -- early afternoon sun, high overhead
Lighting.GeographicLatitude = 25
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.30
Lighting.ColorShift_Top    = Color3.fromRGB(255, 240, 220)  -- warm sun tint
Lighting.ColorShift_Bottom = Color3.fromRGB(190, 200, 220)  -- cool sky bounce
Lighting.FogColor = Color3.fromRGB(220, 230, 240)
Lighting.FogStart = 600
Lighting.FogEnd = 2400

local function ensure(cls, props)
	local fx = Lighting:FindFirstChildOfClass(cls)
	if not fx then fx = Instance.new(cls); fx.Parent = Lighting end
	for k, v in pairs(props) do pcall(function() fx[k] = v end) end
	return fx
end

-- Subtle bloom for highlights (sunshine catching white surfaces)
ensure("BloomEffect", { Intensity = 0.5, Size = 18, Threshold = 1.85 })
-- Light color correction toward warm summer
ensure("ColorCorrectionEffect", {
	Saturation = 0.10,
	Brightness = 0.02,
	Contrast   = 0.06,
	TintColor  = Color3.fromRGB(255, 248, 235),
})
-- Sun rays at low intensity (bright day, not dramatic)
ensure("SunRaysEffect", { Intensity = 0.15, Spread = 0.4 })

-- Atmosphere: light haze for depth, NOT fog
local atm = Lighting:FindFirstChildOfClass("Atmosphere")
if not atm then atm = Instance.new("Atmosphere"); atm.Parent = Lighting end
atm.Density = 0.12
atm.Offset  = 0.05
atm.Color   = Color3.fromRGB(220, 225, 230)
atm.Decay   = Color3.fromRGB(150, 175, 200)
atm.Glare   = 0.05
atm.Haze    = 0.5

-- Optional sky (force a clear blue cartoon sky)
local sky = Lighting:FindFirstChildOfClass("Sky")
if not sky then sky = Instance.new("Sky"); sky.Parent = Lighting end
-- Use Roblox's default daytime sky textures (built-in, no asset id needed)
sky.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
sky.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
sky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
sky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
sky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
sky.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
sky.SunAngularSize = 8
sky.MoonAngularSize = 0
sky.StarCount = 0
sky.CelestialBodiesShown = true

Lighting:SetAttribute("KittyLightingConfigured", true)

print("[StrayLighting v3] sunny daytime cartoon-city theme applied")
