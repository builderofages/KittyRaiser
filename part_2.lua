local function getOrMake(parent, className, name)
    local existing = parent:FindFirstChild(name)
    if existing and existing.ClassName == className then return existing end
    if existing then existing:Destroy() end
    local obj = Instance.new(className)
    obj.Name = name
    obj.Parent = parent
    return obj
end
local modulesFolder = getOrMake(game.ReplicatedStorage, 'Folder', 'Modules')
do
    local s = getOrMake(game.ServerScriptService, 'Script', 'SummonSystem')
    s.Source = [[
-- SummonSystem.server.lua
-- Spawns Robloxian "human" NPCs for the player to prank.
-- Place in: ServerScriptService > SummonSystem (Script)

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local SummonSystem = {}

local SUMMON_COOLDOWN = 1.5
local NPC_DESPAWN_AFTER = 25 -- seconds if not pranked
local lastSummonTime = {}  -- [userId] = os.clock()

-- Find or create the NPC folder in workspace
local npcFolder = Workspace:FindFirstChild("PrankNPCs")
if not npcFolder then
    npcFolder = Instance.new("Folder")
    npcFolder.Name = "PrankNPCs"
    npcFolder.Parent = Workspace
end

-- Get spawn pads (placed in workspace by MapBuilder)
local function getSpawnPads()
    local pads = Workspace:FindFirstChild("SpawnPads")
    if not pads then return {} end
    return pads:GetChildren()
end

-- Build a simple Robloxian-style NPC programmatically (no asset deps)
local function buildHumanNPC()
    local model = Instance.new("Model")
    model.Name = "PrankTarget"
    model:SetAttribute("KittyRaiserNPC", true)
    model:SetAttribute("Pranked", false)

    -- HumanoidRootPart
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2, 2, 1)
    hrp.Transparency = 1
    hrp.CanCollide = false
    hrp.Anchored = false
    hrp.Parent = model

    -- Torso
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    torso.Color = Color3.fromRGB(0, 100, 200)
    torso.Position = hrp.Position
    torso.Parent = model
    local torsoWeld = Instance.new("WeldConstraint")
    torsoWeld.Part0 = hrp
    torsoWeld.Part1 = torso
    torsoWeld.Parent = torso

    -- Head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(1.5, 1.5, 1.5)
    head.Shape = Enum.PartType.Ball
    head.Color = Color3.fromRGB(245, 205, 160)
    head.Position = torso.Position + Vector3.new(0, 1.75, 0)
    head.Parent = model
    local headWeld = Instance.new("WeldConstraint")
    headWeld.Part0 = torso
    headWeld.Part1 = head
    headWeld.Parent = head

    -- Face decal (simple)
    local face = Instance.new("Decal")
    face.Texture = "rbxasset://textures/face.png"
    face.Face = Enum.NormalId.Front
    face.Parent = head

    -- Legs (combined block)
    local legs = Instance.new("Part")
    legs.Name = "Legs"
    legs.Size = Vector3.new(2, 2, 1)
    legs.Color = Color3.fromRGB(40, 40, 80)
    legs.Position = torso.Position + Vector3.new(0, -2, 0)
    legs.Parent = model
    local legWeld = Instance.new("WeldConstraint")
    legWeld.Part0 = torso
    legWeld.Part1 = legs
    legWeld.Parent = legs

    -- Humanoid for ragdoll-style animation later
    local humanoid = Instance.new("Humanoid")
    humanoid.MaxHealth = 100
    humanoid.Health = 100
    humanoid.WalkSpeed = 8
    humanoid.Parent = model

    model.PrimaryPart = hrp
    return model
end

-- Wander AI: NPC walks randomly until pranked or despawn
local function wanderAI(model)
    task.spawn(function()
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local startTime = os.clock()
        while model.Parent and (os.clock() - startTime) < NPC_DESPAWN_AFTER do
            local hrp = model.PrimaryPart
            if not hrp then break end
            local rand = Vector3.new(math.random(-15, 15), 0, math.random(-15, 15))
            hum:MoveTo(hrp.Position + rand)
            task.wait(math.random(2, 4))
        end
        if model.Parent and not model:GetAttribute("Pranked") then
            model:Destroy()
        end
    end)
end

-- Public: summon an NPC for a player
function SummonSystem.summon(player)
    local now = os.clock()
    local last = lastSummonTime[player.UserId] or 0
    if (now - last) < SUMMON_COOLDOWN then
        return false, "summon_cooldown"
    end
    lastSummonTime[player.UserId] = now

    local pads = getSpawnPads()
    if #pads == 0 then
        warn("[SummonSystem] No spawn pads found - using default position")
    end

    local npc = buildHumanNPC()
    local spawnPos
    if #pads > 0 then
        local pad = pads[math.random(1, #pads)]
        spawnPos = pad.Position + Vector3.new(0, 4, 0)
    else
        local char = player.Character
        if char and char.PrimaryPart then
            spawnPos = char.PrimaryPart.Position + Vector3.new(math.random(-10, 10), 5, math.random(-10, 10))
        else
            spawnPos = Vector3.new(0, 10, 0)
        end
    end

    npc:PivotTo(CFrame.new(spawnPos))
    npc:SetAttribute("SummonedBy", player.UserId)
    npc.Parent = npcFolder

    -- Spawn-in animation: tween scale up
    for _, p in ipairs(npc:GetDescendants()) do
        if p:IsA("BasePart") then
            local origSize = p.Size
            p.Size = Vector3.new(0.1, 0.1, 0.1)
            TweenService:Create(p, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = origSize}):Play()
        end
    end

    wanderAI(npc)
    return true, npc
end

-- Despawn pranked NPC after a delay
function SummonSystem.markPranked(npc)
    if not npc then return end
    npc:SetAttribute("Pranked", true)
    task.delay(2, function()
        if npc.Parent then npc:Destroy() end
    end)
end

-- Wire remote
Remotes.RequestSummonHuman.OnServerEvent:Connect(function(player)
    SummonSystem.summon(player)
end)

Players.PlayerRemoving:Connect(function(player)
    lastSummonTime[player.UserId] = nil
    -- Despawn this player's NPCs
    for _, npc in ipairs(npcFolder:GetChildren()) do
        if npc:GetAttribute("SummonedBy") == player.UserId then
            npc:Destroy()
        end
    end
end)

_G.KittyRaiserSummon = SummonSystem
return SummonSystem

]]
end

