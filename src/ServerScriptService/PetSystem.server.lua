-- PetSystem.server.lua  v1 — small primitive cat companion that floats
-- above the player's left shoulder. One pet at a time, equip/unequip via
-- RequestEquipPet RemoteFunction. Pet kinds defined in PET_KINDS table —
-- starter free, premium gated by VIP gamepass.
--
-- Design constraint: no new mesh assets. Pet built from primitives like
-- the cat character, scaled down ~0.4. Welded to HumanoidRootPart for
-- physics-safe follow.

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local Remotes    = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local function ensureRemote(name, kind)
    local folder = ReplicatedStorage:FindFirstChild("RemoteEventsFolder")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "RemoteEventsFolder"
        folder.Parent = ReplicatedStorage
    end
    local existing = folder:FindFirstChild(name)
    if existing then return existing end
    local r = Instance.new(kind)
    r.Name = name; r.Parent = folder
    return r
end
local RequestEquipPet = ensureRemote("RequestEquipPet", "RemoteFunction")
local RequestListPets = ensureRemote("RequestListPets", "RemoteFunction")

local PET_KINDS = {
    none      = nil,  -- unequip
    Mouse     = {furColor = Color3.fromRGB(170, 170, 170), gated = nil},
    Robin     = {furColor = Color3.fromRGB(220, 100, 80),  gated = nil},
    GoldFinch = {furColor = Color3.fromRGB(245, 200, 90),  gated = "VIP"},
    Pearl     = {furColor = Color3.fromRGB(245, 240, 250), gated = "VIP"},
    Ember     = {furColor = Color3.fromRGB(255, 130, 60),  gated = "ULTIMATE_CHAOS"},
}

local DataHandler
task.spawn(function()
    while not _G.KittyRaiserData do task.wait() end
    DataHandler = _G.KittyRaiserData
end)

local function ownsGamepass(player, key)
    if not key then return true end
    local id = GameConfig.GAMEPASS_IDS and GameConfig.GAMEPASS_IDS[key]
    if not id or id == 0 then return false end
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
    end)
    return ok and owns
end

local function newPart(props)
    local p = Instance.new("Part")
    p.Anchored = false; p.CanCollide = false; p.Massless = true
    p.Material = Enum.Material.SmoothPlastic
    p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
    for k, v in pairs(props) do p[k] = v end
    return p
end

local function buildPet(character, kind)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local def = PET_KINDS[kind]
    if not def then return end
    -- Anchor: tiny invisible part welded above and beside the cat's head.
    local anchor = newPart{
        Name = "PetAnchor",
        Size = Vector3.new(0.4, 0.4, 0.4),
        Transparency = 1,
    }
    anchor.CFrame = hrp.CFrame * CFrame.new(-1.4, 1.6, -0.6)
    anchor.Parent = character
    local w = Instance.new("WeldConstraint", anchor)
    w.Part0 = hrp; w.Part1 = anchor
    anchor:SetAttribute("KittyPet", true)
    anchor:SetAttribute("PetKind", kind)

    local body = newPart{
        Name = "PetBody",
        Shape = Enum.PartType.Ball,
        Size = Vector3.new(0.7, 0.6, 0.9),
        Color = def.furColor,
    }
    body.CFrame = anchor.CFrame
    body.Parent = character
    local bw = Instance.new("WeldConstraint", body); bw.Part0 = anchor; bw.Part1 = body
    body:SetAttribute("KittyPet", true)

    local head = newPart{
        Name = "PetHead",
        Shape = Enum.PartType.Ball,
        Size = Vector3.new(0.55, 0.55, 0.55),
        Color = def.furColor,
    }
    head.CFrame = anchor.CFrame * CFrame.new(0, 0.15, -0.45)
    head.Parent = character
    local hw = Instance.new("WeldConstraint", head); hw.Part0 = anchor; hw.Part1 = head
    head:SetAttribute("KittyPet", true)

    -- Two tiny eyes (white sclera + neon green pupil)
    for _, sx in ipairs({-1, 1}) do
        local eye = newPart{
            Name = "PetEye",
            Shape = Enum.PartType.Ball,
            Size = Vector3.new(0.14, 0.14, 0.14),
            Color = Color3.fromRGB(255, 255, 255),
        }
        eye.CFrame = head.CFrame * CFrame.new(sx * 0.14, 0.05, -0.22)
        eye.Parent = character
        local ew = Instance.new("WeldConstraint", eye); ew.Part0 = head; ew.Part1 = eye
        eye:SetAttribute("KittyPet", true)
    end
    -- Tail (single segment)
    local tail = newPart{
        Name = "PetTail",
        Size = Vector3.new(0.18, 0.18, 0.5),
        Color = def.furColor,
    }
    tail.CFrame = body.CFrame * CFrame.new(0, 0.1, 0.4) * CFrame.Angles(math.rad(-25), 0, 0)
    tail.Parent = character
    local tw = Instance.new("WeldConstraint", tail); tw.Part0 = body; tw.Part1 = tail
    tail:SetAttribute("KittyPet", true)

    -- Idle bob: subtle Y oscillation via Heartbeat on the anchor weld offset.
    -- Cheap (1 character per active pet).
    local RunService = game:GetService("RunService")
    local conn
    local startT = os.clock()
    conn = RunService.Heartbeat:Connect(function()
        if not anchor.Parent then if conn then conn:Disconnect() end; return end
        local theta = (os.clock() - startT) * 3
        anchor.CFrame = hrp.CFrame * CFrame.new(-1.4, 1.6 + math.sin(theta) * 0.15, -0.6)
            * CFrame.Angles(0, math.sin(theta * 0.7) * math.rad(15), 0)
    end)
end

local function clearPet(character)
    if not character then return end
    for _, c in ipairs(character:GetChildren()) do
        if c:IsA("BasePart") and c:GetAttribute("KittyPet") then
            c:Destroy()
        end
    end
end

local function applyPet(player, kind)
    local char = player.Character
    if not char then return end
    clearPet(char)
    if kind ~= "none" and PET_KINDS[kind] then
        buildPet(char, kind)
    end
end

RequestEquipPet.OnServerInvoke = function(player, kind)
    if typeof(kind) ~= "string" or PET_KINDS[kind] == nil and kind ~= "none" then
        return false, "invalid_kind"
    end
    local def = PET_KINDS[kind]
    if def and def.gated and not ownsGamepass(player, def.gated) then
        if Remotes.NotifyClient then
            Remotes.NotifyClient:FireClient(player,
                "PET LOCKED  -  needs " .. def.gated .. " gamepass", "warn")
        end
        return false, "no_pass"
    end
    if not DataHandler then return false, "data_loading" end
    DataHandler.modify(player, function(d)
        d.equippedPet = kind
    end)
    applyPet(player, kind)
    return true
end

RequestListPets.OnServerInvoke = function(player)
    local list = {}
    for k, _ in pairs(PET_KINDS) do
        if k ~= "none" then table.insert(list, k) end
    end
    table.sort(list)
    return list
end

-- Re-equip on respawn so the pet survives death.
local function watchSpawn(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        if not DataHandler then return end
        local d = DataHandler.getData(player)
        if d and d.equippedPet then
            applyPet(player, d.equippedPet)
        end
    end)
end
Players.PlayerAdded:Connect(watchSpawn)
for _, p in ipairs(Players:GetPlayers()) do watchSpawn(p) end

print("[PetSystem v1] online — " .. (function()
    local n = 0; for _ in pairs(PET_KINDS) do n = n + 1 end; return n
end)() .. " pet kinds")
