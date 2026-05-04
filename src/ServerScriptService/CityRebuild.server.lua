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
-- ZONE GROUND PATCHES — large flat overlay parts at each zone center so
-- the ground LOOKS different per zone, not just the buildings.
-- =====================================================================
local function placeZonePatch(name, position, color, material)
	local p = Instance.new("Part")
	p.Name = "Zone_" .. name
	p.Anchored = true
	p.CanCollide = true
	p.Size = Vector3.new(640, 0.6, 640)  -- large flat slab covering ~3x3 of grid
	p.Position = position
	p.Material = material
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = cityFolder
end
-- Downtown (NE quadrant, +X +Z): clean granite slate
placeZonePatch("downtown", Vector3.new( 440, 0.3,  440), Color3.fromRGB(82, 78, 80),  Enum.Material.Slate)
-- Suburbs (cross quadrants): warm stone tile (use NW + SE patches)
placeZonePatch("suburbsNW", Vector3.new(-440, 0.3,  440), Color3.fromRGB(140, 110, 85), Enum.Material.Cobblestone)
placeZonePatch("suburbsSE", Vector3.new( 440, 0.3, -440), Color3.fromRGB(140, 110, 85), Enum.Material.Cobblestone)
-- Harbor (SW quadrant): sandy beige sand-ish
placeZonePatch("harbor",   Vector3.new(-440, 0.3, -440), Color3.fromRGB(210, 195, 165), Enum.Material.Sand)

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

-- =====================================================================
-- ZONE PALETTES — three distinct neighborhoods of the city.
--   * downtown: tall skyscrapers, cool stone, dense
--   * suburbs:  shorter brownstones, warm brick, leafy
--   * harbor:   mid-rise warehouses, washed sandstone, open
-- Zones are picked by quadrant of the grid so the player walks between them.
-- =====================================================================
local ZONES = {
	downtown = {
		buildingColors = {
			Color3.fromRGB(180, 175, 170),  -- pale stone
			Color3.fromRGB(155, 150, 145),  -- darker stone
			Color3.fromRGB(120, 115, 110),  -- granite
			Color3.fromRGB(195, 190, 180),  -- limestone
		},
		heightRange = {110, 220},   -- tallest
		preferTall = true,
		spacing = 220,
	},
	suburbs = {
		buildingColors = {
			Color3.fromRGB(170, 110, 80),   -- warm brick brown
			Color3.fromRGB(195, 145, 105),  -- terracotta
			Color3.fromRGB(140, 100, 75),   -- darker brick
			Color3.fromRGB(180, 130, 95),   -- adobe
		},
		heightRange = {50, 110},    -- shorter
		preferTall = false,
		spacing = 200,
	},
	harbor = {
		buildingColors = {
			Color3.fromRGB(210, 195, 175),  -- washed sandstone
			Color3.fromRGB(190, 175, 150),  -- pale sand
			Color3.fromRGB(170, 155, 130),  -- driftwood
			Color3.fromRGB(155, 145, 130),  -- weathered concrete
		},
		heightRange = {40, 90},     -- low warehouses
		preferTall = false,
		spacing = 240,
	},
}

-- Map a grid cell to a zone based on its position around the origin
local function zoneForCell(gx, gz)
	if gx >= 0 and gz >= 0 then return "downtown" end
	if gx < 0 and gz < 0  then return "harbor"   end
	return "suburbs"
end