do
    local s = getOrMake(game.ServerScriptService, 'Script', 'PrankSystem')
    s.Source = [[
-- PrankSystem.server.lua
-- Receives prank requests from client, validates, awards Chaos & XP, fires effect events.
-- Place in: ServerScriptService > PrankSystem (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local PrankConfig = require(ReplicatedStorage.Modules.PrankConfig)
local CosmeticConfig = require(ReplicatedStorage.Modules.CosmeticConfig)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local function waitFor(globalName)
    while not _G[globalName] do task.wait() end
    return _G[globalName]
end

local DataHandler = waitFor("KittyRaiserData")
local AntiCheat = waitFor("KittyRaiserAntiCheat")
local SummonSystem = waitFor("KittyRaiserSummon")

local PrankSystem = {}

local function hasVIP(player)
    local vipId = GameConfig.GAMEPASS_IDS.VIP
    if vipId == 0 then return false end
    local ok, owns = pcall(function()
        return MarketplaceService:UserOwnsGamePassAsync(player.UserId, vipId)
    end)
    return ok and owns or false
end

local function awardChaosAndXP(player, baseChaos)
    local data = DataHandler.getData(player)
    if not data then return 0, 0 end

    -- Multiplier from skin + rebirths + VIP
    local skinMult = CosmeticConfig.getMultiplier(data.equippedSkin or "Default")
    local totalMult = GameConfig.computeMultiplier(data.rebirths or 0, hasVIP(player)) * skinMult

    local chaosGained = math.floor(baseChaos * totalMult)

    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) + chaosGained
        d.totalPranks = (d.totalPranks or 0) + 1
        local xpGain = GameConfig.PRANK_XP_PER_HIT
        d.xp = (d.xp or 0) + xpGain
        -- Level up loop
        while d.level < GameConfig.LEVEL_CAP and d.xp >= GameConfig.xpRequired(d.level) do
            d.xp = d.xp - GameConfig.xpRequired(d.level)
            d.level = d.level + 1
            -- Determine newly unlocked pranks
            local unlocked = {}
            for _, name in ipairs(PrankConfig.Order) do
                if PrankConfig.Pranks[name].unlockLevel == d.level then
                    table.insert(unlocked, name)
                end
            end
            Remotes.LevelUp:FireClient(player, d.level, unlocked)
        end
    end)
    return chaosGained, GameConfig.PRANK_XP_PER_HIT
end

function PrankSystem.handlePrankRequest(player, prankName, targetModel)
    if AntiCheat.isSuspended(player) then
        Remotes.PrankFailed:FireClient(player, "suspended")
        return
    end

    local prank = PrankConfig.getPrank(prankName)
    if not prank then
        Remotes.PrankFailed:FireClient(player, "invalid_prank")
        return
    end

    local data = DataHandler.getData(player)
    if not data then
        Remotes.PrankFailed:FireClient(player, "no_data")
        return
    end

    -- Level lock
    if data.level < prank.unlockLevel then
        Remotes.PrankFailed:FireClient(player, "level_locked")
        return
    end

    -- Rate limit
    local rlOk = AntiCheat.checkRateLimit(player)
    if not rlOk then
        Remotes.PrankFailed:FireClient(player, "rate_limited")
        return
    end

    -- Cooldown
    local cdOk = AntiCheat.checkPrankCooldown(player, prankName, prank.cooldown)
    if not cdOk then
        Remotes.PrankFailed:FireClient(player, "cooldown")
        return
    end

    -- NPC validity
    if not AntiCheat.isValidNPC(targetModel) then
        Remotes.PrankFailed:FireClient(player, "invalid_target")
        return
    end

    -- Distance
    local primary = targetModel.PrimaryPart or targetModel:FindFirstChild("HumanoidRootPart")
    local distOk, distErr = AntiCheat.checkPrankDistance(player, primary, prank.rangeStuds)
    if not distOk then
        Remotes.PrankFailed:FireClient(player, distErr or "out_of_range")
        return
    end

    -- All checks pass — award + mark
    local chaos, xp = awardChaosAndXP(player, prank.baseChaos)
    SummonSystem.markPranked(targetModel)

    -- Tell client to play effects
    local fxPayload = {
        prank = prankName,
        targetCFrame = primary.CFrame,
        chaosGained = chaos,
        screenShake = prank.screenShake,
    }
    Remotes.PrankRegistered:FireClient(player, prankName, targetModel, chaos, fxPayload)

    -- Tell ALL clients in range to see the splash effect (so it's social)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local pChar = p.Character
            if pChar and pChar.PrimaryPart then
                if (pChar.PrimaryPart.Position - primary.Position).Magnitude < 80 then
                    Remotes.PrankRegistered:FireClient(p, prankName, targetModel, 0, fxPayload)
                end
            end
        end
    end
end

Remotes.RequestPrank.OnServerEvent:Connect(function(player, prankName, targetModel)
    PrankSystem.handlePrankRequest(player, prankName, targetModel)
end)

return PrankSystem

]]
end

