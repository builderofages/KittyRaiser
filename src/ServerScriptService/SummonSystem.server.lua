-- SummonSystem.server.lua
-- Spawns Robloxian "human" NPCs for the player to prank.
-- Place in: ServerScriptService > SummonSystem (Script)

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes     = require(ReplicatedStorage.Modules.RemoteEvents)
local GameConfig  = require(ReplicatedStorage.Modules.GameConfig)
local AssetIds    = require(ReplicatedStorage.Modules.AssetIds)
local AudioGroups
do
    local m = ReplicatedStorage.Modules:WaitForChild("AudioGroups", 5)
    if m then local ok, mod = pcall(require, m); if ok then AudioGroups = mod end end
end

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

-- Build a real Robloxian-style NPC using HumanoidDescription so it gets the
-- full R15 rig (head + arms + legs + animations + face). Falls back to a clean
-- proportional welded rig if the description path errors.
local DESC_RIGS = {
	-- A handful of community R15 outfit description ids; if they fail the
	-- fallback rig is used. These are the rig type, not asset bundles, so we
	-- build them with empty descriptions and just tint clothes.
}

local OUTFIT_PALETTES = {
	-- {shirtColor, pantsColor, skinColor}
	{Color3.fromRGB(220, 60, 60),  Color3.fromRGB(40, 40, 80),  Color3.fromRGB(245, 205, 160)},
	{Color3.fromRGB(60, 130, 220), Color3.fromRGB(60, 60, 80),  Color3.fromRGB(200, 165, 130)},
	{Color3.fromRGB(80, 200, 120), Color3.fromRGB(50, 35, 25),  Color3.fromRGB(160, 110, 80)},
	{Color3.fromRGB(220, 200, 80), Color3.fromRGB(40, 30, 60),  Color3.fromRGB(120, 80, 55)},
	{Color3.fromRGB(180, 80, 200), Color3.fromRGB(20, 20, 40),  Color3.fromRGB(95, 65, 45)},
	{Color3.fromRGB(40, 200, 200), Color3.fromRGB(80, 50, 30),  Color3.fromRGB(245, 205, 160)},
}

local function tintRig(model, palette)
	local shirtColor, pantsColor, skinColor = palette[1], palette[2], palette[3]
	local SKIN_PARTS = {
		Head = true, LeftHand = true, RightHand = true,
		LeftFoot = true, RightFoot = true,
	}
	local SHIRT_PARTS = {
		UpperTorso = true, LowerTorso = true,
		LeftUpperArm = true, LeftLowerArm = true,
		RightUpperArm = true, RightLowerArm = true,
	}
	local PANTS_PARTS = {
		LeftUpperLeg = true, LeftLowerLeg = true,
		RightUpperLeg = true, RightLowerLeg = true,
	}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			if SKIN_PARTS[p.Name]    then p.Color = skinColor; p.Material = Enum.Material.SmoothPlastic
			elseif SHIRT_PARTS[p.Name] then p.Color = shirtColor; p.Material = Enum.Material.SmoothPlastic
			elseif PANTS_PARTS[p.Name] then p.Color = pantsColor; p.Material = Enum.Material.SmoothPlastic
			elseif p.Name == "Torso" then p.Color = shirtColor; p.Material = Enum.Material.SmoothPlastic
			end
		end
	end
end

