-- AmbientTraffic.server.lua  v1 — 12 vehicles cruising slow loops on the road
-- grid so the city has visible motion. No physics, no player interaction;
-- pure visual life. Vehicles use cloned mesh templates from MeshLoader when
-- available, falling back to colored boxes.

local Workspace        = game:GetService("Workspace")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getMesh(name)
	local cache = _G.KittyRaiserMeshes
	if cache and cache[name] and cache[name].meshTemplate then
		return cache[name].meshTemplate
	end
	return nil
end

local trafficFolder = Workspace:FindFirstChild("AmbientTraffic") or Instance.new("Folder", Workspace)
trafficFolder.Name = "AmbientTraffic"
trafficFolder:ClearAllChildren()

local CAR_COLORS = {
	Color3.fromRGB(255, 200, 0),
	Color3.fromRGB(220, 60, 60),
	Color3.fromRGB(60, 100, 180),
	Color3.fromRGB(220, 220, 220),
	Color3.fromRGB(40, 40, 50),
	Color3.fromRGB(140, 95, 60),
}

-- Wait for the mesh cache to populate (best-effort, non-blocking).
task.spawn(function()
	for _ = 1, 30 do
		if _G.KittyRaiserMeshes then break end
		task.wait(0.5)
	end

	local taxiM   = getMesh("mesh_taxi_yellow") or getMesh("mesh_taxi")
	local vanM    = getMesh("mesh_delivery_van")
	local truckM  = getMesh("mesh_food_truck")

	-- 12 cars on horizontal east-west streets at z = -480, -320, -160, 0, 160, 320, 480.
	-- 2 cars per street (one east-bound, one west-bound), staggered start position
	-- and speed so they don't all align.
	local LANES = { -480, -320, -160, 160, 320, 480 }
	local CAR_BASES = { taxiM, vanM, truckM }
	local rng = Random.new(2026)

	local id = 0
	for _, z in ipairs(LANES) do
		for direction = -1, 1, 2 do
			id = id + 1
			if id > 12 then break end
			local meshTemplate = CAR_BASES[((id - 1) % #CAR_BASES) + 1]
			local part
			if meshTemplate then
				part = meshTemplate:Clone()
				part.Anchored = true; part.CanCollide = false
				part.Size = Vector3.new(6, 3, 12)
			else
				part = Instance.new("Part")
				part.Anchored = true; part.CanCollide = false
				part.Size = Vector3.new(6, 3, 12)
				part.Material = Enum.Material.SmoothPlastic
			end
			part.Name = "AmbientCar_" .. id
			part.Color = CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)]
			-- Staggered Z offset so cars share the lane without overlapping
			local offset = rng:NextInteger(-200, 200)
			local startX = direction == 1 and -700 or 700
			local endX   = direction == 1 and  700 or -700
			local yaw = direction == 1 and math.rad(90) or math.rad(-90)
			part.CFrame = CFrame.new(startX + offset, 2.5, z) * CFrame.Angles(0, yaw, 0)
			part.Parent = trafficFolder

			-- Driver figure: small primitive head + torso visible through the
			-- car so it looks driven, not abandoned. Welded to the car so it
			-- moves with the TweenService loop.
			local DRIVER_SHIRT = {
				Color3.fromRGB(40, 50, 80), Color3.fromRGB(220, 60, 60),
				Color3.fromRGB(60, 130, 200), Color3.fromRGB(80, 200, 90),
			}
			local SKIN_TONES = {
				Color3.fromRGB(245,205,160), Color3.fromRGB(200,165,130),
				Color3.fromRGB(160,110,80),  Color3.fromRGB(95,65,45),
			}
			local driverTorso = Instance.new("Part", trafficFolder)
			driverTorso.Anchored = true; driverTorso.CanCollide = false
			driverTorso.Size = Vector3.new(1.3, 1.0, 0.8)
			driverTorso.Material = Enum.Material.SmoothPlastic
			driverTorso.Color = DRIVER_SHIRT[rng:NextInteger(1, #DRIVER_SHIRT)]
			driverTorso.CFrame = part.CFrame * CFrame.new(-0.4, 0.6, 1.5)
			local dwt = Instance.new("WeldConstraint", driverTorso)
			dwt.Part0 = part; dwt.Part1 = driverTorso
			local driverHead = Instance.new("Part", trafficFolder)
			driverHead.Anchored = true; driverHead.CanCollide = false
			driverHead.Size = Vector3.new(0.8, 0.8, 0.8)
			driverHead.Shape = Enum.PartType.Ball
			driverHead.Material = Enum.Material.SmoothPlastic
			driverHead.Color = SKIN_TONES[rng:NextInteger(1, #SKIN_TONES)]
			driverHead.CFrame = driverTorso.CFrame * CFrame.new(0, 0.9, 0)
			local dwh = Instance.new("WeldConstraint", driverHead)
			dwh.Part0 = part; dwh.Part1 = driverHead
			-- Face decal for personality
			local face = Instance.new("Decal", driverHead)
			face.Texture = "rbxasset://textures/face.png"
			face.Face = Enum.NormalId.Front
			-- TweenService loop — slow cruise. Speed ~30 studs/sec → 1400/30 ≈ 47s
			local duration = rng:NextNumber(40, 55)
			task.spawn(function()
				while part.Parent do
					local t = TweenService:Create(part,
						TweenInfo.new(duration, Enum.EasingStyle.Linear),
						{CFrame = CFrame.new(endX, 2.5, z) * CFrame.Angles(0, yaw, 0)})
					t:Play()
					t.Completed:Wait()
					if not part.Parent then return end
					-- Snap back to start (off-screen for player so the loop is invisible)
					part.CFrame = CFrame.new(startX, 2.5, z) * CFrame.Angles(0, yaw, 0)
				end
			end)
		end
	end
	print("[AmbientTraffic v1] 12 vehicles cruising the grid")
end)

-- 6 birds circling plaza — small white triangular parts orbiting at y=80
task.spawn(function()
	local birdsFolder = Workspace:FindFirstChild("AmbientBirds") or Instance.new("Folder", Workspace)
	birdsFolder.Name = "AmbientBirds"
	birdsFolder:ClearAllChildren()
	local rng = Random.new(7)
	for i = 1, 6 do
		local b = Instance.new("Part", birdsFolder)
		b.Anchored = true; b.CanCollide = false
		b.Size = Vector3.new(1.6, 0.2, 0.8)
		b.Material = Enum.Material.SmoothPlastic
		b.Color = Color3.fromRGB(245, 245, 250)
		b.Shape = Enum.PartType.Block
		b.Name = "Bird_" .. i
		-- Wing decals (top + bottom V shape)
		local d1 = Instance.new("Decal", b)
		d1.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		d1.Face = Enum.NormalId.Top
		d1.Color3 = Color3.fromRGB(60, 60, 70)
		d1.Transparency = 0.3
		local radius = rng:NextNumber(120, 200)
		local height = rng:NextNumber(70, 110)
		local speed = rng:NextNumber(0.05, 0.10)
		local phase = rng:NextNumber(0, math.pi * 2)
		task.spawn(function()
			local t0 = os.clock()
			while b.Parent do
				local t = (os.clock() - t0) * speed * 2 * math.pi + phase
				local cx, cz = math.cos(t) * radius, math.sin(t) * radius
				-- Bird faces tangent to the orbit
				local lookAt = Vector3.new(cx, height, cz) +
					Vector3.new(-math.sin(t), 0, math.cos(t)) * 4
				b.CFrame = CFrame.new(Vector3.new(cx, height, cz), lookAt)
				task.wait(0.05)
			end
		end)
	end
	print("[AmbientTraffic v1] 6 birds circling plaza")
end)
