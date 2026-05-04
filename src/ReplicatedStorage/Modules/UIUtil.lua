-- UIUtil.lua  — shared polish helpers used by every client UI script.
-- Centralizes:
--   * text-size bounds so TextScaled doesn't blow up on small/huge screens
--   * a single DisplayOrder registry so overlays don't fight
--   * a uniform color palette so different UIs feel like the same game
--   * platform detection (phone / tablet / desktop / console)
--   * responsive modal/list helpers that clamp to the viewport
--   * standardized design tokens (corner radius, stroke, font, easing)

local UserInputService = game:GetService("UserInputService")
local GuiService       = game:GetService("GuiService")
local TweenService     = game:GetService("TweenService")

local UIUtil = {}

-- ============================================================
-- WARM-CARTOON COLOR PALETTE (single source — DO NOT recolor inline)
-- ============================================================
UIUtil.Palette = {
	-- Neutrals
	bgDark   = Color3.fromRGB(38, 26, 18),  -- darkest wood
	bgMid    = Color3.fromRGB(56, 40, 28),  -- panel back
	panel    = Color3.fromRGB(80, 55, 40),  -- bar back / button base
	hairline = Color3.fromRGB(110, 75, 45), -- wood-stain stroke
	-- Accents
	primary  = Color3.fromRGB(255, 200, 80),  -- amber (XP, sun)
	accent   = Color3.fromRGB(120, 200, 80),  -- moss (chaos, success)
	gem      = Color3.fromRGB(220, 130, 220), -- magenta (hell tokens)
	danger   = Color3.fromRGB(220, 80, 70),   -- terracotta (summon, dismiss)
	gold     = Color3.fromRGB(225, 175, 75),  -- premium / robux
	-- Text
	textHi   = Color3.fromRGB(255, 250, 240), -- on dark
	textLo   = Color3.fromRGB(80, 40, 20),    -- on light wood
	textMuted= Color3.fromRGB(180, 160, 140),
	stroke   = Color3.fromRGB(40, 25, 15),    -- text stroke on light
}

-- ============================================================
-- DESIGN TOKENS — standardize so the UI feels coherent
-- ============================================================
UIUtil.Token = {
	cornerSm   = UDim.new(0, 8),
	cornerMd   = UDim.new(0, 12),
	cornerLg   = UDim.new(0, 16),
	cornerPill = UDim.new(1, 0),
	strokeThin = 1,
	strokeReg  = 2,
	strokeBold = 3,
	-- Typography
	fontTitle  = Enum.Font.LuckiestGuy,   -- branded headers only (KITTYRAISER, sign)
	fontHeader = Enum.Font.GothamBlack,   -- modal titles, primary buttons
	fontLabel  = Enum.Font.GothamBold,    -- labels, button text
	fontBody   = Enum.Font.Gotham,        -- descriptions, list rows
	-- Easing presets
	easeIn     = TweenInfo.new(0.18, Enum.EasingStyle.Quad,  Enum.EasingDirection.In),
	easeOut    = TweenInfo.new(0.22, Enum.EasingStyle.Quad,  Enum.EasingDirection.Out),
	easeBack   = TweenInfo.new(0.28, Enum.EasingStyle.Back,  Enum.EasingDirection.Out),
	easeFade   = TweenInfo.new(0.4,  Enum.EasingStyle.Linear),
}

-- ============================================================
-- DISPLAY ORDER REGISTRY
-- ============================================================
UIUtil.DisplayOrder = {
	HUD             = 10,
	Minimap         = 12,
	KillFeed        = 20,
	Toast           = 30,
	Combo           = 35,
	ScreenFlash     = 40,
	Modal           = 60,   -- shop, leaderboard, perk, inventory
	DailyReward     = 70,
	Tutorial        = 80,
	Onboarding      = 90,
	PreSpawnLobby   = 100,
}

-- ============================================================
-- PLATFORM DETECTION (better than the old TouchEnabled-only check)
-- Returns one of: "phone", "tablet", "desktop", "console"
-- ============================================================
function UIUtil.platform()
	-- Console takes priority
	if GuiService:IsTenFootInterface() then return "console" end

	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local minDim = math.min(vp.X, vp.Y)
	local maxDim = math.max(vp.X, vp.Y)
	local touch = UserInputService.TouchEnabled
	local mouse = UserInputService.MouseEnabled
	local keyboard = UserInputService.KeyboardEnabled

	-- Tablets: touch enabled AND screen is large (>=960 min dimension or >=1280 max)
	if touch and (minDim >= 600 or maxDim >= 1024) then
		return "tablet"
	end
	-- Phone: touch and small
	if touch and not (mouse and keyboard) then
		return "phone"
	end
	-- Otherwise desktop
	return "desktop"
