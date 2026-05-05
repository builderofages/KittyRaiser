-- CityDensityBoost.server.lua  v1
-- Scatters parked cars + city props + building clusters across the map so the
-- city feels DENSE instead of barren. Uses v2 city mesh templates from
-- _G.KittyRaiserMeshes when available, falls back to colored boxes.
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getMesh(name)
    local cache = _G.KittyRaiserMeshes
    if cache and cache[name] and cache[name].meshTemplate then
        return cache[name].meshTemplate
    end
    return nil
end

-- Wait for MeshLoader cache
task.spawn(function()
    for _ = 1, 30 do
        if _G.KittyRaiserMeshes then break end
        task.wait(0.5)
    end

    local container = Workspace:FindFirstChild("CityDensityBoost") or Instance.new("Folder")
    container.Name = "CityDensityBoost"
    container:ClearAllChildren()
    container.Parent = Workspace

    local function placeMesh(meshName, position, size, rotY, color)
        local m = getMesh(meshName)
        local p
        if m then
            p = m:Clone()
            p.Anchored = true; p.CanCollide = true
            if size then p.Size = size end
        else
            p = Instance.new("Part")
            p.Anchored = true; p.CanCollide = true
            p.Size = size or Vector3.new(6, 3, 12)
            p.Material = Enum.Material.SmoothPlastic
            p.Color = color or Color3.fromRGB(120, 100, 90)
        end
        p.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotY or 0), 0)
        p.Parent = container
        return p
    end

    local rng = Random.new(2026)

    -- 1. PARKED CARS along sidewalks (40 cars total)
    local CAR_MESHES = {"mesh_taxi_yellow", "mesh_delivery_van", "mesh_food_truck", "mesh_cop_car", "mesh_fire_truck"}
    for i = 1, 40 do
        local x = rng:NextNumber(-600, 600)
        local z = rng:NextNumber(-600, 600)
        -- skip plaza center
        if math.abs(x) > 80 or math.abs(z) > 80 then
            local meshName = CAR_MESHES[((i - 1) % #CAR_MESHES) + 1]
            placeMesh(meshName, Vector3.new(x, 2, z), Vector3.new(6, 3, 12),
                rng:NextInteger(0, 360))
        end
    end

    -- 2. STREET PROPS — fire hydrants, mailboxes, trash cans, traffic lights, lamps
    local PROP_MESHES = {
        {name = "mesh_fire_hydrant",    size = Vector3.new(1.2, 2.4, 1.2),  color = Color3.fromRGB(200, 40, 40)},
        {name = "mesh_mailbox_blue",    size = Vector3.new(1.5, 2.5, 1.5),  color = Color3.fromRGB(40, 80, 180)},
        {name = "mesh_trash_can",       size = Vector3.new(1.5, 2.4, 1.5),  color = Color3.fromRGB(60, 60, 60)},
        {name = "mesh_traffic_light",   size = Vector3.new(1, 8, 1),        color = Color3.fromRGB(60, 50, 30)},
        {name = "mesh_streetlamp",      size = Vector3.new(1, 7, 1),        color = Color3.fromRGB(80, 70, 60)},
        {name = "mesh_park_bench",      size = Vector3.new(4, 1.5, 1.5),    color = Color3.fromRGB(140, 100, 60)},
        {name = "mesh_hot_dog_cart",    size = Vector3.new(3, 4, 2),        color = Color3.fromRGB(200, 60, 50)},
        {name = "mesh_bus_stop_shelter",size = Vector3.new(6, 5, 2),        color = Color3.fromRGB(120, 120, 130)},
    }
    for i = 1, 80 do
        local x = rng:NextNumber(-700, 700)
        local z = rng:NextNumber(-700, 700)
        if math.abs(x) > 60 or math.abs(z) > 60 then
            local prop = PROP_MESHES[rng:NextInteger(1, #PROP_MESHES)]
            placeMesh(prop.name, Vector3.new(x, prop.size.Y / 2, z), prop.size, rng:NextInteger(0, 360), prop.color)
        end
    end

    -- 3. SKYSCRAPER CLUSTERS — 6 zones with 4 skyscraper_chunks each in 2x2 grid
    local CITY_ZONES = {
        Vector3.new( 350,  0,  350), Vector3.new(-350,  0,  350),
        Vector3.new( 350,  0, -350), Vector3.new(-350,  0, -350),
        Vector3.new( 600,  0,    0), Vector3.new(-600,  0,    0),
    }
    for _, center in ipairs(CITY_ZONES) do
        for ix = -1, 1, 2 do
            for iz = -1, 1, 2 do
                local pos = center + Vector3.new(ix * 35, 12, iz * 35)
                placeMesh("mesh_skyscraper_chunk",
                    pos,
                    Vector3.new(28, 24, 28),
                    rng:NextInteger(0, 4) * 90,
                    Color3.fromRGB(180, 170, 140))
            end
        end
    end

    -- 4. TREES sprinkled around (oak + palm)
    for i = 1, 60 do
        local x = rng:NextNumber(-700, 700)
        local z = rng:NextNumber(-700, 700)
        if math.abs(x) > 50 or math.abs(z) > 50 then
            local treeMesh = (i % 2 == 0) and "mesh_oak_tree" or "mesh_palm_tree"
            placeMesh(treeMesh, Vector3.new(x, 4, z),
                Vector3.new(4, 8, 4),
                rng:NextInteger(0, 360),
                Color3.fromRGB(60, 110, 50))
        end
    end

    print(string.format("[CityDensityBoost] placed: 40 cars + 80 street props + 24 skyscrapers + 60 trees = %d total objects",
        #container:GetChildren()))
end)

print("[CityDensityBoost v1] online — boosting city density at boot")
