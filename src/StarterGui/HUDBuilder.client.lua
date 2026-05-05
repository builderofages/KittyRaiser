-- HUDBuilder.client.lua
-- Programmatically constructs the entire MainHUD ScreenGui.
-- Place in: StarterGui > HUDBuilder (LocalScript)
-- Other client scripts (HUDController, InputHandler) reference its named children.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))
local PrankConfig = require(ReplicatedStorage.Modules.PrankConfig)
local UIUtil      = require(ReplicatedStorage.Modules:WaitForChild("UIUtil"))
local AssetIds    = require(ReplicatedStorage.Modules:WaitForChild("AssetIds"))

-- Daytime/cartoon palette (overrides GameConfig HUD colors which were neon)
local PALETTE_BG       = Color3.fromRGB(80, 55, 40)   -- warm wood-stained brown
local PALETTE_PRIMARY  = Color3.fromRGB(255, 200, 80)
local PALETTE_ACCENT   = Color3.fromRGB(120, 200, 80)
local PALETTE_DANGER   = Color3.fromRGB(220, 80, 70)

-- Shared text-size bounds: TextScaled is great until it isn't.
local function bind(label, minSz, maxSz)
    UIUtil.boundText(label, minSz, maxSz)
    return label
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remove any existing MainHUD (dev hot reload)
local existing = playerGui:FindFirstChild("MainHUD")
if existing then existing:Destroy() end

-- IS_MOBILE = phone OR tablet (anything we should make touch-friendly)
local PLATFORM   = UIUtil.platform()
local IS_MOBILE  = (PLATFORM == "phone") or (PLATFORM == "tablet")
local IS_PHONE   = PLATFORM == "phone"

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = UIUtil.DisplayOrder.HUD
screenGui.Parent = playerGui

-- ===== Helpers =====
local function makeFrame(props)
    local f = Instance.new("Frame")
    for k, v in pairs(props) do f[k] = v end
    return f
end

local function makeLabel(props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font = Enum.Font.GothamBlack
    l.TextColor3 = Color3.fromRGB(255,255,255)
    l.TextStrokeTransparency = 0
    l.TextStrokeColor3 = Color3.new(0,0,0)
    l.TextScaled = true
    for k, v in pairs(props) do l[k] = v end
    return l
end

local function makeButton(props)
    local b = Instance.new("TextButton")
    b.AutoButtonColor = false
    b.Font = Enum.Font.GothamBlack
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.TextScaled = true
    b.BorderSizePixel = 0
    for k, v in pairs(props) do b[k] = v end
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = b
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.new(0,0,0)
    stroke.Parent = b
    return b
end

-- ===== TOP BAR =====
local topBar = makeFrame({
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, IS_MOBILE and 80 or 70),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = PALETTE_BG,
    BackgroundTransparency = 0.1,
    BorderSizePixel = 0,
    Parent = screenGui,
})
local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = PALETTE_PRIMARY
stroke.Parent = topBar

-- Generic helper: icon + label "currency cell" used by chaos/hell/rebirth.
-- Always renders a colored circle (UICorner) BEHIND the ImageLabel so even
-- when the asset hasn't loaded / is moderated / is private, the player
-- still sees a visible round badge instead of just the bare number.
local function buildCurrencyCell(parent, name, iconKey, iconColor, posX, sizeX)
    local wrap = makeFrame({
        Name = name,
        Size = UDim2.new(sizeX, 0, 0.7, 0),
        Position = UDim2.new(posX, 0, 0.15, 0),
        BackgroundTransparency = 1,
        Parent = parent,
    })

    -- Always-visible colored circle backplate (38x38). Sits at the LEFT edge
    -- of the wrap; label text starts after it via Position offset 44px.
    local backplate = Instance.new("Frame")
    backplate.Name = "IconBackplate"
    backplate.AnchorPoint = Vector2.new(0, 0.5)
    backplate.Size = UDim2.new(0, 38, 0, 38)
    backplate.Position = UDim2.new(0, 0, 0.5, 0)
    backplate.BackgroundColor3 = iconColor
    backplate.BorderSizePixel = 0
    backplate.Parent = wrap
    Instance.new("UICorner", backplate).CornerRadius = UDim.new(1, 0)
    local bpStroke = Instance.new("UIStroke", backplate)
    bpStroke.Thickness = 2
    bpStroke.Color = UIUtil.Palette.stroke
    bpStroke.Transparency = 0.3

    -- Real icon ImageLabel (if asset is uploaded) sits ON TOP of the
    -- backplate. Tinted white so the icon shape is visible against the
    -- colored circle. Size shrunk slightly so backplate ring shows.
    if iconKey and AssetIds.has(iconKey) then
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.BackgroundTransparency = 1
        icon.Size = UDim2.new(0, 28, 0, 28)
        icon.Position = UDim2.new(0.5, 0, 0.5, 0)
        icon.Image = AssetIds[iconKey]
        icon.ImageColor3 = Color3.fromRGB(255, 255, 255)  -- white tint so any color icon shows
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Parent = backplate
    end
    return wrap
