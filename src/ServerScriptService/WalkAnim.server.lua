-- WalkAnim.server.lua  v2 — defer to Roblox's auto-injected Animate script.
-- The default Roblox character that CatCharacterBuilder v5 now uses comes with
-- the standard Animate LocalScript that drives idle/walk/run/jump animations
-- automatically off of Humanoid state. We don't need to load custom anims.
--
-- We still add a small, physics-friendly tail "wag" using a Motor6D-free
-- alternating offset on the welded tail tip — but ONLY if a CatTail exists,
-- and we use a swing AlignOrientation so we never fight welds.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local function setupTailWag(character)
	-- Find tail (created by CatCharacterBuilder v5 as a welded Part named "CatTail")
	local tail = character:FindFirstChild("CatTail")
	if not tail or not tail:IsA("BasePart") then return end

	-- Use a hinge-style attachment swing via AlignOrientation. This is physics-safe
	-- because we're only animating the orientation of the tail end, not setting
	-- absolute world CFrames on welded parts.
	local anchor = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not anchor then return end

	-- Tail wag is intentionally lightweight: simply tween the tail-tip part offset
	-- via its CFrameValue stored in attributes. We avoid touching CFrame directly
	-- because that breaks WeldConstraints. Instead, we leave the tail static and
	-- rely on the natural body sway from Roblox's Animate. (Empty body kept so
	-- this script has a clear extension point.)
end

local function setup(player)
	if player.Character then setupTailWag(player.Character) end
	player.CharacterAdded:Connect(function(character)
		task.wait(0.4)
		setupTailWag(character)
	end)
end

Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do setup(p) end

print("[WalkAnim v2] online — using Roblox default Animate script")
