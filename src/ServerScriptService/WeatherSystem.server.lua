-- WeatherSystem.server.lua
-- Cycles Sunny / Rainy / Foggy / RedMist. Broadcasts state, applies bonuses.
-- Place in: ServerScriptService > WeatherSystem (Script)

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local function waitFor(g) while not _G[g] do task.wait() end return _G[g] end
local DataHandler = waitFor("KittyRaiserData")

local CurrentWeather = "Sunny"
local CurrentMultBonus = 1.0

local function pickWeather()
    local roll = math.random()
    local cum = 0
    for k, w in pairs(GameConfig.WEATHER_WEIGHTS) do
        cum = cum + w
        if roll <= cum then return k end
    end
    return "Sunny"
end

local function applyVisuals(weather)
    if weather == "Sunny" then
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1000
        Lighting.FogStart = 200
        Lighting.FogColor = Color3.fromRGB(180, 180, 200)
    elseif weather == "Rainy" then
        Lighting.ClockTime = 13
        Lighting.FogEnd = 400
        Lighting.FogStart = 50
        Lighting.FogColor = Color3.fromRGB(100, 100, 130)
    elseif weather == "Foggy" then
        Lighting.ClockTime = 18
        Lighting.FogEnd = 200
        Lighting.FogStart = 20
        Lighting.FogColor = Color3.fromRGB(220, 220, 220)
    elseif weather == "RedMist" then
        Lighting.ClockTime = 22
        Lighting.FogEnd = 250
        Lighting.FogStart = 30
        Lighting.FogColor = Color3.fromRGB(180, 0, 0)
    end
end

function _G.KittyRaiserGetWeatherMult()
    return CurrentMultBonus
end

local function setWeather(weather)
    CurrentWeather = weather
    CurrentMultBonus = (weather == "RedMist") and GameConfig.RED_MIST_CHAOS_MULT or 1.0
    applyVisuals(weather)
    Remotes.WeatherChanged:FireAllClients(weather)
    Remotes.EventBroadcast:FireAllClients(
        weather == "RedMist" and "RED MIST! 2x Chaos for "..GameConfig.RED_MIST_DURATION_MIN.." min!"
        or weather:upper(),
        weather
    )
end

task.spawn(function()
    while true do
        local weather = pickWeather()
        setWeather(weather)
        local dur = (weather == "RedMist") and GameConfig.RED_MIST_DURATION_MIN or GameConfig.WEATHER_CYCLE_MIN
        task.wait(dur * 60)
    end
end)

return true
