-- CatCharacterBuilder.server.lua  v7 — primitive-only decoration.
-- v6 used uploaded mesh_cat_ear / mesh_cat_tail / SurfaceGui face. Playtest
-- (v3.35) showed a "maroon poofy blob" obscuring the cat: SurfaceGui face
-- doesn't render reliably on R15 MeshPart Heads; uploaded ear/tail meshes
-- may not respect Size and may extend beyond their bounding box.
--
-- v7: build EVERYTHING out of primitives (Ball / Cone / Cylinder Parts) welded
-- to standard R15 parts. Eyes / nose / mouth / whiskers are real welded Parts
-- so they're visible from any camera angle. Mesh assets remain in AssetIds
-- but are NOT used here until they're verified geometrically sane (set the
-- player attribute "UseCustomMeshes" to true to opt in).
--
-- Place in: ServerScriptService > CatCharacterBuilder. Auto-runs.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = true

local AudioGroups
do
	local m = ReplicatedStorage:WaitForChild("Modules", 5)
	local a = m and m:WaitForChild("AudioGroups", 5)
	if a then local ok, mod = pcall(require, a); if ok then AudioGroups = mod end end
end

local AssetIds
do
	local m = ReplicatedStorage:WaitForChild("Modules", 5)
	local a = m and m:WaitForChild("AssetIds", 5)
	if a then local ok, mod = pcall(require, a); if ok then AssetIds = mod end end
	if not AssetIds then
		AssetIds = setmetatable({}, {__index = function() return "rbxassetid://0" end})
		AssetIds.has = function() return false end
	end
end

local FUR_COLORS = {
	Color3.fromRGB(220, 130, 50),  -- orange tabby
	Color3.fromRGB(80, 60, 50),    -- brown
	Color3.fromRGB(40, 40, 40),    -- black
	Color3.fromRGB(220, 220, 215), -- white
	Color3.fromRGB(140, 130, 120), -- grey tabby
	Color3.fromRGB(255, 200, 180), -- cream
}

