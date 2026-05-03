-- CatCharacterBuilder.server.lua  v5
-- Strategy: use Roblox's default R15 character (so movement, animation, camera, jump,
-- network ownership all "just work") and DECORATE it into a cat with:
--   - cat fur tint on body parts
--   - ear MeshParts welded to head
--   - tail MeshParts welded to torso
--   - cat face decal
--   - body scaling that gives a cat-like silhouette
--   - PROPORTIONS that are sensible (not oversized!)
-- This replaces the v4 "build a custom welded model" approach which broke movement
-- because of non-standard HumanoidRootPart sizing and welded-part hacks.
--
-- Place in: ServerScriptService > CatCharacterBuilder. Auto-runs.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- IMPORTANT: keep auto-load ON. Roblox spawns the character normally, we just decorate.
Players.CharacterAutoLoads = true

local FUR_COLORS = {
	Color3.fromRGB(220, 130, 50),  -- orange tabby
	Color3.fromRGB(80, 60, 50),    -- brown
	Color3.fromRGB(40, 40, 40),    -- black
	Color3.fromRGB(220, 220, 215), -- white
	Color3.fromRGB(140, 130, 120), -- grey tabby
	Color3.fromRGB(255, 200, 180), -- cream
}

-- =====================================================================
-- Body sizing: small + cute, matches the cat-feel without being huge.
-- BodyTypeScale = 0 disables the avatar's built-in body type so our scales
-- apply directly. Heights/depths sum to a compact silhouette.
-- =====================================================================
local function setCatBodyScales(humanoid)
	local scales = {
		BodyDepthScale  = 1.20,
		BodyWidthScale  = 0.95,
		BodyHeightScale = 0.65,  -- short and round
		HeadScale       = 1.20,  -- big head, cat-like
		BodyTypeScale   = 0.0,
		ProportionScale = 0.25,
	}
	for name, value in pairs(scales) do
		local existing = humanoid:FindFirstChild(name)
		if existing and existing:IsA("NumberValue") then
			existing.Value = value
		end
	end
end

-- =====================================================================
-- Tinting: recolor any character part to fur color.
-- Use BodyColors instance (R15 has one) so it applies cleanly.
-- =====================================================================
local function tintCat(character, furColor)
	-- Strip any clothing/shirt/pants/t-shirt that bundles bring in.
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end

	-- Recolor via BodyColors so it matches every limb consistently.
	local bc = character:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors")
	bc.Parent = character
	local bcc = BrickColor.new(furColor)
	bc.HeadColor       = bcc
	bc.TorsoColor      = bcc
	bc.LeftArmColor    = bcc
	bc.RightArmColor   = bcc
	bc.LeftLegColor    = bcc
	bc.RightLegColor   = bcc

	-- Direct color too, in case the rig uses MeshParts instead of legacy parts.
	for _, p in ipairs(character:GetDescendants()) do
		if p:IsA("BasePart") then
			-- skip parts we want to keep distinct (eyes/nose/accessories) by attribute
			if not p:GetAttribute("CatAccessory") then
				p.Color = furColor
				p.Material = Enum.Material.SmoothPlastic
			end
		end
	end
end

