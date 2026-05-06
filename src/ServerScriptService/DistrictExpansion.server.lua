-- DistrictExpansion.server.lua  v1 — 4-district city.
--
-- Phase-13 directive: "huge city" with 4 distinct neighborhoods around the
-- existing Downtown core. Each district is a 1200-stud square offset from
-- the central plaza. Each gets a unique palette + landmark + entry banner.
-- Total map footprint becomes ~3600 studs (was ~1400).
--
--   DOWNTOWN     +X, +Z  — existing CityRebuild core (skyscrapers)
--   CHINATOWN    -X, +Z  — red lanterns + low-rise + neon signs (warm only)
--   BROOKLYN     +X, -Z  — brownstones + parks + jogger archetypes
--   CENTRAL_PARK -X, -Z  — open green + lake + benches + trees + lake
--
-- Adds 4 LANDMARKS visible from the plaza:
--   Empire-State-style spire at (+1200, height, +1200)
--   Brooklyn-Bridge-style suspension cables at (+1200, 50, -1200)
--   Chinatown gate arch at (-1200, 30, +1200)
--   Park lake + sculpture at (-1200, 5, -1200)

local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds
do
    local m = ReplicatedStorage:FindFirstChild("Modules")
    local mod = m and m:FindFirstChild("AssetIds")
    if mod then local ok, ai = pcall(require, mod); if ok then AssetIds = ai end end
end

local function getMesh(name)
    local cache = _G.KittyRaiserMeshes
    if cache and cache[name] and cache[name].meshTemplate then
        return cache[name].meshTemplate
    end
    return nil
end

local districtFolder = Workspace:FindFirstChild("Districts") or Instance.new("Folder", Workspace)
districtFolder.Name = "Districts"
districtFolder:ClearAllChildren()

-- =====================================================================
-- DISTRICT DEFINITIONS
-- =====================================================================
local DISTRICTS = {
    CHINATOWN = {
        center = Vector3.new(-1200, 0, 1200),
        groundColor = Color3.fromRGB(180, 130, 100),
        groundMaterial = Enum.Material.Cobblestone,
        buildingPalette = {
            Color3.fromRGB(195, 80, 70),    -- red lacquer
            Color3.fromRGB(220, 165, 90),   -- mustard yellow
            Color3.fromRGB(160, 100, 80),   -- terracotta
            Color3.fromRGB(120, 80, 70),    -- darker brick
        },
        heightRange = {30, 80},
        signNames = {"DRAGON BAO","JADE NOODLE","RED LANTERN","GOLD WOK","SILK ROAD"},
    },
    BROOKLYN = {
        center = Vector3.new(1200, 0, -1200),
        groundColor = Color3.fromRGB(140, 110, 90),
        groundMaterial = Enum.Material.Brick,
        buildingPalette = {
            Color3.fromRGB(170, 110, 80),   -- warm brick
            Color3.fromRGB(195, 145, 105),  -- brownstone tan
            Color3.fromRGB(140, 100, 75),   -- darker brick
            Color3.fromRGB(180, 130, 95),   -- adobe
        },
        heightRange = {25, 60},
        signNames = {"COFFEE LAB","BROOK DELI","HIPSTER YOGA","VINYL CO","ARTISAN BREW"},
    },
    CENTRAL_PARK = {
        center = Vector3.new(-1200, 0, -1200),
        groundColor = Color3.fromRGB(95, 145, 80),
        groundMaterial = Enum.Material.Grass,
        buildingPalette = {  -- few buildings; mostly trees
            Color3.fromRGB(160, 120, 95),
            Color3.fromRGB(140, 110, 85),
        },
        heightRange = {10, 25},
        signNames = {"PARK CAFE","PICNIC HUT","BOATHOUSE"},
    },
}

-- =====================================================================
-- HELPERS
-- =====================================================================
local function makePart(props)
    local p = Instance.new("Part")
    p.Anchored = true; p.CanCollide = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    for k, v in pairs(props) do p[k] = v end
    p.Parent = districtFolder
    return p
end

local function makeGroundPatch(district)
    local p = Instance.new("Part", districtFolder)
    p.Name = "Ground_" .. tostring(district.center)
    p.Anchored = true; p.CanCollide = true
    p.Size = Vector3.new(1100, 1, 1100)
    p.Position = district.center + Vector3.new(0, 0.5, 0)
    p.Material = district.groundMaterial
    p.Color = district.groundColor
    p.TopSurface = Enum.SurfaceType.Smooth
end