end

function UIUtil.isMobile()
	local p = UIUtil.platform()
	return p == "phone" or p == "tablet"
end

function UIUtil.isPhone()
	return UIUtil.platform() == "phone"
end

-- ============================================================
-- VIEWPORT-AWARE MODAL SIZING
-- Returns UDim2 size that's clamped to fit on the current viewport.
-- ============================================================
function UIUtil.viewportSize()
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

function UIUtil.modalSize(targetW, targetH, marginPx)
	marginPx = marginPx or 24
	local vp = UIUtil.viewportSize()
	local w = math.min(targetW, math.max(280, vp.X - marginPx * 2))
	local h = math.min(targetH, math.max(320, vp.Y - marginPx * 2 - 80))  -- leave room for top/bottom HUD bars
	return UDim2.new(0, w, 0, h)
end

-- Clamp a fixed-pixel offset so it stays inside the viewport.
function UIUtil.clampOffsetX(offset, minPad)
	minPad = minPad or 16
	local vp = UIUtil.viewportSize()
	-- Negative offsets (right-anchored): clamp to -(viewport - minPad)
	if offset < 0 then
		return math.max(offset, -(vp.X - minPad))
	end
	return math.min(offset, vp.X - minPad)
end

-- ============================================================
-- TEXT-SIZE BOUNDING
-- ============================================================
function UIUtil.boundText(label, minSize, maxSize)
	if not label then return end
	local existing = label:FindFirstChildOfClass("UITextSizeConstraint")
	local c = existing or Instance.new("UITextSizeConstraint")
	c.MinTextSize = minSize or 12
	c.MaxTextSize = maxSize or 36
	c.Parent = label
	return c
end

-- Named text presets so labels feel coherent across screens.
UIUtil.TextSize = {
	tiny   = function(l) return UIUtil.boundText(l, 10, 14) end,
	small  = function(l) return UIUtil.boundText(l, 12, 18) end,
	body   = function(l) return UIUtil.boundText(l, 14, 22) end,
	label  = function(l) return UIUtil.boundText(l, 14, 26) end,
	header = function(l) return UIUtil.boundText(l, 18, 36) end,
	hero   = function(l) return UIUtil.boundText(l, 28, 60) end,
}

-- ============================================================
-- POLISHED FRAME
-- ============================================================
function UIUtil.polishFrame(frame, opts)
	opts = opts or {}
	if not frame:FindFirstChildOfClass("UICorner") then
		local c = Instance.new("UICorner")
		c.CornerRadius = opts.corner or UIUtil.Token.cornerMd
		c.Parent = frame
	end
	if opts.gradient and not frame:FindFirstChildOfClass("UIGradient") then
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, opts.gradient[1]),
			ColorSequenceKeypoint.new(1, opts.gradient[2]),
		}
		g.Rotation = opts.gradientRotation or 90
		g.Parent = frame
	end
	if opts.stroke and not frame:FindFirstChildOfClass("UIStroke") then
		local s = Instance.new("UIStroke")
		s.Thickness = opts.strokeThickness or UIUtil.Token.strokeReg
		s.Color = opts.stroke
		s.Transparency = opts.strokeTransparency or 0.2
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = frame
	end
	return frame
end

-- ============================================================
-- TOAST
-- ============================================================
function UIUtil.makeToast(parent, text, color, duration)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 360, 0, 50)
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.BackgroundColor3 = color or UIUtil.Palette.bgMid
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.Parent = parent
	UIUtil.polishFrame(frame, {
		corner = UIUtil.Token.cornerSm,
		stroke = UIUtil.Palette.stroke,
		strokeThickness = UIUtil.Token.strokeThin,
		strokeTransparency = 0.4,
	})
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.fromOffset(10, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = UIUtil.Token.fontLabel
	label.TextColor3 = UIUtil.Palette.textHi
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = UIUtil.Palette.stroke
	label.TextScaled = true
	UIUtil.TextSize.body(label)
	label.Parent = frame

	frame.Position = UDim2.new(0.5, 0, 0, -60)
	TweenService:Create(frame, UIUtil.Token.easeBack,
		{Position = UDim2.new(0.5, 0, 0, 0)}):Play()

	task.delay(duration or 2.5, function()
		if not frame.Parent then return end
		TweenService:Create(frame, UIUtil.Token.easeFade,
			{BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, -20)}):Play()
		TweenService:Create(label, UIUtil.Token.easeFade,
			{TextTransparency = 1, TextStrokeTransparency = 1}):Play()
		task.wait(0.5)
		frame:Destroy()
	end)
	return frame
end

return UIUtil
