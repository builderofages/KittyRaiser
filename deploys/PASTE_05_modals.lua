-- PASTE 5 — Modal UI restyling (sleek modal framework + 11 panels wired to bottom nav)
local SPS_Sc=game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if not SPS_Sc then warn("SPS missing") return end
local old=SPS_Sc:FindFirstChild("ModalSystem") if old then old:Destroy() end

local src=[==[
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local RS=game:GetService("ReplicatedStorage")
local plr=Players.LocalPlayer
local pg=plr:WaitForChild("PlayerGui")

local function corner(p,r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 16) c.Parent=p return c end
local function stroke(p,col,t) local s=Instance.new("UIStroke") s.Color=col or Color3.fromRGB(140,120,200) s.Thickness=t or 2 s.Parent=p return s end
local function frostedGradient(p) local g=Instance.new("UIGradient") g.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),ColorSequenceKeypoint.new(1,Color3.fromRGB(180,180,210))} g.Transparency=NumberSequence.new(0.85) g.Rotation=90 g.Parent=p end

local function buildShell(name,title,subtitle)
  local existing=pg:FindFirstChild(name) if existing then existing:Destroy() end
  local g=Instance.new("ScreenGui") g.Name=name g.IgnoreGuiInset=true g.DisplayOrder=200 g.ResetOnSpawn=false g.Enabled=false g.Parent=pg
  local dim=Instance.new("Frame") dim.Size=UDim2.fromScale(1,1) dim.BackgroundColor3=Color3.fromRGB(0,0,0) dim.BackgroundTransparency=0.5 dim.BorderSizePixel=0 dim.Parent=g
  local panel=Instance.new("Frame") panel.AnchorPoint=Vector2.new(0.5,0.5) panel.Position=UDim2.fromScale(0.5,0.5)
  panel.Size=UDim2.fromOffset(720,560) panel.BackgroundColor3=Color3.fromRGB(20,18,32) panel.BorderSizePixel=0 panel.Parent=g
  corner(panel,24) stroke(panel,Color3.fromRGB(140,120,200),2) frostedGradient(panel)
  local header=Instance.new("Frame") header.Size=UDim2.new(1,0,0,80) header.BackgroundTransparency=1 header.Parent=panel
  local titleLbl=Instance.new("TextLabel") titleLbl.Size=UDim2.new(1,-80,0,40) titleLbl.Position=UDim2.new(0,24,0,18)
  titleLbl.BackgroundTransparency=1 titleLbl.Font=Enum.Font.GothamBlack titleLbl.TextSize=28
  titleLbl.TextColor3=Color3.fromRGB(255,255,255) titleLbl.TextXAlignment=Enum.TextXAlignment.Left titleLbl.Text=title titleLbl.Parent=header
  local subLbl=Instance.new("TextLabel") subLbl.Size=UDim2.new(1,-80,0,20) subLbl.Position=UDim2.new(0,24,0,52)
  subLbl.BackgroundTransparency=1 subLbl.Font=Enum.Font.GothamMedium subLbl.TextSize=14
  subLbl.TextColor3=Color3.fromRGB(180,160,220) subLbl.TextXAlignment=Enum.TextXAlignment.Left subLbl.Text=subtitle or "" subLbl.Parent=header
  local close=Instance.new("TextButton") close.Size=UDim2.fromOffset(40,40) close.AnchorPoint=Vector2.new(1,0.5)
  close.Position=UDim2.new(1,-16,0.5,0) close.BackgroundColor3=Color3.fromRGB(60,40,90) close.BorderSizePixel=0
  close.Font=Enum.Font.GothamBlack close.TextSize=22 close.TextColor3=Color3.fromRGB(255,200,200) close.Text="X" close.Parent=header
  corner(close,20) stroke(close,Color3.fromRGB(255,120,140),2)
  close.MouseButton1Click:Connect(function() g.Enabled=false end)
  local body=Instance.new("ScrollingFrame") body.Size=UDim2.new(1,-32,1,-100) body.Position=UDim2.fromOffset(16,90)
  body.BackgroundColor3=Color3.fromRGB(14,12,24) body.BorderSizePixel=0
  body.ScrollBarThickness=6 body.CanvasSize=UDim2.fromOffset(0,0) body.AutomaticCanvasSize=Enum.AutomaticSize.Y body.Parent=panel
  corner(body,16)
  local pad=Instance.new("UIPadding") pad.PaddingLeft=UDim.new(0,16) pad.PaddingRight=UDim.new(0,16) pad.PaddingTop=UDim.new(0,16) pad.PaddingBottom=UDim.new(0,16) pad.Parent=body
  return g,body,titleLbl
