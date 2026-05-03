-- MusicSystem.client.lua
-- Background music with weather/event-aware crossfading. Respects player's
-- settingsMusicOn / settingsMusicVolume from saved data.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local player = Players.LocalPlayer

-- Roblox public free music tracks (curated). Replace with custom IDs once uploaded.
local TRACKS = {
    chill   = "rbxassetid://1846458016",  -- public lo-fi loop
    intense = "rbxassetid://1839907000",
    eerie   = "rbxassetid://1842437342",
}

local active = nil
local musicOn = true
local musicVolume = 0.5

local function makeSound(id)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Looped = true
    s.Volume = 0
    s.Parent = SoundService
    return s
end

local function setMusic(trackKey)
    if not musicOn then
        if active then TweenService:Create(active, TweenInfo.new(0.5), {Volume = 0}):Play() end
        return
    end
    local id = TRACKS[trackKey] or TRACKS.chill
    if active and active.SoundId == id then
        TweenService:Create(active, TweenInfo.new(0.5), {Volume = musicVolume}):Play()
        return
    end
    if active then
        local fadeOut = TweenService:Create(active, TweenInfo.new(1.0), {Volume = 0})
        fadeOut:Play()
        fadeOut.Completed:Connect(function()
            if active then active:Destroy() end
        end)
    end
    active = makeSound(id)
    active:Play()
    TweenService:Create(active, TweenInfo.new(1.0), {Volume = musicVolume}):Play()
end

Remotes.UpdatePlayerData.OnClientEvent:Connect(function(d)
    musicOn = d.settingsMusicOn ~= false
    if d.settingsMusicVolume ~= nil then
        musicVolume = math.clamp(d.settingsMusicVolume, 0, 1)
    end
    if active then
        TweenService:Create(active, TweenInfo.new(0.3),
            {Volume = musicOn and musicVolume or 0}):Play()
    end
end)

Remotes.WeatherChanged.OnClientEvent:Connect(function(weather)
    if weather == "RedMist" then setMusic("intense")
    elseif weather == "Foggy" or weather == "Rainy" then setMusic("eerie")
    else setMusic("chill") end
end)

-- Kick off default track
task.delay(2, function() setMusic("chill") end)

print("[MusicSystem] online")