end

-- Chaos counter (left): coin icon + amount
local chaosWrap = buildCurrencyCell(topBar, "ChaosWrap", "coin", PALETTE_PRIMARY, 0.01, 0.18)
bind(makeLabel({
    Name = "ChaosLabel",
    Size = UDim2.new(1, -40, 1, 0),
    Position = UDim2.new(0, 40, 0, 0),
    Text = "0",
    TextColor3 = PALETTE_PRIMARY,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = chaosWrap,
}), 14, 28)

-- Hell-tokens counter: gem icon + amount
local hellWrap = buildCurrencyCell(topBar, "HellWrap", "gem", Color3.fromRGB(220, 110, 220), 0.21, 0.16)
bind(makeLabel({
    Name = "HellLabel",
    Size = UDim2.new(1, -40, 1, 0),
    Position = UDim2.new(0, 40, 0, 0),
    Text = "0",
    TextColor3 = Color3.fromRGB(220, 150, 230),
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = hellWrap,
}), 14, 28)

-- Level + XP bar (middle)
local levelContainer = makeFrame({
    Name = "LevelContainer",
    Size = UDim2.new(0.28, 0, 0.7, 0),
    Position = UDim2.new(0.39, 0, 0.15, 0),
    BackgroundTransparency = 1,
    Parent = topBar,
})
bind(makeLabel({
    Name = "LevelLabel",
    Size = UDim2.new(1, 0, 0.55, 0),
    Position = UDim2.new(0, 0, 0, 0),
    Text = "Level 1",
    Parent = levelContainer,
}), 14, 24)
local xpBarBg = makeFrame({
    Name = "XPBarBG",
    Size = UDim2.new(0.94, 0, 0.28, 0),
    Position = UDim2.new(0.03, 0, 0.62, 0),
    BackgroundColor3 = Color3.fromRGB(45, 30, 18),
    BorderSizePixel = 0,
    Parent = levelContainer,
})
Instance.new("UICorner", xpBarBg).CornerRadius = UDim.new(1, 0)
local xpBarFill = makeFrame({
    Name = "XPBarFill",
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = PALETTE_PRIMARY,
    BorderSizePixel = 0,
    Parent = xpBarBg,
})
Instance.new("UICorner", xpBarFill).CornerRadius = UDim.new(1, 0)
local xpGrad = Instance.new("UIGradient", xpBarFill)
xpGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 130)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 150, 60)),
}
xpGrad.Rotation = 90

-- XP numeric overlay centered on the bar: "Lv 1  -  0 / 100 XP"
local xpText = Instance.new("TextLabel", xpBarBg)
xpText.Name = "XPText"
xpText.AnchorPoint = Vector2.new(0.5, 0.5)
xpText.Position = UDim2.new(0.5, 0, 0.5, 0)
xpText.Size = UDim2.new(1, -8, 1, 0)
xpText.BackgroundTransparency = 1
xpText.Text = "Lv 1  -  0 / 100 XP"
xpText.TextColor3 = Color3.fromRGB(255, 255, 255)
xpText.TextStrokeTransparency = 0
xpText.TextStrokeColor3 = UIUtil.Palette.stroke
xpText.Font = UIUtil.Token.fontHeader
xpText.TextScaled = true
xpText.TextXAlignment = Enum.TextXAlignment.Center
xpText.ZIndex = 2  -- above the fill so the text is readable
bind(xpText, 10, 14)

