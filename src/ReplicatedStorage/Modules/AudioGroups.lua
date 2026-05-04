-- AudioGroups.lua  — central audio mixer.
-- Creates three SoundGroups under SoundService: Music / SFX / UI.
-- Each Sound created in the codebase should set .SoundGroup to one of these
-- via AudioGroups.assign(sound, "SFX") so per-channel volume sliders in the
-- settings menu actually work.

local SoundService = game:GetService("SoundService")

local AudioGroups = {}

local function ensureGroup(name)
    local g = SoundService:FindFirstChild(name)
    if not g then
        g = Instance.new("SoundGroup")
        g.Name = name
        g.Volume = 1
        g.Parent = SoundService
    end
    return g
end

AudioGroups.Music = ensureGroup("MusicGroup")
AudioGroups.SFX   = ensureGroup("SFXGroup")
AudioGroups.UI    = ensureGroup("UIGroup")

-- assign(sound, "Music"|"SFX"|"UI") — set the sound's SoundGroup
function AudioGroups.assign(sound, channel)
    if not sound or not sound:IsA("Sound") then return end
    local g = AudioGroups[channel]
    if g then sound.SoundGroup = g end
end

function AudioGroups.setChannelVolume(channel, vol)
    local g = AudioGroups[channel]
    if g then g.Volume = math.clamp(vol, 0, 1) end
end

function AudioGroups.getChannelVolume(channel)
    local g = AudioGroups[channel]
    return g and g.Volume or 1
end

return AudioGroups
