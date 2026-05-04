-- ChatHider.client.lua
-- Suppresses the default Roblox chat UI during gameplay so it doesn't
-- overlap the HUD. We don't disable chat functionality; we just hide the
-- visible chat window/button. If you want chat re-enabled later, set
-- StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true).
--
-- Place in: StarterPlayer > StarterPlayerScripts > ChatHider (LocalScript)

local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

-- Belt-and-suspenders: hide the legacy chat coregui AND opt out of the
-- new TextChatService UI by setting GeneralChannelEnabled = false on the
-- default channel.
local function tryHide()
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    end)
    -- New TextChatService chat window
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local mainWindow = TextChatService:FindFirstChild("ChatWindowConfiguration")
            if mainWindow then mainWindow.Enabled = false end
            local mainInput = TextChatService:FindFirstChild("ChatInputBarConfiguration")
            if mainInput then mainInput.Enabled = false end
        end
    end)
end

tryHide()
-- Try again a moment later in case CoreGui hadn't initialized yet
task.delay(1, tryHide)
task.delay(3, tryHide)

print("[ChatHider] default chat UI hidden")
