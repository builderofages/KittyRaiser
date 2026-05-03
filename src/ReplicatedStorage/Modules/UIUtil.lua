-- UIUtil.lua  — shared polish helpers used by every client UI script.
-- Centralizes:
--   * text-size bounds so TextScaled doesn't blow up on small/huge screens
--   * a single DisplayOrder registry so overlays don't fight
--   * a uniform color palette so different UIs feel like the same game
--   * tiny "make a polished frame / button / label" helpers

local UIUtil = {}

-- ============================================================
-- COLOR PALETTE
-- ============================================================
UIUtil.Palette = {
	bgDark    = Color3.fromRGB(22, 16, 36),
	bgMid     = Color3.fromRGB(36, 24, 60),
	panel     = Color3.fromRGB(46, 30, 78),
	neonPink  = Color3.fromRGB(255, 80, 200),
	neonCyan  = Color3.fromRGB(80, 220, 255),
	gold      = Color3.fromRGB(255, 215, 0),
	green     = Color3.fromRGB(80, 220, 120),
	danger    = Color3.fromRGB(255, 80, 100),
	white     = Color3.fromRGB(245, 240, 250),
	muted     = Color3.fromRGB(160, 145, 190),
}

-- ============================================================
-- DISPLAY ORDER REGISTRY (single source of truth for overlay z-order)
-- Lower numbers render BELOW higher numbers.
-- ============================================================
UIUtil.DisplayOrder = {
	HUD             = 10,   -- main HUD bars/buttons
	KillFeed        = 20,   -- right-side prank feed
	Toast           = 30,   -- corner toast notifications
	Combo           = 35,   -- combo counter
	ScreenFlash     = 40,   -- damage / impact full-screen flash
	Modal           = 60,   -- shop, leaderboard, inventory
	DailyReward     = 70,   -- daily reward popup
	Tutorial        = 80,   -- in-game tutorial spotlight
	Onboarding      = 90,   -- first-time onboarding
	PreSpawnLobby   = 100,  -- spawn customization screen
}

-- ============================================================
-- TEXT-SIZE BOUNDING
-- ============================================================
function UIUtil.boundText(label, minSize, maxSize)
	if not label then return end
	-- Re-use existing constraint if present
	local existing = label:FindFirstChildOfClass("UITextSizeConstraint")
	local c = existing or Instance.new("UITextSizeConstraint")
	c.MinTextSize = minSize or 12
	c.MaxTextSize = maxSize or 36
	c.Parent = label
	return c
end

-- ============================================================
-- POLISHED FRAME (rounded, gradient, optional stroke)
-- ============================================================
function UIUtil.polishFrame(frame, opts)
	opts = opts or {}
	if not frame:FindFirstChildOfClass("UICorner") then
		local c = Instance.new("UICorner")
		c.CornerRadius = opts.corner or UDim.new(0, 12)
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
		s.Thickness = opts.strokeThickness or 2
		s.Color = opts.stroke
		s.Transparency = opts.strokeTransparency or 0.2
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = frame
	end
	return frame
end

-- ============================================================
-- TOAST: small auto-fading notification at top-center
-- ============================================================
function UIUtil.makeToast(parent, text, color, duration)
	local TweenService = game:GetService("TweenService")
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 360, 0, 50)
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.BackgroundColor3 = color or UIUtil.Palette.bgMid
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.Parent = parent
	UIUtil.polishFrame(frame, {
		corner = UDim.new(0, 10),
		stroke = Color3.new(0, 0, 0),
		strokeThickness = 1,
		strokeTransparency = 0.5,
	})
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.fromOffset(10, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextScaled = true
	UIUtil.boundText(label, 14, 22)
	label.Parent = frame

	-- Slide-in from above
	frame.Position = UDim2.new(0.5, 0, 0, -60)
	TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, 0, 0, 0)}):Play()

	-- Auto-fade
	task.delay(duration or 2.5, function()
		if not frame.Parent then return end
		TweenService:Create(frame, TweenInfo.new(0.4),
			{BackgroundTransparency = 1, Position = UDim2.new(0.5, 0, 0, -20)}):Play()
		TweenService:Create(label, TweenInfo.new(0.4),
			{TextTransparency = 1, TextStrokeTransparency = 1}):Play()
		task.wait(0.5)
		frame:Destroy()
	end)
	return frame
end

-- ============================================================
-- RESPONSIVE SIZING — clamp scale * pixel based on parent
-- ============================================================
function UIUtil.responsivePixel(basePx, screenSize)
	-- Treat 1280px as the design baseline; scale linearly between 0.7x and 1.4x
	local screenW = screenSize and screenSize.X or 1280
	local factor = math.clamp(screenW / 1280, 0.7, 1.4)
	return math.floor(basePx * factor)
end

return UIUtil
