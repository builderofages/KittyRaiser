-- CatCharacterBuilder.server.lua  v6
-- Uses the REAL custom-uploaded cat meshes (mesh_cat_ear, mesh_cat_tail,
-- mesh_cat_head) loaded by MeshLoader.server.lua, instead of welded primitive
-- spheres. Falls back to primitive ears/tail if meshes failed to load.
--
-- Strategy still rides on Roblox's default R15 character (so movement,
-- animation, camera, jumping work natively), but the visible accessories
-- are real custom meshes that look like an actual cat.
--
-- Place in: ServerScriptService > CatCharacterBuilder. Auto-runs.

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = true

-- Ensure server creates SoundGroups so all sounds (server + client) can be
-- routed and the per-channel volume sliders in the settings menu work.
local AudioGroups
do
	local mods = ReplicatedStorage:WaitForChild("Modules", 5)
	local m = mods and mods:WaitForChild("AudioGroups", 5)
	if m then local ok, mod = pcall(require, m); if ok then AudioGroups = mod end end
end

local FUR_COLORS = {
	Color3.fromRGB(220, 130, 50),
	Color3.fromRGB(80, 60, 50),
	Color3.fromRGB(40, 40, 40),
	Color3.fromRGB(220, 220, 215),
	Color3.fromRGB(140, 130, 120),
	Color3.fromRGB(255, 200, 180),
}

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

-- Wait for MeshLoader to populate _G.KittyRaiserMeshes.
-- This may take a few seconds at server boot while InsertService loads each.
local function getMesh(name)
	local cache = _G.KittyRaiserMeshes
	if cache and cache[name] and cache[name].meshTemplate then
		return cache[name].meshTemplate
	end
	return nil
end

-- =====================================================================
-- BODY SCALES  (small, cat-like silhouette)
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
		local existing = humanoid:FindFirstChild(name)
		if existing and existing:IsA("NumberValue") then
			existing.Value = value
		end
	end
end

-- =====================================================================
-- TINTING  (BodyColors + direct .Color)
-- =====================================================================
local function tintCat(character, furColor)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end
	local bc = character:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors")
	bc.Parent = character
	local bcc = BrickColor.new(furColor)
	bc.HeadColor     = bcc
	bc.TorsoColor    = bcc
	bc.LeftArmColor  = bcc
	bc.RightArmColor = bcc
	bc.LeftLegColor  = bcc
	bc.RightLegColor = bcc
	for _, p in ipairs(character:GetDescendants()) do
		if p:IsA("BasePart") and not p:GetAttribute("CatAccessory") then
			p.Color = furColor
			p.Material = Enum.Material.SmoothPlastic
		end
	end
end

