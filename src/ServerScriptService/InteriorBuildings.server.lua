-- InteriorBuildings.server.lua  v1 — 4 enterable shops at plaza edges.
--
-- Each shop has a doorway TouchPart at street level. On Touch the player
-- character is teleported to a hidden interior at (shopX, 1000+idx*200, shopZ)
-- (each shop's interior lives in its own vertical shaft so they don't
-- collide). Inside: 3 vendor pads with ProximityPrompt 'BUY <ITEM>'.
--
-- Items each shop sells: cat food (+50 hunger), water (+50 thirst), medkit
-- (+50 HP), energy drink (+20 WalkSpeed for 30s).
-- Doorway inside teleports back to outside spawn near the shop.

local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local DataHandler
task.spawn(function()
    while not _G.KittyRaiserData do task.wait() end
    DataHandler = _G.KittyRaiserData
end)

local SHOPS = {
    {name="DELI",     door=Vector3.new( 220, 5,  0),    color=Color3.fromRGB(220, 150, 60)},
    {name="PHARMACY", door=Vector3.new(-220, 5,  0),    color=Color3.fromRGB(95, 165, 80)},
    {name="ARCADE",   door=Vector3.new( 0,   5,  220),  color=Color3.fromRGB(180, 80, 200)},
    {name="DINER",    door=Vector3.new( 0,   5, -220),  color=Color3.fromRGB(220, 60, 60)},
}

local ITEMS = {
    {id="cat_food", label="CAT FOOD",     cost=50,  effect="hunger", amount=50},
    {id="water",    label="WATER",        cost=30,  effect="thirst", amount=50},
    {id="medkit",   label="MEDKIT",       cost=200, effect="health", amount=50},
    {id="energy",   label="ENERGY DRINK", cost=300, effect="speed",  amount=20, duration=30},
}

local folder = Workspace:FindFirstChild("InteriorShops") or Instance.new("Folder", Workspace)
folder.Name = "InteriorShops"
folder:ClearAllChildren()

local function applyEffect(player, item)
    if not DataHandler then return false end
    local data = DataHandler.getData(player)
    if not data or (data.chaosPoints or 0) < item.cost then return false end
    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) - item.cost
        if item.effect == "hunger" then
            d.hunger = math.min(100, (d.hunger or 100) + item.amount)
        elseif item.effect == "thirst" then
            d.thirst = math.min(100, (d.thirst or 100) + item.amount)
        end
    end)
    if item.effect == "health" then
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = math.min(hum.MaxHealth, hum.Health + item.amount) end
    elseif item.effect == "speed" then
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            local prev = hum.WalkSpeed
            hum.WalkSpeed = prev + item.amount
            task.delay(item.duration, function()
                if hum.Parent then hum.WalkSpeed = prev end
            end)
        end
    end
    return true
end

local function notify(p, msg, kind)
    if Remotes.NotifyClient then
        Remotes.NotifyClient:FireClient(p, msg, kind or "info")
    end
end