-- Rebirth counter: trophy icon + count.
-- Right-anchored backplate so the trophy circle sits at the RIGHT edge of
-- the wrap, with the rebirth count to its left. Always-visible colored
-- circle even if trophy asset fails to load.
local rebirthWrap = makeFrame({
    Name = "RebirthWrap",
    Size = UDim2.new(0.18, 0, 0.7, 0),
    Position = UDim2.new(0.81, 0, 0.15, 0),
    BackgroundTransparency = 1,
    Parent = topBar,
})
local rebirthBackplate = Instance.new("Frame")
rebirthBackplate.Name = "IconBackplate"
rebirthBackplate.AnchorPoint = Vector2.new(1, 0.5)
rebirthBackplate.Size = UDim2.new(0, 38, 0, 38)
rebirthBackplate.Position = UDim2.new(1, 0, 0.5, 0)
rebirthBackplate.BackgroundColor3 = PALETTE_PRIMARY
rebirthBackplate.BorderSizePixel = 0
rebirthBackplate.Parent = rebirthWrap
Instance.new("UICorner", rebirthBackplate).CornerRadius = UDim.new(1, 0)
local rbStroke = Instance.new("UIStroke", rebirthBackplate)
rbStroke.Thickness = 2; rbStroke.Color = UIUtil.Palette.stroke; rbStroke.Transparency = 0.3
if AssetIds.has("trophy") then
    local icon = Instance.new("ImageLabel")
    icon.Name = "RebirthIcon"
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(0, 28, 0, 28)
    icon.Position = UDim2.new(0.5, 0, 0.5, 0)
    icon.Image = AssetIds.trophy
    icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = rebirthBackplate
end
bind(makeLabel({
    Name = "RebirthLabel",
    Size = UDim2.new(1, -44, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    Text = "0",
    TextXAlignment = Enum.TextXAlignment.Right,
    Parent = rebirthWrap,
}), 14, 32)

-- ===== CENTER BOTTOM: SUMMON BUTTON (icon + glow ring) =====
local summonSize = IS_MOBILE and 88 or 78
-- v3.62 HUD revamp: SUMMON moved to bottom-LEFT corner so it doesn't cover
-- the cat visually. Smaller (110/130 -> 78/88). Bottom-bar still centers
-- below; PrankColumn still right-side. Player-mental-model: 'summon left,
-- attack right'.
local summonBtn = makeButton({
    Name = "SummonButton",
    Size = UDim2.new(0, summonSize, 0, summonSize),
    Position = UDim2.new(0, 16, 1, -(summonSize + 84)),  -- bottom-left, above bottom bar
    BackgroundColor3 = PALETTE_DANGER,
    Text = "",
    Parent = screenGui,
})
local sCorner = summonBtn:FindFirstChildOfClass("UICorner")
if sCorner then sCorner.CornerRadius = UDim.new(1, 0) end
local sStroke = summonBtn:FindFirstChildOfClass("UIStroke")
if sStroke then sStroke.Color = Color3.fromRGB(80, 30, 25); sStroke.Thickness = 4 end
local sGrad = Instance.new("UIGradient", summonBtn)
sGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 130, 110)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 50, 50)),
}
sGrad.Rotation = 90
-- Skull icon centered + drop shadow
if AssetIds.has("skull") then
    local sIconSize = math.floor(summonSize * 0.45)
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "IconShadow"
    shadow.BackgroundTransparency = 1
    shadow.Size = UDim2.new(0, sIconSize, 0, sIconSize)
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Position = UDim2.new(0.5, 0, 0.42, 3)
    shadow.Image = AssetIds.skull
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.55
    shadow.ScaleType = Enum.ScaleType.Fit
    shadow.Parent = summonBtn
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(0, sIconSize, 0, sIconSize)
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.new(0.5, 0, 0.42, 0)
    icon.Image = AssetIds.skull
    icon.ImageColor3 = Color3.fromRGB(255, 245, 230)
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = summonBtn
end
local sLabel = Instance.new("TextLabel")
sLabel.Name = "Label"
sLabel.Size = UDim2.new(1, -16, 0, 22)
sLabel.AnchorPoint = Vector2.new(0.5, 1)
sLabel.Position = UDim2.new(0.5, 0, 1, -10)
sLabel.BackgroundTransparency = 1
sLabel.Text = "SUMMON"
sLabel.Font = Enum.Font.GothamBlack
sLabel.TextColor3 = Color3.fromRGB(255, 250, 240)
sLabel.TextStrokeTransparency = 0.3
sLabel.TextStrokeColor3 = Color3.fromRGB(60, 20, 15)
sLabel.TextScaled = true
sLabel.Parent = summonBtn
bind(sLabel, 12, 20)

