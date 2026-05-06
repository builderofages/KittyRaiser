-- HousingSystem.server.lua  v1 — per-player apartment with furniture placement.
--
-- Architecture:
--   * Each player gets a 60x60 marble apartment in their own vertical shaft
--     at (player.UserId % 1000 * 100, 5000 + player.UserId % 1000 * 80, 0).
--   * Vertical separation 80 studs ensures rooms don't visually leak across.
--   * Apartment building entrance at (-1500, 5, -200) with 1 doorway pad.
--   * Touching the doorway teleports you to YOUR apartment.
--   * Furniture stored as {kind, x, y, z, rotY} in d.apartment.
--   * 10 furniture kinds, each ~free placement (0 cost) but capped at 30 pieces.
--   * Public-vs-private flag: data.apartmentPublic = true means others can visit.
--   * Server-validated: kind must be in catalog, position must be inside room
--     (clamped to +/-28 stud horizontal, 0..28 vertical).

local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local function ensureRemote(name, kind)
    local folder = ReplicatedStorage:FindFirstChild("RemoteEventsFolder")
    if not folder then
        folder = Instance.new("Folder"); folder.Name = "RemoteEventsFolder"; folder.Parent = ReplicatedStorage
    end
    local existing = folder:FindFirstChild(name)
    if existing then return existing end
    local r = Instance.new(kind); r.Name = name; r.Parent = folder
    return r
end
local RequestEnterHome    = ensureRemote("RequestEnterHome",     "RemoteFunction")
local RequestPlaceFurniture = ensureRemote("RequestPlaceFurniture", "RemoteFunction")
local RequestRemoveFurniture = ensureRemote("RequestRemoveFurniture", "RemoteFunction")
local RequestExitHome     = ensureRemote("RequestExitHome",      "RemoteFunction")
local RequestSetHomePublic = ensureRemote("RequestSetHomePublic", "RemoteFunction")
local RequestVisitPlayer  = ensureRemote("RequestVisitPlayer",   "RemoteFunction")

local DataHandler
task.spawn(function()
    while not _G.KittyRaiserData do task.wait() end
    DataHandler = _G.KittyRaiserData
end)

local FURNITURE = {
    cat_bed       = {size=Vector3.new(4, 2, 6),  color=Color3.fromRGB(220, 180, 150)},
    scratch_post  = {size=Vector3.new(2, 6, 2),  color=Color3.fromRGB(180, 130, 90)},
    food_bowl     = {size=Vector3.new(2, 1, 2),  color=Color3.fromRGB(220, 100, 80)},
    water_bowl    = {size=Vector3.new(2, 1, 2),  color=Color3.fromRGB(80, 160, 220)},
    cat_tower     = {size=Vector3.new(4, 12, 4), color=Color3.fromRGB(140, 100, 70)},
    hammock       = {size=Vector3.new(6, 1, 2),  color=Color3.fromRGB(220, 200, 170)},
    fish_tank     = {size=Vector3.new(4, 4, 2),  color=Color3.fromRGB(120, 180, 220)},
    treat_jar     = {size=Vector3.new(2, 3, 2),  color=Color3.fromRGB(220, 150, 60)},
    window_perch  = {size=Vector3.new(6, 1, 2),  color=Color3.fromRGB(180, 175, 165)},
    yarn_ball     = {size=Vector3.new(2, 2, 2),  color=Color3.fromRGB(220, 60, 60)},
}
local MAX_FURNITURE = 30

local apartmentFolder = Workspace:FindFirstChild("Apartments") or Instance.new("Folder", Workspace)
apartmentFolder.Name = "Apartments"

local activeApartments = {}  -- [uid] = {center, parts={}}

local function notify(p, msg, kind)
    if Remotes.NotifyClient then
        Remotes.NotifyClient:FireClient(p, msg, kind or "info")
    end
end

local function apartmentCenter(uid)
    -- Spread per-player apartments across a grid in the sky.
    local idx = uid % 1024
    local row = math.floor(idx / 32)
    local col = idx % 32
    return Vector3.new(col * 200 - 3000, 5000 + row * 80, -3000 + row * 200)
end

