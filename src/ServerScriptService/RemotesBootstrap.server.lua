-- RemotesBootstrap.server.lua
-- Materializes the RemoteEvents/RemoteFunctions folder via the canonical
-- RemoteEvents module, so it exists before any other script needs it.
-- The previous version created a *duplicate* set at ReplicatedStorage root,
-- which conflicted with the folder-based set used by every consumer.
-- Place in: ServerScriptService > RemotesBootstrap (Script). Auto-runs FIRST.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local count = 0
for _ in pairs(Remotes) do count = count + 1 end
print(("[RemotesBootstrap] %d remotes registered in ReplicatedStorage.RemoteEventsFolder"):format(count))
