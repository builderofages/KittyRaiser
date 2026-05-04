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
		-- Cartoon proportions so victims look like Pixar civilians, not blocky Robloxians.
		local scales = {
			BodyDepthScale  = 0.95,
			BodyWidthScale  = 1.20,
			BodyHeightScale = 0.75,
			HeadScale       = 1.55,
			BodyTypeScale   = 0.0,
			ProportionScale = 0.10,
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
