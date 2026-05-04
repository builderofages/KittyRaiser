-- CatLifelike.server.lua  v2 — physics-safe micro animations for the cat.
--
-- The previous version overwrote welded body parts' CFrames with stale
-- spawn-time values, fighting physics. This version animates ONLY the
-- standalone CatEar / CatTail / CatTailTip parts (which are *attached* via
-- WeldConstraint, not part of the R15 Motor6D rig) by tweening the
-- WeldConstraint-driven part's CFrame through TweenService relative to the
-- head/torso transform. We sample the parent's CFrame each tick so the wag
-- follows the cat as it moves.
--
-- Place in: ServerScriptService > CatLifelike (Script). Auto-runs.

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Track per-player connections so we can disconnect them all on
-- PlayerRemoving instead of relying on parent-destruction races.
local conns = {}  -- userId -> { RBXScriptConnection, ... }
local function addConn(player, c)
	if not player then return end
	conns[player.UserId] = conns[player.UserId] or {}
	table.insert(conns[player.UserId], c)
end
local function killConns(userId)
	local list = conns[userId]
	if not list then return end
	for _, c in ipairs(list) do pcall(function() c:Disconnect() end) end
	conns[userId] = nil
end
Players.PlayerRemoving:Connect(function(p) killConns(p.UserId) end)

local function setup(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	-- Identify the owning player (used to track connections for cleanup)
	local owner = Players:GetPlayerFromCharacter(char)
	if owner then killConns(owner.UserId) end  -- clear any prior char's conns

	-- Cat tail wag — find CatTail and its CatTailTip
	local tail    = char:FindFirstChild("CatTail")
	local tailTip = char:FindFirstChild("CatTailTip")
	local anchor  = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if tail and anchor and tail:IsA("BasePart") then
		-- Snapshot the tail's CFrame relative to the torso ONCE.
		local relCF = anchor.CFrame:ToObjectSpace(tail.CFrame)
		-- Disable the existing weld so we can drive CFrame manually each frame.
		for _, w in ipairs(tail:GetChildren()) do
			if w:IsA("WeldConstraint") then w.Enabled = false end
		end
		tail.Anchored = false
		tail.CanCollide = false
		tail.Massless = true
		-- Heartbeat-driven wag using torso-relative CFrame so it follows the cat.
		local startedAt = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if not (tail.Parent and anchor.Parent) then conn:Disconnect() return end
			local t = os.clock() - startedAt
			-- Slow side-to-side wag, with extra wag when moving fast.
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local speed = 0
			if hrp then
				local v = hrp.AssemblyLinearVelocity
				speed = Vector3.new(v.X, 0, v.Z).Magnitude
			end
			local wag = math.sin(t * (3 + speed * 0.05)) * (math.rad(15) + math.rad(speed * 0.6))
			tail.CFrame = (anchor.CFrame * relCF) * CFrame.Angles(0, wag, 0)
			if tailTip and tailTip.Parent then
				-- Tip follows tail with slight lag
				local tipRel = CFrame.new(0, 0, 1.0)
				tailTip.CFrame = tail.CFrame * tipRel
			end
		end)
		if owner then addConn(owner, conn) end
	end

	-- Cat ear twitch — find both CatEar parts
	local ears = {}
	for _, c in ipairs(char:GetChildren()) do
		if c.Name == "CatEar" and c:IsA("BasePart") then
			table.insert(ears, c)
		end
	end
	for _, ear in ipairs(ears) do
		-- Snapshot ear's local-to-head transform
		local head = char:FindFirstChild("Head")
		if not head then break end
		local relCF = head.CFrame:ToObjectSpace(ear.CFrame)
		for _, w in ipairs(ear:GetChildren()) do
			if w:IsA("WeldConstraint") then w.Enabled = false end
		end
		ear.Anchored = false
		ear.CanCollide = false
		ear.Massless = true
		local startedAt = os.clock() + math.random()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if not (ear.Parent and head.Parent) then conn:Disconnect() return end
			local t = os.clock() - startedAt
			-- Mostly still, occasional twitch (every ~6-10s)
			local twitch = 0
			local cycle = math.fmod(t, 8)
			if cycle < 0.4 then
				twitch = math.sin(cycle / 0.4 * math.pi) * math.rad(15)
			end
			ear.CFrame = (head.CFrame * relCF) * CFrame.Angles(twitch, 0, 0)
		end)
		if owner then addConn(owner, conn) end
	end

	-- Cat dust trail: subtle dust puff under paws when running fast.
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if hrp then
		local att = Instance.new("Attachment", hrp)
		att.Name = "CatDustAttachment"
		att.Position = Vector3.new(0, -2.5, 0)  -- below feet
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(180, 165, 145))
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(0.5, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(0.3, 0.6)
		emitter.Speed = NumberRange.new(2, 5)
		emitter.SpreadAngle = Vector2.new(60, 60)
		emitter.Size = NumberSequence.new(0.4, 0.05)
		emitter.Acceleration = Vector3.new(0, 4, 0)
		emitter.Rate = 0
		emitter.Parent = att
		-- Heartbeat: when speed > 12 turn on dust; otherwise off
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if not (hrp.Parent and att.Parent) then conn:Disconnect() return end
			local v = hrp.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			emitter.Rate = speed > 12 and math.min(20, (speed - 12) * 4) or 0
		end)
		if owner then addConn(owner, conn) end
	end

	print("[CatLifelike v2] tail wag + ear twitch + dust trail active for " .. (char.Name or "?"))
end

local function setupPlayer(player)
	if player.Character then setup(player.Character) end
	player.CharacterAdded:Connect(function(char)
		task.wait(0.4)
		setup(char)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end

print("[CatLifelike v2] online")