end

local function row(parent,emoji,name,desc,price,color,onBuy)
  local r=Instance.new("Frame") r.Size=UDim2.new(1,0,0,72) r.BackgroundColor3=Color3.fromRGB(28,24,46) r.BorderSizePixel=0 r.Parent=parent
  corner(r,14) stroke(r,color or Color3.fromRGB(80,60,140),1)
  local em=Instance.new("TextLabel") em.Size=UDim2.fromOffset(56,72) em.Position=UDim2.fromOffset(8,0) em.BackgroundTransparency=1
  em.Font=Enum.Font.GothamBlack em.TextSize=28 em.TextColor3=color or Color3.fromRGB(255,200,80) em.Text=emoji em.Parent=r
  local nm=Instance.new("TextLabel") nm.Size=UDim2.new(1,-200,0,28) nm.Position=UDim2.fromOffset(72,12) nm.BackgroundTransparency=1
  nm.Font=Enum.Font.GothamBold nm.TextSize=16 nm.TextColor3=Color3.fromRGB(255,255,255) nm.TextXAlignment=Enum.TextXAlignment.Left nm.Text=name nm.Parent=r
  local ds=Instance.new("TextLabel") ds.Size=UDim2.new(1,-200,0,22) ds.Position=UDim2.fromOffset(72,38) ds.BackgroundTransparency=1
  ds.Font=Enum.Font.Gotham ds.TextSize=12 ds.TextColor3=Color3.fromRGB(180,160,220) ds.TextXAlignment=Enum.TextXAlignment.Left ds.Text=desc or "" ds.Parent=r
  if price then
    local b=Instance.new("TextButton") b.AnchorPoint=Vector2.new(1,0.5) b.Position=UDim2.new(1,-12,0.5,0) b.Size=UDim2.fromOffset(120,44)
    b.BackgroundColor3=Color3.fromRGB(255,180,40) b.BorderSizePixel=0 b.Font=Enum.Font.GothamBold b.TextSize=14
    b.TextColor3=Color3.fromRGB(40,20,0) b.Text=price b.Parent=r
    corner(b,10) stroke(b,Color3.fromRGB(255,230,150),2)
    if onBuy then b.MouseButton1Click:Connect(onBuy) end
  end
end

local function fillShop(body)
  for _,c in ipairs(body:GetChildren()) do if not c:IsA("UIPadding") and not c:IsA("UIListLayout") then c:Destroy() end end
  local lay=Instance.new("UIListLayout") lay.Padding=UDim.new(0,8) lay.Parent=body
  local items={
    {emoji="$",name="Coin Pack S",desc="100 Coins",price="49 R$",color=Color3.fromRGB(255,200,80)},
    {emoji="$",name="Coin Pack M",desc="500 Coins +50 bonus",price="199 R$",color=Color3.fromRGB(255,200,80)},
    {emoji="$",name="Coin Pack L",desc="2500 Coins +500 bonus",price="799 R$",color=Color3.fromRGB(255,200,80)},
    {emoji="G",name="Gem Pack S",desc="50 Gems",price="99 R$",color=Color3.fromRGB(120,200,255)},
    {emoji="G",name="Gem Pack M",desc="250 Gems +25 bonus",price="399 R$",color=Color3.fromRGB(120,200,255)},
    {emoji="*",name="VIP Pass",desc="2x XP, 2x coins, daily 100 gems",price="499 R$",color=Color3.fromRGB(180,80,255)},
    {emoji="P",name="Auto-Prank Pass",desc="Auto-fire pranks while idle",price="299 R$",color=Color3.fromRGB(255,150,80)},
    {emoji="!",name="Premium Skin Pack",desc="Cyber, Rainbow, Cosmic skins",price="999 R$",color=Color3.fromRGB(255,80,200)},
    {emoji="#",name="Rebirth Boost",desc="50% rebirth multiplier",price="399 R$",color=Color3.fromRGB(80,255,140)},
    {emoji="^",name="Bounty Hunter Pass",desc="See PvP wanted players on minimap",price="299 R$",color=Color3.fromRGB(255,80,80)},
    {emoji="W",name="Flight Pass",desc="Unlock flight at L20 (instead of L100)",price="599 R$",color=Color3.fromRGB(80,200,255)},
  }
  for _,it in ipairs(items) do row(body,it.emoji,it.name,it.desc,it.price,it.color,function()
    local Re=RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("RemoteEvents")
    if Re then local e=Re:FindFirstChild("PromptPurchase") if e then e:FireServer(it.name) end end
  end) end
