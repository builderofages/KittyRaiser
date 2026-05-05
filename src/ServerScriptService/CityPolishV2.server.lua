-- CityPolishV2.server.lua  v1
-- Replaces "scattered randomly" cars with cars LINED UP along streets (proper urban look).
-- Adds window NPCs (silhouettes peering out from skyscraper windows).
-- Adds street lights at intersections, neon signs on building facades.
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getMesh(name)
    local cache = _G.KittyRaiserMeshes
    if cache and cache[name] and cache[name].meshTemplate then
        return cache[name].meshTemplate
    end
    return nil
end

task.spawn(function()
    -- Wait for MeshLoader + CityRebuild + CityDensityBoost
    for _ = 1, 40 do
        if _G.KittyRaiserMeshes and Workspace:FindFirstChild("CityDensityBoost") then break end
        task.wait(0.5)
    end

    local container = Workspace:FindFirstChild("CityPolishV2") or Instance.new("Folder")
    container.Name = "CityPolishV2"
    container:ClearAllChildren()
    container.Parent = Workspace

    -- ============ 1. PARKED CARS ALONG ASPHALT STREETS ============
    -- Asphalt cardinal cross is at z=±20 (E-W street) and x=±20 (N-S street).
    -- Park cars at z=22 (north sidewalk), z=-22 (south sidewalk), x=22, x=-22.
    local CAR_MESHES = {"mesh_taxi_yellow", "mesh_delivery_van", "mesh_food_truck", "mesh_cop_car", "mesh_fire_truck"}
    local CAR_COLORS = {
        Color3.fromRGB(255, 200, 0), Color3.fromRGB(220, 60, 60),
        Color3.fromRGB(60, 100, 180), Color3.fromRGB(220, 220, 220),
        Color3.fromRGB(40, 40, 50),
    }

    local function placeCar(meshIdx, position, rotY)
        local mesh = getMesh(CAR_MESHES[meshIdx])
        local p
        if mesh then
            p = mesh:Clone()
            p.Anchored = true; p.CanCollide = true
            p.Size = Vector3.new(6, 3, 12)
        else
            p = Instance.new("Part")
            p.Anchored = true; p.CanCollide = true
            p.Size = Vector3.new(6, 3, 12)
            p.Material = Enum.Material.SmoothPlastic
            p.Color = CAR_COLORS[meshIdx] or Color3.fromRGB(140, 140, 140)
        end
        p.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotY), 0)
        p.Parent = container
    end

    -- Cars lined up parallel along E-W street (z = +22 north side, -22 south side)
    -- Span from x=-200 to x=200, every 18 studs
    for x = -200, 200, 18 do
        if math.abs(x) > 30 then  -- skip plaza intersection
            placeCar(((x // 18) % 5) + 1, Vector3.new(x, 1.5, 22), 90)
            placeCar((((x + 9) // 18) % 5) + 1, Vector3.new(x, 1.5, -22), -90)
        end
    end
    -- Cars lined up parallel along N-S street (x = +22 east side, -22 west side)
    for z = -200, 200, 18 do
        if math.abs(z) > 30 then
            placeCar(((z // 18) % 5) + 1, Vector3.new(22, 1.5, z), 0)
            placeCar((((z + 9) // 18) % 5) + 1, Vector3.new(-22, 1.5, z), 180)
        end
    end

    -- ============ 2. STREET LAMPS at intersections (every 60 studs along axis) ============
    for d = -240, 240, 60 do
        if math.abs(d) > 30 then
            for _, axis in ipairs({"x", "z"}) do
                for _, sign in ipairs({-1, 1}) do
                    local lampMesh = getMesh("mesh_streetlamp")
                    local lamp
                    if lampMesh then
                        lamp = lampMesh:Clone()
                        lamp.Anchored = true; lamp.CanCollide = true
                        lamp.Size = Vector3.new(1, 8, 1)
                    else
                        lamp = Instance.new("Part")
                        lamp.Anchored = true; lamp.CanCollide = true
                        lamp.Size = Vector3.new(1, 8, 1)
                        lamp.Material = Enum.Material.SmoothPlastic
                        lamp.Color = Color3.fromRGB(80, 70, 60)
                    end
                    if axis == "x" then
                        lamp.Position = Vector3.new(d, 4, sign * 26)
                    else
                        lamp.Position = Vector3.new(sign * 26, 4, d)
                    end
                    lamp.Parent = container
                    -- glow point light
                    local light = Instance.new("PointLight", lamp)
                    light.Color = Color3.fromRGB(255, 220, 140)
                    light.Brightness = 1.2
                    light.Range = 18
                end
            end
        end
    end

    -- ============ 3. WINDOW NPCS (peering silhouettes in skyscraper facades) ============
    -- Skyscraper clusters at the 6 city zones (CityDensityBoost places 4-pack at each).
    -- For each cluster center, add 12 little window-NPC silhouettes on visible faces.
    local CITY_ZONES = {
        Vector3.new( 350, 0,  350), Vector3.new(-350, 0,  350),
        Vector3.new( 350, 0, -350), Vector3.new(-350, 0, -350),
        Vector3.new( 600, 0,    0), Vector3.new(-600, 0,    0),
    }
    for _, center in ipairs(CITY_ZONES) do
        for floor = 1, 4 do  -- 4 visible floors
            for col = 1, 3 do  -- 3 windows per face
                local h = 4 + floor * 5
                local x = center.X + (col - 2) * 6
                local z = center.Z + 18  -- front face
                -- silhouette
                local sil = Instance.new("Part")
                sil.Name = "WindowNPC"
                sil.Size = Vector3.new(2, 2, 0.5)
                sil.Anchored = true; sil.CanCollide = false
                sil.Position = Vector3.new(x, h, z)
                sil.Material = Enum.Material.Neon
                sil.Color = Color3.fromRGB(255, 220, 120)
                sil.Transparency = 0.3
                sil.Parent = container
                -- subtle pulse
                TweenService:Create(sil, TweenInfo.new(2 + math.random(),
                    Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                    {Transparency = 0.6}):Play()
            end
        end
    end

    -- ============ 4. NEON SHOP SIGNS on building facades ============
    local SHOP_NEON_COLORS = {
        Color3.fromRGB(255, 60, 100), Color3.fromRGB(60, 200, 255),
        Color3.fromRGB(255, 200, 60), Color3.fromRGB(200, 60, 255),
        Color3.fromRGB(60, 255, 100),
    }
    for _, center in ipairs(CITY_ZONES) do
        for i, color in ipairs(SHOP_NEON_COLORS) do
            local sign = Instance.new("Part")
            sign.Name = "NeonShopSign"
            sign.Anchored = true; sign.CanCollide = false
            sign.Size = Vector3.new(8, 1.5, 0.4)
            sign.Material = Enum.Material.Neon
            sign.Color = color
            local angle = ((i - 1) / #SHOP_NEON_COLORS) * math.pi * 2
            sign.CFrame = CFrame.new(center.X + math.cos(angle) * 22, 8, center.Z + math.sin(angle) * 22)
                          * CFrame.Angles(0, -angle + math.pi/2, 0)
            sign.Parent = container
            local light = Instance.new("PointLight", sign)
            light.Color = color; light.Brightness = 1.8; light.Range = 16
        end
    end

    -- ============ 5. PLAZA FOUNTAIN with water particles ============
    local pillar = Instance.new("Part")
    pillar.Anchored = true; pillar.CanCollide = true
    pillar.Size = Vector3.new(2, 5, 2)
    pillar.Position = Vector3.new(0, 2.5, 0)
    pillar.Material = Enum.Material.Marble
    pillar.Color = Color3.fromRGB(220, 215, 200)
    pillar.Parent = container

    local pool = Instance.new("Part")
    pool.Anchored = true; pool.CanCollide = true
    pool.Size = Vector3.new(14, 1, 14)
    pool.Position = Vector3.new(0, 0.5, 0)
    pool.Shape = Enum.PartType.Cylinder
    pool.Material = Enum.Material.Marble
    pool.Color = Color3.fromRGB(220, 215, 200)
    pool.Orientation = Vector3.new(0, 0, 90)
    pool.Parent = container

    local water = Instance.new("Part")
    water.Anchored = true; water.CanCollide = false
    water.Size = Vector3.new(12, 0.6, 12)
    water.Position = Vector3.new(0, 1, 0)
    water.Shape = Enum.PartType.Cylinder
    water.Material = Enum.Material.Glass
    water.Color = Color3.fromRGB(140, 200, 230)
    water.Transparency = 0.3
    water.Orientation = Vector3.new(0, 0, 90)
    water.Parent = container

    -- water spray particle on pillar
    local emitter = Instance.new("Attachment", pillar)
    emitter.Position = Vector3.new(0, 2.5, 0)
    local particle = Instance.new("ParticleEmitter", emitter)
    particle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particle.Color = ColorSequence.new(Color3.fromRGB(180, 230, 255))
    particle.Lifetime = NumberRange.new(0.6, 1.2)
    particle.Rate = 30
    particle.Speed = NumberRange.new(8, 12)
    particle.SpreadAngle = Vector2.new(20, 20)
    particle.Acceleration = Vector3.new(0, -20, 0)
    particle.Size = NumberSequence.new(0.4)

    print(string.format("[CityPolishV2 v1] %d objects placed: street-aligned cars + lamps + window NPCs + neon shops + plaza fountain",
        #container:GetChildren()))
end)
