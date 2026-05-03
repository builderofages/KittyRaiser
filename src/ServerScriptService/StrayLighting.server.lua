-- StrayLighting.server.lua  v2 — single source of lighting truth.
-- Tuned down from the previous "hazy-purple smudge" defaults so the world is
-- readable. Cyberpunk-night vibe but with proper contrast and sane fog.

local Lighting = game:GetService("Lighting")

Lighting.Technology = Enum.Technology.Future
Lighting.Brightness = 2.4
Lighting.Ambient = Color3.fromRGB(60, 50, 80)
Lighting.OutdoorAmbient = Color3.fromRGB(110, 95, 140)
Lighting.EnvironmentDiffuseScale = 0.55
Lighting.EnvironmentSpecularScale = 0.65
Lighting.ClockTime = 19.0
Lighting.GeographicLatitude = 41.5
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.35

local function ensure(cls, props)
	local fx = Lighting:FindFirstChildOfClass(cls)
	if not fx then fx = Instance.new(cls); fx.Parent = Lighting end
	for k, v in pairs(props) do pcall(function() fx[k] = v end) end
	return fx
end

ensure("BloomEffect",           { Intensity = 1.4, Size = 18, Threshold = 1.7 })
ensure("ColorCorrectionEffect", { Saturation = 0.10, Brightness = 0.0, Contrast = 0.12,
                                  TintColor = Color3.fromRGB(245, 240, 250) })
ensure("SunRaysEffect",         { Intensity = 0.10, Spread = 0.6 })
-- DepthOfField removed: was making the city blurry and ugly.
-- BlurEffect removed: cinematic blur causes nausea on movement.

local atm = Lighting:FindFirstChildOfClass("Atmosphere")
if not atm then atm = Instance.new("Atmosphere"); atm.Parent = Lighting end
atm.Density = 0.20    -- was 0.45 — way too foggy
atm.Offset  = 0.10
atm.Color   = Color3.fromRGB(140, 130, 170)
atm.Decay   = Color3.fromRGB(80,  60, 110)
atm.Glare   = 0.20
atm.Haze    = 1.0

-- Mark Lighting as already configured so CityRebuild can skip its own pass.
Lighting:SetAttribute("KittyLightingConfigured", true)

print("[StrayLighting v2] applied")