end

local function fillInventory(body)
  for _,c in ipairs(body:GetChildren()) do if not c:IsA("UIPadding") and not c:IsA("UIListLayout") then c:Destroy() end end
  local lay=Instance.new("UIListLayout") lay.Padding=UDim.new(0,8) lay.Parent=body
  row(body,"C","Orange Tabby","Equipped - Common","Equipped",Color3.fromRGB(230,140,60))
  row(body,"C","Black Cat","Owned","Equip",Color3.fromRGB(50,50,50),function()
    local Re=RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("RemoteEvents")
    if Re then local e=Re:FindFirstChild("EquipSkin") if e then e:FireServer("black_cat") end end
  end)
  row(body,"C","Grey Tabby","Owned","Equip",Color3.fromRGB(130,130,140))
  row(body,"H","Top Hat","Owned","Equip",Color3.fromRGB(30,30,40))
  row(body,"H","Wizard Hat","Locked - L25","Locked",Color3.fromRGB(80,40,160))
  row(body,"T","'Pawpaw' Title","Earned at L10","Equip",Color3.fromRGB(255,180,80))
end

local function fillStats(body)
  for _,c in ipairs(body:GetChildren()) do if not c:IsA("UIPadding") and not c:IsA("UIListLayout") then c:Destroy() end end
  local lay=Instance.new("UIListLayout") lay.Padding=UDim.new(0,8) lay.Parent=body
  local ls=plr:FindFirstChild("leaderstats")
  local function v(name) local o=ls and ls:FindFirstChild(name) return o and tostring(o.Value) or "0" end
  row(body,"#","Level",v("Level"),nil,Color3.fromRGB(255,200,80))
  row(body,"X","XP",v("XP"),nil,Color3.fromRGB(255,200,80))
  row(body,"$","Coins",v("Coins"),nil,Color3.fromRGB(255,200,80))
  row(body,"G","Gems",v("Gems"),nil,Color3.fromRGB(120,200,255))
  row(body,"R","Rebirths",v("Rebirths"),nil,Color3.fromRGB(80,255,140))
  row(body,"P","Pranks Used",v("Pranks"),nil,Color3.fromRGB(255,150,80))
  row(body,"K","KOs",v("KOs"),nil,Color3.fromRGB(255,80,80))
  row(body,"!","Wanted Stars",v("Wanted"),nil,Color3.fromRGB(255,180,40))
end

local function fillDaily(body)
  for _,c in ipairs(body:GetChildren()) do if not c:IsA("UIPadding") and not c:IsA("UIListLayout") then c:Destroy() end end
  local lay=Instance.new("UIListLayout") lay.Padding=UDim.new(0,8) lay.Parent=body
  local rewards={
    {emoji="1",name="Day 1",desc="100 Coins",ok=true},
    {emoji="2",name="Day 2",desc="250 Coins"},
    {emoji="3",name="Day 3",desc="10 Gems"},
    {emoji="4",name="Day 4",desc="500 Coins"},
    {emoji="5",name="Day 5",desc="25 Gems"},
    {emoji="6",name="Day 6",desc="1000 Coins"},
    {emoji="7",name="Day 7",desc="100 Gems + Skin Voucher"},
  }
  for _,r in ipairs(rewards) do row(body,r.emoji,r.name,r.desc,r.ok and "Claim" or "Locked",Color3.fromRGB(120,200,255),function()
    local Re=RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("RemoteEvents")
    if Re then local e=Re:FindFirstChild("ClaimDaily") if e then e:FireServer() end end
  end) end
end

