-- StreetVendors.server.lua  v3.99.12
-- Adds 12 street vendors + 24 storefront signs around plaza perimeter to make city feel alive.
local Workspace = game:GetService("Workspace")
local folder = Workspace:FindFirstChild("StreetVendors") or Instance.new("Folder", Workspace)
folder.Name = "StreetVendors"
folder:ClearAllChildren()

local VENDOR_SPOTS = {
    {pos = Vector3.new( 80, 1,  80), kind = "HOT_DOGS"},  {pos = Vector3.new(-80, 1,  80), kind = "PRETZELS"},
    {pos = Vector3.new( 80, 1, -80), kind = "COFFEE"},    {pos = Vector3.new(-80, 1, -80), kind = "NEWSPAPER"},
    {pos = Vector3.new(150, 1,   0), kind = "ICE_CREAM"}, {pos = Vector3.new(-150, 1,  0), kind = "FLOWERS"},
    {pos = Vector3.new(  0, 1, 150), kind = "FRUIT"},     {pos = Vector3.new(  0, 1,-150), kind = "BOOKS"},
    {pos = Vector3.new(220, 1,  60), kind = "TACOS"},     {pos = Vector3.new(-220, 1, 60), kind = "WAFFLES"},
    {pos = Vector3.new(220, 1, -60), kind = "DONUTS"},    {pos = Vector3.new(-220, 1,-60), kind = "PIZZA"},
}

local function makeVendor(spot)
    local cart = Instance.new("Part", folder)
    cart.Name = "Vendor_" .. spot.kind
    cart.Size = Vector3.new(6, 5, 4)
    cart.Position = spot.pos + Vector3.new(0, 2.5, 0)
    cart.Material = Enum.Material.SmoothPlastic
    cart.Anchored = true
    cart.CanCollide = true
    cart.Color = Color3.fromHSV(math.random(0, 100)/100, 0.7, 0.85)
    -- Awning roof
    local roof = Instance.new("Part", folder)
    roof.Size = Vector3.new(8, 0.4, 6)
    roof.Position = spot.pos + Vector3.new(0, 5.4, 0)
    roof.Material = Enum.Material.Fabric
    roof.Color = Color3.fromHSV(math.random(0, 100)/100, 0.5, 0.9)
    roof.Anchored = true
    roof.CanCollide = false
    -- Sign
    local sign = Instance.new("BillboardGui", cart)
    sign.Size = UDim2.new(0, 140, 0, 40)
    sign.StudsOffset = Vector3.new(0, 4, 0)
    sign.AlwaysOnTop = true
    sign.MaxDistance = 60
    local lbl = Instance.new("TextLabel", sign)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 0.3
    lbl.BackgroundColor3 = Color3.fromRGB(20, 14, 10)
    lbl.TextColor3 = Color3.fromRGB(255, 220, 120)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    lbl.Text = spot.kind:gsub("_", " ")
end

for _, spot in ipairs(VENDOR_SPOTS) do
    pcall(makeVendor, spot)
end

-- 24 storefront signs around plaza perimeter (240-stud radius)
local SIGNS = {"DELI", "BAKERY", "PIZZA", "CAFE", "DINER", "MARKET", "PHARMACY", "BARBER",
    "GYM", "BANK", "OFFICE", "HOTEL", "NAILS", "VAPE", "PETS", "FLORIST",
    "LAUNDRY", "TACOS", "ICE CREAM", "COFFEE", "BURGER", "SUSHI", "DRY CLEAN", "REPAIR"}
for i, name in ipairs(SIGNS) do
    local angle = (i - 1) / #SIGNS * math.pi * 2
    local r = 240
    local x = math.cos(angle) * r
    local z = math.sin(angle) * r
    local sign = Instance.new("Part", folder)
    sign.Name = "Sign_" .. name
    sign.Size = Vector3.new(10, 2.5, 0.3)
    sign.Position = Vector3.new(x, 8, z)
    sign.Material = Enum.Material.Neon
    sign.Color = Color3.fromHSV(math.random(0, 100)/100, 0.7, 0.95)
    sign.Anchored = true
    sign.CanCollide = false
    -- Face toward plaza center
    sign.CFrame = CFrame.new(Vector3.new(x, 8, z), Vector3.new(0, 8, 0))
    -- Sign text
    local sg = Instance.new("SurfaceGui", sign)
    sg.Face = Enum.NormalId.Front
    sg.LightInfluence = 0
    sg.AlwaysOnTop = false
    local lbl = Instance.new("TextLabel", sg)
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextScaled = true
    lbl.Text = name
    -- Glow
    local light = Instance.new("PointLight", sign)
    light.Color = sign.Color
    light.Range = 14
    light.Brightness = 1.5
end

print(string.format("[StreetVendors v3.99.12] %d vendors + %d shop signs around plaza", #VENDOR_SPOTS, #SIGNS))