task.spawn(function()
	-- Wait for MeshLoader to populate cache.
	for _ = 1, 30 do
		if _G.KittyRaiserMeshes then break end
		task.wait(0.5)
	end

	local skyMesh   = getMesh("mesh_skyscraper")
	local brownMesh = getMesh("mesh_brownstone")
	local rng = Random.new(73)
	local SP = 220
	local placedByZone = { downtown = 0, suburbs = 0, harbor = 0 }

	for gx = -3, 3 do
		for gz = -3, 3 do
			if math.abs(gx) > 0 or math.abs(gz) > 0 then
				local zoneName = zoneForCell(gx, gz)
				local zone = ZONES[zoneName]
				local cx = gx * SP + rng:NextInteger(-30, 30)
				local cz = gz * SP + rng:NextInteger(-30, 30)
				local h  = rng:NextInteger(zone.heightRange[1], zone.heightRange[2])
				local color = zone.buildingColors[rng:NextInteger(1, #zone.buildingColors)]
				local cf = CFrame.new(cx, h/2 + 1, cz)
				local pickMesh
				if zone.preferTall then
					pickMesh = skyMesh or brownMesh
				else
					pickMesh = brownMesh or skyMesh
				end
				local b = placeBuilding(pickMesh, cf, h, color, fallbackBuildingBox)
				if b then b:SetAttribute("Zone", zoneName) end
				placedByZone[zoneName] = placedByZone[zoneName] + 1
			end
		end
	end
	print("[CityRebuild v7] zones placed:",
		"downtown="..placedByZone.downtown,
		"suburbs="..placedByZone.suburbs,
		"harbor="..placedByZone.harbor)
end)

-- =====================================================================
-- STREET PROPS  — taxi/hydrant/mailbox/trashcan + zone-aware extras:
--   downtown: streetlamps + manhole covers + occasional fire trucks
--   suburbs:  oak trees + park benches
--   harbor:   palm trees + park benches
-- =====================================================================
task.spawn(function()
	for _ = 1, 30 do
		if _G.KittyRaiserMeshes then break end
		task.wait(0.5)
	end
	local rng = Random.new(91)
	-- Generic everywhere
	local taxiMesh   = getMesh("mesh_taxi")
	local hydrantMesh = getMesh("mesh_hydrant")
	local mailMesh   = getMesh("mesh_mailbox")
	local trashMesh  = getMesh("mesh_trashcan")
	-- Zone-specific
	local lampMesh   = getMesh("mesh_streetlamp")
	local benchMesh  = getMesh("mesh_park_bench")
	local oakMesh    = getMesh("mesh_oak_tree")
	local palmMesh   = getMesh("mesh_palm_tree")
	local manholeMesh = getMesh("mesh_manhole")
	local fireMesh   = getMesh("mesh_fire_truck")

	local function zoneFor(x, z)
		if x >= 0 and z >= 0 then return "downtown" end
		if x <  0 and z <  0 then return "harbor"   end
		return "suburbs"
	end

	local function place(mesh, x, y, z, sizeY, color, material, rotDeg)
		if not mesh then return false end
		local p = mesh:Clone()
		p.Anchored = true; p.CanCollide = true
		p.Size = Vector3.new(sizeY, sizeY, sizeY)
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotDeg or rng:NextInteger(0, 359)), 0))
		p.Parent = cityFolder
		return true
	end

	-- Generic props (60 across the map)
	local PROP_COUNT = 60
	local placed = 0
	for _ = 1, PROP_COUNT do
		local px = rng:NextInteger(-700, 700)
		local pz = rng:NextInteger(-700, 700)
		if math.sqrt(px * px + (pz - 24)^2) < 24 then continue end
		local pick = rng:NextNumber()
		if pick < 0.18 and taxiMesh then
			if place(taxiMesh, px, 3.5/2, pz, 3.5, Color3.fromRGB(255, 200, 0)) then placed = placed + 1 end
		elseif pick < 0.50 and hydrantMesh then
			if place(hydrantMesh, px, 1, pz, 2.0, Color3.fromRGB(200, 50, 40)) then placed = placed + 1 end
		elseif pick < 0.75 and mailMesh then
			if place(mailMesh, px, 1.2, pz, 2.4, Color3.fromRGB(50, 90, 160)) then placed = placed + 1 end
		elseif trashMesh then
			if place(trashMesh, px, 1.2, pz, 2.4, Color3.fromRGB(60, 70, 60)) then placed = placed + 1 end
		end
	end

	-- Zone-specific props (40 across the map, zone-biased)
	local ZONE_COUNT = 40
	local zonePlaced = 0
	for _ = 1, ZONE_COUNT do
		local px = rng:NextInteger(-700, 700)
		local pz = rng:NextInteger(-700, 700)
		if math.sqrt(px * px + (pz - 24)^2) < 24 then continue end
		local zone = zoneFor(px, pz)
		if zone == "downtown" then
			local pick = rng:NextNumber()
			if pick < 0.5 and lampMesh then
				if place(lampMesh, px, 4.5/2, pz, 4.5, Color3.fromRGB(40, 35, 30), Enum.Material.Metal) then zonePlaced = zonePlaced + 1 end
			elseif pick < 0.85 and manholeMesh then
				if place(manholeMesh, px, 0.05, pz, 2.0, Color3.fromRGB(45, 45, 50), Enum.Material.Metal) then zonePlaced = zonePlaced + 1 end
			elseif fireMesh then
				if place(fireMesh, px, 3, pz, 6.0, Color3.fromRGB(200, 40, 30)) then zonePlaced = zonePlaced + 1 end
			end
		elseif zone == "suburbs" then
			local pick = rng:NextNumber()
			if pick < 0.65 and oakMesh then
				if place(oakMesh, px, 5, pz, 9.0, Color3.fromRGB(110, 80, 55), Enum.Material.Wood) then zonePlaced = zonePlaced + 1 end
			elseif benchMesh then
				if place(benchMesh, px, 0.6, pz, 2.2, Color3.fromRGB(95, 65, 40), Enum.Material.Wood) then zonePlaced = zonePlaced + 1 end
			end
		else  -- harbor
			local pick = rng:NextNumber()
			if pick < 0.65 and palmMesh then
				if place(palmMesh, px, 5, pz, 8.5, Color3.fromRGB(115, 175, 95), Enum.Material.Grass) then zonePlaced = zonePlaced + 1 end
			elseif benchMesh then
				if place(benchMesh, px, 0.6, pz, 2.2, Color3.fromRGB(95, 65, 40), Enum.Material.Wood) then zonePlaced = zonePlaced + 1 end
			end
		end
	end

	print("[CityRebuild v8] generic props:", placed, " zone props:", zonePlaced)
