-- PASTE 2 — Pre-game cat customization lobby (LocalScript injected to StarterPlayerScripts)
-- GTA-style transition: lobby UI → SPAWN button → fade → gameplay HUD
local SPS=game:GetService("ServerScriptService")
local SPS_Sc=game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
if not SPS_Sc then warn("SPS missing") return end

-- Remove old lobby if it exists (idempotent re-deploy)
local old=SPS_Sc:FindFirstChild("PreGameLobby") if old then old:Destroy() end

local src=[==[
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local UIS=game:GetService("UserInputService")
local plr=Players.LocalPlayer
local pg=plr:WaitForChild("PlayerGui")

-- Hide HUD until lobby done
local function setHUD(visible)
  for _,gui in ipairs(pg:GetChildren()) do
    if gui:IsA("ScreenGui") and gui.Name~="PreGameLobby" and gui.Name~="LobbyFade" then
      gui.Enabled=visible
    end
  end
end
setHUD(false)

-- Skin catalog (fallback if not loaded)
local CAT=RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("CosmeticCatalog")
local skins
if CAT then local ok,m=pcall(require,CAT) if ok then skins=m end end
if not skins or #skins==0 then
  skins={
    {id="orange_tabby",name="Orange Tabby",rarity="Common",price=0,color=Color3.fromRGB(230,140,60)},
    {id="black_cat",name="Black Cat",rarity="Common",price=0,color=Color3.fromRGB(20,20,20)},
    {id="white_persian",name="White Persian",rarity="Common",price=0,color=Color3.fromRGB(245,245,240)},
    {id="grey_tabby",name="Grey Tabby",rarity="Common",price=0,color=Color3.fromRGB(130,130,140)},
    {id="calico",name="Calico",rarity="Common",price=0,color=Color3.fromRGB(220,180,120)},
    {id="siamese",name="Siamese",rarity="Uncommon",price=0,unlock="Lvl 5",color=Color3.fromRGB(220,200,170)},
    {id="bengal",name="Bengal",rarity="Rare",price=0,unlock="Lvl 15",color=Color3.fromRGB(210,150,80)},
    {id="cyber_cat",name="Cyber Cat",rarity="Epic",price=199,color=Color3.fromRGB(20,200,255)},
    {id="rainbow_cat",name="Rainbow Cat",rarity="Legendary",price=499,color=Color3.fromRGB(255,100,200)},
    {id="cosmic_cat",name="Cosmic Cat",rarity="Mythic",price=999,color=Color3.fromRGB(140,60,255)},
  }
end

local idx=1

-- Root
local gui=Instance.new("ScreenGui") gui.Name="PreGameLobby" gui.IgnoreGuiInset=true gui.DisplayOrder=10000 gui.ResetOnSpawn=false gui.Parent=pg

-- Background gradient
local bg=Instance.new("Frame") bg.Size=UDim2.fromScale(1,1) bg.BorderSizePixel=0 bg.BackgroundColor3=Color3.fromRGB(15,12,28) bg.Parent=gui
local grad=Instance.new("UIGradient") grad.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(35,18,55)),ColorSequenceKeypoint.new(0.5,Color3.fromRGB(15,10,30)),ColorSequenceKeypoint.new(1,Color3.fromRGB(8,6,18))} grad.Rotation=130 grad.Parent=bg

-- Animated stars
for i=1,40 do
  local s=Instance.new("Frame") s.Size=UDim2.fromOffset(math.random(2,4),math.random(2,4))
  s.Position=UDim2.fromScale(math.random(),math.random()) s.BorderSizePixel=0
  s.BackgroundColor3=Color3.fromRGB(255,255,200) s.BackgroundTransparency=math.random(30,80)/100
  local c=Instance.new("UICorner") c.CornerRadius=UDim.new(1,0) c.Parent=s
  s.Parent=bg
end