-- =====================================================================
-- Cat ears (welded to head)
-- =====================================================================
local function buildEars(head, furColor)
	local insideColor = Color3.fromRGB(255, 180, 200)
	for _, off in ipairs({ Vector3.new(-0.45, 0.55, 0), Vector3.new(0.45, 0.55, 0) }) do
		local ear = Instance.new("Part")
		ear.Name = "CatEar"
		ear.Size = Vector3.new(0.45, 0.7, 0.18)
		ear.Color = furColor
		ear.Material = Enum.Material.SmoothPlastic
		ear.CanCollide = false
		ear.Massless = true
		ear:SetAttribute("CatAccessory", true)

		local sx = (off.X < 0) and -math.rad(8) or math.rad(8)
		ear.CFrame = head.CFrame * CFrame.new(off) * CFrame.Angles(math.rad(-5), sx, 0)
		ear.Parent = head

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = ear
		weld.Parent = ear

		-- Inner ear (pink)
		local inner = Instance.new("Part")
		inner.Name = "CatEarInner"
		inner.Size = Vector3.new(0.25, 0.4, 0.05)
		inner.Color = insideColor
		inner.Material = Enum.Material.SmoothPlastic
		inner.CanCollide = false
		inner.Massless = true
		inner:SetAttribute("CatAccessory", true)
		inner.CFrame = ear.CFrame * CFrame.new(0, 0, -0.1)
		inner.Parent = head
		local iw = Instance.new("WeldConstraint")
		iw.Part0 = ear; iw.Part1 = inner; iw.Parent = inner
	end
end

-- =====================================================================
-- Cat tail (welded to upper torso, hangs from back)
-- =====================================================================
local function buildTail(character, furColor)
	-- Anchor point: prefer UpperTorso (R15) then Torso (R6).
	local anchor = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not anchor then return end

	local tail = Instance.new("Part")
	tail.Name = "CatTail"
	tail.Size = Vector3.new(0.35, 0.35, 1.6)
	tail.Color = furColor
	tail.Material = Enum.Material.SmoothPlastic
	tail.CanCollide = false
	tail.Massless = true
	tail:SetAttribute("CatAccessory", true)

	-- Position behind torso, angled up
	tail.CFrame = anchor.CFrame * CFrame.new(0, 0.2, 0.7) * CFrame.Angles(math.rad(35), 0, 0)
	tail.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = tail
	weld.Parent = tail

	-- Tail tip (slightly bigger ball at end)
	local tip = Instance.new("Part")
	tip.Name = "CatTailTip"
	tip.Shape = Enum.PartType.Ball
	tip.Size = Vector3.new(0.4, 0.4, 0.4)
	tip.Color = furColor
	tip.Material = Enum.Material.SmoothPlastic
	tip.CanCollide = false
	tip.Massless = true
	tip:SetAttribute("CatAccessory", true)
	tip.CFrame = tail.CFrame * CFrame.new(0, 0, 1.0)
	tip.Parent = character
	local tw = Instance.new("WeldConstraint")
	tw.Part0 = tail; tw.Part1 = tip; tw.Parent = tip
end

-- =====================================================================
-- Cat face: replace default face decal with a custom kitty face
-- Built via simple SurfaceGui because we don't have a custom asset id.
-- =====================================================================
local function buildFace(head)
	-- remove default decals
	for _, c in ipairs(head:GetChildren()) do
		if c:IsA("Decal") and c.Name == "face" then
			c:Destroy()
		end
	end

	local sg = head:FindFirstChild("CatFaceGui")
	if sg then sg:Destroy() end
	sg = Instance.new("SurfaceGui")
	sg.Name = "CatFaceGui"
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 100
	sg.AlwaysOnTop = false
	sg.LightInfluence = 1
	sg.Adornee = head
	sg.Parent = head

	local function dot(x, y, w, h, color)
		local f = Instance.new("Frame")
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(w, h)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.Parent = sg
		Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
		return f
	end

	-- eyes (white sclera + green vertical pupil)
	local leftEye = dot(0.34, 0.45, 0.18, 0.18, Color3.fromRGB(255, 255, 255))
	local rightEye = dot(0.66, 0.45, 0.18, 0.18, Color3.fromRGB(255, 255, 255))
	local lp = dot(0.34, 0.45, 0.05, 0.14, Color3.fromRGB(50, 200, 100))
	local rp = dot(0.66, 0.45, 0.05, 0.14, Color3.fromRGB(50, 200, 100))
	-- nose
	dot(0.5, 0.62, 0.07, 0.05, Color3.fromRGB(255, 130, 140))
	-- mouth (small : '>' shape via two thin frames)
	local m1 = Instance.new("Frame")
	m1.AnchorPoint = Vector2.new(0.5, 0.5)
	m1.Position = UDim2.fromScale(0.45, 0.72)
	m1.Size = UDim2.fromScale(0.07, 0.012)
	m1.Rotation = 25
	m1.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
	m1.BorderSizePixel = 0
	m1.Parent = sg
	local m2 = m1:Clone()
	m2.Position = UDim2.fromScale(0.55, 0.72)
	m2.Rotation = -25
	m2.Parent = sg
