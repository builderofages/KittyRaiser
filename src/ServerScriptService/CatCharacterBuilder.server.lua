-- CatCharacterBuilder.server.lua  v10 — REAL QUADRUPED CAT.
--
-- v9 was still a vertical biped cat-shape that read as a humanoid.
-- v10 builds the cat HORIZONTAL (the same quadruped pose as the lobby
-- preview): body parallel to the ground, four legs underneath touching
-- the floor, head forward at -Z, tail arching back and up at +Z.
--
-- Strategy:
--   1. Hide the entire R15 body (Transparency=1) and strip cosmetic Accessories.
--   2. Shrink R15 body scales aggressively (0.30) so the underlying invisible
--      humanoid is small. Disable AutomaticScalingEnabled so our scales stick.
--   3. Set Humanoid.HipHeight = 1.5 so HRP floats 1.5 studs above ground —
--      that's exactly where our cat-body center needs to be so the paws
--      touch the ground.
--   4. Weld the quadruped cat shape to HumanoidRootPart, body centered on HRP,
--      legs pointing down (-Y from HRP) so paws sit on the floor.
--   5. The R15 still drives Humanoid:Move() / WalkSpeed so the cat moves like
--      any other character — but visually it's a small quadruped sliding
--      across the ground, with humans towering over it.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

Players.CharacterAutoLoads = true

local AudioGroups
do
	local m = ReplicatedStorage:WaitForChild("Modules", 5)
	local a = m and m:WaitForChild("AudioGroups", 5)
	if a then local ok, mod = pcall(require, a); if ok then AudioGroups = mod end end
end

local AssetIds
do
	local m = ReplicatedStorage:WaitForChild("Modules", 5)
	local a = m and m:WaitForChild("AssetIds", 5)
	if a then local ok, mod = pcall(require, a); if ok then AssetIds = mod end end
	if not AssetIds then
		AssetIds = setmetatable({}, {__index = function() return "rbxassetid://0" end})
		AssetIds.has = function() return false end
	end
end

local FUR_COLORS = {
	Color3.fromRGB(220, 130, 50),
	Color3.fromRGB(105, 75, 55),
	Color3.fromRGB(45, 40, 40),
	Color3.fromRGB(225, 220, 210),
	Color3.fromRGB(150, 140, 130),
	Color3.fromRGB(245, 215, 175),
}

local function newPart(props)
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	return p
end

local function weldTo(parent, child)
	local w = Instance.new("WeldConstraint")
	w.Part0 = parent; w.Part1 = child
	w.Parent = child
end

local function markAccessory(p) p:SetAttribute("CatAccessory", true) end

-- =====================================================================
-- HIDE THE R15 + STRIP DEFAULT ACCESSORIES
-- =====================================================================
local R15_BODY_PARTS = {
	Head = true, UpperTorso = true, LowerTorso = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
	Torso = true, ["Left Arm"] = true, ["Right Arm"] = true,
	["Left Leg"] = true, ["Right Leg"] = true,
}
local function hideR15(character)
	for _, p in ipairs(character:GetDescendants()) do
		if p:IsA("BasePart") and R15_BODY_PARTS[p.Name] and not p:GetAttribute("CatAccessory") then
			p.Transparency = 1
			for _, c in ipairs(p:GetChildren()) do
				if c:IsA("Decal") and (c.Name == "face" or c.Name == "Face") then
					c:Destroy()
				end
			end
		end
	end
end

local function stripCosmetics(character)
	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic")
		   or child:IsA("Accessory") or child:IsA("Hat") or child:IsA("CharacterMesh") then
			child:Destroy()
		end
	end
end