local function buildShop(idx, shop)
    -- Outside doorway pad
    local door = Instance.new("Part", folder)
    door.Name = "ShopDoor_" .. shop.name
    door.Anchored = true; door.CanCollide = false
    door.Size = Vector3.new(8, 12, 1)
    door.Position = shop.door
    door.Material = Enum.Material.Wood
    door.Color = shop.color
    door.Transparency = 0.2
    local sg = Instance.new("BillboardGui", door)
    sg.Size = UDim2.new(0, 200, 0, 50)
    sg.StudsOffset = Vector3.new(0, 8, 0)
    local lbl = Instance.new("TextLabel", sg)
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text = shop.name
    lbl.Font = Enum.Font.LuckiestGuy
    lbl.TextScaled = true
    lbl.TextColor3 = Color3.fromRGB(255, 240, 200)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)

    -- Interior vertical shaft
    local interiorY = 1000 + idx * 200
    local interiorCenter = Vector3.new(shop.door.X, interiorY, shop.door.Z)

    -- Floor + ceiling + 4 walls (40x40 room)
    local floor = Instance.new("Part", folder)
    floor.Anchored = true; floor.CanCollide = true
    floor.Size = Vector3.new(40, 1, 40)
    floor.Position = interiorCenter + Vector3.new(0, -1, 0)
    floor.Material = Enum.Material.Marble
    floor.Color = Color3.fromRGB(220, 215, 200)

    local ceiling = Instance.new("Part", folder)
    ceiling.Anchored = true; ceiling.CanCollide = true
    ceiling.Size = Vector3.new(40, 1, 40)
    ceiling.Position = interiorCenter + Vector3.new(0, 14, 0)
    ceiling.Material = Enum.Material.SmoothPlastic
    ceiling.Color = Color3.fromRGB(180, 175, 165)

    for _, wallSpec in ipairs({
        {pos=interiorCenter+Vector3.new( 0, 7,  20), size=Vector3.new(40, 16, 1)},
        {pos=interiorCenter+Vector3.new( 0, 7, -20), size=Vector3.new(40, 16, 1)},
        {pos=interiorCenter+Vector3.new( 20, 7, 0), size=Vector3.new(1, 16, 40)},
        {pos=interiorCenter+Vector3.new(-20, 7, 0), size=Vector3.new(1, 16, 40)},
    }) do
        local w = Instance.new("Part", folder)
        w.Anchored = true; w.CanCollide = true
        w.Size = wallSpec.size; w.Position = wallSpec.pos
        w.Material = Enum.Material.Brick
        w.Color = shop.color:Lerp(Color3.new(0.3, 0.2, 0.1), 0.5)
    end

    -- Vendor pads (4 items)
    for vIdx, item in ipairs(ITEMS) do
        local pad = Instance.new("Part", folder)
        pad.Anchored = true; pad.CanCollide = true
        pad.Size = Vector3.new(4, 4, 4)
        pad.Position = interiorCenter + Vector3.new((vIdx - 2.5) * 8, 2, -10)
        pad.Material = Enum.Material.SmoothPlastic
        pad.Color = Color3.fromRGB(200, 175, 130)
        local label = Instance.new("BillboardGui", pad)
        label.Size = UDim2.new(0, 120, 0, 40)
        label.StudsOffset = Vector3.new(0, 4, 0)
        label.AlwaysOnTop = true
        local txt = Instance.new("TextLabel", label)
        txt.Size = UDim2.fromScale(1, 1)
        txt.BackgroundTransparency = 1
        txt.Text = item.label .. "\n" .. item.cost .. " CHAOS"
        txt.Font = Enum.Font.GothamBold
        txt.TextScaled = true
        txt.TextColor3 = Color3.fromRGB(80, 40, 20)
        txt.TextStrokeTransparency = 0.5

        local prompt = Instance.new("ProximityPrompt", pad)
        prompt.ActionText = "BUY"
        prompt.ObjectText = item.label
        prompt.HoldDuration = 0
        prompt.MaxActivationDistance = 8
        prompt.KeyboardKeyCode = Enum.KeyCode.E
        prompt.Triggered:Connect(function(player)
            if applyEffect(player, item) then
                notify(player, "BOUGHT " .. item.label .. "  -  -" .. item.cost .. " CHAOS", "good")
            else
                notify(player, "NEED " .. item.cost .. " CHAOS", "warn")
            end
        end)
    end

    -- Exit doorway inside
    local exitDoor = Instance.new("Part", folder)
    exitDoor.Anchored = true; exitDoor.CanCollide = false
    exitDoor.Size = Vector3.new(8, 12, 1)
    exitDoor.Position = interiorCenter + Vector3.new(0, 6, 19)
    exitDoor.Material = Enum.Material.Wood
    exitDoor.Color = shop.color
    exitDoor.Transparency = 0.3
    local exitG = Instance.new("BillboardGui", exitDoor)
    exitG.Size = UDim2.new(0, 100, 0, 30)
    exitG.StudsOffset = Vector3.new(0, 8, 0)
    exitG.AlwaysOnTop = true
    local exitLbl = Instance.new("TextLabel", exitG)
    exitLbl.Size = UDim2.fromScale(1, 1)
    exitLbl.BackgroundTransparency = 1
    exitLbl.Text = "EXIT"
    exitLbl.Font = Enum.Font.LuckiestGuy
    exitLbl.TextScaled = true
    exitLbl.TextColor3 = Color3.fromRGB(255, 240, 200)
    exitLbl.TextStrokeTransparency = 0
    exitLbl.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)

    -- Door enter/exit teleport (2s cooldown to avoid teleport-loop)
    local enteringFlag = {}
    door.Touched:Connect(function(hit)
        local model = hit:FindFirstAncestorOfClass("Model")
        local p = model and Players:GetPlayerFromCharacter(model)
        if not p or enteringFlag[p.UserId] then return end
        enteringFlag[p.UserId] = true
        if model.PrimaryPart then
            model:PivotTo(CFrame.new(interiorCenter + Vector3.new(0, 4, -5)))
        end
        task.delay(2, function() enteringFlag[p.UserId] = nil end)
    end)
    exitDoor.Touched:Connect(function(hit)
        local model = hit:FindFirstAncestorOfClass("Model")
        local p = model and Players:GetPlayerFromCharacter(model)
        if not p or enteringFlag[p.UserId] then return end
        enteringFlag[p.UserId] = true
        if model.PrimaryPart then
            model:PivotTo(CFrame.new(shop.door + Vector3.new(0, 0, 8)))
        end
        task.delay(2, function() enteringFlag[p.UserId] = nil end)
    end)
end

task.spawn(function()
    task.wait(2)
    for i, shop in ipairs(SHOPS) do buildShop(i, shop) end
    print("[InteriorBuildings v1] " .. #SHOPS .. " enterable shops ready")
end)