end

-- =====================================================================
-- Floating display name (above head)
-- =====================================================================
local function buildNameTag(player, head)
	if head:FindFirstChild("CatNameTag") then return end
	local g = Instance.new("BillboardGui")
	g.Name = "CatNameTag"
	g.Size = UDim2.new(0, 200, 0, 50)
	g.StudsOffset = Vector3.new(0, 2.4, 0)
	g.AlwaysOnTop = true
	g.Parent = head
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = player.DisplayName
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(255, 255, 255)
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.Parent = g
end

-- =====================================================================
-- Apply everything to a freshly-spawned character.
-- =====================================================================
local function decorateCharacter(player, character)
	local hum = character:WaitForChild("Humanoid", 5)
	if not hum then return end

	-- Wait until parts exist
	local head = character:WaitForChild("Head", 5)
	if not head then return end

	-- Pick fur color (attribute set by lobby, or random)
	local fc = player:GetAttribute("FurColor")
	local color
	if typeof(fc) == "Color3" then
		color = fc
	else
		color = FUR_COLORS[math.random(1, #FUR_COLORS)]
		player:SetAttribute("FurColor", color)
	end

	-- Body scale + tint + ears + tail + face + name
	pcall(setCatBodyScales, hum)
	pcall(tintCat, character, color)
	pcall(buildEars, head, color)
	pcall(buildTail, character, color)
	pcall(buildFace, head)
	pcall(buildNameTag, player, head)

	-- Defaults that "feel" right for a cat. Do NOT modify HipHeight: R15
	-- default is 2.0 and changing it makes the cat sink into the floor.
	hum.WalkSpeed = 18
	hum.JumpPower = 55

	-- Mark the character as a cat so other systems can detect
	character:SetAttribute("KittyCat", true)
	character:SetAttribute("FurColor", color)

	print("[CatCharacterBuilder v5] decorated " .. player.Name .. " as cat")
end

local function setupPlayer(player)
	if player.Character then
		decorateCharacter(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		-- Wait a frame for default parts to appear
		task.wait(0.1)
		decorateCharacter(player, character)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end

-- =====================================================================
-- Listen for spawn customization request from PreSpawnLobby
-- =====================================================================
task.spawn(function()
	local Modules = ReplicatedStorage:WaitForChild("Modules", 10)
	local RemoteEvents = Modules and Modules:WaitForChild("RemoteEvents", 5)
	if not RemoteEvents then return end
	local ok, Remotes = pcall(require, RemoteEvents)
	if not ok or not Remotes or not Remotes.RequestSpawnCustomization then return end

	Remotes.RequestSpawnCustomization.OnServerEvent:Connect(function(player, data)
		if typeof(data) == "table" and typeof(data.furColor) == "table" then
			local r = tonumber(data.furColor[1]) or 220
			local g = tonumber(data.furColor[2]) or 130
			local b = tonumber(data.furColor[3]) or 50
			player:SetAttribute("FurColor", Color3.fromRGB(r, g, b))
			player:SetAttribute("SkinName", tostring(data.skinName or ""))
		end
		-- LoadCharacter respawns the player; CharacterAdded fires and we decorate.
		pcall(function() player:LoadCharacter() end)
	end)
	print("[CatCharacterBuilder v5] listening for RequestSpawnCustomization")
end)

print("[CatCharacterBuilder v5] online — Roblox-native character + cat decoration")
