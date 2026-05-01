-- HUDBuilder.client.lua
-- Programmatically constructs the entire MainHUD ScreenGui.
-- Place in: StarterGui > HUDBuilder (LocalScript)
-- Other client scripts (HUDController, InputHandler) reference its named children.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))
local PrankConfig = require(ReplicatedStorage.Modules.PrankConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remove any existing MainHUD (dev hot reload)
local existing = playerGui:FindFirstChild("MainHUD")
if existing then existing:Destroy() end

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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
    BackgroundColor3 = Color3.fromRGB(20, 10, 30),
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    Parent = screenGui,
})
local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = GameConfig.HUD_PRIMARY_COLOR
stroke.Parent = topBar

makeLabel({
    Name = "ChaosLabel",
    Size = UDim2.new(0.3, 0, 0.7, 0),
    Position = UDim2.new(0.01, 0, 0.15, 0),
    Text = "💚 0",
    TextColor3 = GameConfig.HUD_ACCENT_COLOR,
    TextXAlignment = Enum.TextXAlignment.Left,
    Parent = topBar,
}).Parent = topBar

local levelContainer = makeFrame({
    Name = "LevelContainer",
    Size = UDim2.new(0.3, 0, 0.7, 0),
    Position = UDim2.new(0.35, 0, 0.15, 0),
    BackgroundTransparency = 1,
    Parent = topBar,
})
makeLabel({
    Name = "LevelLabel",
    Size = UDim2.new(1, 0, 0.5, 0),
    Position = UDim2.new(0, 0, 0, 0),
    Text = "Level 1",
    Parent = levelContainer,
})
local xpBarBg = makeFrame({
    Name = "XPBarBG",
    Size = UDim2.new(0.9, 0, 0.3, 0),
    Position = UDim2.new(0.05, 0, 0.6, 0),
    BackgroundColor3 = Color3.fromRGB(40, 20, 60),
    BorderSizePixel = 0,
    Parent = levelContainer,
})
Instance.new("UICorner", xpBarBg).CornerRadius = UDim.new(1, 0)
local xpBarFill = makeFrame({
    Name = "XPBarFill",
    Size = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = GameConfig.HUD_ACCENT_COLOR,
    BorderSizePixel = 0,
    Parent = xpBarBg,
})
Instance.new("UICorner", xpBarFill).CornerRadius = UDim.new(1, 0)

makeLabel({
    Name = "RebirthLabel",
    Size = UDim2.new(0.3, 0, 0.7, 0),
    Position = UDim2.new(0.69, 0, 0.15, 0),
    Text = "👑 0",
    TextXAlignment = Enum.TextXAlignment.Right,
    Parent = topBar,
})

-- ===== CENTER BOTTOM: SUMMON BUTTON =====
local summonSize = IS_MOBILE and 180 or 140
local summonBtn = makeButton({
    Name = "SummonButton",
    Size = UDim2.new(0, summonSize, 0, summonSize),
    Position = UDim2.new(0.5, -summonSize/2, 1, -(summonSize + 30)),
    BackgroundColor3 = GameConfig.HUD_DANGER_COLOR,
    Text = "SUMMON\nHUMAN",
    Parent = screenGui,
})

-- ===== RIGHT SIDE: PRANK BUTTONS =====
local prankColumn = makeFrame({
    Name = "PrankColumn",
    Size = UDim2.new(0, IS_MOBILE and 80 or 70, 0, 4 * (IS_MOBILE and 90 or 80)),
    Position = UDim2.new(1, -(IS_MOBILE and 90 or 80), 0.5, -(2 * (IS_MOBILE and 90 or 80))),
    BackgroundTransparency = 1,
    Parent = screenGui,
})
local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Padding = UDim.new(0, 6)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = prankColumn

for i, prankName in ipairs(PrankConfig.Order) do
    local prank = PrankConfig.Pranks[prankName]
    local btn = makeButton({
        Name = "Prank_" .. prankName,
        Size = UDim2.new(0, IS_MOBILE and 70 or 60, 0, IS_MOBILE and 70 or 60),
        BackgroundColor3 = Color3.fromRGB(60, 30, 90),
        Text = prankName == "Pie" and "🥧" or prankName == "Anvil" and "🔨" or prankName == "FartCloud" and "💨" or "👁️",
        TextSize = 36,
        LayoutOrder = i,
        Parent = prankColumn,
    })
    btn:SetAttribute("PrankName", prankName)
    btn:SetAttribute("Locked", true)
    btn:SetAttribute("UnlockLevel", prank.unlockLevel)
    -- Locked overlay
    local lock = makeLabel({
        Name = "LockOverlay",
        Size = UDim2.new(1, 0, 1, 0),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundColor3 = Color3.new(0,0,0),
        BackgroundTransparency = 0.5,
        Text = "🔒\nLv " .. prank.unlockLevel,
        TextSize = 18,
    })
    lock.BackgroundTransparency = 0.5
    lock.Parent = btn
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
local bottomBar = makeFrame({
    Name = "BottomBar",
    Size = UDim2.new(0, IS_MOBILE and 360 or 320, 0, IS_MOBILE and 60 or 50),
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -10),
    BackgroundTransparency = 1,
    Parent = screenGui,
})
local botLayout = Instance.new("UIListLayout")
botLayout.FillDirection = Enum.FillDirection.Horizontal
botLayout.Padding = UDim.new(0, 6)
botLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
botLayout.Parent = bottomBar