-- Title
local title=Instance.new("TextLabel") title.Size=UDim2.new(1,0,0,80) title.Position=UDim2.new(0,0,0,40)
title.BackgroundTransparency=1 title.Font=Enum.Font.GothamBlack title.TextScaled=true
title.TextColor3=Color3.fromRGB(255,200,80) title.Text="🐾 KITTY RAISER" title.Parent=gui
local tStroke=Instance.new("UIStroke") tStroke.Color=Color3.fromRGB(80,30,120) tStroke.Thickness=4 tStroke.Parent=title

local sub=Instance.new("TextLabel") sub.Size=UDim2.new(1,0,0,30) sub.Position=UDim2.new(0,0,0,120)
sub.BackgroundTransparency=1 sub.Font=Enum.Font.GothamMedium sub.TextSize=20
sub.TextColor3=Color3.fromRGB(220,200,255) sub.Text="Choose your cat. Cause chaos. Get rich." sub.Parent=gui

-- Skin preview circle
local card=Instance.new("Frame") card.Size=UDim2.fromOffset(360,360) card.AnchorPoint=Vector2.new(0.5,0.5)
card.Position=UDim2.fromScale(0.5,0.48) card.BackgroundColor3=Color3.fromRGB(28,22,48) card.BorderSizePixel=0 card.Parent=gui
local cardC=Instance.new("UICorner") cardC.CornerRadius=UDim.new(0,28) cardC.Parent=card
local cardS=Instance.new("UIStroke") cardS.Color=Color3.fromRGB(120,80,200) cardS.Thickness=3 cardS.Parent=card

-- Cat preview
local catFace=Instance.new("Frame") catFace.AnchorPoint=Vector2.new(0.5,0.5) catFace.Position=UDim2.fromScale(0.5,0.5)
catFace.Size=UDim2.fromOffset(220,220) catFace.BorderSizePixel=0 catFace.BackgroundColor3=skins[1].color catFace.Parent=card
local fc=Instance.new("UICorner") fc.CornerRadius=UDim.new(1,0) fc.Parent=catFace
-- Ears
local earL=Instance.new("Frame") earL.Size=UDim2.fromOffset(50,60) earL.Position=UDim2.fromOffset(20,-15) earL.BorderSizePixel=0 earL.BackgroundColor3=skins[1].color earL.Rotation=-25 earL.Parent=catFace
local earLC=Instance.new("UICorner") earLC.CornerRadius=UDim.new(0.5,0) earLC.Parent=earL
local earR=Instance.new("Frame") earR.Size=UDim2.fromOffset(50,60) earR.Position=UDim2.fromOffset(150,-15) earR.BorderSizePixel=0 earR.BackgroundColor3=skins[1].color earR.Rotation=25 earR.Parent=catFace
local earRC=Instance.new("UICorner") earRC.CornerRadius=UDim.new(0.5,0) earRC.Parent=earR
-- Eyes
local function eye(x) local e=Instance.new("Frame") e.Size=UDim2.fromOffset(28,40) e.Position=UDim2.fromOffset(x,80) e.BorderSizePixel=0 e.BackgroundColor3=Color3.fromRGB(60,255,140) e.Parent=catFace local c=Instance.new("UICorner") c.CornerRadius=UDim.new(1,0) c.Parent=e local p=Instance.new("Frame") p.Size=UDim2.fromOffset(8,30) p.AnchorPoint=Vector2.new(0.5,0.5) p.Position=UDim2.fromScale(0.5,0.5) p.BorderSizePixel=0 p.BackgroundColor3=Color3.fromRGB(0,0,0) p.Parent=e local pc=Instance.new("UICorner") pc.CornerRadius=UDim.new(1,0) pc.Parent=p return e end
eye(50) eye(140)
-- Nose
local nose=Instance.new("Frame") nose.Size=UDim2.fromOffset(20,16) nose.Position=UDim2.fromOffset(100,140) nose.BorderSizePixel=0 nose.BackgroundColor3=Color3.fromRGB(255,140,180) nose.Parent=catFace
local nC=Instance.new("UICorner") nC.CornerRadius=UDim.new(0.5,0) nC.Parent=nose
-- Whiskers
for i=-1,1 do local w=Instance.new("Frame") w.Size=UDim2.fromOffset(50,2) w.Position=UDim2.fromOffset(20,150+i*8) w.BorderSizePixel=0 w.BackgroundColor3=Color3.fromRGB(255,255,255) w.BackgroundTransparency=0.3 w.Parent=catFace end
for i=-1,1 do local w=Instance.new("Frame") w.Size=UDim2.fromOffset(50,2) w.Position=UDim2.fromOffset(150,150+i*8) w.BorderSizePixel=0 w.BackgroundColor3=Color3.fromRGB(255,255,255) w.BackgroundTransparency=0.3 w.Parent=catFace end