-- =====================================================================
-- HELPERS
-- =====================================================================
local function newPart(props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	return p
end

local function weldTo(parent, child)
	local w = Instance.new("WeldConstraint")
	w.Part0 = parent; w.Part1 = child
	w.Parent = child
end

-- Mark cat-decoration parts so the tinting loop skips them
local function markAccessory(p) p:SetAttribute("CatAccessory", true) end

-- =====================================================================
-- BODY SCALES
-- =====================================================================
local function setCatBodyScales(humanoid)
	local scales = {
		BodyDepthScale  = 1.10,
		BodyWidthScale  = 0.90,
		BodyHeightScale = 0.65,
		HeadScale       = 1.20,
		BodyTypeScale   = 0.0,
		ProportionScale = 0.20,
	}
	for name, value in pairs(scales) do
		local nv = humanoid:FindFirstChild(name)
		if nv and nv:IsA("NumberValue") then nv.Value = value end
	end
end

-- =====================================================================
-- TINTING — strip clothing, recolor every BasePart that isn't accessory
-- =====================================================================
local function tintCat(character, furColor)
	-- Aggressive cosmetics strip — Shirt/Pants/ShirtGraphic/Decal-on-shirt
	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end

	-- If a multi-color skin is equipped (Calico/Tuxedo/etc), CosmeticHandler
	-- already set BodyColors per-limb. Don't overwrite with single-color tint.
	-- (CosmeticHandler sets MultiColorSkin attribute when it applies one.)
	if character:GetAttribute("MultiColorSkin") then
		-- Still strip clothing + tint accessories below, but skip the
		-- per-part .Color overwrite that would flatten the multi-color look.
		return
	end

	-- BodyColors (legacy) for any R6 fallback
	local bc = character:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors")
	bc.Parent = character
	local bcc = BrickColor.new(furColor)
	bc.HeadColor       = bcc
	bc.TorsoColor      = bcc
	bc.LeftArmColor    = bcc
	bc.RightArmColor   = bcc
	bc.LeftLegColor    = bcc
	bc.RightLegColor   = bcc

	-- Direct .Color tint for MeshPart-based R15 + classic R6 parts.
	-- Skip CatAccessory parts (we handle those separately so inner-ear pink etc stays).
	for _, p in ipairs(character:GetDescendants()) do
		if p:IsA("BasePart") and not p:GetAttribute("CatAccessory") then
			-- Don't recolor HumanoidRootPart (transparent) or the actual Head (we
			-- want the Head fur color too — it's visible).
			p.Color = furColor
			p.Material = Enum.Material.SmoothPlastic
		end
	end
end

-- =====================================================================
-- EARS — primitive cone shape per ear, with pink inner ear.
-- =====================================================================
local function buildEars(head, furColor)
	local insideColor = Color3.fromRGB(255, 180, 200)
	for _, side in ipairs({-1, 1}) do
		local ear = newPart({
			Name = "CatEar",
			Size = Vector3.new(0.45, 0.7, 0.18),
			Color = furColor,
		})
		markAccessory(ear)
		ear.CFrame = head.CFrame
			* CFrame.new(side * 0.5, 0.55, 0)
			* CFrame.Angles(math.rad(-5), side * math.rad(8), side * math.rad(-3))
		ear.Parent = head
		weldTo(head, ear)

		-- Pink inner ear
		local inner = newPart({
			Name = "CatEarInner",
			Size = Vector3.new(0.28, 0.45, 0.06),
			Color = insideColor,
		})
		markAccessory(inner)
		inner.CFrame = ear.CFrame * CFrame.new(0, 0, -0.08)
		inner.Parent = head
		weldTo(ear, inner)
	end
end

-- =====================================================================
-- TAIL — primitive cylinder welded to upper torso, curving up + tip ball.
-- =====================================================================
local function buildTail(character, furColor)
	local anchor = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not anchor then return end

	local tail = newPart({
		Name = "CatTail",
		Size = Vector3.new(0.35, 0.35, 1.6),
		Color = furColor,
	})
	markAccessory(tail)
	tail.CFrame = anchor.CFrame * CFrame.new(0, 0.2, 0.7) * CFrame.Angles(math.rad(35), 0, 0)
	tail.Parent = character
	weldTo(anchor, tail)

	local tip = newPart({
		Name = "CatTailTip",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.4, 0.4, 0.4),
		Color = furColor,
	})
	markAccessory(tip)
	tip.CFrame = tail.CFrame * CFrame.new(0, 0, 1.0)
	tip.Parent = character
	weldTo(tail, tip)
end