-- ===== RIGHT SIDE: PRANK BUTTONS =====
-- v3.62: moved inward 50px (was flush against right edge, blending with the
-- minimap into a 'LV X markers' look). Now 50px in from edge with a darker
-- panel background so the column reads as a discrete action bar.
local PRANK_W = IS_MOBILE and 88 or 76
local prankColumn = makeFrame({
    Name = "PrankColumn",
    Size = UDim2.new(0, PRANK_W + 16, 0, 8 * (PRANK_W + 6) + 16),
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -64, 0.5, 80),  -- offset down so it clears minimap
    BackgroundColor3 = Color3.fromRGB(50, 35, 20),
    BackgroundTransparency = 0.25,
    Parent = screenGui,
})
Instance.new("UICorner", prankColumn).CornerRadius = UDim.new(0, 14)
local pcStroke = Instance.new("UIStroke", prankColumn)
pcStroke.Thickness = 2; pcStroke.Color = Color3.fromRGB(110, 75, 40)
local pcPad = Instance.new("UIPadding", prankColumn)
pcPad.PaddingTop = UDim.new(0, 8); pcPad.PaddingBottom = UDim.new(0, 8)
local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Padding = UDim.new(0, 6)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = prankColumn

-- Map prank name -> uploaded icon asset key
local PRANK_ICON = {
    Pie        = "pie",
    Anvil      = "anvil",
    FartCloud  = "tp",      -- toilet-paper-roll fits the goofy vibe
    LaserEyes  = "wings",
    CatScratch = "scratch",
    Hairball   = "fish",
    Whip       = "paw",
    Purrgatory = "skull",
}

for i, prankName in ipairs(PrankConfig.Order) do
    local prank = PrankConfig.Pranks[prankName]
    local btn = makeButton({
        Name = "Prank_" .. prankName,
        Size = UDim2.new(0, PRANK_W, 0, PRANK_W),
        BackgroundColor3 = Color3.fromRGB(70, 50, 35),
        Text = "",
        LayoutOrder = i,
        Parent = prankColumn,
    })
    btn:SetAttribute("PrankName", prankName)
    btn:SetAttribute("UnlockLevel", prank.unlockLevel)

    -- Real icon asset preferred; ASCII abbreviation fallback.
    local iconKey = PRANK_ICON[prankName]
    if iconKey and AssetIds.has(iconKey) then
        -- Drop shadow under the icon
        local shadow = Instance.new("ImageLabel")
        shadow.Name = "PrankIconShadow"
        shadow.BackgroundTransparency = 1
        shadow.Size = UDim2.new(1, -14, 1, -14)
        shadow.Position = UDim2.fromOffset(7, 9)
        shadow.Image = AssetIds[iconKey]
        shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
        shadow.ImageTransparency = 0.55
        shadow.ScaleType = Enum.ScaleType.Fit
        shadow.Parent = btn
        -- White icon (gets re-tinted by lock state below if needed)
        local img = Instance.new("ImageLabel")
        img.Name = "PrankIcon"
        img.BackgroundTransparency = 1
        img.Size = UDim2.new(1, -14, 1, -14)
        img.Position = UDim2.fromOffset(7, 7)
        img.Image = AssetIds[iconKey]
        img.ImageColor3 = Color3.fromRGB(255, 250, 235)
        img.ScaleType = Enum.ScaleType.Fit
        img.Parent = btn
    else
        local short = (prankName:upper()):sub(1, 3)
        btn.Text = short
        btn.TextScaled = true
        bind(btn, 16, 28)
    end
    -- Locked overlay: dark scrim + bold "Lv N" text. Initial visibility is
    -- set by unlockLevel so first prank (unlockLevel=1) is immediately
    -- visible at spawn even before UpdatePlayerData arrives. HUDController
    -- toggles overlay.Visible later as level changes.
    local startsLocked = (prank.unlockLevel or 1) > 1
    btn:SetAttribute("Locked", startsLocked)
    local lock = makeFrame({
        Name = "LockOverlay",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(20, 14, 8),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        Visible = startsLocked,
    })
    Instance.new("UICorner", lock).CornerRadius = UDim.new(0, 12)
    lock.Parent = btn
    local lockLbl = Instance.new("TextLabel", lock)
    lockLbl.Size = UDim2.fromScale(1, 1)
    lockLbl.BackgroundTransparency = 1
    lockLbl.Text = "LV " .. prank.unlockLevel
    lockLbl.Font = Enum.Font.GothamBlack
    lockLbl.TextColor3 = Color3.fromRGB(255, 230, 180)
    lockLbl.TextStrokeTransparency = 0
    lockLbl.TextStrokeColor3 = Color3.fromRGB(40, 25, 15)
    lockLbl.TextScaled = true
    bind(lockLbl, 12, 22)
    -- Cooldown overlay
    local cd = makeFrame({
        Name = "CooldownOverlay",
        Size = UDim2.new(1, 0, 0, 0),
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Color3.new(0,0,0),
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        Visible = false,
    })
    cd.Parent = btn
