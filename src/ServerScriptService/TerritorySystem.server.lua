-- TerritorySystem.server.lua  v1 — clan territory capture + zone bonuses.
--
-- 6 zones around the map. Each has a CONTROL POINT pad (visible cylinder).
-- Standing on the pad alone for 30s -> your CLAN captures the zone.
-- Owning clan gets:
--   * +50 chaos drip per pranking-member every 60s while in their zone
--   * Zone tinted in clan color on the (future) territory map UI
--   * Cap point glows their tag color
--
-- Per-zone state in workspace attribute Zone_<name>_OwnerClan = clanId
-- + Zone_<name>_OwnerTag for visual.
--
-- Capture progress per zone tracked in workspace attribute
-- Zone_<name>_CapProgress (0..30) when contested.

local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))

local DataHandler
task.spawn(function()
    while not _G.KittyRaiserData do task.wait() end
    DataHandler = _G.KittyRaiserData
end)

local ZONES = {
    {name="PLAZA",        center=Vector3.new(0, 5, 0),         radius=140},
    {name="DOWNTOWN",     center=Vector3.new(800, 5, 800),     radius=200},
    {name="CHINATOWN",    center=Vector3.new(-1200, 5, 1200),  radius=200},
    {name="BROOKLYN",     center=Vector3.new(1200, 5, -1200),  radius=200},
    {name="CENTRAL_PARK", center=Vector3.new(-1200, 5, -1200), radius=200},
    {name="WATERFRONT",   center=Vector3.new(0, 5, -1500),     radius=200},
}
local CAP_TIME_S = 30
local DRIP_INTERVAL_S = 60
local DRIP_AMOUNT = 50

local DataStoreService = game:GetService("DataStoreService")
local clanStore = DataStoreService:GetDataStore("KR_ClanStore_v1")

local capProgress = {}  -- [zoneName] = {progress = 0, capturingClanId = nil}

local function notify(p, msg, kind)
    if Remotes.NotifyClient then
        Remotes.NotifyClient:FireClient(p, msg, kind or "info")
    end
end

local function loadClan(clanId)
    if not clanId then return nil end
    local ok, data = pcall(function() return clanStore:GetAsync(clanId) end)
    if ok and data then return data end
    return nil
end

-- Build visible control points
for _, zone in ipairs(ZONES) do
    local pad = Instance.new("Part", Workspace)
    pad.Name = "TerritoryPad_" .. zone.name
    pad.Anchored = true; pad.CanCollide = false
    pad.Shape = Enum.PartType.Cylinder
    pad.Size = Vector3.new(2, 16, 16)
    pad.Position = zone.center + Vector3.new(0, 1, 0)
    pad.Material = Enum.Material.Neon
    pad.Color = Color3.fromRGB(140, 140, 140)
    pad.Transparency = 0.7
    pad.CFrame = CFrame.new(pad.Position) * CFrame.Angles(0, 0, math.rad(90))
    local g = Instance.new("BillboardGui", pad)
    g.Name = "ZoneSign"
    g.Size = UDim2.new(0, 220, 0, 50)
    g.StudsOffset = Vector3.new(0, 14, 0)
    g.AlwaysOnTop = false
    local lbl = Instance.new("TextLabel", g)
    lbl.Size = UDim2.fromScale(1, 1)
    lbl.BackgroundTransparency = 1
    lbl.Text = zone.name .. "  -  unclaimed"
    lbl.Font = Enum.Font.LuckiestGuy
    lbl.TextScaled = true
    lbl.TextColor3 = Color3.fromRGB(245, 235, 220)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(40, 25, 10)
    workspace:SetAttribute("Zone_" .. zone.name .. "_OwnerClan", "")
    workspace:SetAttribute("Zone_" .. zone.name .. "_OwnerTag", "")
    capProgress[zone.name] = {progress=0, capturingClanId=nil, capturingTag=""}
end