-- =====================================================================
-- QUADRUPED CAT — body horizontal, legs underneath, head forward, tail back.
-- All offsets relative to HRP center (which floats at HipHeight above ground).
-- =====================================================================
local function buildCatShape(character, furColor)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	-- Clear any prior cat shape
	for _, c in ipairs(character:GetChildren()) do
		if c:IsA("BasePart") and c:GetAttribute("CatBody") then
			c:Destroy()
		end
	end

	local SCALE = 1.0  -- exact match to lobby preview proportions
	local function s(v) return v * SCALE end

	local function attach(part, anchor)
		part.Parent = character
		weldTo(anchor or hrp, part)
		markAccessory(part)
		part:SetAttribute("CatBody", true)
	end

	-- BODY: horizontal oblong, long axis along Z. Body center at HRP center.
	local body = newPart{
		Name = "CatBody",
		Size = Vector3.new(s(1.6), s(1.2), s(2.4)),
		Color = furColor,
	}
	body.CFrame = hrp.CFrame
	attach(body, hrp)

	-- CHEST (forward bulge)
	local chest = newPart{
		Name = "CatChest",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(s(1.5), s(1.3), s(1.5)),
		Color = furColor,
	}
	chest.CFrame = hrp.CFrame * CFrame.new(0, 0, -s(0.8))
	attach(chest, body)

	-- HEAD (forward, slightly raised)
	local head = newPart{
		Name = "CatHead",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(s(1.35), s(1.3), s(1.3)),
		Color = furColor,
	}
	head.CFrame = hrp.CFrame * CFrame.new(0, s(0.45), -s(1.55))
	attach(head, body)

	-- CHEEKS
	for _, sx in ipairs({-1, 1}) do
		local cheek = newPart{
			Name = "CatCheek",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s(0.6), s(0.55), s(0.55)),
			Color = furColor,
		}
		cheek.CFrame = head.CFrame * CFrame.new(sx * s(0.45), -s(0.15), -s(0.2))
		attach(cheek, head)
	end

	-- EYES (sclera + slit pupil) facing -Z
	for _, sx in ipairs({-1, 1}) do
		local sclera = newPart{
			Name = "CatEye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s(0.32), s(0.32), s(0.32)),
			Color = Color3.fromRGB(255, 255, 255),
		}
		sclera.CFrame = head.CFrame * CFrame.new(sx * s(0.32), s(0.1), -s(0.55))
		attach(sclera, head)

		local pupil = newPart{
			Name = "CatPupil",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s(0.12), s(0.26), s(0.12)),
			Color = Color3.fromRGB(60, 220, 110),
			Material = Enum.Material.Neon,
		}
		pupil.CFrame = sclera.CFrame * CFrame.new(0, 0, -s(0.1))
		attach(pupil, head)
	end

	-- NOSE
	local nose = newPart{
		Name = "CatNose",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(s(0.18), s(0.14), s(0.14)),
		Color = Color3.fromRGB(255, 130, 150),
	}
	nose.CFrame = head.CFrame * CFrame.new(0, -s(0.18), -s(0.6))
	attach(nose, head)

	-- MOUTH
	for _, sx in ipairs({-1, 1}) do
		local m = newPart{
			Name = "CatMouth",
			Size = Vector3.new(s(0.18), s(0.04), s(0.04)),
			Color = Color3.fromRGB(60, 30, 30),
		}
		m.CFrame = head.CFrame
			* CFrame.new(sx * s(0.08), -s(0.34), -s(0.62))
			* CFrame.Angles(0, 0, sx * math.rad(20))
		attach(m, head)
	end

	-- WHISKERS
	for _, sx in ipairs({-1, 1}) do
		for _, yOff in ipairs({-0.05, -0.18, -0.31}) do
			local w = newPart{
				Name = "CatWhisker",
				Size = Vector3.new(s(0.55), s(0.025), s(0.025)),
				Color = Color3.fromRGB(40, 40, 40),
			}
			w.CFrame = head.CFrame * CFrame.new(sx * s(0.65), s(yOff), -s(0.45))
			attach(w, head)
		end
	end

	-- EARS (outer + pink inner)
	for _, sx in ipairs({-1, 1}) do
		local off = Vector3.new(sx * s(0.4), s(0.7), -s(0.05))
		local angle = sx * math.rad(8)
		local ear = newPart{
			Name = "CatEar",
			Size = Vector3.new(s(0.4), s(0.6), s(0.15)),
			Color = furColor,
		}
		ear.CFrame = head.CFrame * CFrame.new(off) * CFrame.Angles(math.rad(-5), angle, 0)
		attach(ear, head)
		local inner = newPart{
			Name = "CatEarInner",
			Size = Vector3.new(s(0.22), s(0.38), s(0.05)),
			Color = Color3.fromRGB(255, 180, 200),
		}
		inner.CFrame = ear.CFrame * CFrame.new(0, 0, -s(0.08))
		attach(inner, ear)
	end

	-- 4 LEGS underneath, with white paw tips at the bottom.
	-- Leg center at y = -0.85 (relative to body), leg height 1.0, paw at y = -0.55 below leg.
	-- Leg bottom = -0.85 - 0.5 = -1.35; paw bottom = -0.85 - 0.55 - 0.1 = -1.5.
	-- So we want HipHeight = 1.5 so paws touch ground.
	for _, lp in ipairs({
		Vector3.new(-0.45, -0.85, -0.7),   -- front-left
		Vector3.new( 0.45, -0.85, -0.7),   -- front-right
		Vector3.new(-0.45, -0.85,  0.85),  -- back-left
		Vector3.new( 0.45, -0.85,  0.85),  -- back-right
	}) do
		local leg = newPart{
			Name = "CatLeg",
			Size = Vector3.new(s(0.4), s(1.0), s(0.4)),
			Color = furColor,
		}
		leg.CFrame = body.CFrame * CFrame.new(s(lp.X), s(lp.Y), s(lp.Z))
		attach(leg, body)
		local paw = newPart{
			Name = "CatPaw",
			Size = Vector3.new(s(0.45), s(0.2), s(0.5)),
			Color = Color3.fromRGB(245, 240, 230),
		}
		paw.CFrame = leg.CFrame * CFrame.new(0, -s(0.55), s(0.05))
		attach(paw, leg)
	end

	-- TAIL — curved arc behind cat (+Z), arching upward.
	-- Tail uses a Motor6D so we can drive a gentle wag via Heartbeat without
	-- breaking the welded chain (the base segment Motor6D rotates, downstream
	-- WeldConstraints carry through the rotation).
	local tailRoot = body
	local tailBase
	local prevCF = body.CFrame * CFrame.new(0, s(0.2), s(1.2))
	local prevSize = 0.42
	for i = 1, 6 do
		local sz = math.max(0.22, prevSize - 0.03)
		local pitch = math.rad(-18 - i * 4)
		local seg = newPart{
			Name = (i == 6) and "CatTailTip" or "CatTail",
			Size = Vector3.new(s(sz), s(sz), s(0.6)),
			Color = furColor,
		}
		seg.CFrame = prevCF * CFrame.Angles(pitch, 0, 0) * CFrame.new(0, 0, s(0.4))
		if i == 1 then
			-- First segment hinged via Motor6D so we can swing the whole tail.
			seg.Parent = character
			markAccessory(seg)
			seg:SetAttribute("CatBody", true)
			local motor = Instance.new("Motor6D")
			motor.Name = "TailMotor"
			motor.Part0 = tailRoot
			motor.Part1 = seg
			motor.C0 = tailRoot.CFrame:ToObjectSpace(seg.CFrame)
			motor.C1 = CFrame.new()
			motor.Parent = tailRoot
			tailBase = seg
		else
			attach(seg, tailBase)
		end
		prevCF = seg.CFrame
		prevSize = sz
	end

	-- Idle tail wag: rotate the Motor6D's C1 around Y between -15 and +15deg
	-- on a sine curve. Gentle, looks alive even without custom animation.
	if tailBase then
		local motor = tailRoot:FindFirstChild("TailMotor")
		if motor then
			local RunService = game:GetService("RunService")
			local baseC1 = motor.C1
			local conn
			conn = RunService.Heartbeat:Connect(function()
				if not motor.Parent then if conn then conn:Disconnect() end; return end
				local theta = math.sin(os.clock() * 2.0) * math.rad(15)
				motor.C1 = baseC1 * CFrame.Angles(0, theta, 0)
			end)
		end
	end

	-- Floating name tag above the cat head.
	local g = Instance.new("BillboardGui")
	g.Name = "CatNameTag"
	g.Size = UDim2.new(0, 200, 0, 40)
	g.StudsOffset = Vector3.new(0, s(1.4), 0)
	g.AlwaysOnTop = true
	g.Parent = head
	local lbl = Instance.new("TextLabel", g)
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = ""
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0
	lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	local c = Instance.new("UITextSizeConstraint", lbl); c.MinTextSize = 14; c.MaxTextSize = 24

	-- Run trail: dust ParticleEmitter on a tiny part welded under the cat,
	-- enabled only when the cat is actually moving fast enough to "run".
	-- Keeps the trail from sparkling while idle.
	local trailPart = newPart{
		Name = "CatTrailEmitter",
		Size = Vector3.new(0.4, 0.1, 0.4),
		Transparency = 1,
		CanCollide = false,
	}
	trailPart.CFrame = body.CFrame * CFrame.new(0, -s(1.4), s(0.6))
	attach(trailPart, body)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RunDust"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(245, 230, 200))
	emitter.LightEmission = 0
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Rate = 0  -- driven by Heartbeat below
	emitter.Speed = NumberRange.new(2, 4)
	emitter.SpreadAngle = Vector2.new(45, 45)
	emitter.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0.8),
	}
	emitter.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	}
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Parent = trailPart

	-- Drive emission rate from the Humanoid's MoveDirection magnitude. Use
	-- a Heartbeat tick (cheap, single-character).
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		local RunService = game:GetService("RunService")
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if not trailPart.Parent or not hum.Parent then
				if conn then conn:Disconnect() end; return
			end
			local moving = hum.MoveDirection.Magnitude > 0.1 and hum.WalkSpeed >= 10
			emitter.Rate = moving and 24 or 0
		end)
	end

	return head, body, lbl
