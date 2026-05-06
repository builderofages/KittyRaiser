-- CollectiblesSystem.server.lua  v1 — 50 hidden cat-coins around the map.
-- Touch to collect. Per-player progress tracked in DataHandler. Each coin
-- gives +50 chaos. Full set unlocks 'Collector' tag + 5,000 chaos bonus.
-- Coins respawn nightly per player (so retention regulars can re-grind).

local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local TOTAL_COINS = 50
local MAP_RANGE = 1500
local COIN_VALUE = 50
local FULL_SET_BONUS = 5000

local DataHandler
task.spawn(function()
    while not _G.KittyRaiserData do task.wait() end
    DataHandler = _G.KittyRaiserData
end)

-- Deterministic placement: same seed = same positions every server. So
-- experienced players can teach friends "there's one on top of the bridge."
local rng = Random.new(2026)
local positions = {}
for i = 1, TOTAL_COINS do
    positions[i] = Vector3.new(
        rng:NextInteger(-MAP_RANGE, MAP_RANGE),
        rng:NextInteger(8, 60),  -- some up high on rooftops
        rng:NextInteger(-MAP_RANGE, MAP_RANGE))
end

local folder = Workspace:FindFirstChild("Collectibles") or Instance.new("Folder", Workspace)
folder.Name = "Collectibles"
folder:ClearAllChildren()

local function makeCoin(idx, position)
    local coin = Instance.new("Part", folder)
    coin.Name = "CatCoin_" .. idx
    coin.Anchored = true
    coin.CanCollide = false
    coin.Shape = Enum.PartType.Cylinder
    coin.Size = Vector3.new(0.6, 4, 4)
    coin.Position = position
    coin.Material = Enum.Material.Neon
    coin.Color = Color3.fromRGB(255, 220, 80)
    coin.Transparency = 0.1
    coin:SetAttribute("CoinIndex", idx)
    coin.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))

    -- Glow
    local pl = Instance.new("PointLight", coin)
    pl.Color = Color3.fromRGB(255, 220, 100)
    pl.Range = 12
    pl.Brightness = 0.9

    -- Spin animation
    task.spawn(function()
        local t0 = os.clock()
        while coin.Parent do
            local elapsed = os.clock() - t0
            coin.CFrame = CFrame.new(position.X, position.Y + math.sin(elapsed * 1.5) * 0.3, position.Z)
                * CFrame.Angles(0, 0, math.rad(90))
                * CFrame.Angles(elapsed * 1.5, 0, 0)
            task.wait(0.05)
        end
    end)

    -- Touched: validate, mark per-player as collected, grant chaos.
    coin.Touched:Connect(function(hit)
        local char = hit:FindFirstAncestorOfClass("Model")
        if not char then return end
        local p = Players:GetPlayerFromCharacter(char)
        if not p or not DataHandler then return end
        local data = DataHandler.getData(p)
        if not data then return end
        data.collectedCoins = data.collectedCoins or {}
        local key = tostring(idx)
        if data.collectedCoins[key] then return end  -- already had this one
        DataHandler.modify(p, function(d)
            d.collectedCoins = d.collectedCoins or {}
            d.collectedCoins[key] = os.time()
            d.chaosPoints = (d.chaosPoints or 0) + COIN_VALUE
            -- Count unique coins collected
            local n = 0; for _ in pairs(d.collectedCoins) do n = n + 1 end
            if n == TOTAL_COINS then
                d.chaosPoints = d.chaosPoints + FULL_SET_BONUS
                d.tags = d.tags or {}
                if not table.find(d.tags, "COLLECTOR") then
                    table.insert(d.tags, "COLLECTOR")
                end
            end
        end)
        if Remotes.NotifyClient then
            local data2 = DataHandler.getData(p)
            local n = 0
            if data2 and data2.collectedCoins then
                for _ in pairs(data2.collectedCoins) do n = n + 1 end
            end
            if n == TOTAL_COINS then
                Remotes.NotifyClient:FireClient(p,
                    "ALL 50 CAT COINS  -  +5K CHAOS + COLLECTOR TAG", "good")
            else
                Remotes.NotifyClient:FireClient(p,
                    "CAT COIN " .. n .. "/" .. TOTAL_COINS .. "  -  +" .. COIN_VALUE .. " CHAOS", "good")
            end
        end
        -- Coin disappears for THIS player by going invisible client-side
        -- via a player-specific attribute. For a server-authoritative
        -- approach we just hide it briefly + respawn after 30s on the
        -- principle that it's a shared world but rewards are per-player.
        coin.Transparency = 1
        pl.Brightness = 0
        task.wait(30)
        coin.Transparency = 0.1
        pl.Brightness = 0.9
    end)
    return coin
end

task.spawn(function()
    task.wait(3)  -- let world finish building
    for i, pos in ipairs(positions) do
        makeCoin(i, pos)
    end
    print("[CollectiblesSystem v1] " .. TOTAL_COINS .. " cat coins placed")
end)