local function fillSlot(body)
  for _,c in ipairs(body:GetChildren()) do if not c:IsA("UIPadding") and not c:IsA("UIListLayout") then c:Destroy() end end
  local lay=Instance.new("UIListLayout") lay.Padding=UDim.new(0,8) lay.Parent=body
  row(body,"*","Spin (50 Coins)","Slot machine - 3 reels of cat icons",nil,Color3.fromRGB(255,200,80))
  local frame=Instance.new("Frame") frame.Size=UDim2.fromOffset(640,180) frame.BackgroundColor3=Color3.fromRGB(28,24,46) frame.BorderSizePixel=0 frame.Parent=body
  corner(frame,18) stroke(frame,Color3.fromRGB(180,140,255),2)
  local layH=Instance.new("UIListLayout") layH.FillDirection=Enum.FillDirection.Horizontal layH.HorizontalAlignment=Enum.HorizontalAlignment.Center layH.VerticalAlignment=Enum.VerticalAlignment.Center layH.Padding=UDim.new(0,16) layH.Parent=frame
  for i=1,3 do
    local reel=Instance.new("TextLabel") reel.Size=UDim2.fromOffset(120,140) reel.BackgroundColor3=Color3.fromRGB(40,30,70) reel.BorderSizePixel=0
    reel.Font=Enum.Font.GothamBlack reel.TextSize=72 reel.TextColor3=Color3.fromRGB(255,200,80) reel.Text="?" reel.Parent=frame
    corner(reel,16) stroke(reel,Color3.fromRGB(255,200,80),2)
  end
  local spin=Instance.new("TextButton") spin.Size=UDim2.fromOffset(320,56) spin.BackgroundColor3=Color3.fromRGB(255,180,40) spin.BorderSizePixel=0 spin.Font=Enum.Font.GothamBlack spin.TextSize=20 spin.TextColor3=Color3.fromRGB(40,20,0) spin.Text="SPIN (50 Coins)" spin.Parent=body
  corner(spin,16) stroke(spin,Color3.fromRGB(255,230,150),3)
  spin.MouseButton1Click:Connect(function() local Re=RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("RemoteEvents") if Re then local e=Re:FindFirstChild("SpinSlot") if e then e:FireServer() end end end)
end

local function fillFortune(body)
  for _,c in ipairs(body:GetChildren()) do if not c:IsA("UIPadding") and not c:IsA("UIListLayout") then c:Destroy() end end
  local lay=Instance.new("UIListLayout") lay.Padding=UDim.new(0,12) lay.Parent=body
  local card=Instance.new("Frame") card.Size=UDim2.fromOffset(640,260) card.BackgroundColor3=Color3.fromRGB(28,24,46) card.BorderSizePixel=0 card.Parent=body
  corner(card,18) stroke(card,Color3.fromRGB(255,180,40),2)
  local fLbl=Instance.new("TextLabel") fLbl.Size=UDim2.fromScale(1,0.75) fLbl.BackgroundTransparency=1 fLbl.Font=Enum.Font.GothamMedium fLbl.TextScaled=true fLbl.TextColor3=Color3.fromRGB(255,230,150) fLbl.Text="Pull a fortune to start your day..." fLbl.TextWrapped=true fLbl.Parent=card
  local pull=Instance.new("TextButton") pull.Size=UDim2.fromScale(1,0.25) pull.Position=UDim2.fromScale(0,0.75) pull.BackgroundColor3=Color3.fromRGB(255,180,40) pull.BorderSizePixel=0 pull.Font=Enum.Font.GothamBlack pull.TextSize=20 pull.TextColor3=Color3.fromRGB(40,20,0) pull.Text="PULL DAILY FORTUNE" pull.Parent=card
  corner(pull,18) stroke(pull,Color3.fromRGB(255,230,150),3)
  pull.MouseButton1Click:Connect(function() local Re=RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("RemoteEvents") if Re then local e=Re:FindFirstChild("PullFortune") if e then e:FireServer() end end end)
end

local function fillLeaderboard(body)
  for _,c in ipairs(body:GetChildren()) do if not c:IsA("UIPadding") and not c:IsA("UIListLayout") then c:Destroy() end end
  local lay=Instance.new("UIListLayout") lay.Padding=UDim.new(0,8) lay.Parent=body
  for i=1,10 do
    local txt="#"..i.." "..(i==1 and "(YOU) " or "").." Player"..i
    row(body,tostring(i),txt,(1000-i*73).." pranks",nil,Color3.fromRGB(255,200,80))
  end
end

local function fillFriends(body)
  for _,c in ipairs(body:GetChildren()) do if not c:IsA("UIPadding") and not c:IsA("UIListLayout") then c:Destroy() end end
  local lay=Instance.new("UIListLayout") lay.Padding=UDim.new(0,8) lay.Parent=body
  for _,p in ipairs(Players:GetPlayers()) do
    if p~=plr then row(body,"@",p.DisplayName,"In game","Invite",Color3.fromRGB(120,200,255),function()
      local Re=RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("RemoteEvents")
      if Re then local e=Re:FindFirstChild("InviteFriend") if e then e:FireServer(p.UserId) end end
    end) end
  end
  if #Players:GetPlayers()<2 then
    row(body,"...","No other players","Invite friends to play together",nil)
  end
end