end

-- =====================================================================
-- BODY SCALES + HIPHEIGHT — make the underlying R15 small + position HRP
-- so the welded cat shape sits on the ground.
-- =====================================================================
local function setCatBodyScales(humanoid)
	-- Disable Roblox's automatic scaling so our explicit values stick.
	pcall(function() humanoid.AutomaticScalingEnabled = false end)
	local scales = {
		BodyDepthScale  = 0.30,
		BodyWidthScale  = 0.30,
		BodyHeightScale = 0.30,
		HeadScale       = 0.30,
		BodyTypeScale   = 0.0,
		ProportionScale = 0.0,
	}
	for name, value in pairs(scales) do
		local nv = humanoid:FindFirstChild(name)
		if nv and nv:IsA("NumberValue") then nv.Value = value end
	end
	-- HipHeight = 1.5 puts HRP center exactly where the cat body needs to be
	-- for paws to touch ground (paw bottom at -1.5 from HRP center).
	humanoid.HipHeight = 1.5
	-- Camera offset: lift focus point slightly so the camera frames the cat
	-- and the world ahead, not the back of the cat's head.
	humanoid.CameraOffset = Vector3.new(0, 1.0, 0)
end

-- =====================================================================
-- SPAWN CHIME + CITY AMBIENT
-- =====================================================================
local function playSpawnChime(character)
	if not AssetIds.has("spawn_chime") then return end
	local head = character:FindFirstChild("Head")
	local s = Instance.new("Sound")
	s.SoundId = AssetIds.spawn_chime
	s.Volume = 0.7
	if AudioGroups then AudioGroups.assign(s, "UI") end
	s.Parent = head or character
	s:Play()
	game:GetService("Debris"):AddItem(s, 4)
