-- PASTE 6 — 5 remaining mini-games (Trash Dive, Rooftop Race, Catnip Hunt, Photobomb, Restaurant Heist)
-- Spawns portal pads in city. Touching one teleports to a private arena, runs the game loop, returns with rewards.
local SSS=game:GetService("ServerScriptService")
local old=SSS:FindFirstChild("MiniGameServer") if old then old:Destroy() end

local src=[[
local Players=game:GetService("Players")
local TS=game:GetService("TeleportService")
local Workspace=workspace
local TweenService=game:GetService("TweenService")

-- Find arena root (or build)
local Arena=Workspace:FindFirstChild("MiniGameArenas")
if not Arena then Arena=Instance.new("Folder") Arena.Name="MiniGameArenas" Arena.Parent=Workspace end

-- Helper: floating arena island at fixed position
local function buildIsland(name,offsetX,offsetZ,baseColor)
  local island=Workspace.MiniGameArenas:FindFirstChild(name)
  if island then return island end
  island=Instance.new("Folder") island.Name=name island.Parent=Arena
  local floor=Instance.new("Part") floor.Name="Floor" floor.Anchored=true floor.Size=Vector3.new(120,2,120)
  floor.CFrame=CFrame.new(offsetX,500,offsetZ) floor.Color=baseColor or Color3.fromRGB(60,80,60)
  floor.Material=Enum.Material.Grass floor.Parent=island
  -- 4 walls
  for i,p in ipairs({{0,500.5,60},{0,500.5,-60},{60,500.5,0},{-60,500.5,0}}) do
    local wall=Instance.new("Part") wall.Anchored=true
    wall.Size=(i<=2) and Vector3.new(120,8,2) or Vector3.new(2,8,120)
    wall.CFrame=CFrame.new(offsetX+p[1],p[2]+4,offsetZ+p[3]) wall.Color=Color3.fromRGB(80,80,100) wall.Transparency=0.3
    wall.Material=Enum.Material.ForceField wall.Parent=island
  end
  return island
end

-- 1. Trash Dive — collect coins from floating trash piles
local trashIsland=buildIsland("TrashDive",-300,-300,Color3.fromRGB(80,70,50))
for i=1,15 do
  local trash=Instance.new("Part") trash.Anchored=true trash.Size=Vector3.new(4,3,3)
  trash.Color=Color3.fromRGB(60+math.random(0,40),50+math.random(0,30),40+math.random(0,30))
  trash.Material=Enum.Material.Plastic
  trash.CFrame=CFrame.new(-300+math.random(-50,50),502,-300+math.random(-50,50))
  trash.Name="TrashPile" trash.Parent=trashIsland
end

-- 2. Rooftop Race — checkpoint course
local raceIsland=buildIsland("RooftopRace",300,-300,Color3.fromRGB(50,50,70))
for i=1,8 do
  local cp=Instance.new("Part") cp.Anchored=true cp.Size=Vector3.new(8,1,8)
  cp.CFrame=CFrame.new(300-40+i*10,502+(i%2)*4,-300-40+i*8)
  cp.Color=Color3.fromRGB(255,180,40) cp.Material=Enum.Material.Neon
  cp.Name="Checkpoint"..i cp.Parent=raceIsland
end

-- 3. Catnip Hunt — hidden catnip plants
local nipIsland=buildIsland("CatnipHunt",-300,300,Color3.fromRGB(40,100,60))
for i=1,20 do
  local nip=Instance.new("Part") nip.Anchored=true nip.Size=Vector3.new(2,2,2)
  nip.Shape=Enum.PartType.Ball nip.Color=Color3.fromRGB(140,220,80) nip.Material=Enum.Material.Grass
  nip.CFrame=CFrame.new(-300+math.random(-55,55),502,300+math.random(-55,55))
  nip.Name="Catnip" nip.Parent=nipIsland
end

-- 4. Photobomb — pose at flash points before timer
local photoIsland=buildIsland("Photobomb",300,300,Color3.fromRGB(80,40,80))
for i=1,6 do
  local pad=Instance.new("Part") pad.Anchored=true pad.Size=Vector3.new(8,1,8)
  pad.CFrame=CFrame.new(300+math.cos(i*math.pi/3)*40,502,300+math.sin(i*math.pi/3)*40)
  pad.Color=Color3.fromRGB(255,80,200) pad.Material=Enum.Material.Neon
  pad.Name="FlashPad" pad.Parent=photoIsland
end

-- 5. Restaurant Heist — grab fish from cooking station
local heistIsland=buildIsland("RestaurantHeist",0,-500,Color3.fromRGB(120,60,60))
for i=1,10 do
  local fish=Instance.new("Part") fish.Anchored=true fish.Size=Vector3.new(3,0.6,1.4)
  fish.Color=Color3.fromRGB(220,180,140) fish.Material=Enum.Material.SmoothPlastic
  fish.CFrame=CFrame.new(math.random(-50,50),502,-500+math.random(-50,50))
  fish.Name="Fish" fish.Parent=heistIsland
end
local boss=Instance.new("Part") boss.Anchored=true boss.Size=Vector3.new(4,8,4)
boss.Color=Color3.fromRGB(200,80,80) boss.Material=Enum.Material.SmoothPlastic
boss.CFrame=CFrame.new(0,505,-540) boss.Name="ChefBoss" boss.Parent=heistIsland

-- Build portal pads in main city (4 corners)
local Portals=Workspace:FindFirstChild("MiniGamePortals")
if Portals then Portals:Destroy() end
Portals=Instance.new("Folder") Portals.Name="MiniGamePortals" Portals.Parent=Workspace

local function makePortal(label,x,z,destX,destZ,color)
  local p=Instance.new("Model") p.Name="Portal_"..label p.Parent=Portals
  local base=Instance.new("Part") base.Anchored=true base.Size=Vector3.new(10,0.5,10) base.CFrame=CFrame.new(x,1,z) base.Color=color base.Material=Enum.Material.Neon base.Name="Pad" base.Parent=p
  local arch=Instance.new("Part") arch.Anchored=true arch.Size=Vector3.new(0.6,12,8) arch.CFrame=CFrame.new(x,7,z) arch.Color=color arch.Material=Enum.Material.Neon arch.Transparency=0.3 arch.CanCollide=false arch.Parent=p
  local sign=Instance.new("Part") sign.Anchored=true sign.CanCollide=false sign.Size=Vector3.new(8,2,0.2) sign.CFrame=CFrame.new(x,15,z) sign.Color=color sign.Parent=p
  local sgui=Instance.new("SurfaceGui") sgui.Face=Enum.NormalId.Front sgui.Parent=sign
  local lbl=Instance.new("TextLabel") lbl.Size=UDim2.fromScale(1,1) lbl.BackgroundTransparency=1 lbl.Font=Enum.Font.GothamBlack lbl.TextScaled=true lbl.TextColor3=Color3.fromRGB(255,255,255) lbl.Text=label lbl.Parent=sgui
  base.Touched:Connect(function(hit)
    local plr=Players:GetPlayerFromCharacter(hit.Parent)
    if not plr or not plr.Character then return end
    local hrp=plr.Character:FindFirstChild("HumanoidRootPart") if not hrp then return end
    -- cooldown via attribute
    local last=plr:GetAttribute("LastPortal") or 0
    if tick()-last<3 then return end
    plr:SetAttribute("LastPortal",tick())
    hrp.CFrame=CFrame.new(destX,510,destZ)
    -- set in-game flag
    plr:SetAttribute("InMiniGame",label)
    plr:SetAttribute("MGStart",tick())
    print("[MiniGame] "..plr.Name.." entered "..label)
  end)
end

makePortal("TRASH DIVE",      80,  80,  -300,-300,Color3.fromRGB(120,80,40))
makePortal("ROOFTOP RACE",   -80,  80,   300,-300,Color3.fromRGB(80,160,255))
makePortal("CATNIP HUNT",     80, -80,  -300, 300,Color3.fromRGB(140,220,80))
makePortal("PHOTOBOMB",      -80, -80,   300, 300,Color3.fromRGB(255,80,200))
makePortal("RESTAURANT HEIST",  0,160,    0,  -500,Color3.fromRGB(255,140,80))

-- Pickup loops for each game
local function awardCoins(plr,n)
  local ls=plr:FindFirstChild("leaderstats") if not ls then return end
  local c=ls:FindFirstChild("Coins") if c then c.Value=c.Value+n end
  local x=ls:FindFirstChild("XP") if x then x.Value=x.Value+math.floor(n/2) end
end

-- Trash Dive coin pickup
for _,trash in ipairs(trashIsland:GetChildren()) do
  if trash.Name=="TrashPile" and trash:IsA("BasePart") then
    trash.Touched:Connect(function(hit)
      local plr=Players:GetPlayerFromCharacter(hit.Parent)
      if plr and trash.Parent and plr:GetAttribute("InMiniGame")=="TRASH DIVE" then
        awardCoins(plr,25)
        trash:Destroy()
      end
    end)
  end
end
-- Catnip pickup
for _,nip in ipairs(nipIsland:GetChildren()) do
  if nip.Name=="Catnip" and nip:IsA("BasePart") then
    nip.Touched:Connect(function(hit)
      local plr=Players:GetPlayerFromCharacter(hit.Parent)
      if plr and nip.Parent and plr:GetAttribute("InMiniGame")=="CATNIP HUNT" then
        awardCoins(plr,30)
        nip:Destroy()
      end
    end)
  end
end
-- Fish pickup
for _,fish in ipairs(heistIsland:GetChildren()) do
  if fish.Name=="Fish" and fish:IsA("BasePart") then
    fish.Touched:Connect(function(hit)
      local plr=Players:GetPlayerFromCharacter(hit.Parent)
      if plr and fish.Parent and plr:GetAttribute("InMiniGame")=="RESTAURANT HEIST" then
        awardCoins(plr,40)
        fish:Destroy()
      end
    end)
  end
end
-- Race checkpoint reward
for i=1,8 do
  local cp=raceIsland:FindFirstChild("Checkpoint"..i)
  if cp then cp.Touched:Connect(function(hit)
    local plr=Players:GetPlayerFromCharacter(hit.Parent)
    if plr and plr:GetAttribute("InMiniGame")=="ROOFTOP RACE" then
      local last=plr:GetAttribute("LastCP") or 0
      if i==last+1 then plr:SetAttribute("LastCP",i) awardCoins(plr,15)
        if i==8 then awardCoins(plr,200) plr:SetAttribute("LastCP",0) end
      end
    end
  end) end
end
-- Photobomb pad chain
for i=1,6 do
  local pad=photoIsland:FindFirstChild("FlashPad")
  if pad then pad.Touched:Connect(function(hit)
    local plr=Players:GetPlayerFromCharacter(hit.Parent)
    if plr and plr:GetAttribute("InMiniGame")=="PHOTOBOMB" then awardCoins(plr,20) end
  end) end
end

-- Auto-eject from minigame after 3 minutes
task.spawn(function()
  while true do task.wait(10)
    for _,plr in ipairs(Players:GetPlayers()) do
      local mg=plr:GetAttribute("InMiniGame")
      local start=plr:GetAttribute("MGStart") or 0
      if mg and tick()-start>180 then
        plr:SetAttribute("InMiniGame",nil) plr:SetAttribute("LastCP",0)
        if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
          plr.Character.HumanoidRootPart.CFrame=CFrame.new(0,15,0)
        end
        local ls=plr:FindFirstChild("leaderstats") if ls then local g=ls:FindFirstChild("Gems") if g then g.Value=g.Value+5 end end
      end
    end
  end
end)

print("[MiniGame] 5 mini-games online with 5 portals in city")
]]

local s=Instance.new("Script") s.Name="MiniGameServer" s.Source=src s.Parent=SSS
print("[Done] 5 mini-games deployed")