local function buildEmptyRoom(uid)
    local center = apartmentCenter(uid)
    local roomFolder = Instance.new("Folder", apartmentFolder)
    roomFolder.Name = "Apt_" .. uid
    -- Floor + ceiling + 4 walls (60x60 room)
    local floor = Instance.new("Part", roomFolder)
    floor.Anchored = true; floor.CanCollide = true
    floor.Size = Vector3.new(60, 1, 60)
    floor.Position = center + Vector3.new(0, -1, 0)
    floor.Material = Enum.Material.Marble
    floor.Color = Color3.fromRGB(225, 220, 205)
    local ceiling = Instance.new("Part", roomFolder)
    ceiling.Anchored = true; ceiling.CanCollide = true
    ceiling.Size = Vector3.new(60, 1, 60)
    ceiling.Position = center + Vector3.new(0, 30, 0)
    ceiling.Material = Enum.Material.SmoothPlastic
    ceiling.Color = Color3.fromRGB(180, 175, 165)
    for _, w in ipairs({
        {pos=center+Vector3.new( 0, 15,  30), size=Vector3.new(60, 30, 1)},
        {pos=center+Vector3.new( 0, 15, -30), size=Vector3.new(60, 30, 1)},
        {pos=center+Vector3.new( 30, 15, 0), size=Vector3.new(1, 30, 60)},
        {pos=center+Vector3.new(-30, 15, 0), size=Vector3.new(1, 30, 60)},
    }) do
        local wall = Instance.new("Part", roomFolder)
        wall.Anchored = true; wall.CanCollide = true
        wall.Size = w.size; wall.Position = w.pos
        wall.Material = Enum.Material.SmoothPlastic
        wall.Color = Color3.fromRGB(195, 175, 150)
    end
    -- Exit doorway
    local exitDoor = Instance.new("Part", roomFolder)
    exitDoor.Name = "ExitDoor"
    exitDoor.Anchored = true; exitDoor.CanCollide = false
    exitDoor.Size = Vector3.new(8, 12, 1)
    exitDoor.Position = center + Vector3.new(0, 6, 29)
    exitDoor.Material = Enum.Material.Wood
    exitDoor.Color = Color3.fromRGB(180, 140, 90)
    exitDoor.Transparency = 0.3
    local g = Instance.new("BillboardGui", exitDoor)
    g.Size = UDim2.new(0, 100, 0, 30)
    g.StudsOffset = Vector3.new(0, 8, 0)
    g.AlwaysOnTop = true
    local lbl = Instance.new("TextLabel", g)
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text = "EXIT"
    lbl.Font = Enum.Font.LuckiestGuy
    lbl.TextScaled = true
    lbl.TextColor3 = Color3.fromRGB(255, 240, 200)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)
    -- Exit teleport
    local exitFlag = {}
    exitDoor.Touched:Connect(function(hit)
        local model = hit:FindFirstAncestorOfClass("Model")
        local p = model and Players:GetPlayerFromCharacter(model)
        if not p or exitFlag[p.UserId] then return end
        exitFlag[p.UserId] = true
        if model.PrimaryPart then
            model:PivotTo(CFrame.new(-1490, 5, -200))
        end
        task.delay(2, function() exitFlag[p.UserId] = nil end)
    end)
    return roomFolder, center
end

local function spawnFurniture(roomFolder, center, kind, lx, ly, lz, rotY)
    local def = FURNITURE[kind]
    if not def then return nil end
    local part = Instance.new("Part", roomFolder)
    part.Name = "Furniture_" .. kind
    part.Anchored = true; part.CanCollide = true
    part.Size = def.size
    part.CFrame = CFrame.new(center + Vector3.new(lx, ly + def.size.Y/2, lz))
        * CFrame.Angles(0, math.rad(rotY or 0), 0)
    part.Color = def.color
    part.Material = Enum.Material.SmoothPlastic
    part:SetAttribute("FurnitureKind", kind)
    return part
end

local function rebuildApartment(uid, includeFurniture)
    -- Clear if exists
    local existing = apartmentFolder:FindFirstChild("Apt_" .. uid)
    if existing then existing:Destroy() end
    local roomFolder, center = buildEmptyRoom(uid)
    activeApartments[uid] = {center=center, folder=roomFolder}
    -- Place furniture from data
    if includeFurniture and DataHandler then
        local p = Players:GetPlayerByUserId(uid)
        if p then
            local data = DataHandler.getData(p)
            if data and data.apartment then
                for _, item in ipairs(data.apartment) do
                    spawnFurniture(roomFolder, center, item.kind, item.x, item.y, item.z, item.rotY)
                end
            end
        end
    end
    return roomFolder, center
end

-- =====================================================================
-- HANDLERS
-- =====================================================================
RequestEnterHome.OnServerInvoke = function(player)
    if not DataHandler then return false, "data_loading" end
    local roomFolder, center = rebuildApartment(player.UserId, true)
    if player.Character then
        player.Character:PivotTo(CFrame.new(center + Vector3.new(0, 4, 0)))
    end
    return true
end

RequestExitHome.OnServerInvoke = function(player)
    if player.Character then
        player.Character:PivotTo(CFrame.new(-1490, 5, -200))
    end
    return true
