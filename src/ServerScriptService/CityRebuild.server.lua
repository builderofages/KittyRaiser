-- CityRebuild.server.lua  v6 — sunny daytime cartoon city.
-- Uses the real uploaded meshes (mesh_skyscraper, mesh_brownstone, mesh_taxi,
-- mesh_hydrant, mesh_trashcan, mesh_mailbox) to populate the world. Texture
-- assets (asphalt, brick, concrete, grass) decorate ground + buildings. NO neon.

local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local InsertService    = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[CityRebuild v6] booting...")

local AssetIds
do
	local mods = ReplicatedStorage:FindFirstChild("Modules")
	local m = mods and mods:FindFirstChild("AssetIds")
	if m then local ok, mod = pcall(require, m); if ok then AssetIds = mod end end
	if not AssetIds then
		AssetIds = setmetatable({}, {__index = function() return "rbxassetid://0" end})
		AssetIds.has = function() return false end
	end
end

-- Defer lighting to StrayLighting (single source of truth).
if not Lighting:GetAttribute("KittyLightingConfigured") then task.wait(0.5) end

-- =====================================================================
-- KILL OLD CYBERPUNK ASSETS
-- =====================================================================
for _, name in ipairs({"CyberpunkCity", "CyberCity", "ToolboxCity", "Lowpoly", "LowPoly", "CityTiles"}) do
	local o = Workspace:FindFirstChild(name)
	while o do o:Destroy(); o = Workspace:FindFirstChild(name) end
end
for _, p in ipairs(Workspace:GetDescendants()) do
	if p:IsA("BasePart") and p.Material == Enum.Material.Neon then
		-- Skip player parts/character parts
		if not p:FindFirstAncestorWhichIsA("Model") or not p:FindFirstAncestorWhichIsA("Model"):FindFirstChildOfClass("Humanoid") then
			pcall(function() p:Destroy() end)
		end
	end
end

-- =====================================================================
-- GROUND  (warm-grey asphalt with grass at edges)
-- =====================================================================
local ground = Workspace:FindFirstChild("KittyGround")
if not ground then
	ground = Instance.new("Part")
	ground.Name = "KittyGround"
	ground.Anchored = true; ground.CanCollide = true
	ground.Size = Vector3.new(4000, 4, 4000)
	ground.Position = Vector3.new(0, -2, 0)
	ground.Material = Enum.Material.Asphalt
	ground.Color = Color3.fromRGB(95, 90, 85)
	ground.TopSurface = Enum.SurfaceType.Smooth
	ground.Parent = Workspace
end
if AssetIds.has("asphalt") then
	-- Tiled asphalt texture
	local tex = ground:FindFirstChild("AsphaltTex") or Instance.new("Texture")
	tex.Name = "AsphaltTex"
	tex.Texture = AssetIds.asphalt
	tex.Face = Enum.NormalId.Top
	tex.StudsPerTileU = 32
	tex.StudsPerTileV = 32
	tex.Parent = ground
end

-- =====================================================================
-- SPAWN
-- =====================================================================
for _, sp in ipairs(Workspace:GetDescendants()) do
	if sp:IsA("SpawnLocation") then sp:Destroy() end
end
local spawn = Instance.new("SpawnLocation")
spawn.Name = "MainSpawn"
spawn.Anchored = true; spawn.CanCollide = true
spawn.Size = Vector3.new(8, 1, 8)
spawn.CFrame = CFrame.new(0, 5, 24)
spawn.Material = Enum.Material.SmoothPlastic
spawn.Transparency = 1
spawn.Parent = Workspace

-- =====================================================================
-- HELPER: get a cloneable mesh template from MeshLoader
-- =====================================================================
local function getMesh(name)
	local cache = _G.KittyRaiserMeshes
	if cache and cache[name] and cache[name].meshTemplate then
		return cache[name].meshTemplate
	end
	return nil
end

local cityFolder = Workspace:FindFirstChild("CartoonCity") or Instance.new("Folder", Workspace)
cityFolder.Name = "CartoonCity"
cityFolder:ClearAllChildren()

