-- Minimap.client.lua  v2 — responsive top-right minimap with player + NPC dots.
-- Uses warm cartoon palette (no cyberpunk pink stroke). Auto-resizes when
-- viewport changes (mobile rotation / window resize).

local Players    = game:GetService("Players")
local Workspace  = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIUtil = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("UIUtil"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Smaller on phone, full size on desktop
local function pickSize()
	local p = UIUtil.platform()
	if p == "phone"  then return 130 end
	if p == "tablet" then return 160 end
	return 180
end

local SCALE = 0.18  -- world studs per pixel

local mm = Instance.new("ScreenGui")
mm.Name = "Minimap"
mm.IgnoreGuiInset = false
mm.ResetOnSpawn = false
mm.DisplayOrder = UIUtil.DisplayOrder.Minimap
mm.Parent = playerGui

local size = pickSize()
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(1, 0)
frame.Size = UDim2.new(0, size, 0, size)
frame.Position = UDim2.new(1, -16, 0, 96)  -- right edge minus 16px gutter
frame.BackgroundColor3 = UIUtil.Palette.bgDark
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 0
frame.Parent = mm
Instance.new("UICorner", frame).CornerRadius = UDim.new(1, 0)
local stroke = Instance.new("UIStroke", frame)
stroke.Thickness = UIUtil.Token.strokeBold
stroke.Color = UIUtil.Palette.hairline

-- Title above the minimap, anchored bottom-center
local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 1)
title.Size = UDim2.new(1, 0, 0, 18)
title.Position = UDim2.new(0.5, 0, 0, -4)
title.BackgroundTransparency = 1
title.Text = "MAP"
title.Font = UIUtil.Token.fontLabel
title.TextScaled = true
title.TextColor3 = UIUtil.Palette.textHi
title.TextStrokeTransparency = 0.4
title.TextStrokeColor3 = UIUtil.Palette.stroke
title.Parent = frame
UIUtil.TextSize.small(title)

-- Player dot — gold (you're the cat)
local self_dot = Instance.new("Frame")
self_dot.AnchorPoint = Vector2.new(0.5, 0.5)
self_dot.Size = UDim2.new(0, 8, 0, 8)
self_dot.Position = UDim2.new(0.5, 0, 0.5, 0)
self_dot.BackgroundColor3 = UIUtil.Palette.gold
self_dot.BorderSizePixel = 0
self_dot.Parent = frame
Instance.new("UICorner", self_dot).CornerRadius = UDim.new(1, 0)

-- Listen for viewport resize and re-pick size
local cam = workspace.CurrentCamera
if cam then
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local s = pickSize()
		frame.Size = UDim2.new(0, s, 0, s)
	end)
end

local function getOriginPos()
	local char = player.Character
	if char and char.PrimaryPart then return char.PrimaryPart.Position end
	return Vector3.new(0, 0, 0)
end

-- Update entity dots every 0.5s
local entityDots = {}
task.spawn(function()
	while mm.Parent do
		local origin = getOriginPos()
		local entities = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and p.Character and p.Character.PrimaryPart then
				table.insert(entities, {
					pos = p.Character.PrimaryPart.Position,
					color = UIUtil.Palette.accent,
					name = p.Name,
				})
			end
		end
		local crowd = Workspace:FindFirstChild("AmbientCrowd")
		if crowd then
			for _, npc in ipairs(crowd:GetChildren()) do
				if npc:IsA("Model") and npc.PrimaryPart then
					local d = (npc.PrimaryPart.Position - origin).Magnitude
					if d < 200 then
						table.insert(entities, {
							pos = npc.PrimaryPart.Position,
							color = UIUtil.Palette.textMuted,
							small = true,
						})
					end
				end
			end
		end
		local pnpcs = Workspace:FindFirstChild("PrankNPCs")
		if pnpcs then
			for _, npc in ipairs(pnpcs:GetChildren()) do
				if npc:IsA("Model") and npc.PrimaryPart then
					table.insert(entities, {
						pos = npc.PrimaryPart.Position,
						color = UIUtil.Palette.danger,
						small = true,
					})
				end
			end
		end
		-- Cops chasing me: pulse-bright red dot
		local cops = Workspace:FindFirstChild("Cops")
		if cops then
			for _, cop in ipairs(cops:GetChildren()) do
				if cop:IsA("Model") and cop.PrimaryPart and cop:GetAttribute("ChasingUserId") == player.UserId then
					-- Pulse magnitude based on time
					local pulse = 0.5 + math.abs(math.sin(os.clock() * 4)) * 0.5
					table.insert(entities, {
						pos = cop.PrimaryPart.Position,
						color = Color3.fromRGB(255, 80, 80):Lerp(Color3.fromRGB(255, 220, 80), 1 - pulse),
						small = false,  -- larger so it stands out
						isCop = true,
					})
				end
			end
		end
		local frameSize = frame.AbsoluteSize.X
		local half = frameSize / 2
		for i, ent in ipairs(entities) do
			local dot = entityDots[i]
			if not dot then
				dot = Instance.new("Frame")
				dot.AnchorPoint = Vector2.new(0.5, 0.5)
				dot.BorderSizePixel = 0
				Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
				dot.Parent = frame
				entityDots[i] = dot
			end
			local relX = (ent.pos.X - origin.X) * SCALE
			local relZ = (ent.pos.Z - origin.Z) * SCALE
			dot.Visible = (math.abs(relX) < half and math.abs(relZ) < half)
			local sz = ent.small and 5 or 7
			dot.Size = UDim2.new(0, sz, 0, sz)
			dot.Position = UDim2.new(0.5, relX, 0.5, relZ)
			dot.BackgroundColor3 = ent.color
		end
		for i = #entities + 1, #entityDots do
			if entityDots[i] then entityDots[i].Visible = false end
		end
		task.wait(0.5)
	end
end)

print("[Minimap v2] responsive minimap, warm palette")
