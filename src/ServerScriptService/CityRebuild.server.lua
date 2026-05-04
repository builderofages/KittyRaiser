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
	-- Denser grid: 9x9 with spacing 160 (was 7x7 at 220). Plus secondary
	-- "infill" buildings between main blocks for street-wall density.
	local SP = 160
	local placedByZone = { downtown = 0, suburbs = 0, harbor = 0 }

	for gx = -4, 4 do
		for gz = -4, 4 do
			if math.abs(gx) > 0 or math.abs(gz) > 0 then
				local zoneName = zoneForCell(gx, gz)
				local zone = ZONES[zoneName]
				local cx = gx * SP + rng:NextInteger(-20, 20)
				local cz = gz * SP + rng:NextInteger(-20, 20)
				local h  = rng:NextInteger(zone.heightRange[1], zone.heightRange[2])
				local color = zone.buildingColors[rng:NextInteger(1, #zone.buildingColors)]
				local cf = CFrame.new(cx, h/2 + 1, cz)
				local pickMesh = zone.preferTall and (skyMesh or brownMesh) or (brownMesh or skyMesh)
				local b = placeBuilding(pickMesh, cf, h, color, fallbackBuildingBox)
				if b then b:SetAttribute("Zone", zoneName) end
				placedByZone[zoneName] = placedByZone[zoneName] + 1

				-- Infill: smaller secondary building in each cell so streets
				-- aren't barren between the main blocks.
				if rng:NextNumber() < 0.7 then
					local ix = cx + rng:NextInteger(-65, 65)
					local iz = cz + rng:NextInteger(-65, 65)
					local ih = math.floor(h * rng:NextNumber() * 0.55 + 30)
					local icolor = zone.buildingColors[rng:NextInteger(1, #zone.buildingColors)]
					local icf = CFrame.new(ix, ih/2 + 1, iz)
					local imesh = (rng:NextNumber() < 0.5) and brownMesh or pickMesh
					local ib = placeBuilding(imesh, icf, ih, icolor, fallbackBuildingBox)
					if ib then ib:SetAttribute("Zone", zoneName) end
					placedByZone[zoneName] = placedByZone[zoneName] + 1
				end
			end
		end
	end
	print("[CityRebuild v9] dense zones placed:",
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
	-- Generic everywhere (v1 meshes — kept for fallback)
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
	-- v2 PHASE-10 MESHES (richer cartoon variants, used preferentially)
	local taxiYellowMesh    = getMesh("mesh_taxi_yellow")
	local deliveryVanMesh   = getMesh("mesh_delivery_van")
	local foodTruckMesh     = getMesh("mesh_food_truck")
	local fireHydrantMesh   = getMesh("mesh_fire_hydrant")
	local trashCanMesh      = getMesh("mesh_trash_can")
	local mailboxBlueMesh   = getMesh("mesh_mailbox_blue")
	local busStopMesh       = getMesh("mesh_bus_stop_shelter")
	local trafficLightMesh  = getMesh("mesh_traffic_light")
	local hotDogCartMesh    = getMesh("mesh_hot_dog_cart")
	local skyChunkMesh      = getMesh("mesh_skyscraper_chunk")

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

	-- Generic props (180 across the map — was 60, now 3x denser).
	-- More cars in different colors so streets feel alive, not just yellow taxis.
	local CAR_COLORS = {
		Color3.fromRGB(255, 200, 0),    -- yellow taxi
		Color3.fromRGB(220, 60, 60),    -- red sedan
		Color3.fromRGB(60, 100, 180),   -- blue sedan
		Color3.fromRGB(40, 40, 50),     -- black
		Color3.fromRGB(220, 220, 220),  -- white
		Color3.fromRGB(80, 130, 80),    -- olive
		Color3.fromRGB(200, 130, 60),   -- orange
		Color3.fromRGB(140, 95, 60),    -- brown
	}
	local PROP_COUNT = 180
	local placed = 0
	-- Prefer v2 meshes when present, fall back to v1
	local pickCar = function()
		local pool = {}
		if taxiYellowMesh   then table.insert(pool, taxiYellowMesh) end
		if deliveryVanMesh  then table.insert(pool, deliveryVanMesh) end
		if foodTruckMesh    then table.insert(pool, foodTruckMesh) end
		if taxiMesh         then table.insert(pool, taxiMesh) end
		return pool[rng:NextInteger(1, math.max(1, #pool))]
	end
	local hydrantPick = fireHydrantMesh or hydrantMesh
	local mailPick    = mailboxBlueMesh or mailMesh
	local trashPick   = trashCanMesh    or trashMesh
	for _ = 1, PROP_COUNT do
		local px = rng:NextInteger(-720, 720)
		local pz = rng:NextInteger(-720, 720)
		if math.sqrt(px * px + (pz - 24)^2) < 28 then continue end
		local pick = rng:NextNumber()
		local carMesh = pickCar()
		if pick < 0.30 and carMesh then
			local cc = CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)]
			if place(carMesh, px, 3.5/2, pz, 3.5, cc) then placed = placed + 1 end
		elseif pick < 0.55 and hydrantPick then
			if place(hydrantPick, px, 1, pz, 2.0, Color3.fromRGB(200, 50, 40)) then placed = placed + 1 end
		elseif pick < 0.78 and mailPick then
			if place(mailPick, px, 1.2, pz, 2.4, Color3.fromRGB(50, 90, 160)) then placed = placed + 1 end
		elseif trashPick then
			if place(trashPick, px, 1.2, pz, 2.4, Color3.fromRGB(60, 70, 60)) then placed = placed + 1 end
		end
	end

	-- Zone-specific props (120 across the map, zone-biased)
	local ZONE_COUNT = 120
	local zonePlaced = 0
	for _ = 1, ZONE_COUNT do
		local px = rng:NextInteger(-720, 720)
		local pz = rng:NextInteger(-720, 720)
		if math.sqrt(px * px + (pz - 24)^2) < 28 then continue end
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

	-- =====================================================================
	-- v2 PHASE-10 SET-DRESSING (placed per directive)
	-- Plaza:    2 trash_can corners, 2 mailbox_blue, 1 hot_dog_cart, 1 bus_stop_shelter
	-- Downtown: 4 skyscraper_chunk in 2x2 grid behind plaza, 4 traffic_light at intersections,
	--           2 taxi_yellow + 1 delivery_van + 1 food_truck on streets, 6 fire_hydrant on sidewalks
	-- =====================================================================
	local v2 = 0

	-- Plaza corners (plaza is 140x140 centered on origin)
	if trashCanMesh then
		for _, c in ipairs({Vector3.new(-58, 1.2, -58), Vector3.new(58, 1.2, -58)}) do
			if place(trashCanMesh, c.X, c.Y, c.Z, 2.4, Color3.fromRGB(60, 70, 60), nil, 0) then v2 = v2 + 1 end
		end
	end
	if mailboxBlueMesh then
		for _, c in ipairs({Vector3.new(-30, 1.2, -55), Vector3.new(30, 1.2, -55)}) do
			if place(mailboxBlueMesh, c.X, c.Y, c.Z, 2.4, Color3.fromRGB(50, 90, 160), nil, 0) then v2 = v2 + 1 end
		end
	end
	if hotDogCartMesh then
		if place(hotDogCartMesh, 0, 1.5, 30, 3.0, Color3.fromRGB(220, 70, 60), nil, 0) then v2 = v2 + 1 end
	end
	if busStopMesh then
		if place(busStopMesh, -45, 2.5, -55, 5.0, Color3.fromRGB(90, 100, 110), nil, 90) then v2 = v2 + 1 end
	end

	-- Downtown skyline (2x2 chunks) behind plaza horizon at +X/+Z corner
	if skyChunkMesh then
		for gx = 0, 1 do
			for gz = 0, 1 do
				local cx = 280 + gx * 90
				local cz = 280 + gz * 90
				if place(skyChunkMesh, cx, 60, cz, 120,
				         Color3.fromRGB(180, 175, 170), Enum.Material.Brick, 0) then v2 = v2 + 1 end
			end
		end
	end

	-- Traffic lights at downtown intersections (160-stud grid, +X/+Z quadrant)
	if trafficLightMesh then
		for _, ipos in ipairs({Vector3.new(160, 4, 160), Vector3.new(320, 4, 160),
		                       Vector3.new(160, 4, 320), Vector3.new(320, 4, 320)}) do
			if place(trafficLightMesh, ipos.X, ipos.Y, ipos.Z, 6.0,
			         Color3.fromRGB(50, 50, 55), Enum.Material.Metal, 0) then v2 = v2 + 1 end
		end
	end

	-- Featured vehicles on the main street loop (just outside plaza, +X axis)
	if taxiYellowMesh then
		if place(taxiYellowMesh,  100, 1.8, 80, 3.5, Color3.fromRGB(255, 200, 0), nil, 90) then v2 = v2 + 1 end
		if place(taxiYellowMesh, -100, 1.8, 80, 3.5, Color3.fromRGB(255, 200, 0), nil, 270) then v2 = v2 + 1 end
	end
	if deliveryVanMesh then
		if place(deliveryVanMesh, 80, 2.0, 120, 4.0, Color3.fromRGB(220, 220, 220), nil, 90) then v2 = v2 + 1 end
	end
	if foodTruckMesh then
		if place(foodTruckMesh, -80, 2.2, 120, 4.5, Color3.fromRGB(200, 130, 60), nil, 270) then v2 = v2 + 1 end
	end

	-- Fire hydrants lining downtown sidewalks
	if fireHydrantMesh then
		for _, hpos in ipairs({Vector3.new(155, 1, 60), Vector3.new(-155, 1, 60),
		                       Vector3.new(155, 1, -60), Vector3.new(-155, 1, -60),
		                       Vector3.new(60, 1, 155), Vector3.new(-60, 1, 155)}) do
			if place(fireHydrantMesh, hpos.X, hpos.Y, hpos.Z, 2.0,
			         Color3.fromRGB(200, 50, 40), nil, 0) then v2 = v2 + 1 end
		end
	end

	print("[CityRebuild v10] generic props:", placed, "zone props:", zonePlaced, "v2 props:", v2)
end)

-- =====================================================================
-- ROAD GRID — paint white lane stripes on the asphalt so the city
-- reads as STREETS, not just an empty plane with buildings on it.
-- =====================================================================
task.spawn(function()
	local stripes = Workspace:FindFirstChild("RoadStripes") or Instance.new("Folder", Workspace)
	stripes.Name = "RoadStripes"
	stripes:ClearAllChildren()
	-- Lanes run along grid edges (every 160 studs to match building grid).
	for axis = -3, 3 do
		local lane = axis * 160
		-- N-S lane at x=lane (full Z extent)
		for z = -640, 640, 32 do
			local stripe = Instance.new("Part", stripes)
			stripe.Anchored = true; stripe.CanCollide = false
			stripe.Size = Vector3.new(0.6, 0.1, 14)
			stripe.Position = Vector3.new(lane, 0.6, z)
			stripe.Material = Enum.Material.SmoothPlastic
			stripe.Color = Color3.fromRGB(245, 230, 180)
		end
		-- E-W lane at z=lane (full X extent)
		for x = -640, 640, 32 do
			local stripe = Instance.new("Part", stripes)
			stripe.Anchored = true; stripe.CanCollide = false
			stripe.Size = Vector3.new(14, 0.1, 0.6)
			stripe.Position = Vector3.new(x, 0.6, lane)
			stripe.Material = Enum.Material.SmoothPlastic
			stripe.Color = Color3.fromRGB(245, 230, 180)
		end
	end
	print("[CityRebuild v9] road stripes painted")
end)

-- =====================================================================
-- DISTANT HORIZON SKYLINE (Phase-12) — 12 thin tall dark-blue cubes on a
-- 600-stud-radius circle around the plaza, behind the active 9x9 grid. Reads
-- as 'horizon city' so the world doesn't end at the active building edge.
-- =====================================================================
task.spawn(function()
	local horizon = Workspace:FindFirstChild("HorizonSkyline") or Instance.new("Folder", Workspace)
	horizon.Name = "HorizonSkyline"
	horizon:ClearAllChildren()
	for i = 0, 11 do
		local theta = (i / 12) * math.pi * 2
		local r = 900
		local h = 60 + (i % 3) * 25  -- vary height for organic skyline
		local b = Instance.new("Part", horizon)
		b.Anchored = true; b.CanCollide = false  -- player can't walk to them anyway
		b.Size = Vector3.new(40, h, 40)
		b.Position = Vector3.new(math.cos(theta) * r, h / 2, math.sin(theta) * r)
		b.Material = Enum.Material.SmoothPlastic
		b.Color = Color3.fromRGB(45, 50, 70)  -- dark plum/navy
		-- Top window glow row for that "city at golden hour" silhouette feel
		local glow = Instance.new("Part", horizon)
		glow.Anchored = true; glow.CanCollide = false
		glow.Size = Vector3.new(40, 4, 40)
		glow.Position = b.Position + Vector3.new(0, h / 2 - 8, 0)
		glow.Material = Enum.Material.Neon
		glow.Color = Color3.fromRGB(255, 200, 130)
		glow.Transparency = 0.3
	end
	print("[CityRebuild v10] horizon skyline placed")
end)

-- =====================================================================
-- NEON SHOP FACADES (Phase-12) — SurfaceGui labels on the 4 downtown
-- skyscraper_chunks so the city has visible storefronts/business names.
-- No new mesh assets needed; uses TextLabel + UIGradient.
-- =====================================================================
task.spawn(function()
	for _ = 1, 30 do
		if cityFolder:FindFirstChildWhichIsA("BasePart") then break end
		task.wait(0.5)
	end
	local SHOP_NAMES = {"PURRFECT EATS","9TH LIFE LOFTS","CATNIP CO","MEOW BANK",
	                    "WHISKER WORKS","KITTY AVE","FUR GALLERY","CLAW CO"}
	local NEON_COLORS = {
		Color3.fromRGB(255, 110, 130),  -- hot pink
		Color3.fromRGB(120, 220, 255),  -- cyan
		Color3.fromRGB(255, 200, 90),   -- amber
		Color3.fromRGB(180, 255, 140),  -- lime
		Color3.fromRGB(255, 150, 80),   -- orange
		Color3.fromRGB(200, 140, 255),  -- violet
	}
	local rng = Random.new(2026)
	local placed = 0
	for _, p in ipairs(cityFolder:GetChildren()) do
		if placed >= 8 then break end
		if p:IsA("BasePart") and p:GetAttribute("Zone") == "downtown" and p.Size.Y > 80 then
			-- Pick a random face for the sign
			local face = (rng:NextInteger(1, 2) == 1) and Enum.NormalId.Front or Enum.NormalId.Back
			local sg = Instance.new("SurfaceGui", p)
			sg.Face = face
			sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			sg.CanvasSize = Vector2.new(640, 200)
			sg.LightInfluence = 0  -- pure-emit neon
			sg.AlwaysOnTop = false
			local container = Instance.new("Frame", sg)
			container.Size = UDim2.new(0.7, 0, 0.12, 0)
			container.Position = UDim2.new(0.15, 0, 0.45, 0)
			container.BackgroundColor3 = Color3.fromRGB(20, 18, 30)
			container.BackgroundTransparency = 0.2
			Instance.new("UICorner", container).CornerRadius = UDim.new(0, 8)
			local stroke = Instance.new("UIStroke", container)
			stroke.Thickness = 3
			stroke.Color = NEON_COLORS[rng:NextInteger(1, #NEON_COLORS)]
			stroke.Transparency = 0
			local lbl = Instance.new("TextLabel", container)
			lbl.Size = UDim2.fromScale(1, 1)
			lbl.BackgroundTransparency = 1
			lbl.Text = SHOP_NAMES[rng:NextInteger(1, #SHOP_NAMES)]
			lbl.Font = Enum.Font.GothamBlack
			lbl.TextScaled = true
			lbl.TextColor3 = stroke.Color
			lbl.TextStrokeTransparency = 0.3
			lbl.TextStrokeColor3 = Color3.fromRGB(20, 18, 30)
			placed = placed + 1
		end
	end
	print("[CityRebuild v10] " .. placed .. " neon shop facades placed")
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

-- Floor: warm sunset-cream cobblestone (Pixar-cartoon, not dim concrete).
local pf = Instance.new("Part", plaza)
pf.Name = "PlazaFloor"
pf.Anchored = true; pf.CanCollide = true
pf.Size = Vector3.new(140, 2, 140)
pf.Position = Vector3.new(0, 1.5, 0)
pf.Material = Enum.Material.Cobblestone
pf.Color = Color3.fromRGB(255, 220, 170)  -- sunset cream

-- Plaza perimeter walls (low cream borders with warm cornice top-cap).
-- Replaces the dim grey concrete look from Phase-9 playtest screenshots.
for _, def in ipairs({
	{name="WallN", size=Vector3.new(140, 4, 4), pos=Vector3.new(0, 4, -68)},
	{name="WallE", size=Vector3.new(4, 4, 140), pos=Vector3.new(68, 4, 0)},
	{name="WallW", size=Vector3.new(4, 4, 140), pos=Vector3.new(-68, 4, 0)},
	-- South wall split for plaza entry gap (player walks in from -Z)
	{name="WallSL", size=Vector3.new(50, 4, 4), pos=Vector3.new(-45, 4, 68)},
	{name="WallSR", size=Vector3.new(50, 4, 4), pos=Vector3.new(45, 4, 68)},
}) do
	local w = Instance.new("Part", plaza)
	w.Name = def.name
	w.Anchored = true; w.CanCollide = true
	w.Size = def.size; w.Position = def.pos
	w.Material = Enum.Material.SmoothPlastic
	w.Color = Color3.fromRGB(255, 220, 170)  -- sunset cream
	-- Cornice top-cap (slightly warmer orange-cream)
	local cap = Instance.new("Part", plaza)
	cap.Name = def.name .. "_Cap"
	cap.Anchored = true; cap.CanCollide = false
	cap.Size = def.size + Vector3.new(0.6, -3, 0.6)  -- extends 0.3 stud over edges
	cap.Position = def.pos + Vector3.new(0, 2.5, 0)
	cap.Material = Enum.Material.SmoothPlastic
	cap.Color = Color3.fromRGB(255, 175, 90)  -- cornice warmth
end

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
