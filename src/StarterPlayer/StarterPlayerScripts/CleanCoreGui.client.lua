-- CleanCoreGui.client.lua
-- Hide unused Roblox CoreGui elements that would clutter the UI.
-- Kept enabled: PlayerList (so leaderstats show), Chat, Health.

local StarterGui = game:GetService("StarterGui")

local DISABLED = {
    Enum.CoreGuiType.Backpack,        -- no tools/items in this game
    Enum.CoreGuiType.EmotesMenu,      -- replaced by our own EmoteWheel
}

for _, kind in ipairs(DISABLED) do
    pcall(function() StarterGui:SetCoreGuiEnabled(kind, false) end)
end

-- Keep PlayerList visible (leaderstats display).
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, true) end)
