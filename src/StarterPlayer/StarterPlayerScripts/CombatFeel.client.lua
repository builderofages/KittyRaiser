-- CombatFeel.client.lua  v2 — hit-stop, damage numbers, combo, screen flash.
-- Bound text sizes, softer flash, no double camera-shake (EffectsController
-- already does the position shake; we only do the FOV pulse here).

local Players       = game:GetService("Players")
local TweenService  = game:GetService("TweenService")
local SoundService  = game:GetService("SoundService")
local Workspace     = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris        = game:GetService("Debris")

local Remotes      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local AssetIds     = require(ReplicatedStorage.Modules:WaitForChild("AssetIds"))
local PrankConfig  = require(ReplicatedStorage.Modules.PrankConfig)
local UIUtil       = require(ReplicatedStorage.Modules:WaitForChild("UIUtil"))

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera    = Workspace.CurrentCamera

-- Combo tracking
local combo = 0
local lastComboTime = 0
local COMBO_TIMEOUT = 3

local comboGui = Instance.new("ScreenGui")
comboGui.Name = "ComboGui"
comboGui.IgnoreGuiInset = false
comboGui.ResetOnSpawn = false
comboGui.DisplayOrder = UIUtil.DisplayOrder.Combo
comboGui.Parent = playerGui

local comboLabel = Instance.new("TextLabel")
comboLabel.Size = UDim2.new(0, 320, 0, 70)
comboLabel.AnchorPoint = Vector2.new(0.5, 0)
comboLabel.Position = UDim2.new(0.5, 0, 0.18, 0)
comboLabel.BackgroundTransparency = 1
comboLabel.Text = ""
comboLabel.Font = Enum.Font.GothamBlack
comboLabel.TextScaled = true
comboLabel.TextColor3 = Color3.fromRGB(255, 220, 50)
comboLabel.TextStrokeTransparency = 0
comboLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
comboLabel.Visible = false
comboLabel.Parent = comboGui
UIUtil.boundText(comboLabel, 22, 48)

-- Screen flash overlay (soft, vignette-style)
local flashGui = Instance.new("ScreenGui")
flashGui.Name = "ScreenFlash"
flashGui.IgnoreGuiInset = true
flashGui.ResetOnSpawn = false
flashGui.DisplayOrder = UIUtil.DisplayOrder.ScreenFlash
flashGui.Parent = playerGui
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = flashGui
-- Soft vignette gradient: transparent in center, slight tint at edges.
local flashGradient = Instance.new("UIGradient")
flashGradient.Color = ColorSequence.new(Color3.new(1, 1, 1))
flashGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.5, 0.5),
	NumberSequenceKeypoint.new(1, 0),
})
flashGradient.Rotation = 0
flashGradient.Parent = flash

local function comboColorFor(c)
	if c >= 20 then return Color3.fromRGB(255, 100, 255) end
	if c >= 10 then return Color3.fromRGB(255, 80, 80)  end
	if c >= 5  then return Color3.fromRGB(255, 165, 0)  end
	return Color3.fromRGB(255, 220, 50)
end

local function bumpCombo()
	local now = os.clock()
	if (now - lastComboTime) < COMBO_TIMEOUT then
		combo = combo + 1
	else
		combo = 1
	end
	lastComboTime = now
	if combo >= 2 then
		comboLabel.Text = "x" .. combo .. " COMBO"
		comboLabel.TextColor3 = comboColorFor(combo)
		comboLabel.TextTransparency = 0
		comboLabel.TextStrokeTransparency = 0
		comboLabel.Visible = true
		-- Pulse via scale on AnchorPoint so it doesn't shift position
		comboLabel.Size = UDim2.new(0, 320, 0, 70)
		TweenService:Create(comboLabel,
			TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{Size = UDim2.new(0, 360, 0, 80)}):Play()
		task.delay(0.28, function()
			TweenService:Create(comboLabel, TweenInfo.new(0.15),
				{Size = UDim2.new(0, 320, 0, 70)}):Play()
		end)
		task.delay(COMBO_TIMEOUT, function()
			if (os.clock() - lastComboTime) >= COMBO_TIMEOUT then
				TweenService:Create(comboLabel, TweenInfo.new(0.4),
					{TextTransparency = 1, TextStrokeTransparency = 1}):Play()
				task.wait(0.5)
				comboLabel.Visible = false
				combo = 0
			end
		end)
	end
