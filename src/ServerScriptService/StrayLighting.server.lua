-- StrayLighting.server.lua — Grok's exact Stray cyberpunk noir tuning
-- Place in: ServerScriptService > StrayLighting (Script). Auto-runs.

local Lighting = game:GetService("Lighting")

Lighting.Technology = Enum.Technology.Future
Lighting.Brightness = 2.8
Lighting.Ambient = Color3.fromRGB(40, 20, 80)
Lighting.OutdoorAmbient = Color3.fromRGB(70, 40, 110)
Lighting.EnvironmentDiffuseScale = 0.8
Lighting.EnvironmentSpecularScale = 1.2
Lighting.ClockTime = 19.5
Lighting.GeographicLatitude = 41.5
Lighting.GlobalShadows = true

local function ensure(cls, props)
  local fx = Lighting:FindFirstChildOfClass(cls)
  if not fx then fx = Instance.new(cls); fx.Parent = Lighting end
  for k, v in pairs(props) do pcall(function() fx[k] = v end) end
  return fx
end

ensure("BloomEffect",          {Intensity = 3.2, Size = 24, Threshold = 1.4})
ensure("ColorCorrectionEffect",{Saturation = 0.35, Brightness = 0.08, Contrast = 0.15, TintColor = Color3.fromRGB(255, 240, 230)})
ensure("DepthOfFieldEffect",   {FocusDistance = 60, InFocusRadius = 25, FarIntensity = 0.08, NearIntensity = 0.02})
ensure("SunRaysEffect",        {Intensity = 0.25, Spread = 0.8})
ensure("BlurEffect",           {Size = 0})  -- 0 by default; ramp up for cinematics

local atm = Lighting:FindFirstChildOfClass("Atmosphere")
if not atm then atm = Instance.new("Atmosphere", Lighting) end
atm.Density = 0.45; atm.Offset = 0.25
atm.Color = Color3.fromRGB(80, 30, 140)
atm.Decay = Color3.fromRGB(50, 15, 90)
atm.Glare = 0.55; atm.Haze = 2.0

print("[StrayLighting] Grok's cyberpunk noir tuning applied")
