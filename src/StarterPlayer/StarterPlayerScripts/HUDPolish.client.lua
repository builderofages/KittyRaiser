-- HUDPolish.client.lua  v2 — surgical, not blanket.
-- The previous version slapped a purple gradient + pink stroke on EVERY frame
-- in the HUD — modal close buttons, leaderboard rows, lock overlays, cooldown
-- overlays — and made the whole UI look like a single uniform purple smudge.
--
-- This version only polishes top-level bars and primary buttons, and respects
-- existing UIGradient / UIStroke that scripts have already added.

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Names we WILL polish (anything else is left alone).
local POLISH_BARS = {
	TopBar = true,
	BottomBar = true,
}
local POLISH_BUTTONS = {
	SummonButton = true,
	ShopButton = true, InventoryButton = true,
	RebirthButton = true, LeaderboardButton = true,
}

local function isPrankBtn(inst)
	return typeof(inst) == "Instance" and inst:IsA("TextButton") and inst.Name:sub(1, 6) == "Prank_"
end

local function ensureGradient(frame, top, bottom, rotation)
	if frame:FindFirstChildOfClass("UIGradient") then return end
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, top),
		ColorSequenceKeypoint.new(1, bottom),
	}
	g.Rotation = rotation or 90
	g.Parent = frame
end

local function ensureStroke(frame, color, thickness, transparency)
	if frame:FindFirstChildOfClass("UIStroke") then return end
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2
	s.Color = color
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = frame
end

local function polishOne(inst)
	if not (inst:IsA("Frame") or inst:IsA("TextButton") or inst:IsA("ImageButton")) then return end

	if POLISH_BARS[inst.Name] then
		-- Warm wood-stained bar with subtle amber edge
		ensureGradient(inst,
			Color3.fromRGB(85, 60, 40),
			Color3.fromRGB(50, 35, 25), 90)
		ensureStroke(inst, Color3.fromRGB(255, 200, 120), 1, 0.4)
		return
	end

	if POLISH_BUTTONS[inst.Name] then
		-- Glossy variant of existing color
		ensureGradient(inst,
			Color3.fromRGB(255, 255, 255):Lerp(inst.BackgroundColor3, 0.35),
			inst.BackgroundColor3, 90)
		ensureStroke(inst, Color3.fromRGB(80, 50, 25), 2, 0.3)
		return
	end

	if isPrankBtn(inst) then
		-- Prank icon buttons: warm leather/wood gradient
		ensureGradient(inst,
			Color3.fromRGB(95, 70, 50),
			Color3.fromRGB(60, 45, 30), 90)
		ensureStroke(inst, Color3.fromRGB(220, 150, 80), 2, 0.2)
		return
	end
end

local function polishHUD()
	local hud = playerGui:WaitForChild("MainHUD", 30)
	if not hud then return end
	for _, inst in ipairs(hud:GetDescendants()) do polishOne(inst) end
	hud.DescendantAdded:Connect(polishOne)
end

task.spawn(polishHUD)
print("[HUDPolish v2] surgical polish applied (bars + primary buttons + prank btns)")
