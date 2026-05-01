-- PASTE 3 — Modern HUD redesign (replaces existing HUD with frosted-glass aesthetic)
-- Drops a LocalScript that REBUILDS PlayerGui.MainHUD on character spawn.
local SPS_Sc=game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if not SPS_Sc then warn("SPS missing") return end
local old=SPS_Sc:FindFirstChild("ModernHUD") if old then old:Destroy() end

local src=[==[
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local UIS=game:GetService("UserInputService")
local RS=game:GetService("ReplicatedStorage")
local plr=Players.LocalPlayer
local pg=plr:WaitForChild("PlayerGui")

-- Remove old HUD shells
for _,n in ipairs({"MainHUD","HUDOld","ModernHUD"}) do
  local g=pg:FindFirstChild(n) if g then g:Destroy() end
end

local gui=Instance.new("ScreenGui")
gui.Name="ModernHUD" gui.IgnoreGuiInset=true gui.DisplayOrder=100 gui.ResetOnSpawn=false gui.Parent=pg

-- Helpers
local function corner(p,r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 12) c.Parent=p return c end
local function stroke(p,col,t) local s=Instance.new("UIStroke") s.Color=col or Color3.fromRGB(255,255,255) s.Thickness=t or 1 s.Transparency=0.5 s.Parent=p return s end
local function pad(p,n) local pa=Instance.new("UIPadding") pa.PaddingLeft=UDim.new(0,n) pa.PaddingRight=UDim.new(0,n) pa.PaddingTop=UDim.new(0,n) pa.PaddingBottom=UDim.new(0,n) pa.Parent=p return pa end
local function frostedGradient(p)
  local g=Instance.new("UIGradient") g.Color=ColorSequence.new{
    ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),
    ColorSequenceKeypoint.new(1,Color3.fromRGB(180,180,210))
  } g.Transparency=NumberSequence.new(0.85) g.Rotation=90 g.Parent=p return g
end

----- TOP BAR (frosted) -----
local top=Instance.new("Frame") top.Name="TopBar" top.Size=UDim2.new(1,-32,0,72) top.Position=UDim2.new(0,16,0,16)
top.BackgroundColor3=Color3.fromRGB(20,18,32) top.BackgroundTransparency=0.15 top.BorderSizePixel=0 top.Parent=gui
corner(top,18) stroke(top,Color3.fromRGB(140,120,200),1) frostedGradient(top)

-- Player avatar bubble (left)
local avatar=Instance.new("Frame") avatar.Size=UDim2.fromOffset(56,56) avatar.Position=UDim2.new(0,8,0.5,-28)
avatar.BackgroundColor3=Color3.fromRGB(255,180,80) avatar.BorderSizePixel=0 avatar.Parent=top
corner(avatar,28) stroke(avatar,Color3.fromRGB(255,220,140),2)
local avEmoji=Instance.new("TextLabel") avEmoji.Size=UDim2.fromScale(1,1) avEmoji.BackgroundTransparency=1
avEmoji.Font=Enum.Font.GothamBlack avEmoji.TextScaled=true avEmoji.TextColor3=Color3.fromRGB(40,20,0)
avEmoji.Text="🐱" avEmoji.Parent=avatar

local nameBox=Instance.new("Frame") nameBox.Size=UDim2.fromOffset(180,56) nameBox.Position=UDim2.new(0,72,0.5,-28)
nameBox.BackgroundTransparency=1 nameBox.Parent=top
local nameLbl=Instance.new("TextLabel") nameLbl.Size=UDim2.new(1,0,0.5,0) nameLbl.BackgroundTransparency=1
nameLbl.Font=Enum.Font.GothamBold nameLbl.TextSize=18 nameLbl.TextXAlignment=Enum.TextXAlignment.Left
nameLbl.TextColor3=Color3.fromRGB(255,255,255) nameLbl.Text=plr.DisplayName nameLbl.Parent=nameBox
local lvlLbl=Instance.new("TextLabel") lvlLbl.Size=UDim2.new(1,0,0.5,0) lvlLbl.Position=UDim2.fromScale(0,0.5)
lvlLbl.BackgroundTransparency=1 lvlLbl.Font=Enum.Font.GothamMedium lvlLbl.TextSize=14
lvlLbl.TextXAlignment=Enum.TextXAlignment.Left lvlLbl.TextColor3=Color3.fromRGB(180,160,220)
lvlLbl.Text="Lvl 1 • 0 / 100 XP" lvlLbl.Parent=nameBox

-- XP bar
local xpBg=Instance.new("Frame") xpBg.Size=UDim2.fromOffset(180,6) xpBg.Position=UDim2.new(0,72,1,-12)
xpBg.BackgroundColor3=Color3.fromRGB(50,40,80) xpBg.BorderSizePixel=0 xpBg.Parent=top
corner(xpBg,3)
local xpFill=Instance.new("Frame") xpFill.Size=UDim2.fromScale(0,1) xpFill.BackgroundColor3=Color3.fromRGB(255,200,80) xpFill.BorderSizePixel=0 xpFill.Parent=xpBg
corner(xpFill,3)
local xpG=Instance.new("UIGradient") xpG.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(255,220,100)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,140,40))} xpG.Parent=xpFill

