-- ChatTags.server.lua
-- Adds a [L<level>] [👑<rebirths>] tag to chat messages so players can see
-- each other's progression in chat. Uses the modern TextChatService API.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedUtil = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("SharedUtil"))
local DataHandler = SharedUtil.waitForGlobal("KittyRaiserData", 30)
if not DataHandler then return end

-- TextChatService may not be enabled on legacy chat games; guard.
if not TextChatService.OnIncomingMessage then
    print("[ChatTags] TextChatService not available; skipping (legacy chat?)")
    return
end

TextChatService.OnIncomingMessage = function(message)
    local props = Instance.new("TextChatMessageProperties")
    if not message.TextSource then return props end
    local userId = message.TextSource.UserId
    local player = Players:GetPlayerByUserId(userId)
    if not player then return props end
    local d = DataHandler.getData(player)
    if not d then return props end
    local prefix = ("<font color=\"#%s\">[L%d %s]</font> "):format(
        "FFD700",
        d.level or 1,
        ((d.rebirths or 0) > 0) and ("R" .. d.rebirths) or ""
    )
    props.PrefixText = prefix .. (message.PrefixText or "")
    return props
end

print("[ChatTags] online")