end)

-- =====================================================================
-- PLAZA  (sunny park-style plaza, NOT pink-neon-glow)
-- =====================================================================
-- =====================================================================
-- PLAZA — sunny cobblestone-tan square (NO wooden disc).
-- Diagnostic: this used to have an inner Brick-material disc that read as
-- a wooden stage in playtest. Removed. Plaza is now a single warm cobblestone
-- square with a marble fountain in the middle.
-- =====================================================================
local plaza = Workspace:FindFirstChild("Plaza") or Instance.new("Folder", Workspace)
plaza.Name = "Plaza"
plaza:ClearAllChildren()

-- Floor: warm cobblestone-tan square
local pf = Instance.new("Part", plaza)
pf.Name = "PlazaFloor"
pf.Anchored = true; pf.CanCollide = true
pf.Size = Vector3.new(140, 2, 140)
pf.Position = Vector3.new(0, 1.5, 0)
pf.Material = Enum.Material.Cobblestone
pf.Color = Color3.fromRGB(205, 190, 165)  -- brighter tan than before

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
	crown.Color = Color3.fromRGB(115, 175, 95)  -- summer green, not autumn
end

-- Particle pool kept for prank effects (no neon)
local pool = Workspace:FindFirstChild("PrankParticlePool") or Instance.new("Folder", Workspace)
pool.Name = "PrankParticlePool"

-- Diagnostic: print plaza floor material + color so playtester can verify
print(("[CityRebuild v7] plaza floor: material=%s color=%s tree_count=%d"):format(
	tostring(pf.Material), tostring(pf.Color),
	#plaza:GetChildren()))
print("[CityRebuild v7] sunny daytime cartoon city ready")