do
    local s = getOrMake(game.ServerScriptService, 'Script', 'MonetizationHandler')
    s.Source = [[
-- MonetizationHandler.server.lua
-- Processes GamePass ownership checks + DevProduct ProcessReceipt.
-- Place in: ServerScriptService > MonetizationHandler (Script)

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local CosmeticConfig = require(ReplicatedStorage.Modules.CosmeticConfig)

local function waitFor(globalName)
    while not _G[globalName] do task.wait() end
    return _G[globalName]
end
local DataHandler = waitFor("KittyRaiserData")

-- Receipt de-dup store
local receiptStore = DataStoreService:GetDataStore("KittyRaiserReceipts_v1")

-- Map DevProduct ID -> handler function
local DevProductHandlers = {}

local function awardChaos(player, amount)
    DataHandler.modify(player, function(d)
        d.chaosPoints = (d.chaosPoints or 0) + amount
        d.totalRobuxSpent = (d.totalRobuxSpent or 0) + 1 -- approximate, real R$ via API
    end)
    Remotes.NotifyClient:FireClient(player, "+" .. amount .. " Chaos!", "success")
end

-- Wire DevProducts (filled when IDs are known)
local function registerDevProducts()
    if GameConfig.DEVPRODUCT_IDS.CHAOS_5K ~= 0 then
        DevProductHandlers[GameConfig.DEVPRODUCT_IDS.CHAOS_5K] = function(player) awardChaos(player, 5000) end
    end
    if GameConfig.DEVPRODUCT_IDS.CHAOS_50K ~= 0 then
        DevProductHandlers[GameConfig.DEVPRODUCT_IDS.CHAOS_50K] = function(player) awardChaos(player, 50000) end
    end
    if GameConfig.DEVPRODUCT_IDS.REBIRTH_SKIP ~= 0 then
        DevProductHandlers[GameConfig.DEVPRODUCT_IDS.REBIRTH_SKIP] = function(player)
            DataHandler.modify(player, function(d)
                d.level = math.max(d.level, GameConfig.REBIRTH_REQUIRED_LEVEL)
                d.xp = 0
            end)
            Remotes.NotifyClient:FireClient(player, "Rebirth requirement skipped!", "success")
        end
    end
end
registerDevProducts()

-- ProcessReceipt: must return PurchaseGranted or NotProcessedYet
MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

    local key = "p_" .. receiptInfo.PurchaseId

    -- Already processed?
    local alreadyProcessed = false
    local ok = pcall(function()
        receiptStore:UpdateAsync(key, function(old)
            if old then
                alreadyProcessed = true
                return old
            end
            return os.time()
        end)
    end)
    if not ok then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    if alreadyProcessed then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    local handler = DevProductHandlers[receiptInfo.ProductId]
    if not handler then
        warn("[Monetization] No handler for product", receiptInfo.ProductId)
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local handled = pcall(function() handler(player) end)
    if handled then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- GamePass purchase listener (live grants)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, purchased)
    if not purchased then return end
    -- Demon skin
    if gamepassId == GameConfig.GAMEPASS_IDS.DEMON_SKIN then
        DataHandler.modify(player, function(d)
            if not table.find(d.ownedSkins, "Demon") then
                table.insert(d.ownedSkins, "Demon")
            end
        end)
        Remotes.NotifyClient:FireClient(player, "Demon Cat unlocked!", "success")
    elseif gamepassId == GameConfig.GAMEPASS_IDS.NEON_SKIN then
        DataHandler.modify(player, function(d)
            if not table.find(d.ownedSkins, "Neon") then
                table.insert(d.ownedSkins, "Neon")
            end
        end)
        Remotes.NotifyClient:FireClient(player, "Neon Cat unlocked!", "success")
    elseif gamepassId == GameConfig.GAMEPASS_IDS.VIP then
        Remotes.NotifyClient:FireClient(player, "VIP active! 2x Chaos!", "success")
    end
end)

