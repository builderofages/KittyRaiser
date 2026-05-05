-- MusicSystem.server.lua  v1 — loops between 5 chaotic-cat music tracks
-- Plays in SoundService at the Music group. Cycles to next track when current ends.
-- Volume controlled by SettingsMenu music slider (via AudioGroups module).
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetIds   = require(ReplicatedStorage.Modules.AssetIds)
local AudioGroups = require(ReplicatedStorage.Modules.AudioGroups)

-- Music track keys in priority/cycle order. Will skip any with rbxassetid://0.
local TRACKS = {
    "music_track1_chaos_jazz",
    "music_track2_funky_alley_chase",
    "music_track3_uptempo_8bit_groove",
    "music_track4_cartoon_heist_riff",
    "music_track5_street_vendor_swing",
}

local sound -- current playing
local trackIndex = 1

local function pickNext()
    -- find next track with valid AssetId
    for i = 1, #TRACKS do
        trackIndex = trackIndex % #TRACKS + 1
        local key = TRACKS[trackIndex]
        if AssetIds.has(key) then return AssetIds[key], key end
    end
    return nil, nil
end

local function startTrack()
    local id, key = pickNext()
    if not id then
        warn("[MusicSystem] no valid music tracks in AssetIds (all are rbxassetid://0)")
        return
    end
    if sound then sound:Destroy() end
    sound = Instance.new("Sound")
    sound.Name = "BackgroundMusic"
    sound.SoundId = id
    sound.Volume = 0.55
    sound.Looped = false
    AudioGroups.assign(sound, "Music")
    sound.Parent = SoundService
    sound:Play()
    print("[MusicSystem] now playing: " .. key)
    sound.Ended:Once(function()
        task.wait(2 + math.random() * 3)  -- short gap between tracks
        startTrack()
    end)
end

-- Boot: small delay so other systems load first
task.spawn(function()
    task.wait(8)
    startTrack()
end)

print("[MusicSystem v1] online — will cycle 5 chaotic-cat tracks")