local function updateZoneSign(zone, ownerTag)
    local pad = Workspace:FindFirstChild("TerritoryPad_" .. zone.name)
    if not pad then return end
    local g = pad:FindFirstChild("ZoneSign")
    local lbl = g and g:FindFirstChildOfClass("TextLabel")
    if not lbl then return end
    if ownerTag and ownerTag ~= "" then
        lbl.Text = zone.name .. "  -  [" .. ownerTag .. "]"
        pad.Color = Color3.fromRGB(255, 200, 100)
        pad.Transparency = 0.5
    else
        lbl.Text = zone.name .. "  -  unclaimed"
        pad.Color = Color3.fromRGB(140, 140, 140)
        pad.Transparency = 0.7
    end
end

-- =====================================================================
-- CAPTURE LOOP — 1Hz tick
-- =====================================================================
task.spawn(function()
    while true do
        task.wait(1)
        for _, zone in ipairs(ZONES) do
            -- Find players standing on this zone's pad
            local players = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character and p.Character.PrimaryPart then
                    local d = (p.Character.PrimaryPart.Position - zone.center).Magnitude
                    if d < 12 then table.insert(players, p) end
                end
            end
            if #players == 0 then
                -- Decay progress when nobody's there
                if capProgress[zone.name].progress > 0 then
                    capProgress[zone.name].progress =
                        math.max(0, capProgress[zone.name].progress - 1)
                end
            else
                -- Check if all players belong to the same clan
                local clans = {}
                for _, p in ipairs(players) do
                    local data = DataHandler and DataHandler.getData(p)
                    local cid = data and data.clanId or "_solo_" .. p.UserId
                    clans[cid] = (clans[cid] or 0) + 1
                end
                local dominant = nil
                local count = 0
                for cid, n in pairs(clans) do
                    if n > count then dominant = cid; count = n end
                end
                local total = #players
                local contested = (count < total)
                if contested then
                    -- No progress when contested
                else
                    local currentOwner = workspace:GetAttribute("Zone_" .. zone.name .. "_OwnerClan")
                    if dominant == currentOwner then
                        -- Defending; nothing to do
                    else
                        if capProgress[zone.name].capturingClanId ~= dominant then
                            capProgress[zone.name].progress = 0
                            capProgress[zone.name].capturingClanId = dominant
                            local clanData = loadClan(dominant)
                            capProgress[zone.name].capturingTag = clanData and clanData.tag or ""
                        end
                        capProgress[zone.name].progress = capProgress[zone.name].progress + 1
                        if capProgress[zone.name].progress >= CAP_TIME_S then
                            -- CAPTURE
                            workspace:SetAttribute("Zone_" .. zone.name .. "_OwnerClan", dominant)
                            workspace:SetAttribute("Zone_" .. zone.name .. "_OwnerTag",
                                capProgress[zone.name].capturingTag)
                            capProgress[zone.name].progress = 0
                            updateZoneSign(zone, capProgress[zone.name].capturingTag)
                            -- Announce
                            for _, p in ipairs(Players:GetPlayers()) do
                                notify(p, zone.name .. " CAPTURED by [" .. capProgress[zone.name].capturingTag .. "]", "good")
                            end
                            print("[TerritorySystem] " .. zone.name .. " captured by clan " .. tostring(dominant))
                        end
                    end
                end
            end
        end
    end
end)

-- =====================================================================
-- CHAOS DRIP LOOP
-- =====================================================================
task.spawn(function()
    while true do
        task.wait(DRIP_INTERVAL_S)
        for _, zone in ipairs(ZONES) do
            local ownerClan = workspace:GetAttribute("Zone_" .. zone.name .. "_OwnerClan")
            if ownerClan and ownerClan ~= "" and DataHandler then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character and p.Character.PrimaryPart then
                        local d = (p.Character.PrimaryPart.Position - zone.center).Magnitude
                        if d < zone.radius then
                            local data = DataHandler.getData(p)
                            if data and data.clanId == ownerClan then
                                DataHandler.modify(p, function(dd)
                                    dd.chaosPoints = (dd.chaosPoints or 0) + DRIP_AMOUNT
                                end)
                                notify(p, "ZONE BONUS  -  +" .. DRIP_AMOUNT .. " CHAOS (" .. zone.name .. ")", "good")
                            end
                        end
                    end
                end
            end
        end
    end
end)

print("[TerritorySystem v1] online - 6 zones, " .. CAP_TIME_S .. "s capture time, " .. DRIP_AMOUNT .. " chaos drip per " .. DRIP_INTERVAL_S .. "s")