end

-- ===== BOTTOM BAR: SHOP / INVENTORY / REBIRTH / LEADERBOARD =====
-- v3.62: tighter — buttons 80x54 -> 64x44, padding 6 -> 4, container narrower.
-- STATS + MENU buttons hooked in by PerkUI/SettingsMenu so total fits 6 in
-- 6*64 + 5*4 = 404px on desktop comfortably within the 420px container.
local bottomBar = makeFrame({
    Name = "BottomBar",
    Size = UDim2.new(0, IS_MOBILE and 460 or 420, 0, IS_MOBILE and 52 or 44),
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -8),
    BackgroundColor3 = Color3.fromRGB(50, 35, 20),
    BackgroundTransparency = 0.25,
    Parent = screenGui,
})
Instance.new("UICorner", bottomBar).CornerRadius = UDim.new(0, 12)
local bbStroke = Instance.new("UIStroke", bottomBar)
bbStroke.Thickness = 2; bbStroke.Color = Color3.fromRGB(110, 75, 40)
local bbPad = Instance.new("UIPadding", bottomBar)
bbPad.PaddingLeft = UDim.new(0, 6); bbPad.PaddingRight = UDim.new(0, 6)
bbPad.PaddingTop  = UDim.new(0, 4); bbPad.PaddingBottom = UDim.new(0, 4)
local botLayout = Instance.new("UIListLayout")
botLayout.FillDirection = Enum.FillDirection.Horizontal
botLayout.Padding = UDim.new(0, 4)
botLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
botLayout.VerticalAlignment = Enum.VerticalAlignment.Center
botLayout.Parent = bottomBar

local function bottomButton(name, label, iconKey, color, layoutOrder)
    local btn = makeButton({
        Name = name,
        Size = UDim2.new(0, IS_MOBILE and 72 or 64, 0, IS_MOBILE and 48 or 40),
        BackgroundColor3 = color,
        Text = "",
        LayoutOrder = layoutOrder,
        Parent = bottomBar,
    })
    -- Smaller icon to fit the 64x40 button. Icon top, label bottom.
    if iconKey and AssetIds.has(iconKey) then
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.BackgroundTransparency = 1
        icon.Size = UDim2.new(0, 18, 0, 18)
        icon.Position = UDim2.new(0.5, -9, 0, 3)
        icon.Image = AssetIds[iconKey]
        icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Parent = btn
    end
    local labelText = Instance.new("TextLabel")
    labelText.Name = "Label"
    labelText.Size = UDim2.new(1, -4, 0, 14)
    labelText.Position = UDim2.new(0, 2, 1, -16)
    labelText.BackgroundTransparency = 1
    labelText.Text = label
    labelText.Font = Enum.Font.GothamBlack
    labelText.TextColor3 = Color3.fromRGB(255, 255, 255)
    labelText.TextStrokeTransparency = 0.4
    labelText.TextStrokeColor3 = Color3.new(0, 0, 0)
    labelText.TextScaled = true
    labelText.Parent = btn
    bind(labelText, 9, 13)
    return btn
end

bottomButton("ShopButton",        "SHOP",     "shop",  Color3.fromRGB(95, 165, 80),  1)
bottomButton("InventoryButton",   "INV",      "bag",   Color3.fromRGB(140, 95, 60),  2)
bottomButton("RebirthButton",     "REBIRTH",  "star",  Color3.fromRGB(220, 150, 60), 3)
bottomButton("LeaderboardButton", "TOP",      "bars",  Color3.fromRGB(85, 130, 175), 4)

-- ===== NOTIFICATION TOAST AREA =====
local toastFrame = makeFrame({
    Name = "ToastFrame",
    Size = UDim2.new(0, 400, 0, 60),
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 90),
    BackgroundTransparency = 1,
    Parent = screenGui,
})