end

local function ensureCityAmbient()
	local SoundService = game:GetService("SoundService")
	local TweenService = game:GetService("TweenService")
	if SoundService:FindFirstChild("CityAmbient") then return end
	if not AssetIds.has("city_ambient") then return end
	local s = Instance.new("Sound")
	s.Name = "CityAmbient"
	s.SoundId = AssetIds.city_ambient
	s.Looped = true
	s.Volume = 0
	if AudioGroups then AudioGroups.assign(s, "Music") end
	s.Parent = SoundService
	s:Play()
	TweenService:Create(s, TweenInfo.new(2.0, Enum.EasingStyle.Quad), {Volume = 0.6}):Play()
end
task.spawn(ensureCityAmbient)

-- =====================================================================
-- DECORATE — apply everything to a freshly-spawned character.
-- =====================================================================
local function decorateCharacter(player, character)
	local hum  = character:WaitForChild("Humanoid", 5);          if not hum then return end
	local _r15head = character:WaitForChild("Head", 5);          if not _r15head then return end
	local hrp  = character:WaitForChild("HumanoidRootPart", 5);  if not hrp then return end

	task.wait(0.05)

	local fc = player:GetAttribute("FurColor")
	local color
	if typeof(fc) == "Color3" then color = fc
	else color = FUR_COLORS[math.random(1, #FUR_COLORS)]
		player:SetAttribute("FurColor", color) end

	pcall(stripCosmetics, character)
	pcall(setCatBodyScales, hum)
	pcall(hideR15, character)
	local catHead, catBody, nameLbl = nil, nil, nil
	pcall(function()
		catHead, catBody, nameLbl = buildCatShape(character, color)
	end)
	if nameLbl then nameLbl.Text = player.DisplayName end
	pcall(playSpawnChime, character)

	hum.WalkSpeed = 18
	hum.JumpPower = 50

	character:SetAttribute("KittyCat", true)
	character:SetAttribute("FurColor", color)

	print(("[CatCharacterBuilder v10] %s spawned as quadruped cat (color=%s)"):format(
		player.Name, tostring(color)))
end

local function setupPlayer(player)
	if player.Character then decorateCharacter(player, player.Character) end
	player.CharacterAdded:Connect(function(character)
		task.wait(0.1)
		decorateCharacter(player, character)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end

-- Fur-color tween mid-game.
local TweenService = game:GetService("TweenService")
local FUR_TINTABLE = { CatBody=true, CatChest=true, CatHead=true, CatCheek=true,
                       CatEar=true, CatLeg=true, CatTail=true, CatTailTip=true }
local function watchFurChanges(player)
	player:GetAttributeChangedSignal("FurColor"):Connect(function()
		local newColor = player:GetAttribute("FurColor")
		if typeof(newColor) ~= "Color3" then return end
		local char = player.Character
		if not char then return end
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") and FUR_TINTABLE[p.Name] then
				TweenService:Create(p, TweenInfo.new(0.6), {Color = newColor}):Play()
			end
		end
	end)
end
Players.PlayerAdded:Connect(watchFurChanges)
for _, p in ipairs(Players:GetPlayers()) do watchFurChanges(p) end

-- =====================================================================
-- LOBBY -> CHARACTER (listens on BOTH module + root copies, v3.40 fix)
-- =====================================================================
local function handleSpawnRequest(player, data)
	if typeof(data) == "table" and typeof(data.furColor) == "table" then
		local r = tonumber(data.furColor[1]) or 220
		local g = tonumber(data.furColor[2]) or 130
		local b = tonumber(data.furColor[3]) or 50
		local color = Color3.fromRGB(r, g, b)
		player:SetAttribute("FurColor", color)
		player:SetAttribute("SkinName", tostring(data.skinName or ""))
		print(("[CatCharacterBuilder v10] %s requested fur RGB(%d,%d,%d) name=%s"):format(
			player.Name, r, g, b, tostring(data.skinName or "")))
	end
	pcall(function() player:LoadCharacter() end)
end

task.spawn(function()
	local Modules = ReplicatedStorage:WaitForChild("Modules", 10)
	local RemoteEvents = Modules and Modules:WaitForChild("RemoteEvents", 5)
	if RemoteEvents then
		local ok, Remotes = pcall(require, RemoteEvents)
		if ok and Remotes and Remotes.RequestSpawnCustomization then
			Remotes.RequestSpawnCustomization.OnServerEvent:Connect(handleSpawnRequest)
			print("[CatCharacterBuilder v10] listening on Modules.RemoteEvents")
		end
	end
	local rootEvent = ReplicatedStorage:WaitForChild("RequestSpawnCustomization", 10)
	if rootEvent and rootEvent:IsA("RemoteEvent") then
		rootEvent.OnServerEvent:Connect(handleSpawnRequest)
		print("[CatCharacterBuilder v10] listening on ReplicatedStorage root")
	end
end)

print("[CatCharacterBuilder v10] online — REAL quadruped cat (horizontal body, paws on ground)")