----- CURRENCY CARDS (right side of top bar) -----
local function currencyCard(parent,xOff,iconText,initial,color)
  local c=Instance.new("Frame") c.Size=UDim2.fromOffset(140,52) c.Position=UDim2.new(1,-xOff-8,0.5,-26)
  c.BackgroundColor3=Color3.fromRGB(28,24,46) c.BorderSizePixel=0 c.Parent=parent
  corner(c,14) stroke(c,color,2)
  local icon=Instance.new("TextLabel") icon.Size=UDim2.fromOffset(36,52) icon.BackgroundTransparency=1
  icon.Font=Enum.Font.GothamBlack icon.TextSize=22 icon.TextColor3=color icon.Text=iconText icon.Parent=c
  local val=Instance.new("TextLabel") val.Size=UDim2.new(1,-40,1,0) val.Position=UDim2.fromOffset(40,0)
  val.BackgroundTransparency=1 val.Font=Enum.Font.GothamBold val.TextSize=18 val.TextColor3=Color3.fromRGB(255,255,255)
  val.TextXAlignment=Enum.TextXAlignment.Left val.Text=initial val.Parent=c
  return c,val
end
local _,coinsLbl=currencyCard(top,148*2,"🪙","0",Color3.fromRGB(255,200,80))
local _,gemsLbl =currencyCard(top,148  ,"💎","0",Color3.fromRGB(120,200,255))
local _,robuxLbl=currencyCard(top,0    ,"R$","0",Color3.fromRGB(120,255,140))

----- LEFT PRANK COLUMN -----
local prankCol=Instance.new("Frame") prankCol.Name="PrankColumn"
prankCol.Size=UDim2.fromOffset(72,420) prankCol.Position=UDim2.new(0,16,0.5,-210)
prankCol.BackgroundTransparency=1 prankCol.Parent=gui
local lay=Instance.new("UIListLayout") lay.FillDirection=Enum.FillDirection.Vertical lay.Padding=UDim.new(0,8) lay.HorizontalAlignment=Enum.HorizontalAlignment.Center lay.Parent=prankCol