-- Skin info
local nameLbl=Instance.new("TextLabel") nameLbl.Size=UDim2.new(1,0,0,30) nameLbl.Position=UDim2.new(0,0,1,-72)
nameLbl.BackgroundTransparency=1 nameLbl.Font=Enum.Font.GothamBold nameLbl.TextSize=24
nameLbl.TextColor3=Color3.fromRGB(255,255,255) nameLbl.Text=skins[1].name nameLbl.Parent=card

local rarityLbl=Instance.new("TextLabel") rarityLbl.Size=UDim2.new(1,0,0,22) rarityLbl.Position=UDim2.new(0,0,1,-44)
rarityLbl.BackgroundTransparency=1 rarityLbl.Font=Enum.Font.GothamMedium rarityLbl.TextSize=16
rarityLbl.TextColor3=Color3.fromRGB(180,160,220) rarityLbl.Text=skins[1].rarity rarityLbl.Parent=card

-- Arrows
local function arrow(side)
  local b=Instance.new("TextButton") b.AnchorPoint=Vector2.new(0.5,0.5) b.Size=UDim2.fromOffset(60,60)
  b.BackgroundColor3=Color3.fromRGB(80,50,150) b.BorderSizePixel=0 b.Font=Enum.Font.GothamBlack b.TextSize=32
  b.TextColor3=Color3.fromRGB(255,255,255) b.Text=side=="L" and "<" or ">" b.Parent=gui
  if side=="L" then b.Position=UDim2.fromScale(0.32,0.48) else b.Position=UDim2.fromScale(0.68,0.48) end
  local c=Instance.new("UICorner") c.CornerRadius=UDim.new(1,0) c.Parent=b
  local s=Instance.new("UIStroke") s.Color=Color3.fromRGB(180,140,255) s.Thickness=2 s.Parent=b
  return b
end
local L=arrow("L") local R=arrow("R")

local function refresh()
  local s=skins[idx]
  catFace.BackgroundColor3=s.color earL.BackgroundColor3=s.color earR.BackgroundColor3=s.color
  nameLbl.Text=s.name
  local rTxt=s.rarity .. (s.unlock and (" • Unlocks at " .. s.unlock) or "") .. (s.price and s.price>0 and (" • " .. s.price .. " R$") or "")
  rarityLbl.Text=rTxt
  local cMap={Common=Color3.fromRGB(180,180,180),Uncommon=Color3.fromRGB(100,220,140),Rare=Color3.fromRGB(80,160,255),Epic=Color3.fromRGB(180,80,255),Legendary=Color3.fromRGB(255,180,60),Mythic=Color3.fromRGB(255,80,200)}
  rarityLbl.TextColor3=cMap[s.rarity] or Color3.fromRGB(180,160,220)
end

