-- TerrainBiome.server.lua  v1
-- Replaces the flat baseplate with proper Terrain — grass biome under city, asphalt
-- roads in cardinal directions, water in fountain pools. Runs once on server boot.
local Workspace = game:GetService("Workspace")
local terrain = Workspace.Terrain

task.spawn(function()
    task.wait(2)  -- let CityRebuild place plaza first
    -- 1. Big grass region under everything
    local grassRegion = Region3.new(Vector3.new(-800, -2, -800), Vector3.new(800, 2, 800))
    grassRegion = grassRegion:ExpandToGrid(4)
    terrain:FillRegion(grassRegion, 4, Enum.Material.Grass)

    -- 2. Asphalt cross roads at the cardinal axes (40-stud wide)
    for _, axis in ipairs({"x", "z"}) do
        local r
        if axis == "x" then
            r = Region3.new(Vector3.new(-800, -1, -20), Vector3.new(800, 1, 20))
        else
            r = Region3.new(Vector3.new(-20, -1, -800), Vector3.new(20, 1, 800))
        end
        r = r:ExpandToGrid(4)
        terrain:FillRegion(r, 4, Enum.Material.Asphalt)
    end

    -- 3. Concrete plaza patch (60x60 around spawn)
    local plazaR = Region3.new(Vector3.new(-30, -1, -30), Vector3.new(30, 1, 30))
    plazaR = plazaR:ExpandToGrid(4)
    terrain:FillRegion(plazaR, 4, Enum.Material.Concrete)

    -- 4. Mid-ring sidewalks (cobblestone) at 60-80 stud band
    local function sidewalk(x1, z1, x2, z2)
        local r = Region3.new(Vector3.new(x1, -1, z1), Vector3.new(x2, 1, z2))
        r = r:ExpandToGrid(4)
        terrain:FillRegion(r, 4, Enum.Material.Cobblestone)
    end
    sidewalk(-100, 60, 100, 80)
    sidewalk(-100, -80, 100, -60)
    sidewalk(60, -100, 80, 100)
    sidewalk(-80, -100, -60, 100)

    print("[TerrainBiome v1] grass + asphalt cross + plaza concrete + cobblestone sidewalks generated")
end)