local pranks={
  {key="1",emoji="🐾",name="Scratch",color=Color3.fromRGB(255,150,80)},
  {key="2",emoji="🥧",name="Pie",color=Color3.fromRGB(255,200,140)},
  {key="3",emoji="🐟",name="Fish",color=Color3.fromRGB(120,200,255)},
  {key="4",emoji="🥤",name="Slushie",color=Color3.fromRGB(180,80,200)},
  {key="5",emoji="🚽",name="TP",color=Color3.fromRGB(220,220,220)},
  {key="6",emoji="🪨",name="Anvil",color=Color3.fromRGB(80,80,80)},
  {key="7",emoji="💀",name="Purrgatory",color=Color3.fromRGB(140,40,200)},
  {key="8",emoji="✈️",name="Flight",color=Color3.fromRGB(80,200,255)},
}
for _,p in ipairs(pranks) do
  local b=Instance.new("TextButton") b.Size=UDim2.fromOffset(64,64) b.BackgroundColor3=Color3.fromRGB(28,24,46) b.BorderSizePixel=0
  b.AutoButtonColor=false b.Text="" b.Parent=prankCol
  corner(b,16) stroke(b,p.color,2)
  local em=Instance.new("TextLabel") em.Size=UDim2.fromScale(1,0.7) em.BackgroundTransparency=1
  em.Font=Enum.Font.GothamBlack em.TextScaled=true em.Text=p.emoji em.Parent=b
  local key=Instance.new("TextLabel") key.Size=UDim2.new(1,0,0.3,0) key.Position=UDim2.fromScale(0,0.7)
  key.BackgroundTransparency=1 key.Font=Enum.Font.GothamBold key.TextSize=12
  key.TextColor3=p.color key.Text=p.key.." • "..p.name key.Parent=b
  b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(0.15),{Size=UDim2.fromOffset(70,70)}):Play() end)
  b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.15),{Size=UDim2.fromOffset(64,64)}):Play() end)
  b.MouseButton1Click:Connect(function()
    local Re=RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("RemoteEvents")
    if Re then local e=Re:FindFirstChild("UsePrank") if e then e:FireServer(p.name) end end
  end)
end

----- BOTTOM PILL NAV -----
local nav=Instance.new("Frame") nav.Name="BottomNav"
nav.Size=UDim2.fromOffset(560,68) nav.AnchorPoint=Vector2.new(0.5,1)
nav.Position=UDim2.new(0.5,0,1,-20) nav.BackgroundColor3=Color3.fromRGB(20,18,32) nav.BackgroundTransparency=0.1 nav.BorderSizePixel=0 nav.Parent=gui
corner(nav,34) stroke(nav,Color3.fromRGB(140,120,200),1) frostedGradient(nav)

local navLay=Instance.new("UIListLayout") navLay.FillDirection=Enum.FillDirection.Horizontal navLay.Padding=UDim.new(0,8) navLay.HorizontalAlignment=Enum.HorizontalAlignment.Center navLay.VerticalAlignment=Enum.VerticalAlignment.Center navLay.Parent=nav
pad(nav,8)

local navItems={
  {emoji="🛒",name="Shop"},
  {emoji="🎒",name="Inventory"},
  {emoji="📊",name="Stats"},
  {emoji="🎁",name="Daily"},
  {emoji="🎰",name="Slot"},
  {emoji="🔮",name="Fortune"},
  {emoji="🏆",name="Leaderboard"},
}
for _,i in ipairs(navItems) do
  local b=Instance.new("TextButton") b.Size=UDim2.fromOffset(60,52) b.BackgroundColor3=Color3.fromRGB(40,30,70) b.BorderSizePixel=0
  b.AutoButtonColor=false b.Text="" b.Parent=nav
  corner(b,26)
  local em=Instance.new("TextLabel") em.Size=UDim2.fromScale(1,0.7) em.BackgroundTransparency=1
  em.Font=Enum.Font.GothamBlack em.TextScaled=true em.Text=i.emoji em.Parent=b
  local nm=Instance.new("TextLabel") nm.Size=UDim2.new(1,0,0.3,0) nm.Position=UDim2.fromScale(0,0.7) nm.BackgroundTransparency=1
  nm.Font=Enum.Font.GothamBold nm.TextSize=10 nm.TextColor3=Color3.fromRGB(220,200,255) nm.Text=i.name nm.Parent=b
  b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(80,60,140)}):Play() end)
  b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(40,30,70)}):Play() end)
  b.MouseButton1Click:Connect(function()
    local target=pg:FindFirstChild(i.name.."UI") or pg:FindFirstChild(i.name)
    if target and target:IsA("ScreenGui") then target.Enabled=not target.Enabled end
    local Re=RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("RemoteEvents")
    if Re then local e=Re:FindFirstChild("OpenUI") if e then e:FireServer(i.name) end end
  end)