-- =====================================================================
-- FACE — REAL welded primitive parts (eyes/nose/mouth/whiskers) so they're
-- visible from every angle and on any head MeshPart. No SurfaceGui.
-- =====================================================================
local function buildFace(head)
	-- Strip Roblox's default face Decal so it doesn't conflict
	for _, c in ipairs(head:GetChildren()) do
		if c:IsA("Decal") and (c.Name == "face" or c.Name == "Face") then
			c:Destroy()
		end
	end
	-- Strip any prior CatFaceGui from older versions
	local oldGui = head:FindFirstChild("CatFaceGui")
	if oldGui then oldGui:Destroy() end
	-- Strip any prior face-feature welded parts (defensive — prevents orphan
	-- duplicates if buildFace runs more than once on the same character).
	local PRIOR_NAMES = { CatEye=true, CatPupil=true, CatNose=true, CatMouth=true, CatWhisker=true }
	for _, c in ipairs(head:GetChildren()) do
		if PRIOR_NAMES[c.Name] then c:Destroy() end
	end

	-- Pull head size for relative placement
	local headHalfZ = head.Size.Z * 0.5
	local headHalfY = head.Size.Y * 0.5
	-- Place face features on the FRONT face of the head (negative Z in head's local space)

	-- Eyes (white sclera + green slit pupil)
	for _, sx in ipairs({-1, 1}) do
		local sclera = newPart({
			Name = "CatEye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.32, 0.32, 0.32),
			Color = Color3.fromRGB(255, 255, 255),
			Material = Enum.Material.SmoothPlastic,
		})
		markAccessory(sclera)
		sclera.CFrame = head.CFrame * CFrame.new(sx * 0.32, 0.1, -headHalfZ * 0.85)
		sclera.Parent = head
		weldTo(head, sclera)

		-- Pupil (vertical slit) - smaller part offset slightly forward
		local pupil = newPart({
			Name = "CatPupil",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.12, 0.26, 0.12),
			Color = Color3.fromRGB(60, 220, 110),
			Material = Enum.Material.Neon,
		})
		markAccessory(pupil)
		pupil.CFrame = sclera.CFrame * CFrame.new(0, 0, -0.08)
		pupil.Parent = head
		weldTo(sclera, pupil)
	end

	-- Nose (pink ball)
	local nose = newPart({
		Name = "CatNose",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.18, 0.14, 0.14),
		Color = Color3.fromRGB(255, 130, 150),
		Material = Enum.Material.SmoothPlastic,
	})
	markAccessory(nose)
	nose.CFrame = head.CFrame * CFrame.new(0, -0.18, -headHalfZ * 0.95)
	nose.Parent = head
	weldTo(head, nose)

	-- Mouth (two thin parts forming a small smile under the nose)
	for _, sx in ipairs({-1, 1}) do
		local mouth = newPart({
			Name = "CatMouth",
			Size = Vector3.new(0.18, 0.04, 0.04),
			Color = Color3.fromRGB(60, 30, 30),
			Material = Enum.Material.SmoothPlastic,
		})
		markAccessory(mouth)
		mouth.CFrame = head.CFrame
			* CFrame.new(sx * 0.08, -0.34, -headHalfZ * 0.95)
			* CFrame.Angles(0, 0, sx * math.rad(20))
		mouth.Parent = head
		weldTo(head, mouth)
	end

	-- Whiskers (3 per side, thin cylinders extending outward from cheeks)
	for _, sx in ipairs({-1, 1}) do
		for _, yOff in ipairs({-0.05, -0.18, -0.31}) do
			local whisker = newPart({
				Name = "CatWhisker",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.55, 0.03, 0.03),
				Color = Color3.fromRGB(40, 40, 40),
				Material = Enum.Material.SmoothPlastic,
			})
			markAccessory(whisker)
			whisker.CFrame = head.CFrame
				* CFrame.new(sx * 0.55, yOff, -headHalfZ * 0.85)
				* CFrame.Angles(0, 0, 0)
				-- Cylinder long-axis is X; rotate to point outward from face
			whisker.Parent = head
			weldTo(head, whisker)
		end
	end
end

-- =====================================================================
-- NAME TAG
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
	local c = Instance.new("UITextSizeConstraint", l); c.MinTextSize = 14; c.MaxTextSize = 24
end

-- =====================================================================
-- SPAWN CHIME + AMBIENT
-- =====================================================================
local function playSpawnChime(character)
	if not AssetIds.has("spawn_chime") then return end
	local head = character:FindFirstChild("Head")
	local s = Instance.new("Sound")
	s.SoundId = AssetIds.spawn_chime
	s.Volume = 0.7
	if AudioGroups then AudioGroups.assign(s, "UI") end
	s.Parent = head or character
	s:Play()
	game:GetService("Debris"):AddItem(s, 4)
end

local function ensureCityAmbient()
	local SoundService = game:GetService("SoundService")
	local TweenService = game:GetService("TweenService")
	if SoundService:FindFirstChild("CityAmbient") then return end
	if not AssetIds.has("city_ambient") then return end
	local s = Instance.new("Sound")
	s.Name = "CityAmbient"
	s.SoundId = AssetIds.city_ambient
	s.Looped = true
	s.Volume = 0
	if AudioGroups then AudioGroups.assign(s, "Music") end
	s.Parent = SoundService
	s:Play()
	TweenService:Create(s, TweenInfo.new(2.0, Enum.EasingStyle.Quad), {Volume = 0.6}):Play()
end
task.spawn(ensureCityAmbient)