local function fillGang(body)
  for _,c in ipairs(body:GetChildren()) do if not c:IsA("UIPadding") and not c:IsA("UIListLayout") then c:Destroy() end end
  local lay=Instance.new("UIListLayout") lay.Padding=UDim.new(0,8) lay.Parent=body
  row(body,"&","Create Gang","100 Coins to found - choose name & color","Create",Color3.fromRGB(255,150,80),function()
    local Re=RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("RemoteEvents")
    if Re then local e=Re:FindFirstChild("CreateGang") if e then e:FireServer() end end
  end)
  row(body,"&","Join Gang","Browse open gangs","Browse",Color3.fromRGB(120,200,255))
  row(body,"!","Gang War","War another gang for 24h","Declare",Color3.fromRGB(255,80,80))
  row(body,"#","Gang Treasury","Pool resources for upgrades","View",Color3.fromRGB(80,255,140))
end

local function fillTrade(body)
  for _,c in ipairs(body:GetChildren()) do if not c:IsA("UIPadding") and not c:IsA("UIListLayout") then c:Destroy() end end
  local lay=Instance.new("UIListLayout") lay.Padding=UDim.new(0,8) lay.Parent=body
  row(body,"<>","Open Trades","See pending trade requests",nil,Color3.fromRGB(255,200,80))
  row(body,">>","Send Trade Request","Pick a player to trade with","Pick",Color3.fromRGB(120,200,255))
  row(body,"V","Trade Vault","Vault unlocked at L15","Locked",Color3.fromRGB(180,80,255))
end

local function fillBP(body)
  for _,c in ipairs(body:GetChildren()) do if not c:IsA("UIPadding") and not c:IsA("UIListLayout") then c:Destroy() end end
  local lay=Instance.new("UIListLayout") lay.Padding=UDim.new(0,8) lay.Parent=body
  for tier=1,30 do
    local emoji=tier%5==0 and "*" or "."
    local name="Tier "..tier
    local desc=tier%5==0 and "BIG REWARD: 5x Gems + Cosmetic" or "100 Coins + 10 XP"
    row(body,emoji,name,desc,(tier<=3) and "Claim" or "Locked",Color3.fromRGB(255,180,40))
  end
end

-- Build all panels (start hidden)
local sShop,bShop=buildShell("ShopUI","Shop","Boost your chaos with Robux upgrades") fillShop(bShop)
local sInv,bInv=buildShell("InventoryUI","Inventory","Skins, hats, accessories, titles") fillInventory(bInv)
local sStats,bStats=buildShell("StatsUI","Stats","Your career as a chaos cat") fillStats(bStats)
local sDaily,bDaily=buildShell("DailyUI","Daily Reward","7-day login streak") fillDaily(bDaily)
local sSlot,bSlot=buildShell("SlotUI","Lucky Slot","Spin to win coins, gems, skins") fillSlot(bSlot)
local sFort,bFort=buildShell("FortuneUI","Daily Fortune","One pull per day - effects last 24h") fillFortune(bFort)
local sLB,bLB=buildShell("LeaderboardUI","Leaderboard","Top pranksters in this server") fillLeaderboard(bLB)
local sFr,bFr=buildShell("FriendsUI","Friends","Invite, join, party up") fillFriends(bFr)
local sGang,bGang=buildShell("GangUI","Gangs","Found a crew, claim turf, war other gangs") fillGang(bGang)
local sTrade,bTrade=buildShell("TradeUI","Trade","Swap skins/items with friends") fillTrade(bTrade)
local sBP,bBP=buildShell("BattlePassUI","Battle Pass","30 tiers - season ends in 30 days") fillBP(bBP)

-- Wire OpenUI from server (if RemoteEvents exists)
local Re=RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("RemoteEvents")
local function bindOpen()
  if not Re then return end
  local e=Re:FindFirstChild("OpenUI")
  if not e then return end
  e.OnClientEvent:Connect(function(name)
    local map={Shop=sShop,Inventory=sInv,Stats=sStats,Daily=sDaily,Slot=sSlot,Fortune=sFort,Leaderboard=sLB,Friends=sFr,Gang=sGang,Trade=sTrade,BattlePass=sBP}
    local g=map[name] if g then g.Enabled=not g.Enabled end
  end)
end
bindOpen()

print("[Modals] 11 panels built")
]==]
local s=Instance.new("LocalScript") s.Name="ModalSystem" s.Source=src s.Parent=SPS_Sc
for _,p in ipairs(game:GetService("Players"):GetPlayers()) do pcall(function() p:LoadCharacter() end) end
print("[Done] Modal system deployed")