end

----- BIG SUMMON BUTTON (right side) -----
local summon=Instance.new("TextButton") summon.AnchorPoint=Vector2.new(1,1)
summon.Size=UDim2.fromOffset(170,80) summon.Position=UDim2.new(1,-20,1,-110)
summon.BackgroundColor3=Color3.fromRGB(255,180,40) summon.BorderSizePixel=0 summon.Font=Enum.Font.GothamBlack
summon.TextSize=20 summon.TextColor3=Color3.fromRGB(40,20,0) summon.Text="🐈  SUMMON" summon.AutoButtonColor=false summon.Parent=gui
corner(summon,22) stroke(summon,Color3.fromRGB(255,230,150),3)
local sg=Instance.new("UIGradient") sg.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(255,200,80)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,140,40))} sg.Rotation=90 sg.Parent=summon
task.spawn(function() while summon.Parent do local t=TweenService:Create(summon,TweenInfo.new(0.9,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Size=UDim2.fromOffset(180,84)}) t:Play() task.wait(1.8) end end)
summon.MouseButton1Click:Connect(function()
  local Re=RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("RemoteEvents")
  if Re then local e=Re:FindFirstChild("Summon") if e then e:FireServer() end end
end)

----- KEYBOARD HOTKEYS for prank column -----
UIS.InputBegan:Connect(function(input,gp)
  if gp then return end
  local map={[Enum.KeyCode.One]="Scratch",[Enum.KeyCode.Two]="Pie",[Enum.KeyCode.Three]="Fish",[Enum.KeyCode.Four]="Slushie",[Enum.KeyCode.Five]="TP",[Enum.KeyCode.Six]="Anvil",[Enum.KeyCode.Seven]="Purrgatory",[Enum.KeyCode.Eight]="Flight"}
  local nm=map[input.KeyCode]
  if nm then
    local Re=RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("RemoteEvents")
    if Re then local e=Re:FindFirstChild("UsePrank") if e then e:FireServer(nm) end end
  end
end)

----- SUBSCRIBE TO STAT CHANGES -----
local ls=plr:WaitForChild("leaderstats",5)
if ls then
  local function bind(name,lbl,fmt)
    local v=ls:FindFirstChild(name)
    if not v then return end
    local function update() lbl.Text=fmt and fmt(v.Value) or tostring(v.Value) end
    v:GetPropertyChangedSignal("Value"):Connect(update) update()
  end
  bind("Coins",coinsLbl)
  bind("Gems",gemsLbl)
  bind("Robux",robuxLbl)
  -- Level/XP
  local lv=ls:FindFirstChild("Level") local xp=ls:FindFirstChild("XP")
  local function refLvl()
    local L=lv and lv.Value or 1
    local X=xp and xp.Value or 0
    local need=100+L*50
    lvlLbl.Text="Lvl "..L.." • "..X.." / "..need.." XP"
    xpFill.Size=UDim2.fromScale(math.clamp(X/need,0,1),1)
  end
  if lv then lv:GetPropertyChangedSignal("Value"):Connect(refLvl) end
  if xp then xp:GetPropertyChangedSignal("Value"):Connect(refLvl) end
  refLvl()
end

print("[ModernHUD] Built")
]==]

local s=Instance.new("LocalScript") s.Name="ModernHUD" s.Source=src s.Parent=SPS_Sc
-- Reload all chars so HUD shows immediately
for _,p in ipairs(game:GetService("Players"):GetPlayers()) do pcall(function() p:LoadCharacter() end) end
print("[Done] Modern HUD deployed")