-- =====================================================================
-- SKYLINE  (real meshes if loaded, textured fallback if not)
-- =====================================================================
local function placeBuilding(meshTemplate, cf, sizeY, color, fallbackBox)
	local p
	if meshTemplate then
		p = meshTemplate:Clone()
		p.Anchored = true; p.CanCollide = true
		p.Size = Vector3.new(sizeY * 0.45, sizeY, sizeY * 0.45)
		p.Color = color
		p.Material = Enum.Material.Brick
		p.Reflectance = 0
		p:PivotTo(cf)
	else
		p = fallbackBox(cf, sizeY, color)
	end
	p.Parent = cityFolder
	return p
end

local function fallbackBuildingBox(cf, sizeY, color)
	local b = Instance.new("Part")
	b.Anchored = true; b.CanCollide = true
	b.Size = Vector3.new(sizeY * 0.55, sizeY, sizeY * 0.55)
	b.Color = color
	b.Material = Enum.Material.Brick
	b.TopSurface = Enum.SurfaceType.Smooth
	b:PivotTo(cf)
	-- Apply brick OR concrete texture if available
	if AssetIds.has("brick") then
		for _, face in ipairs({Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
			local t = Instance.new("Texture", b)
			t.Texture = AssetIds.brick
			t.Face = face
			t.StudsPerTileU = 8
			t.StudsPerTileV = 8
		end
	end
	-- Window stripes (warm yellow lit windows)
	for floor = 1, math.floor(sizeY / 6) - 1 do
		local stripe = Instance.new("Part")
		stripe.Anchored = true; stripe.CanCollide = false
		stripe.Size = Vector3.new(b.Size.X * 0.95, 1.6, b.Size.Z * 0.95)
		stripe.Position = b.Position + Vector3.new(0, -sizeY/2 + floor * 6, 0)
		stripe.Material = Enum.Material.SmoothPlastic
		stripe.Color = Color3.fromRGB(255, 220, 150)
		stripe.Transparency = 0.15
		stripe.Parent = cityFolder
	end
	return b
end

-- Daytime brownstone palette (NOT cyberpunk neon)
local BUILDING_COLORS = {
	Color3.fromRGB(170, 110, 80),   -- warm brown brick
	Color3.fromRGB(190, 175, 150),  -- sandstone
	Color3.fromRGB(140, 100, 75),   -- darker brick
	Color3.fromRGB(210, 195, 175),  -- limestone
	Color3.fromRGB(160, 130, 100),  -- adobe
	Color3.fromRGB(200, 160, 130),  -- terracotta
}

task.spawn(function()
	-- Wait briefly for MeshLoader to populate cache.
	for _ = 1, 30 do
		if _G.KittyRaiserMeshes then break end
		task.wait(0.5)
	end

	local skyMesh = getMesh("mesh_skyscraper")
	local brownMesh = getMesh("mesh_brownstone")
	local rng = Random.new(73)
	local SP = 220

	for gx = -3, 3 do
		for gz = -3, 3 do
			if math.abs(gx) > 0 or math.abs(gz) > 0 then
				local cx = gx * SP + rng:NextInteger(-30, 30)
				local cz = gz * SP + rng:NextInteger(-30, 30)
				local h  = rng:NextInteger(60, 180)
				local color = BUILDING_COLORS[rng:NextInteger(1, #BUILDING_COLORS)]
				local cf = CFrame.new(cx, h/2 + 1, cz)
				local pickMesh = (rng:NextNumber() < 0.5) and skyMesh or brownMesh
				placeBuilding(pickMesh, cf, h, color, fallbackBuildingBox)
			end
		end
	end
	print("[CityRebuild v6] skyline placed (48 buildings, real meshes when available)")
end)

-- =====================================================================
-- STREET PROPS  (taxi / hydrant / mailbox / trashcan)
-- =====================================================================
task.spawn(function()
	for _ = 1, 30 do
		if _G.KittyRaiserMeshes then break end
		task.wait(0.5)
	end
	local rng = Random.new(91)
	local taxiMesh   = getMesh("mesh_taxi")
	local hydrantMesh = getMesh("mesh_hydrant")
	local mailMesh   = getMesh("mesh_mailbox")
	local trashMesh  = getMesh("mesh_trashcan")

	-- Place props at intersections / sidewalks of the grid
	local PROP_COUNT = 60
	local placed = 0
	for _ = 1, PROP_COUNT do
		local px = rng:NextInteger(-700, 700)
		local pz = rng:NextInteger(-700, 700)
		-- Don't crash into the spawn area
		if math.sqrt(px * px + (pz - 24)^2) < 24 then continue end
		local pick = rng:NextNumber()
		local mesh, sizeY, color
		if pick < 0.18 and taxiMesh then
			mesh = taxiMesh; sizeY = 3.5; color = Color3.fromRGB(255, 200, 0)  -- yellow taxi
		elseif pick < 0.50 and hydrantMesh then
			mesh = hydrantMesh; sizeY = 2.0; color = Color3.fromRGB(200, 50, 40) -- red hydrant
		elseif pick < 0.75 and mailMesh then
			mesh = mailMesh; sizeY = 2.4; color = Color3.fromRGB(50, 90, 160)   -- blue mailbox
		elseif trashMesh then
			mesh = trashMesh; sizeY = 2.4; color = Color3.fromRGB(60, 70, 60)   -- olive trashcan
		end
		if mesh then
			local p = mesh:Clone()
			p.Anchored = true; p.CanCollide = true
			p.Size = Vector3.new(sizeY, sizeY, sizeY)
			p.Color = color
			p.Material = Enum.Material.SmoothPlastic
			p:PivotTo(CFrame.new(px, sizeY/2, pz) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 359)), 0))
			p.Parent = cityFolder
			placed = placed + 1
		end
	end
	print("[CityRebuild v6] street props placed:", placed)
end)

-- =====================================================================
-- PLAZA  (sunny park-style plaza, NOT pink-neon-glow)
-- =====================================================================
local plaza = Workspace:FindFirstChild("Plaza") or Instance.new("Folder", Workspace)
plaza.Name = "Plaza"
plaza:ClearAllChildren()

-- Floor: warm cobblestone
local pf = Instance.new("Part", plaza)
pf.Name = "PlazaFloor"
pf.Anchored = true; pf.CanCollide = true
pf.Size = Vector3.new(140, 2, 140)
pf.Position = Vector3.new(0, 1.5, 0)
pf.Material = Enum.Material.Cobblestone
pf.Color = Color3.fromRGB(165, 155, 140)

-- Inner brick circle (visual interest)
local innerCircle = Instance.new("Part", plaza)
innerCircle.Anchored = true; innerCircle.CanCollide = false
innerCircle.Shape = Enum.PartType.Cylinder
innerCircle.Size = Vector3.new(0.3, 60, 60)
innerCircle.CFrame = CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(90))
innerCircle.Material = Enum.Material.Brick
innerCircle.Color = Color3.fromRGB(195, 145, 105)