-- On player join, sync their existing GamePass ownership into ownedSkins (covers prior purchases)
Players.PlayerAdded:Connect(function(player)
    task.wait(2) -- let DataHandler load
    local data = DataHandler.getData(player)
    if not data then return end
    for skinId, skin in pairs(CosmeticConfig.Skins) do
        if skin.currency == "robux" then
            local gpId = GameConfig.GAMEPASS_IDS[string.upper(skinId) .. "_SKIN"]
            if gpId and gpId ~= 0 then
                local ok, owns = pcall(function()
                    return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gpId)
                end)
                if ok and owns and not table.find(data.ownedSkins, skinId) then
                    table.insert(data.ownedSkins, skinId)
                end
            end
        end
    end
    DataHandler.replicateToClient(player)
end)

-- DevProduct purchase via remote (client-initiated prompt is fine, but server is source of truth)
Remotes.RequestUseDevProduct.OnServerEvent:Connect(function(player, productKey)
    local id = GameConfig.DEVPRODUCT_IDS[productKey]
    if not id or id == 0 then return end
    MarketplaceService:PromptProductPurchase(player, id)
end)

return true

]]
end

do
    local s = getOrMake(game.ServerScriptService, 'Script', 'RebirthHandler')
    s.Source = [[
-- RebirthHandler.server.lua
-- Handles rebirth requests, validates eligibility, applies prestige.
-- Place in: ServerScriptService > RebirthHandler (Script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local function waitFor(globalName)
    while not _G[globalName] do task.wait() end
    return _G[globalName]
end
local DataHandler = waitFor("KittyRaiserData")

Remotes.RequestRebirth.OnServerInvoke = function(player)
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end

    if data.level < GameConfig.REBIRTH_REQUIRED_LEVEL then
        return false, "level_too_low"
    end

    if data.rebirths >= GameConfig.REBIRTH_SOFT_CAP then
        return false, "soft_cap_reached"
    end

    DataHandler.modify(player, function(d)
        d.rebirths = (d.rebirths or 0) + 1
        d.level = 1
        d.xp = 0
        -- Keep chaos points across rebirths so player feels progress
        -- Drop ownedSkins, equippedSkin remain
    end)

    local newData = DataHandler.getData(player)
    local newMult = GameConfig.computeMultiplier(newData.rebirths, false)
    Remotes.RebirthCompleted:FireClient(player, newData.rebirths, newMult)
    return true, newData.rebirths
end

return true

]]
end

do
    local s = getOrMake(game.ServerScriptService, 'Script', 'CosmeticHandler')
    s.Source = [[
-- CosmeticHandler.server.lua
-- Handles skin purchase (Chaos currency) + equip + applies skin to character.
-- Place in: ServerScriptService > CosmeticHandler (Script)

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local CosmeticConfig = require(ReplicatedStorage.Modules.CosmeticConfig)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local function waitFor(globalName)
    while not _G[globalName] do task.wait() end
    return _G[globalName]
end
local DataHandler = waitFor("KittyRaiserData")

local CosmeticHandler = {}

local function applySkinToCharacter(character, skinId)
    if not character then return end
    local skin = CosmeticConfig.getSkin(skinId)
    if not skin then return end

    local bodyColors = character:FindFirstChildOfClass("BodyColors")
    if not bodyColors then
        bodyColors = Instance.new("BodyColors")
        bodyColors.Parent = character
    end

    -- Apply colors via BrickColor (BodyColors uses BrickColor)
    local function toBrick(c) return BrickColor.new(c) end
    if skin.bodyColors.HeadColor then bodyColors.HeadColor = toBrick(skin.bodyColors.HeadColor) end
    if skin.bodyColors.TorsoColor then bodyColors.TorsoColor = toBrick(skin.bodyColors.TorsoColor) end
    if skin.bodyColors.LeftArmColor then bodyColors.LeftArmColor = toBrick(skin.bodyColors.LeftArmColor) end
    if skin.bodyColors.RightArmColor then bodyColors.RightArmColor = toBrick(skin.bodyColors.RightArmColor) end
    if skin.bodyColors.LeftLegColor then bodyColors.LeftLegColor = toBrick(skin.bodyColors.LeftLegColor) end
    if skin.bodyColors.RightLegColor then bodyColors.RightLegColor = toBrick(skin.bodyColors.RightLegColor) end

    -- Material override for Neon
    if skin.material then
        for _, p in ipairs(character:GetDescendants()) do
            if p:IsA("BasePart") then
                p.Material = skin.material
            end
        end
    end

    -- Glow effect
    if skin.glowEffect then
        local existing = character:FindFirstChild("SkinGlow")
        if not existing then
            local light = Instance.new("PointLight")
            light.Name = "SkinGlow"
            light.Brightness = 2
            light.Range = 12
            light.Color = skin.bodyColors.TorsoColor or Color3.new(1,1,1)
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then light.Parent = hrp end
        end
    end
end

local function applyOnRespawn(player, character)
    local data = DataHandler.getData(player)
    if not data then return end
    -- wait for body parts
    character:WaitForChild("Humanoid")
    task.wait(0.1)
    applySkinToCharacter(character, data.equippedSkin or "Default")
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char) applyOnRespawn(player, char) end)
end)