local function placeBuildings(district, name)
    local rng = Random.new(name == "CHINATOWN" and 11 or name == "BROOKLYN" and 22 or 33)
    -- 6x6 grid in district
    for gx = -3, 2 do
        for gz = -3, 2 do
            -- Skip center 2x2 for landmark
            if math.abs(gx) <= 1 and math.abs(gz) <= 1 then continue end
            local h = rng:NextInteger(district.heightRange[1], district.heightRange[2])
            local color = district.buildingPalette[rng:NextInteger(1, #district.buildingPalette)]
            local cx = district.center.X + (gx + 0.5) * 160 + rng:NextInteger(-15, 15)
            local cz = district.center.Z + (gz + 0.5) * 160 + rng:NextInteger(-15, 15)
            local b = makePart{
                Name = name .. "_Building",
                Size = Vector3.new(60 + rng:NextInteger(-10, 10), h, 60 + rng:NextInteger(-10, 10)),
                Position = Vector3.new(cx, h/2 + 1, cz),
                Color = color,
                Material = (name == "CENTRAL_PARK") and Enum.Material.Wood or Enum.Material.Brick,
            }
            b:SetAttribute("Zone", name:lower())
            -- Storefront sign 30% chance (if there are signNames)
            if district.signNames and #district.signNames > 0 and rng:NextNumber() < 0.30 then
                local face = (rng:NextInteger(1, 2) == 1) and Enum.NormalId.Front or Enum.NormalId.Back
                local sg = Instance.new("SurfaceGui", b)
                sg.Face = face
                sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
                sg.CanvasSize = Vector2.new(640, 200)
                sg.LightInfluence = 1
                local container = Instance.new("Frame", sg)
                container.Size = UDim2.new(0.7, 0, 0.12, 0)
                container.Position = UDim2.new(0.15, 0, 0.42, 0)
                container.BackgroundColor3 = color
                container.BackgroundTransparency = 0.1
                Instance.new("UICorner", container).CornerRadius = UDim.new(0, 4)
                local stroke = Instance.new("UIStroke", container)
                stroke.Thickness = 2; stroke.Color = Color3.fromRGB(40, 25, 10)
                local lbl = Instance.new("TextLabel", container)
                lbl.Size = UDim2.fromScale(1, 1)
                lbl.BackgroundTransparency = 1
                lbl.Text = district.signNames[rng:NextInteger(1, #district.signNames)]
                lbl.Font = Enum.Font.LuckiestGuy
                lbl.TextScaled = true
                lbl.TextColor3 = Color3.fromRGB(255, 240, 220)
                lbl.TextStrokeTransparency = 0.4
                lbl.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)
            end
        end
    end
end

local function placeChinatownGate(center)
    -- Gate arch: two vertical pillars + horizontal lintel + curved rooftop wedges
    local pillarL = makePart{
        Name = "ChinatownGate_PillarL",
        Size = Vector3.new(8, 40, 8),
        Position = center + Vector3.new(-25, 20, 0),
        Color = Color3.fromRGB(180, 60, 50),
        Material = Enum.Material.Wood,
    }
    pillarL:SetAttribute("Landmark", "ChinatownGate")
    local pillarR = makePart{
        Name = "ChinatownGate_PillarR",
        Size = Vector3.new(8, 40, 8),
        Position = center + Vector3.new(25, 20, 0),
        Color = Color3.fromRGB(180, 60, 50),
        Material = Enum.Material.Wood,
    }
    pillarR:SetAttribute("Landmark", "ChinatownGate")
    local lintel = makePart{
        Name = "ChinatownGate_Lintel",
        Size = Vector3.new(60, 6, 10),
        Position = center + Vector3.new(0, 38, 0),
        Color = Color3.fromRGB(220, 170, 70),
        Material = Enum.Material.Wood,
    }
    -- Pagoda-style roof
    local roof = makePart{
        Name = "ChinatownGate_Roof",
        Size = Vector3.new(72, 4, 14),
        Position = center + Vector3.new(0, 44, 0),
        Color = Color3.fromRGB(140, 50, 40),
        Material = Enum.Material.Wood,
    }
    -- Sign
    local signSG = Instance.new("SurfaceGui", lintel)
    signSG.Face = Enum.NormalId.Front
    signSG.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
    signSG.CanvasSize = Vector2.new(640, 64)
    signSG.LightInfluence = 1
    local lbl = Instance.new("TextLabel", signSG)
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text = "CHINATOWN"
    lbl.Font = Enum.Font.LuckiestGuy
    lbl.TextScaled = true
    lbl.TextColor3 = Color3.fromRGB(40, 25, 10)
    lbl.TextStrokeTransparency = 0.5
end

local function placeEmpireSpire(center)
    -- Center at +1200, +1200. 200-stud-tall spire.
    local base = makePart{
        Name = "EmpireSpire_Base",
        Size = Vector3.new(80, 30, 80),
        Position = center + Vector3.new(0, 15, 0),
        Color = Color3.fromRGB(170, 165, 160),
        Material = Enum.Material.Brick,
    }
    base:SetAttribute("Landmark", "EmpireSpire")
    local mid = makePart{
        Name = "EmpireSpire_Mid",
        Size = Vector3.new(60, 90, 60),
        Position = center + Vector3.new(0, 75, 0),
        Color = Color3.fromRGB(155, 150, 145),
        Material = Enum.Material.Brick,
    }
    local top = makePart{
        Name = "EmpireSpire_Top",
        Size = Vector3.new(40, 60, 40),
        Position = center + Vector3.new(0, 150, 0),
        Color = Color3.fromRGB(140, 135, 130),
        Material = Enum.Material.Brick,
    }
    local needle = makePart{
        Name = "EmpireSpire_Needle",
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(40, 6, 6),
        Position = center + Vector3.new(0, 200, 0),
        Color = Color3.fromRGB(90, 90, 100),
        Material = Enum.Material.Metal,
    }
    needle.CFrame = CFrame.new(needle.Position) * CFrame.Angles(0, 0, math.rad(90))
end

local function placeBrooklynBridge(center)
    -- Two large pylons + suspension cables (just thin parts at angles).
    local pylonA = makePart{
        Name = "BrooklynBridge_PylonA",
        Size = Vector3.new(20, 100, 20),
        Position = center + Vector3.new(-60, 50, 0),
        Color = Color3.fromRGB(160, 130, 110),
        Material = Enum.Material.Brick,
    }
    pylonA:SetAttribute("Landmark", "BrooklynBridge")
    local pylonB = makePart{
        Name = "BrooklynBridge_PylonB",
        Size = Vector3.new(20, 100, 20),
        Position = center + Vector3.new(60, 50, 0),
        Color = Color3.fromRGB(160, 130, 110),
        Material = Enum.Material.Brick,
    }
    -- Deck
    local deck = makePart{
        Name = "BrooklynBridge_Deck",
        Size = Vector3.new(160, 4, 30),
        Position = center + Vector3.new(0, 20, 0),
        Color = Color3.fromRGB(80, 75, 70),
        Material = Enum.Material.Concrete,
    }
    -- Suspension cables (decorative)
    for _, off in ipairs({-15, 15}) do
        local cable = makePart{
            Name = "BrooklynBridge_Cable",
            Shape = Enum.PartType.Cylinder,
            Size = Vector3.new(140, 0.6, 0.6),
            Position = center + Vector3.new(0, 80, off),
            Color = Color3.fromRGB(60, 55, 50),
            Material = Enum.Material.Metal,
            CanCollide = false,
        }
        cable.CFrame = CFrame.new(cable.Position) * CFrame.Angles(0, 0, math.rad(90))
    end
end

local function placeParkLake(center)
    -- Lake: large flat water disc + park benches around the edge.
    local lake = makePart{
        Name = "ParkLake",
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(2, 200, 200),
        Position = center + Vector3.new(0, 0.5, 0),
        Color = Color3.fromRGB(80, 140, 180),
        Material = Enum.Material.Water,
        Transparency = 0.2,
    }
    lake.CFrame = CFrame.new(lake.Position) * CFrame.Angles(0, 0, math.rad(90))
    lake:SetAttribute("Landmark", "ParkLake")
    -- Statue in center
    local statueBase = makePart{
        Name = "ParkStatue_Base",
        Size = Vector3.new(8, 10, 8),
        Position = center + Vector3.new(0, 5, 0),
        Color = Color3.fromRGB(180, 175, 165),
        Material = Enum.Material.Marble,
    }
    local statueBody = makePart{
        Name = "ParkStatue_Body",
        Shape = Enum.PartType.Ball,
        Size = Vector3.new(6, 8, 6),
        Position = center + Vector3.new(0, 14, 0),
        Color = Color3.fromRGB(180, 175, 165),
        Material = Enum.Material.Marble,
    }
    -- 5 trees
    local rng = Random.new(99)
    for i = 1, 12 do
        local theta = (i / 12) * math.pi * 2
        local r = 130 + rng:NextInteger(-20, 20)
        local trunk = makePart{
            Name = "ParkTree_Trunk",
            Size = Vector3.new(2, 8, 2),
            Position = center + Vector3.new(math.cos(theta) * r, 4, math.sin(theta) * r),
            Color = Color3.fromRGB(85, 55, 30),
            Material = Enum.Material.Wood,
        }
        local crown = makePart{
            Name = "ParkTree_Crown",
            Shape = Enum.PartType.Ball,
            Size = Vector3.new(8, 8, 8),
            Position = trunk.Position + Vector3.new(0, 8, 0),
            Color = Color3.fromRGB(95, 165, 80),
            Material = Enum.Material.Grass,
        }
    end
end

-- =====================================================================
-- BUILD
-- =====================================================================
task.spawn(function()
    -- Wait briefly for CityRebuild to settle
    task.wait(2)

    for name, district in pairs(DISTRICTS) do
        makeGroundPatch(district)
        placeBuildings(district, name)
    end
    placeChinatownGate(DISTRICTS.CHINATOWN.center)
    placeEmpireSpire(Vector3.new(1200, 0, 1200))  -- in default Downtown extension
    placeBrooklynBridge(DISTRICTS.BROOKLYN.center)
    placeParkLake(DISTRICTS.CENTRAL_PARK.center)
    print("[DistrictExpansion v1] 4 districts placed: Chinatown, Brooklyn, Central Park, plus Downtown spire")
end)