local function buildHumanNPC()
	-- Try to spawn a real R15 character via HumanoidDescription
	local ok, model = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)

	if not ok or not model then
		-- Fallback: simple clean R6 rig (still better than a blue blob)
		model = Instance.new("Model")

		local hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Size = Vector3.new(2, 2, 1); hrp.Transparency = 1; hrp.CanCollide = false
		hrp.Parent = model

		local torso = Instance.new("Part")
		torso.Name = "Torso"; torso.Size = Vector3.new(2, 2, 1)
		torso.Color = Color3.fromRGB(0, 100, 200); torso.Parent = model
		local tw = Instance.new("WeldConstraint")
		tw.Part0 = hrp; tw.Part1 = torso; tw.Parent = torso

		local head = Instance.new("Part")
		head.Name = "Head"; head.Size = Vector3.new(1.5, 1.5, 1.5)
		head.Shape = Enum.PartType.Ball; head.Color = Color3.fromRGB(245, 205, 160)
		head.Position = torso.Position + Vector3.new(0, 1.75, 0); head.Parent = model
		local hw = Instance.new("WeldConstraint")
		hw.Part0 = torso; hw.Part1 = head; hw.Parent = head

		local hum = Instance.new("Humanoid"); hum.Parent = model
		model.PrimaryPart = hrp
	end

	model.Name = "PrankTarget"
	model:SetAttribute("KittyRaiserNPC", true)
	model:SetAttribute("Pranked", false)

	-- Random outfit palette
	local palette = OUTFIT_PALETTES[math.random(1, #OUTFIT_PALETTES)]
	pcall(tintRig, model, palette)

	-- Strip clothing/shirts so the tint shows
	for _, c in ipairs(model:GetChildren()) do
		if c:IsA("Shirt") or c:IsA("Pants") or c:IsA("ShirtGraphic") or c:IsA("Accessory") then
			c:Destroy()
		end
	end

	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = math.random(8, 14)
		hum.MaxHealth = 100
		hum.Health = 100
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		-- Normal human proportions — these victims are humans the cat is
		-- pranking. The cat (player) is small; humans tower over it.
		local scales = {
			BodyDepthScale  = 1.00,
			BodyWidthScale  = 1.00,
			BodyHeightScale = 1.05,
			HeadScale       = 1.00,
			BodyTypeScale   = 1.00,
			ProportionScale = 1.00,
		}
		for sname, sval in pairs(scales) do
			local nv = hum:FindFirstChild(sname)
			if nv and nv:IsA("NumberValue") then nv.Value = sval end
		end
	end

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

-- =====================================================================
-- BOSS NPC: bigger, brighter, with a floating HP bar that drains as the
-- player pranks them. Boss survives multiple pranks (5 hits) and pays out
-- ~10x normal chaos when finally pranked.
-- =====================================================================
local BOSS_HP = 5
local BOSS_REWARD_MULT = 3  -- 5 hits * 3x base = 15x total reward

local function makeBossHpBar(npc)
    local head = npc:FindFirstChild("Head")
    if not head then return end
    local g = Instance.new("BillboardGui")
    g.Name = "BossHpBar"
    g.Size = UDim2.new(0, 180, 0, 28)
    g.StudsOffset = Vector3.new(0, 2.6, 0)
    g.AlwaysOnTop = true
    g.Parent = head
    local panel = Instance.new("Frame", g)
    panel.Size = UDim2.fromScale(1, 1)
    panel.BackgroundColor3 = Color3.fromRGB(28, 18, 12)
    panel.BorderSizePixel = 0
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 6)
    local label = Instance.new("TextLabel", panel)
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Size = UDim2.new(1, -8, 0, 12)
    label.Position = UDim2.new(0.5, 0, 0, 1)
    label.BackgroundTransparency = 1
    label.Text = "BOSS"
    label.TextColor3 = Color3.fromRGB(255, 220, 80)
    label.Font = Enum.Font.GothamBlack
    label.TextScaled = true
    local lc = Instance.new("UITextSizeConstraint", label); lc.MinTextSize = 10; lc.MaxTextSize = 14
    local barBg = Instance.new("Frame", panel)
    barBg.AnchorPoint = Vector2.new(0.5, 1)
    barBg.Size = UDim2.new(1, -8, 0, 10)
    barBg.Position = UDim2.new(0.5, 0, 1, -3)
    barBg.BackgroundColor3 = Color3.fromRGB(60, 40, 25)
    barBg.BorderSizePixel = 0
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(1, 0)
    local fill = Instance.new("Frame", barBg)
    fill.Name = "Fill"
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(220, 80, 70)
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    return fill
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

    -- 1-in-8 chance of being a BOSS variant
    local isBoss = math.random(1, 8) == 1
    if isBoss then
        npc:SetAttribute("Boss", true)
        npc:SetAttribute("BossHP", BOSS_HP)
        -- Make the boss bigger + golden tint
        local hum = npc:FindFirstChildOfClass("Humanoid")
        if hum then
            for sname, sval in pairs({
                BodyDepthScale=1.20, BodyWidthScale=1.50, BodyHeightScale=1.25,
                HeadScale=1.80,
            }) do
                local nv = hum:FindFirstChild(sname)
                if nv and nv:IsA("NumberValue") then nv.Value = sval end
            end
            hum.MaxHealth = BOSS_HP * 100
            hum.Health = hum.MaxHealth
        end
        -- Tint shirt parts gold to mark boss
        for _, p in ipairs(npc:GetDescendants()) do
            if p:IsA("BasePart") and (p.Name == "UpperTorso" or p.Name == "LowerTorso" or p.Name == "Torso") then
                p.Color = Color3.fromRGB(225, 175, 75)
            end
        end
        npc.Name = "PrankBoss"
    end

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

    -- Spawn slightly above the target so they "drop in"
    local startCF = CFrame.new(spawnPos + Vector3.new(0, 6, 0))
    local landCF = CFrame.new(spawnPos)
    npc:PivotTo(startCF)
    npc:SetAttribute("SummonedBy", player.UserId)
    npc.Parent = npcFolder

    -- Brief drop-in poof of smoke at landing point
    task.spawn(function()
        local emitterPart = Instance.new("Part")
        emitterPart.Anchored = true; emitterPart.CanCollide = false
        emitterPart.Transparency = 1; emitterPart.Size = Vector3.new(1,1,1)
        emitterPart.CFrame = landCF
        emitterPart.Parent = Workspace
        local emitter = Instance.new("ParticleEmitter")
        emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
        emitter.Color = ColorSequence.new(Color3.fromRGB(220, 220, 230))
        emitter.Lifetime = NumberRange.new(0.5, 1.0)
        emitter.Rate = 0
        emitter.Speed = NumberRange.new(8, 14)
        emitter.SpreadAngle = Vector2.new(180, 180)
        emitter.Size = NumberSequence.new(2.5, 0.5)
        emitter.Transparency = NumberSequence.new(0.2, 1)
        emitter.Parent = emitterPart
        emitter:Emit(20)
        task.wait(2)
        emitterPart:Destroy()
    end)

    -- Drop-in: PivotTo from above (works for both R15 and welded fallback)
    task.spawn(function()
        local steps = 10
        for i = 1, steps do
            local t = i / steps
            local eased = 1 - (1 - t) * (1 - t)  -- ease-out quad
            npc:PivotTo(startCF:Lerp(landCF, eased))
            task.wait(0.04)
        end
    end)

    wanderAI(npc)

    -- Boss: build floating HP bar after the drop-in finishes + play warning stinger
    if npc:GetAttribute("Boss") then
        task.delay(0.6, function()
            if not npc.Parent then return end
            makeBossHpBar(npc)
        end)
        if AssetIds.has("boss_warning") then
            local s = Instance.new("Sound")
            s.SoundId = AssetIds.boss_warning
            s.Volume = 1.0
            if AudioGroups then AudioGroups.assign(s, "SFX") end
            s.Parent = npc:FindFirstChild("Head") or npc
            s:Play()
            game:GetService("Debris"):AddItem(s, 5)
        end
    end

    return true, npc
end

-- Despawn pranked NPC after a delay.
-- For bosses: drain HP first; only mark Pranked when HP hits 0. The PrankSystem
-- still calls this on every hit, so we tap HP and rebuild the bar instead.
function SummonSystem.markPranked(npc)
    if not npc then return end
    if npc:GetAttribute("Boss") and not npc:GetAttribute("BossDefeated") then
        local hp = (npc:GetAttribute("BossHP") or BOSS_HP) - 1
        npc:SetAttribute("BossHP", math.max(0, hp))
        local head = npc:FindFirstChild("Head")
        local bar = head and head:FindFirstChild("BossHpBar")
        if bar then
            local fill = bar:FindFirstChild("Frame") and bar.Frame:FindFirstChild("Fill")
            if fill then
                local pct = hp / BOSS_HP
                game:GetService("TweenService"):Create(fill,
                    TweenInfo.new(0.25),
                    {Size = UDim2.new(math.max(0, pct), 0, 1, 0),
                     BackgroundColor3 = (pct < 0.4)
                        and Color3.fromRGB(255, 80, 60)
                        or Color3.fromRGB(220, 80, 70)}):Play()
            end
        end
        if hp > 0 then
            return  -- still alive, don't mark Pranked
        end
        npc:SetAttribute("BossDefeated", true)
    end
    npc:SetAttribute("Pranked", true)
    task.delay(2, function()
        if npc.Parent then npc:Destroy() end
    end)
end

-- Public: get bonus chaos multiplier for a target
function SummonSystem.getRewardMultiplier(npc)
    if npc and npc:GetAttribute("Boss") then return BOSS_REWARD_MULT end
    return 1
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