-- Fountain in the center (cylindrical basin + central spout)
local basin = Instance.new("Part", plaza)
basin.Anchored = true; basin.CanCollide = true
basin.Shape = Enum.PartType.Cylinder
basin.Size = Vector3.new(2.5, 14, 14)
basin.CFrame = CFrame.new(0, 4, 0) * CFrame.Angles(0, 0, math.rad(90))
basin.Material = Enum.Material.Marble
basin.Color = Color3.fromRGB(220, 215, 205)

local water = Instance.new("Part", plaza)
water.Anchored = true; water.CanCollide = false
water.Shape = Enum.PartType.Cylinder
water.Size = Vector3.new(0.3, 12, 12)
water.CFrame = CFrame.new(0, 5.4, 0) * CFrame.Angles(0, 0, math.rad(90))
water.Material = Enum.Material.Water
water.Color = Color3.fromRGB(120, 180, 220)
water.Transparency = 0.2

local spout = Instance.new("Part", plaza)
spout.Anchored = true; spout.CanCollide = true
spout.Size = Vector3.new(0.8, 4.5, 0.8)
spout.Position = Vector3.new(0, 7, 0)
spout.Material = Enum.Material.Marble
spout.Color = Color3.fromRGB(220, 215, 205)

local spoutTop = Instance.new("Part", plaza)
spoutTop.Anchored = true; spoutTop.CanCollide = false
spoutTop.Shape = Enum.PartType.Ball
spoutTop.Size = Vector3.new(1.6, 1.6, 1.6)
spoutTop.Position = Vector3.new(0, 9.3, 0)
spoutTop.Material = Enum.Material.Marble
spoutTop.Color = Color3.fromRGB(220, 215, 205)