-- Equip
Remotes.RequestEquipSkin.OnServerInvoke = function(player, skinId)
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end
    if not table.find(data.ownedSkins, skinId) then return false, "not_owned" end
    DataHandler.modify(player, function(d) d.equippedSkin = skinId end)
    if player.Character then applySkinToCharacter(player.Character, skinId) end
    return true, nil
end

-- Purchase with Chaos
Remotes.RequestPurchaseSkinChaos.OnServerInvoke = function(player, skinId)
    local skin = CosmeticConfig.getSkin(skinId)
    if not skin then return false, "invalid_skin" end
    if skin.currency ~= "chaos" then return false, "wrong_currency" end
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end
    if table.find(data.ownedSkins, skinId) then return false, "already_owned" end
    if (data.chaosPoints or 0) < skin.cost then return false, "not_enough_chaos" end
    DataHandler.modify(player, function(d)
        d.chaosPoints = d.chaosPoints - skin.cost
        table.insert(d.ownedSkins, skinId)
    end)
    return true, nil
end

return CosmeticHandler

]]
end

do
    local s = getOrMake(game.ServerScriptService, 'Script', 'LeaderboardHandler')
    s.Source = [[
-- LeaderboardHandler.server.lua
-- Maintains a per-server live leaderboard of top 10 Chaos earners.
-- Place in: ServerScriptService > LeaderboardHandler (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)

local function waitFor(globalName) while not _G[globalName] do task.wait() end return _G[globalName] end
local DataHandler = waitFor("KittyRaiserData")

local UPDATE_INTERVAL = 5

local function buildAndBroadcast()
    local entries = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local d = DataHandler.getData(p)
        if d then
            table.insert(entries, {
                name = p.DisplayName or p.Name,
                userId = p.UserId,
                chaos = d.chaosPoints or 0,
                level = d.level or 1,
                rebirths = d.rebirths or 0,
            })
        end
    end
    table.sort(entries, function(a, b) return a.chaos > b.chaos end)
    -- Top 10
    local top = {}
    for i = 1, math.min(10, #entries) do top[i] = entries[i] end
    Remotes.LeaderboardUpdated:FireAllClients(top)
end

task.spawn(function()
    while true do
        task.wait(UPDATE_INTERVAL)
        pcall(buildAndBroadcast)
    end
end)

return true

]]
end

do
    local s = getOrMake(game.ServerScriptService, 'Script', 'PerkSystem')
    s.Source = [[
-- PerkSystem.server.lua
-- Grants perk slots every 5 levels, presents picker, applies effects, allows reset.
-- Place in: ServerScriptService > PerkSystem (Script)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local PerkConfig = require(ReplicatedStorage.Modules.PerkConfig)

local function waitFor(g) while not _G[g] do task.wait() end return _G[g] end
local DataHandler = waitFor("KittyRaiserData")

local PerkSystem = {}

-- Equip / pick perk for slot
Remotes.RequestEquipPerk.OnServerInvoke = function(player, slot, perkId)
    if type(slot) ~= "number" or not perkId then return false, "bad_args" end
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end
    local availableSlots = GameConfig.perkSlotsAtLevel(data.level or 1)
    if slot > availableSlots then return false, "slot_locked" end
    local options = PerkConfig.optionsForSlot(slot)
    if not options or not table.find(options, perkId) then return false, "invalid_perk_for_slot" end
    DataHandler.modify(player, function(d)
        d.perks = d.perks or {}
        d.perks[tostring(slot)] = perkId  -- store keys as strings (DataStore quirk)
    end)
    return true, nil
end

-- Reset all perks (Hell Tokens cost or Robux)
Remotes.RequestResetPerks.OnServerInvoke = function(player, useRobux)
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end
    if useRobux then
        local prodId = GameConfig.DEVPRODUCT_IDS.PERK_RESET
        if prodId == 0 then return false, "robux_product_unset" end
        -- Server can't directly charge; needs PromptProductPurchase via client.
        -- For server-side flow, the client should call MarketplaceService:PromptProductPurchase first then we await ProcessReceipt.
        return false, "use_client_prompt"
    else
        local cost = GameConfig.PERK_RESET_HELLTOKENS
        if (data.hellTokens or 0) < cost then return false, "not_enough_helltokens" end
        DataHandler.modify(player, function(d)
            d.hellTokens = d.hellTokens - cost
            d.perks = {}
        end)
        return true, nil
    end
end

-- Stat allocation (each level gives 1 unspent stat point + 5 levels gives a perk slot)
Remotes.RequestAllocStat.OnServerInvoke = function(player, statName)
    local data = DataHandler.getData(player)
    if not data then return false, "no_data" end
    if not table.find(GameConfig.STAT_NAMES, statName) then return false, "bad_stat" end
    if (data.unspentStatPoints or 0) <= 0 then return false, "no_points" end
    if (data.stats[statName] or 0) >= GameConfig.STAT_MAX then return false, "maxed" end
    DataHandler.modify(player, function(d)
        d.unspentStatPoints = d.unspentStatPoints - 1
        d.stats[statName] = (d.stats[statName] or 0) + 1
    end)
    -- Apply on character
    PerkSystem.applyStatsToCharacter(player)
    return true, nil
end

function PerkSystem.applyStatsToCharacter(player)
    local data = DataHandler.getData(player)
    if not data or not data.stats then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    -- Speed
    hum.WalkSpeed = 16 + (data.stats.Speed or 0) * GameConfig.STAT_EFFECTS.Speed.walkSpeedPerPoint
    -- Jump
    hum.JumpPower = 50 + (data.stats.Jump or 0) * GameConfig.STAT_EFFECTS.Jump.jumpPowerPerPoint
end

-- Hook into LevelUp event to grant stat points + perk slots
Remotes.LevelUp.OnServerEvent:Connect(function() end)  -- noop, but let server scripts watch
local function grantOnLevelUp(player)
    local data = DataHandler.getData(player)
    if not data then return end
    DataHandler.modify(player, function(d)
        d.unspentStatPoints = (d.unspentStatPoints or 0) + GameConfig.STATS_PER_LEVEL
    end)
    -- If multiple of 5, prompt perk picker
    if data.level % GameConfig.PERK_GRANT_EVERY == 0 then
        local slot = math.floor(data.level / GameConfig.PERK_GRANT_EVERY)
        Remotes.PerkSlotEarned:FireClient(player, slot, PerkConfig.optionsForSlot(slot))
    end
end

-- We can't directly listen to PrankSystem's level-up easily without a global pubsub.
-- Use a watcher on data.level.
local Players = game:GetService("Players")
local lastSeenLevel = {}
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        PerkSystem.applyStatsToCharacter(player)
    end)
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = DataHandler.getData(player)
            if data then
                local prev = lastSeenLevel[player.UserId] or data.level
                if data.level > prev then
                    -- Level up happened
                    for newLvl = prev+1, data.level do
                        DataHandler.modify(player, function(d)
                            d.unspentStatPoints = (d.unspentStatPoints or 0) + GameConfig.STATS_PER_LEVEL
                        end)
                        if newLvl % GameConfig.PERK_GRANT_EVERY == 0 then
                            local slot = math.floor(newLvl / GameConfig.PERK_GRANT_EVERY)
                            Remotes.PerkSlotEarned:FireClient(player, slot, PerkConfig.optionsForSlot(slot))
                        end
                    end
                end
                lastSeenLevel[player.UserId] = data.level
            end
        end
    end
end)

_G.KittyRaiserPerks = PerkSystem
return PerkSystem

]]
end