-- ===== SHOP MODAL (responsive: clamp to viewport) =====
local shopModal = makeFrame({
    Name = "ShopModal",
    Size = UIUtil.modalSize(600, 500, 24),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundColor3 = UIUtil.Palette.bgMid,
    BorderSizePixel = 0,
    Visible = false,
    Parent = screenGui,
})
Instance.new("UICorner", shopModal).CornerRadius = UIUtil.Token.cornerLg
local shopStroke = Instance.new("UIStroke")
shopStroke.Thickness = UIUtil.Token.strokeBold
shopStroke.Color = UIUtil.Palette.primary
shopStroke.Parent = shopModal

bind(makeLabel({
    Name = "ShopTitle",
    Size = UDim2.new(1, -80, 0, 50),
    Position = UDim2.new(0, 16, 0, 12),
    Text = "COSMETIC SHOP",
    TextColor3 = UIUtil.Palette.primary,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = shopModal,
}), 18, 32)

-- 48x48 close button (Apple HIG min touch target)
local shopClose = makeButton({
    Name = "CloseButton",
    Size = UDim2.new(0, 48, 0, 48),
    Position = UDim2.new(1, -56, 0, 8),
    BackgroundColor3 = PALETTE_DANGER,
    Text = "X",
    Parent = shopModal,
})
bind(shopClose, 18, 26)

local shopList = Instance.new("ScrollingFrame")
shopList.Name = "ShopList"
shopList.Size = UDim2.new(1, -20, 1, -80)
shopList.Position = UDim2.new(0, 10, 0, 70)
shopList.BackgroundTransparency = 1
shopList.BorderSizePixel = 0
shopList.CanvasSize = UDim2.new(0, 0, 0, 0)
shopList.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopList.ScrollBarThickness = 8
shopList.Parent = shopModal
local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 8)
shopLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopLayout.Parent = shopList

-- ===== LEADERBOARD MODAL =====
local lbModal = makeFrame({
    Name = "LeaderboardModal",
    Size = UIUtil.modalSize(420, 540, 24),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundColor3 = UIUtil.Palette.bgMid,
    BorderSizePixel = 0,
    Visible = false,
    Parent = screenGui,
})
Instance.new("UICorner", lbModal).CornerRadius = UIUtil.Token.cornerLg
local lbStroke = Instance.new("UIStroke")
lbStroke.Thickness = UIUtil.Token.strokeBold
lbStroke.Color = UIUtil.Palette.accent
lbStroke.Parent = lbModal

bind(makeLabel({
    Name = "LBTitle",
    Size = UDim2.new(1, -80, 0, 50),
    Position = UDim2.new(0, 16, 0, 12),
    Text = "TOP CHAOS",
    TextColor3 = UIUtil.Palette.accent,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = lbModal,
}), 18, 32)
local lbClose = makeButton({
    Name = "CloseButton",
    Size = UDim2.new(0, 48, 0, 48),
    Position = UDim2.new(1, -56, 0, 8),
    BackgroundColor3 = PALETTE_DANGER,
    Text = "X",
    Parent = lbModal,
})
bind(lbClose, 18, 26)
local lbList = Instance.new("Frame")
lbList.Name = "LBList"
lbList.Size = UDim2.new(1, -20, 1, -80)
lbList.Position = UDim2.new(0, 10, 0, 70)
lbList.BackgroundTransparency = 1
lbList.Parent = lbModal
local lbLayout = Instance.new("UIListLayout")
lbLayout.Padding = UDim.new(0, 4)
lbLayout.Parent = lbList

-- ===== TUTORIAL TOOLTIP (hidden, controller drives it) =====
local tutorial = makeFrame({
    Name = "TutorialTooltip",
    Size = UDim2.new(0, 400, 0, 90),
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 100),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    Visible = false,
    Parent = screenGui,
})
Instance.new("UICorner", tutorial).CornerRadius = UDim.new(0, 12)
local tutLabel = bind(makeLabel({
    Name = "Text",
    Size = UDim2.new(1, -20, 1, -20),
    Position = UDim2.new(0, 10, 0, 10),
    Text = "",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Parent = tutorial,
}), 14, 26)

-- ===== VIEWPORT-AWARE RECLAMP =====
-- When the window is resized or device rotated, re-clamp modal sizes so they
-- stay within the viewport.
local cam = workspace.CurrentCamera
if cam then
    cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        if shopModal and shopModal.Parent then
            shopModal.Size = UIUtil.modalSize(600, 500, 24)
        end
        if lbModal and lbModal.Parent then
            lbModal.Size = UIUtil.modalSize(420, 540, 24)
        end
    end)
end

print("[HUDBuilder] MainHUD constructed (responsive)")

-- Expose remote-controlled refs (other client scripts find by Name)
return screenGui