end

RequestPlaceFurniture.OnServerInvoke = function(player, kind, x, y, z, rotY)
    if not DataHandler then return false, "data_loading" end
    if typeof(kind) ~= "string" or not FURNITURE[kind] then return false, "invalid_kind" end
    if typeof(x) ~= "number" or typeof(y) ~= "number" or typeof(z) ~= "number" then
        return false, "invalid_pos"
    end
    -- Clamp inside the room
    x = math.clamp(x, -28, 28); z = math.clamp(z, -28, 28); y = math.clamp(y, 0, 28)
    rotY = math.clamp(rotY or 0, 0, 360)
    local data = DataHandler.getData(player)
    if not data then return false, "data_loading" end
    data.apartment = data.apartment or {}
    if #data.apartment >= MAX_FURNITURE then return false, "too_many" end
    DataHandler.modify(player, function(d)
        d.apartment = d.apartment or {}
        table.insert(d.apartment, {kind=kind, x=x, y=y, z=z, rotY=rotY})
    end)
    -- If apartment is currently active, spawn the new piece live
    local apt = activeApartments[player.UserId]
    if apt then spawnFurniture(apt.folder, apt.center, kind, x, y, z, rotY) end
    return true
end

RequestRemoveFurniture.OnServerInvoke = function(player, idx)
    if not DataHandler then return false, "data_loading" end
    if typeof(idx) ~= "number" then return false, "invalid_idx" end
    local data = DataHandler.getData(player)
    if not data or not data.apartment or not data.apartment[idx] then
        return false, "no_such_item"
    end
    DataHandler.modify(player, function(d)
        if d.apartment then table.remove(d.apartment, idx) end
    end)
    -- Re-render apartment
    rebuildApartment(player.UserId, true)
    return true
end

RequestSetHomePublic.OnServerInvoke = function(player, isPublic)
    if not DataHandler then return false, "data_loading" end
    DataHandler.modify(player, function(d)
        d.apartmentPublic = isPublic and true or false
    end)
    return true
end

RequestVisitPlayer.OnServerInvoke = function(player, targetUid)
    if not DataHandler then return false, "data_loading" end
    if typeof(targetUid) ~= "number" then return false, "invalid_target" end
    local target = Players:GetPlayerByUserId(targetUid)
    if not target then return false, "target_offline" end
    local tdata = DataHandler.getData(target)
    if not tdata or not tdata.apartmentPublic then return false, "private" end
    rebuildApartment(targetUid, true)
    if player.Character then
        local center = apartmentCenter(targetUid)
        player.Character:PivotTo(CFrame.new(center + Vector3.new(0, 4, 0)))
    end
    return true
end

-- =====================================================================
-- APARTMENT BUILDING ENTRANCE
-- =====================================================================
local entrance = Instance.new("Part", Workspace)
entrance.Name = "ApartmentEntranceDoor"
entrance.Anchored = true; entrance.CanCollide = false
entrance.Size = Vector3.new(8, 12, 1)
entrance.Position = Vector3.new(-1500, 5, -200)
entrance.Material = Enum.Material.Wood
entrance.Color = Color3.fromRGB(180, 140, 90)
entrance.Transparency = 0.2
local sg = Instance.new("BillboardGui", entrance)
sg.Size = UDim2.new(0, 200, 0, 50)
sg.StudsOffset = Vector3.new(0, 8, 0)
local lbl = Instance.new("TextLabel", sg)
lbl.Size = UDim2.fromScale(1, 1)
lbl.BackgroundTransparency = 1
lbl.Text = "YOUR APARTMENT"
lbl.Font = Enum.Font.LuckiestGuy
lbl.TextScaled = true
lbl.TextColor3 = Color3.fromRGB(255, 240, 200)
lbl.TextStrokeTransparency = 0
lbl.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)

local enterFlag = {}
entrance.Touched:Connect(function(hit)
    local model = hit:FindFirstAncestorOfClass("Model")
    local p = model and Players:GetPlayerFromCharacter(model)
    if not p or enterFlag[p.UserId] then return end
    enterFlag[p.UserId] = true
    local _, center = rebuildApartment(p.UserId, true)
    if model.PrimaryPart then
        model:PivotTo(CFrame.new(center + Vector3.new(0, 4, 0)))
    end
    task.delay(2, function() enterFlag[p.UserId] = nil end)
end)

print("[HousingSystem v1] online - per-player apartments, " .. (function()
    local n = 0; for _ in pairs(FURNITURE) do n = n + 1 end; return n
end)() .. " furniture kinds, max " .. MAX_FURNITURE .. " pieces")