do
    local s = getOrMake(game.ServerScriptService, 'Script', 'SurvivalSystem')
    s.Source = [[
-- SurvivalSystem.server.lua
-- Hunger/thirst decay over time. Below 25 = slow. At 0 = ragdoll respawn.
-- Place in: ServerScriptService > SurvivalSystem (Script)

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local function waitFor(g) while not _G[g] do task.wait() end return _G[g] end
local DataHandler = waitFor("KittyRaiserData")

if not GameConfig.SURVIVAL_ENABLED then
    print("[SurvivalSystem] Disabled in config")
    return
end

local TICK = 5  -- decay every 5 sec
local hungerPerTick = (GameConfig.HUNGER_DECAY_PER_MIN / 60) * TICK
local thirstPerTick = (GameConfig.THIRST_DECAY_PER_MIN / 60) * TICK

task.spawn(function()
    while true do
        task.wait(TICK)
        for _, player in ipairs(Players:GetPlayers()) do
            local data = DataHandler.getData(player)
            if data then
                DataHandler.modify(player, function(d)
                    d.hunger = math.clamp((d.hunger or 100) - hungerPerTick, 0, 100)
                    d.thirst = math.clamp((d.thirst or 100) - thirstPerTick, 0, 100)
                end)
                Remotes.SurvivalUpdate:FireClient(player, data.hunger, data.thirst)
                -- Apply slow if low
                local char = player.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        if data.hunger < GameConfig.SURVIVAL_DEBUFF_AT or data.thirst < GameConfig.SURVIVAL_DEBUFF_AT then
                            hum.WalkSpeed = math.max(8, hum.WalkSpeed - 4)
                        end
                        if data.hunger <= 0 or data.thirst <= 0 then
                            hum.Health = 0  -- respawn
                            DataHandler.modify(player, function(d)
                                d.hunger = 50
                                d.thirst = 50
                            end)
                        end
                    end
                end
            end
        end
    end
end)

-- Food/water sources detection: parts with attribute "FoodSource" or "WaterSource"
local function setupFoodPart(part)
    if not part:IsA("BasePart") then return end
    if not part:GetAttribute("FoodSource") and not part:GetAttribute("WaterSource") then return end
    part.Touched:Connect(function(hit)
        local char = hit and hit.Parent
        if not char then return end
        local player = Players:GetPlayerFromCharacter(char)
        if not player then return end
        local now = os.clock()
        local lastUse = part:GetAttribute("LastUse_"..player.UserId) or 0
        if (now - lastUse) < 5 then return end
        part:SetAttribute("LastUse_"..player.UserId, now)
        DataHandler.modify(player, function(d)
            if part:GetAttribute("FoodSource") then
                d.hunger = math.min(100, (d.hunger or 0) + GameConfig.FOOD_RESTORE)
            end
            if part:GetAttribute("WaterSource") then
                d.thirst = math.min(100, (d.thirst or 0) + GameConfig.WATER_RESTORE)
            end
        end)
        Remotes.NotifyClient:FireClient(player, part:GetAttribute("FoodSource") and "+Food" or "+Water", "success")
    end)
end

for _, p in ipairs(Workspace:GetDescendants()) do setupFoodPart(p) end
Workspace.DescendantAdded:Connect(setupFoodPart)

-- Direct request remotes (used by interaction prompts)
Remotes.RequestEatFood.OnServerEvent:Connect(function(player, sourceModel)
    if sourceModel and sourceModel:GetAttribute("FoodSource") then
        DataHandler.modify(player, function(d)
            d.hunger = math.min(100, (d.hunger or 0) + GameConfig.FOOD_RESTORE)
        end)
    end
end)
Remotes.RequestDrinkWater.OnServerEvent:Connect(function(player, sourceModel)
    if sourceModel and sourceModel:GetAttribute("WaterSource") then
        DataHandler.modify(player, function(d)
            d.thirst = math.min(100, (d.thirst or 0) + GameConfig.WATER_RESTORE)
        end)
    end
end)

return true

]]
end

print('[KittyRaiser] chunk 2/5 loaded - 8 scripts')
