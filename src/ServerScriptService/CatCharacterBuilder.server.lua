-- CatCharacterBuilder.server.lua  v9 — actual cat shape, not humanoid + decoration.
--
-- Playtest of v8 showed the character was a Robloxian-with-cat-face: face decal
-- on a humanoid head, default hair accessory still visible (red afro), body
-- still humanoid-proportioned. Players want to LOOK like the cat shown in the
-- PreSpawnLobby preview.
--
-- v9 strategy:
--   1. Keep R15 character for movement (HumanoidRootPart drives Humanoid:Move()).
--   2. Strip ALL Shirt / Pants / ShirtGraphic / Accessory (kills default hair).
--   3. Set transparency=1 on every R15 BasePart that's visible (Head, UpperTorso,
--      LowerTorso, all Arm/Leg/Hand/Foot parts) — they're still there for
--      physics + Motor6D rig, just invisible.
--   4. Build a welded cat-shape Model parented to HumanoidRootPart using the
--      same primitive structure as PreSpawnLobby.buildCat but scaled up to
--      humanoid size. Body, head with cheeks, eyes (ball + slit pupil), nose,
--      whiskers, ears with pink inner, four legs with white paw tips, curved
--      tail of segments.
--   5. The cat-shape parts are welded to the HRP so they follow movement.
--      No CFrame manipulation; physics-safe.
--
-- Place in: ServerScriptService > CatCharacterBuilder. Auto-runs.

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
	Color3.fromRGB(220, 130, 50),  -- orange tabby
	Color3.fromRGB(80, 60, 50),    -- brown
	Color3.fromRGB(40, 40, 40),    -- black
	Color3.fromRGB(220, 220, 215), -- white
	Color3.fromRGB(140, 130, 120), -- grey tabby
	Color3.fromRGB(255, 200, 180), -- cream
}

-- =====================================================================
-- HELPERS
-- =====================================================================
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
-- HIDE R15 BODY (so only our cat shape is visible)
-- =====================================================================
local R15_BODY_PARTS = {
	Head = true, UpperTorso = true, LowerTorso = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
	-- legacy R6
	Torso = true, ["Left Arm"] = true, ["Right Arm"] = true,
	["Left Leg"] = true, ["Right Leg"] = true,
}
local function hideR15(character)
	for _, p in ipairs(character:GetDescendants()) do
		if p:IsA("BasePart") and R15_BODY_PARTS[p.Name] and not p:GetAttribute("CatAccessory") then
			p.Transparency = 1
			-- Strip face decal too if present
			for _, c in ipairs(p:GetChildren()) do
				if c:IsA("Decal") and (c.Name == "face" or c.Name == "Face") then
					c:Destroy()
				end
			end
		end
	end
end

-- Strip default cosmetics (Shirt / Pants / ShirtGraphic) AND default Accessory
-- items (the red afro hair, etc.) — without this the cat has hair on top.
local function stripCosmetics(character)
	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic")
		   or child:IsA("Accessory") or child:IsA("Hat") then
			child:Destroy()
		end
	end
end