-- =====================================================================
-- DECORATE
-- =====================================================================
local function decorateCharacter(player, character)
	local hum  = character:WaitForChild("Humanoid", 5); if not hum then return end
	local head = character:WaitForChild("Head", 5);     if not head then return end

	-- Wait one extra frame so HumanoidDescription's default Shirt/Pants exist
	-- and we can strip them BEFORE we tint.
	task.wait(0.05)

	local fc = player:GetAttribute("FurColor")
	local color
	if typeof(fc) == "Color3" then color = fc
	else color = FUR_COLORS[math.random(1, #FUR_COLORS)]
		player:SetAttribute("FurColor", color) end

	pcall(setCatBodyScales, hum)
	pcall(tintCat, character, color)
	pcall(buildFace, head)         -- BEFORE ears so face wins z-order
	pcall(buildEars, head, color)
	pcall(buildTail, character, color)
	pcall(buildNameTag, player, head)
	pcall(playSpawnChime, character)

	hum.WalkSpeed = 18
	hum.JumpPower = 55

	character:SetAttribute("KittyCat", true)
	character:SetAttribute("FurColor", color)

	print(("[CatCharacterBuilder v7] decorated %s as cat (color=%s)"):format(
		player.Name, tostring(color)))
end

local function setupPlayer(player)
	if player.Character then decorateCharacter(player, player.Character) end
	player.CharacterAdded:Connect(function(character)
		task.wait(0.1)
		decorateCharacter(player, character)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end

-- Fur-color tween: if a player's FurColor attribute changes mid-game (skin
-- equip etc.), smoothly interpolate body + accessory colors.
local TweenService = game:GetService("TweenService")
local function watchFurChanges(player)
	player:GetAttributeChangedSignal("FurColor"):Connect(function()
		local newColor = player:GetAttribute("FurColor")
		if typeof(newColor) ~= "Color3" then return end
		local char = player.Character
		if not char then return end
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then
				-- Tint everything that's not face / inner-ear / mouth / whiskers
				if not p:GetAttribute("CatAccessory") then
					TweenService:Create(p, TweenInfo.new(0.6), {Color = newColor}):Play()
				elseif p.Name == "CatEar" or p.Name == "CatTail" or p.Name == "CatTailTip" then
					TweenService:Create(p, TweenInfo.new(0.6), {Color = newColor}):Play()
				end
			end
		end
	end)
end
Players.PlayerAdded:Connect(watchFurChanges)
for _, p in ipairs(Players:GetPlayers()) do watchFurChanges(p) end

-- =====================================================================
-- LOBBY -> CHARACTER
-- IMPORTANT: there are TWO copies of RequestSpawnCustomization in the
-- DataModel — one at ReplicatedStorage root (from RemotesBootstrap, the
-- bootstrap script that fires first) and one under
-- ReplicatedStorage.Modules.RemoteEvents (created by the RemoteEvents
-- module). Whichever the client fires must match what the server listens
-- on, or the fur color from the lobby never lands.
-- We listen on BOTH to be safe.
-- =====================================================================
local function handleSpawnRequest(player, data)
	if typeof(data) == "table" and typeof(data.furColor) == "table" then
		local r = tonumber(data.furColor[1]) or 220
		local g = tonumber(data.furColor[2]) or 130
		local b = tonumber(data.furColor[3]) or 50
		local color = Color3.fromRGB(r, g, b)
		player:SetAttribute("FurColor", color)
		player:SetAttribute("SkinName", tostring(data.skinName or ""))
		print(("[CatCharacterBuilder v8] %s requested fur RGB(%d,%d,%d) name=%s"):format(
			player.Name, r, g, b, tostring(data.skinName or "")))
	else
		print(("[CatCharacterBuilder v8] %s requested spawn with no fur data"):format(player.Name))
	end
	pcall(function() player:LoadCharacter() end)
end

task.spawn(function()
	-- Listener 1: module copy (ReplicatedStorage.Modules.RemoteEvents)
	local Modules = ReplicatedStorage:WaitForChild("Modules", 10)
	local RemoteEvents = Modules and Modules:WaitForChild("RemoteEvents", 5)
	if RemoteEvents then
		local ok, Remotes = pcall(require, RemoteEvents)
		if ok and Remotes and Remotes.RequestSpawnCustomization then
			Remotes.RequestSpawnCustomization.OnServerEvent:Connect(handleSpawnRequest)
			print("[CatCharacterBuilder v8] listening on Modules.RemoteEvents")
		end
	end
	-- Listener 2: root copy (RemotesBootstrap)
	local rootEvent = ReplicatedStorage:WaitForChild("RequestSpawnCustomization", 10)
	if rootEvent and rootEvent:IsA("RemoteEvent") then
		rootEvent.OnServerEvent:Connect(handleSpawnRequest)
		print("[CatCharacterBuilder v8] listening on ReplicatedStorage root")
	end
end)

print("[CatCharacterBuilder v7] online — primitive-only decoration")
