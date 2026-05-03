-- StrayLighting.server.lua — canonical lighting script.
-- This is the SINGLE source of truth for Lighting properties. Previously
-- CityRebuild also set Lighting.Brightness/Ambient/Atmosphere etc. which
-- created an order-dependent race; CityRebuild now only owns geometry.
-- Place in: ServerScriptService > StrayLighting (Script).

local Lighting = game:GetService("Lighting")

Lighting.Technology = Enum.Technology.Future
Lighting.Brightness = 3.0
Lighting.Ambient = Color3.fromRGB(70, 35, 110)
Lighting.OutdoorAmbient = Color3.fromRGB(95, 60, 145)
Lighting.EnvironmentDiffuseScale = 0.7
Lighting.EnvironmentSpecularScale = 0.9
Lighting.ClockTime = 19.5
Lighting.GeographicLatitude = 41.5
Lighting.GlobalShadows = true

local function ensure(cls, props)
    local fx = Lighting:FindFirstChildOfClass(cls)
    if not fx then fx = Instance.new(cls); fx.Parent = Lighting end
    for k, v in pairs(props) do pcall(function() fx[k] = v end) end
    return fx
end

ensure("BloomEffect",           {Intensity = 2.6, Size = 24, Threshold = 1.55})
ensure("ColorCorrectionEffect", {Saturation = 0.30, Brightness = 0.04, Contrast = 0.16,
                                 TintColor = Color3.fromRGB(255, 240, 230)})
ensure("DepthOfFieldEffect",    {FocusDistance = 60, InFocusRadius = 25,
                                 FarIntensity = 0.06, NearIntensity = 0.02})
ensure("SunRaysEffect",         {Intensity = 0.22, Spread = 0.7})
ensure("BlurEffect",            {Size = 0})

local atm = Lighting:FindFirstChildOfClass("Atmosphere")
if not atm then atm = Instance.new("Atmosphere"); atm.Parent = Lighting end
-- Density was 0.45 + an extra 0.28 from CityRebuild = opaque fog wall ~25 studs.
-- 0.30 gives noir feel without choking visibility.
atm.Density = 0.30; atm.Offset = 0.22
atm.Color = Color3.fromRGB(95, 30, 150)
atm.Decay = Color3.fromRGB(60, 18, 100)
atm.Glare = 0.50; atm.Haze = 1.7

print("[StrayLighting] cyberpunk noir tuning applied (canonical)")
