-- SpawnEnforcer.server.lua  v2 — true safety net only.
-- Previously this script was racing CatCharacterBuilder and spawning a separate
-- broken custom rig, which is why the player ended up with an oversized,
-- immovable cat. Now this script does NOTHING unless a player has been alive
-- for 15 seconds without a Humanoid character — in which case it falls back
-- to LoadCharacter() (the standard Roblox path).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[SpawnEnforcer v2] passive safety mode")

-- Make sure CharacterAutoLoads is ON (CatCharacterBuilder needs it).
Players.CharacterAutoLoads = true

local function ensureAlive(player)
	-- Wait until they've had a chance to spawn naturally.
	task.wait(15)
	if not player.Parent then return end
	local char = player.Character
	if char and char:FindFirstChildOfClass("Humanoid") then return end
	-- Fallback: ask Roblox to load the default character.
	local ok = pcall(function() player:LoadCharacter() end)
	if not ok then
		warn("[SpawnEnforcer v2] LoadCharacter failed for " .. player.Name)
	else
		print("[SpawnEnforcer v2] forced LoadCharacter for " .. player.Name)
	end
end

local function setup(player)
	task.spawn(function()
		pcall(ensureAlive, player)
	end)
end

Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do setup(p) end

-- Forward spawn customization requests to LoadCharacter (CatCharacterBuilder
-- already handles fur color via an attribute set on its own listener; this is a
-- redundancy in case CatCharacterBuilder is missing).
task.spawn(function()
	local Modules = ReplicatedStorage:WaitForChild("Modules", 10)
	local RemoteEvents = Modules and Modules:WaitForChild("RemoteEvents", 5)
	if not RemoteEvents then return end
	local ok, Remotes = pcall(require, RemoteEvents)
	if not ok or not Remotes or not Remotes.RequestSpawnCustomization then return end
	-- Don't double-respawn: CatCharacterBuilder is the authoritative listener.
	-- We just log to confirm the event flows through.
	Remotes.RequestSpawnCustomization.OnServerEvent:Connect(function(player)
		print("[SpawnEnforcer v2] saw RequestSpawnCustomization from " .. player.Name)
	end)
end)