L.MouseButton1Click:Connect(function() idx=idx-1 if idx<1 then idx=#skins end refresh() end)
R.MouseButton1Click:Connect(function() idx=idx+1 if idx>#skins then idx=1 end refresh() end)

-- Skin counter
local counter=Instance.new("TextLabel") counter.Size=UDim2.new(0,200,0,24) counter.AnchorPoint=Vector2.new(0.5,0)
counter.Position=UDim2.fromScale(0.5,0.78) counter.BackgroundTransparency=1
counter.Font=Enum.Font.GothamMedium counter.TextSize=16 counter.TextColor3=Color3.fromRGB(180,160,220)
counter.Parent=gui
local function updateCounter() counter.Text="Skin "..idx.." / "..#skins end
updateCounter()
L.MouseButton1Click:Connect(updateCounter) R.MouseButton1Click:Connect(updateCounter)

-- SPAWN button
local spawn=Instance.new("TextButton") spawn.AnchorPoint=Vector2.new(0.5,1) spawn.Position=UDim2.fromScale(0.5,0.95)
spawn.Size=UDim2.fromOffset(360,72) spawn.BackgroundColor3=Color3.fromRGB(255,180,40) spawn.BorderSizePixel=0
spawn.Font=Enum.Font.GothamBlack spawn.TextSize=28 spawn.TextColor3=Color3.fromRGB(40,20,0)
spawn.Text="🐾  SPAWN INTO CITY" spawn.Parent=gui
local sC=Instance.new("UICorner") sC.CornerRadius=UDim.new(0,18) sC.Parent=spawn
local sS=Instance.new("UIStroke") sS.Color=Color3.fromRGB(255,230,150) sS.Thickness=3 sS.Parent=spawn
local sG=Instance.new("UIGradient") sG.Color=ColorSequence.new{ColorSequenceKeypoint.new(0,Color3.fromRGB(255,200,80)),ColorSequenceKeypoint.new(1,Color3.fromRGB(255,140,40))} sG.Rotation=90 sG.Parent=spawn

-- Pulse animation on spawn button
task.spawn(function()
  while spawn and spawn.Parent do
    local t=TweenService:Create(spawn,TweenInfo.new(0.8,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Size=UDim2.fromOffset(380,76)})
    t:Play() task.wait(1.6)
    if not spawn or not spawn.Parent then break end
  end
end)

-- Send selection to server (event creation if missing)
local function sendSkin(skinId)
  local Re=RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("RemoteEvents")
  if Re then
    local e=Re:FindFirstChild("EquipSkin")
    if e and e:IsA("RemoteEvent") then e:FireServer(skinId) end
  end
end

spawn.MouseButton1Click:Connect(function()
  spawn.Active=false
  -- GTA fade
  local fade=Instance.new("ScreenGui") fade.Name="LobbyFade" fade.IgnoreGuiInset=true fade.DisplayOrder=20000 fade.Parent=pg
  local f=Instance.new("Frame") f.Size=UDim2.fromScale(1,1) f.BorderSizePixel=0 f.BackgroundColor3=Color3.fromRGB(0,0,0) f.BackgroundTransparency=1 f.Parent=fade
  TweenService:Create(f,TweenInfo.new(0.6,Enum.EasingStyle.Sine),{BackgroundTransparency=0}):Play()
  task.wait(0.7)
  sendSkin(skins[idx].id)
  gui:Destroy()
  setHUD(true)
  task.wait(0.4)
  TweenService:Create(f,TweenInfo.new(0.8,Enum.EasingStyle.Sine),{BackgroundTransparency=1}):Play()
  task.wait(0.9) fade:Destroy()
end)

print("[Lobby] Pre-game cat customization shown")
]==]

local s=Instance.new("LocalScript")
s.Name="PreGameLobby"
s.Source=src
s.Parent=SPS_Sc

-- Reload character so lobby shows immediately for current player
for _,p in ipairs(game:GetService("Players"):GetPlayers()) do
  pcall(function() p:LoadCharacter() end)
end

print("[Done] Pre-game lobby deployed")