-- =====================================================================
-- CAT BODY — primitive welded shape parented to HumanoidRootPart.
-- Mirrors the PreSpawnLobby preview cat, scaled up ~1.7x for humanoid size.
-- =====================================================================
local function buildCatShape(character, furColor)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	-- Clear any prior cat shape (e.g. from a previous spawn on the same char)
	for _, c in ipairs(character:GetChildren()) do
		if c:IsA("BasePart") and c:GetAttribute("CatBody") then
			c:Destroy()
		end
	end

	local SCALE = 1.7  -- character-size multiplier vs the lobby preview
	local function s(v) return v * SCALE end

	local function attach(part, anchor)
		part.Parent = character
		weldTo(anchor or hrp, part)
		markAccessory(part)
		part:SetAttribute("CatBody", true)
	end

	-- Body — sleek oblong, slightly tapered. Sits centered on HRP.
	local body = newPart{
		Name = "CatBody",
		Size = Vector3.new(s(1.6), s(1.2), s(2.4)),
		Color = furColor,
	}
	body.CFrame = hrp.CFrame
	attach(body, hrp)

	-- Chest — slight forward bulge
	local chest = newPart{
		Name = "CatChest",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(s(1.5), s(1.3), s(1.5)),
		Color = furColor,
	}
	chest.CFrame = hrp.CFrame * CFrame.new(0, 0, -s(0.8))
	attach(chest, body)

	-- Head — proportional, sits forward
	local head = newPart{
		Name = "CatHead",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(s(1.35), s(1.3), s(1.3)),
		Color = furColor,
	}
	head.CFrame = hrp.CFrame * CFrame.new(0, s(0.45), -s(1.55))
	attach(head, body)

	-- Cheeks for cat face shape
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

	-- Eyes (sclera + slit pupil) — facing the head's -Z direction
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

	-- Nose
	local nose = newPart{
		Name = "CatNose",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(s(0.18), s(0.14), s(0.14)),
		Color = Color3.fromRGB(255, 130, 150),
	}
	nose.CFrame = head.CFrame * CFrame.new(0, -s(0.18), -s(0.6))
	attach(nose, head)

	-- Mouth (two angled bars)
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

	-- Whiskers (3 per side)
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

	-- Ears (outer + pink inner)
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

	-- Legs (slim cylinders) with white paw tips
	for _, lp in ipairs({
		Vector3.new(-0.45, -0.85, -0.7),
		Vector3.new( 0.45, -0.85, -0.7),
		Vector3.new(-0.45, -0.85,  0.85),
		Vector3.new( 0.45, -0.85,  0.85),
	}) do
		local leg = newPart{
			Name = "CatLeg",
			Size = Vector3.new(s(0.4), s(1.0), s(0.4)),
			Color = furColor,
		}
		leg.CFrame = body.CFrame * CFrame.new(s(lp.X), s(lp.Y), s(lp.Z))
		attach(leg, body)
		-- Paw tip (white)
		local paw = newPart{
			Name = "CatPaw",
			Size = Vector3.new(s(0.45), s(0.2), s(0.5)),
			Color = Color3.fromRGB(245, 240, 230),
		}
		paw.CFrame = leg.CFrame * CFrame.new(0, -s(0.55), s(0.05))
		attach(paw, leg)
	end

	-- Tail — curved arc of segments
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
		attach(seg, body)
		prevCF = seg.CFrame
		prevSize = sz
	end

	-- Floating name tag above the cat head (not on R15 head, since that's invisible)
	local g = Instance.new("BillboardGui")
	g.Name = "CatNameTag"
	g.Size = UDim2.new(0, 200, 0, 40)
	g.StudsOffset = Vector3.new(0, s(1.2), 0)
	g.AlwaysOnTop = true
	g.Parent = head
	local lbl = Instance.new("TextLabel", g)
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = ""  -- filled below
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0
	lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	local c = Instance.new("UITextSizeConstraint", lbl); c.MinTextSize = 14; c.MaxTextSize = 24
	character:SetAttribute("CatHeadName", head.Name)
	-- expose head + body so callers can reach them
	return head, body, lbl
end

-- =====================================================================
-- BODY SCALES — make the underlying R15 small so the cat shape dominates.
-- (R15 parts are invisible; the scales mostly affect HRP collision box and
-- camera distance.)
-- =====================================================================
local function setCatBodyScales(humanoid)
	local scales = {
		BodyDepthScale  = 1.10,
		BodyWidthScale  = 0.90,
		BodyHeightScale = 0.65,
		HeadScale       = 1.20,
		BodyTypeScale   = 0.0,
		ProportionScale = 0.20,
	}
	for name, value in pairs(scales) do
		local nv = humanoid:FindFirstChild(name)
		if nv and nv:IsA("NumberValue") then nv.Value = value end
	end
end

-- =====================================================================
-- SPAWN CHIME + CITY AMBIENT (unchanged from v8)
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

	-- Wait one extra frame so HumanoidDescription's defaults are present
	-- BEFORE we strip them.
	task.wait(0.05)

	local fc = player:GetAttribute("FurColor")
	local color
	if typeof(fc) == "Color3" then color = fc
	else color = FUR_COLORS[math.random(1, #FUR_COLORS)]
		player:SetAttribute("FurColor", color) end

	pcall(setCatBodyScales, hum)
	pcall(stripCosmetics, character)
	pcall(hideR15, character)
	local catHead, catBody, nameLbl = nil, nil, nil
	pcall(function()
		catHead, catBody, nameLbl = buildCatShape(character, color)
	end)
	if nameLbl then nameLbl.Text = player.DisplayName end
	pcall(playSpawnChime, character)

	hum.WalkSpeed = 18
	hum.JumpPower = 55

	character:SetAttribute("KittyCat", true)
	character:SetAttribute("FurColor", color)

	print(("[CatCharacterBuilder v9] decorated %s as cat (color=%s)"):format(
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

-- Fur-color tween mid-game: tint every CatBody-attribute part (the welded
-- cat shape) but leave whisker/eye/nose/inner-ear distinct features alone.
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
		print(("[CatCharacterBuilder v9] %s requested fur RGB(%d,%d,%d) name=%s"):format(
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
			print("[CatCharacterBuilder v9] listening on Modules.RemoteEvents")
		end
	end
	local rootEvent = ReplicatedStorage:WaitForChild("RequestSpawnCustomization", 10)
	if rootEvent and rootEvent:IsA("RemoteEvent") then
		rootEvent.OnServerEvent:Connect(handleSpawnRequest)
		print("[CatCharacterBuilder v9] listening on ReplicatedStorage root")
	end
end)

print("[CatCharacterBuilder v9] online — actual cat shape (R15 hidden, welded primitives on top)")