-- =====================================================================
-- EARS  (real mesh_cat_ear if available, primitive cone fallback)
-- =====================================================================
local function buildEars(head, furColor)
	local insideColor = Color3.fromRGB(255, 180, 200)
	local meshTemplate = getMesh("mesh_cat_ear")
	for _, side in ipairs({-1, 1}) do
		local ear
		if meshTemplate then
			ear = meshTemplate:Clone()
			ear.Name = "CatEar"
			ear.Size = Vector3.new(0.55, 0.85, 0.55)
			ear.Color = furColor
			ear.Material = Enum.Material.SmoothPlastic
			ear.CanCollide = false
			ear.Massless = true
			ear.Anchored = false
		else
			ear = Instance.new("Part")
			ear.Name = "CatEar"
			ear.Size = Vector3.new(0.45, 0.7, 0.18)
			ear.Color = furColor
			ear.Material = Enum.Material.SmoothPlastic
			ear.CanCollide = false
			ear.Massless = true
		end
		ear:SetAttribute("CatAccessory", true)
		ear.CFrame = head.CFrame
			* CFrame.new(side * 0.45, 0.55, 0)
			* CFrame.Angles(math.rad(-5), side * math.rad(8), side * math.rad(-3))
		ear.Parent = head
		local w = Instance.new("WeldConstraint")
		w.Part0 = head; w.Part1 = ear; w.Parent = ear

		-- Pink inner ear (always primitive — small detail, doesn't need a mesh)
		local inner = Instance.new("Part")
		inner.Name = "CatEarInner"
		inner.Size = Vector3.new(0.22, 0.38, 0.06)
		inner.Color = insideColor
		inner.Material = Enum.Material.SmoothPlastic
		inner.CanCollide = false
		inner.Massless = true
		inner:SetAttribute("CatAccessory", true)
		inner.CFrame = ear.CFrame * CFrame.new(0, 0, -0.08)
		inner.Parent = head
		local iw = Instance.new("WeldConstraint")
		iw.Part0 = ear; iw.Part1 = inner; iw.Parent = inner
	end
end

-- =====================================================================
-- TAIL  (real mesh_cat_tail if available, primitive cylinder fallback)
-- =====================================================================
local function buildTail(character, furColor)
	local anchor = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not anchor then return end
	local meshTemplate = getMesh("mesh_cat_tail")
	local tail
	if meshTemplate then
		tail = meshTemplate:Clone()
		tail.Name = "CatTail"
		tail.Size = Vector3.new(0.45, 0.45, 1.8)
		tail.Color = furColor
		tail.Material = Enum.Material.SmoothPlastic
		tail.CanCollide = false
		tail.Massless = true
		tail.Anchored = false
	else
		tail = Instance.new("Part")
		tail.Name = "CatTail"
		tail.Size = Vector3.new(0.35, 0.35, 1.6)
		tail.Color = furColor
		tail.Material = Enum.Material.SmoothPlastic
		tail.CanCollide = false
		tail.Massless = true
	end
	tail:SetAttribute("CatAccessory", true)
	tail.CFrame = anchor.CFrame * CFrame.new(0, 0.2, 0.7) * CFrame.Angles(math.rad(35), 0, 0)
	tail.Parent = character
	local w = Instance.new("WeldConstraint")
	w.Part0 = anchor; w.Part1 = tail; w.Parent = tail
end

-- =====================================================================
-- FACE (kitty face SurfaceGui)
-- =====================================================================
local function buildFace(head)
	for _, c in ipairs(head:GetChildren()) do
		if c:IsA("Decal") and c.Name == "face" then c:Destroy() end
	end
	local sg = head:FindFirstChild("CatFaceGui")
	if sg then sg:Destroy() end
	sg = Instance.new("SurfaceGui")
	sg.Name = "CatFaceGui"
	sg.Face = Enum.NormalId.Front
	sg.PixelsPerStud = 100
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
	dot(0.34, 0.45, 0.18, 0.18, Color3.fromRGB(255, 255, 255))
	dot(0.66, 0.45, 0.18, 0.18, Color3.fromRGB(255, 255, 255))
	dot(0.34, 0.45, 0.05, 0.14, Color3.fromRGB(50, 200, 100))
	dot(0.66, 0.45, 0.05, 0.14, Color3.fromRGB(50, 200, 100))
	dot(0.5, 0.62, 0.07, 0.05, Color3.fromRGB(255, 130, 140))
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
-- SPAWN CHIME (uses real spawn_chime asset)
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

-- Looping background ambient music. Created ONCE per server in SoundService
-- so all players hear the same loop. Routed to Music channel.
local function ensureCityAmbient()
	local SoundService = game:GetService("SoundService")
	if SoundService:FindFirstChild("CityAmbient") then return end
	if not AssetIds.has("city_ambient") then return end
	local s = Instance.new("Sound")
	s.Name = "CityAmbient"
	s.SoundId = AssetIds.city_ambient
	s.Looped = true
	s.Volume = 0.6
	if AudioGroups then AudioGroups.assign(s, "Music") end
	s.Parent = SoundService
	s:Play()
end
task.spawn(ensureCityAmbient)

-- =====================================================================
-- DECORATE
-- =====================================================================
local function decorateCharacter(player, character)
	local hum  = character:WaitForChild("Humanoid", 5); if not hum then return end
	local head = character:WaitForChild("Head", 5);     if not head then return end

	local fc = player:GetAttribute("FurColor")
	local color
	if typeof(fc) == "Color3" then color = fc
	else color = FUR_COLORS[math.random(1, #FUR_COLORS)]
		player:SetAttribute("FurColor", color) end

	pcall(setCatBodyScales, hum)
	pcall(tintCat, character, color)
	pcall(buildEars, head, color)
	pcall(buildTail, character, color)
	pcall(buildFace, head)
	pcall(buildNameTag, player, head)
	pcall(playSpawnChime, character)

	hum.WalkSpeed = 18
	hum.JumpPower = 55

	character:SetAttribute("KittyCat", true)
	character:SetAttribute("FurColor", color)
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

-- =====================================================================
-- LOBBY -> CHARACTER
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
		pcall(function() player:LoadCharacter() end)
	end)
end)

print("[CatCharacterBuilder v6] using real mesh assets when available")