end

local function fovPulse(delta, durationMS)
	-- Gentle FOV pulse only; position shake is owned by EffectsController.
	local origFov = camera.FieldOfView
	TweenService:Create(camera, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{FieldOfView = origFov + (delta or 5)}):Play()
	task.wait((durationMS or 80) / 1000)
	TweenService:Create(camera, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{FieldOfView = origFov}):Play()
end

local function screenFlash(color, intensity)
	-- Softer than the previous full-white flashbang.
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - math.clamp((intensity or 0.25) * 0.6, 0, 0.5)
	TweenService:Create(flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = 1}):Play()
end

local function spawnDamageNumber(worldCFrame, amount)
	local part = Instance.new("Part")
	part.Anchored = true; part.CanCollide = false; part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = worldCFrame + Vector3.new(math.random()*4-2, 3, math.random()*4-2)
	part.Parent = Workspace

	local g = Instance.new("BillboardGui")
	g.Size = UDim2.new(0, 140, 0, 60)
	g.AlwaysOnTop = true
	g.StudsOffset = Vector3.new(0, 1.4, 0)
	g.Parent = part

	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = "+" .. amount
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = comboColorFor(combo)
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.Parent = g
	UIUtil.boundText(l, 16, 38)

	task.spawn(function()
		for i = 1, 28 do
			part.CFrame = part.CFrame + Vector3.new(0, 0.16, 0)
			l.TextTransparency = i / 28
			l.TextStrokeTransparency = (i / 28) * 0.7
			task.wait(0.04)
		end
		part:Destroy()
	end)
end

local function playPrankSound(prankName)
	local soundIdMap = {
		CatScratch = AssetIds.cat_scratch,
		Pie        = AssetIds.pie_splat,
		Hairball   = AssetIds.fish_slap,
		Anvil      = AssetIds.anvil_clang,
		FartCloud  = AssetIds.tp_unroll,
		LaserEyes  = AssetIds.flight_whoosh,
		Whip       = AssetIds.cat_scratch,
		Purrgatory = AssetIds.purrgatory,
	}
	local id = soundIdMap[prankName]
	if id and id ~= "rbxassetid://0" then
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = 1.0
		s.Parent = SoundService
		s:Play()
		Debris:AddItem(s, 4)
	end
end

if Remotes.PrankRegistered then
	Remotes.PrankRegistered.OnClientEvent:Connect(function(prankName, targetModel, chaos, fxPayload)
		local prank = PrankConfig.Pranks[prankName]
		bumpCombo()

		-- FOV pulse intensity scales with prank's screenShake config but capped.
		local shake = (prank and prank.screenShake) or 0
		if shake > 0 then
			task.spawn(fovPulse, math.min(shake * 0.5, 6), 80)
		end

		-- Per-prank flash color (toned down)
		local flashColor = Color3.fromRGB(255, 240, 200)
		if prankName == "Anvil"      then flashColor = Color3.fromRGB(255, 220, 130)
		elseif prankName == "Pie"     then flashColor = Color3.fromRGB(255, 250, 230)
		elseif prankName == "LaserEyes" then flashColor = Color3.fromRGB(255, 100, 100)
		elseif prankName == "Purrgatory" then flashColor = Color3.fromRGB(180, 100, 220)
		end
		screenFlash(flashColor, 0.22)

		if targetModel and targetModel.PrimaryPart and chaos and chaos > 0 then
			spawnDamageNumber(targetModel.PrimaryPart.CFrame, chaos)
		end
		playPrankSound(prankName)
	end)
end

print("[CombatFeel v2] FOV pulse, soft flash, bounded text, combo")