-- Welcome sign — wooden cartoon, NOT pink neon
local frame = Instance.new("Part", plaza)
frame.Anchored = true; frame.CanCollide = false
frame.Size = Vector3.new(82, 16, 1.4)
frame.Position = Vector3.new(0, 16, -64)
frame.Material = Enum.Material.WoodPlanks
frame.Color = Color3.fromRGB(110, 75, 45)

local board = Instance.new("Part", plaza)
board.Anchored = true; board.CanCollide = false
board.Size = Vector3.new(78, 12.5, 0.6)
board.Position = Vector3.new(0, 16, -63.2)
board.Material = Enum.Material.WoodPlanks
board.Color = Color3.fromRGB(195, 155, 100)

local sg = Instance.new("SurfaceGui", board); sg.Face = Enum.NormalId.Front
sg.LightInfluence = 0.7
sg.PixelsPerStud = 16
sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud

local stl = Instance.new("TextLabel", sg)
stl.AnchorPoint = Vector2.new(0.5, 0.5)
stl.Position = UDim2.fromScale(0.5, 0.5)
stl.Size = UDim2.new(0.94, 0, 0.7, 0)
stl.BackgroundTransparency = 1
stl.Text = "WELCOME TO KITTYRAISER"
stl.Font = Enum.Font.LuckiestGuy
stl.TextScaled = true
stl.TextColor3 = Color3.fromRGB(80, 40, 20)
stl.TextStrokeTransparency = 0.6
stl.TextStrokeColor3 = Color3.fromRGB(255, 240, 200)
local stc = Instance.new("UITextSizeConstraint", stl)
stc.MinTextSize = 60; stc.MaxTextSize = 220

-- Two wooden post supports
for _, sx in ipairs({-32, 32}) do
	local post = Instance.new("Part", plaza)
	post.Anchored = true; post.CanCollide = true
	post.Size = Vector3.new(2, 16, 2)
	post.Position = Vector3.new(sx, 8, -64)
	post.Material = Enum.Material.Wood
	post.Color = Color3.fromRGB(95, 65, 40)
end

-- Trees around plaza edge for cartoon vibes
for _, treePos in ipairs({
	Vector3.new(-50, 0, -50), Vector3.new(50, 0, -50),
	Vector3.new(-50, 0, 50),  Vector3.new(50, 0, 50),
	Vector3.new(-58, 0, 0),   Vector3.new(58, 0, 0),
}) do
	local trunk = Instance.new("Part", plaza)
	trunk.Anchored = true; trunk.CanCollide = true
	trunk.Size = Vector3.new(2, 8, 2)
	trunk.Position = treePos + Vector3.new(0, 5, 0)
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(85, 55, 30)
	local crown = Instance.new("Part", plaza)
	crown.Anchored = true; crown.CanCollide = true
	crown.Shape = Enum.PartType.Ball
	crown.Size = Vector3.new(8, 8, 8)
	crown.Position = treePos + Vector3.new(0, 12, 0)
	crown.Material = Enum.Material.Grass
	crown.Color = Color3.fromRGB(80, 140, 70)
end

-- Particle pool kept for prank effects (no neon)
local pool = Workspace:FindFirstChild("PrankParticlePool") or Instance.new("Folder", Workspace)
pool.Name = "PrankParticlePool"

print("[CityRebuild v6] sunny daytime cartoon city ready")