local function bottomButton(name, text, color, layoutOrder)
    return makeButton({
        Name = name,
        Size = UDim2.new(0, IS_MOBILE and 80 or 70, 0, IS_MOBILE and 56 or 44),
        BackgroundColor3 = color,
        Text = text,
        TextSize = IS_MOBILE and 18 or 14,
        LayoutOrder = layoutOrder,
        Parent = bottomBar,
    })
end

bottomButton("ShopButton", "SHOP", Color3.fromRGB(0, 200, 100), 1)
bottomButton("InventoryButton", "INV", Color3.fromRGB(80, 60, 200), 2)
bottomButton("RebirthButton", "REBIRTH", Color3.fromRGB(255, 150, 0), 3)
bottomButton("LeaderboardButton", "TOP", Color3.fromRGB(0, 150, 255), 4)

-- ===== NOTIFICATION TOAST AREA =====
local toastFrame = makeFrame({
    Name = "ToastFrame",
    Size = UDim2.new(0, 400, 0, 60),
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 90),
    BackgroundTransparency = 1,
    Parent = screenGui,
})

-- ===== SHOP MODAL (hidden by default) =====
local shopModal = makeFrame({
    Name = "ShopModal",
    Size = UDim2.new(0, 600, 0, 500),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundColor3 = Color3.fromRGB(20, 10, 30),
    BorderSizePixel = 0,
    Visible = false,
    Parent = screenGui,
})
Instance.new("UICorner", shopModal).CornerRadius = UDim.new(0, 16)
local shopStroke = Instance.new("UIStroke")
shopStroke.Thickness = 3
shopStroke.Color = GameConfig.HUD_PRIMARY_COLOR
shopStroke.Parent = shopModal

makeLabel({
    Name = "ShopTitle",
    Size = UDim2.new(1, -20, 0, 50),
    Position = UDim2.new(0, 10, 0, 10),
    Text = "COSMETIC SHOP",
    TextColor3 = GameConfig.HUD_ACCENT_COLOR,
    Parent = shopModal,
})

local shopClose = makeButton({
    Name = "CloseButton",
    Size = UDim2.new(0, 40, 0, 40),
    Position = UDim2.new(1, -50, 0, 10),
    BackgroundColor3 = GameConfig.HUD_DANGER_COLOR,
    Text = "X",
    Parent = shopModal,
})

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
    Size = UDim2.new(0, 360, 0, 480),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundColor3 = Color3.fromRGB(20, 10, 30),
    BorderSizePixel = 0,
    Visible = false,
    Parent = screenGui,
})
Instance.new("UICorner", lbModal).CornerRadius = UDim.new(0, 16)
local lbStroke = Instance.new("UIStroke")
lbStroke.Thickness = 3
lbStroke.Color = GameConfig.HUD_ACCENT_COLOR
lbStroke.Parent = lbModal

makeLabel({
    Name = "LBTitle",
    Size = UDim2.new(1, -20, 0, 50),
    Position = UDim2.new(0, 10, 0, 10),
    Text = "TOP CHAOS",
    TextColor3 = GameConfig.HUD_ACCENT_COLOR,
    Parent = lbModal,
})
local lbClose = makeButton({
    Name = "CloseButton",
    Size = UDim2.new(0, 40, 0, 40),
    Position = UDim2.new(1, -50, 0, 10),
    BackgroundColor3 = GameConfig.HUD_DANGER_COLOR,
    Text = "X",
    Parent = lbModal,
})
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
local tutLabel = makeLabel({
    Name = "Text",
    Size = UDim2.new(1, -20, 1, -20),
    Position = UDim2.new(0, 10, 0, 10),
    Text = "",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Parent = tutorial,
})

print("[HUDBuilder] MainHUD constructed")

-- Expose remote-controlled refs (other client scripts find by Name)
return screenGui
