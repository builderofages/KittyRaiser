-- PASTE 7 — Missing NPC types (11 new species)
local SSS=game:GetService("ServerScriptService")
local old=SSS:FindFirstChild("ExtraNPCs") if old then old:Destroy() end
local src=[==[
local Workspace=workspace
local function newPart(parent,name,color,size,material) local p=Instance.new("Part") p.Name=name p.Anchored=true p.Material=material or Enum.Material.SmoothPlastic p.Color=color p.Size=size p.Parent=parent return p end
local NPCs=Workspace:FindFirstChild("ExtraNPCs") if NPCs then NPCs:Destroy() end
NPCs=Instance.new("Folder") NPCs.Name="ExtraNPCs" NPCs.Parent=Workspace
local function place(model,x,y,z) model.Parent=NPCs model:PivotTo(CFrame.new(x,y,z)) end

local function makeTurtle()
  local m=Instance.new("Model") m.Name="Turtle"
  local shell=newPart(m,"Shell",Color3.fromRGB(60,120,60),Vector3.new(2.4,1.2,2),Enum.Material.Slate) shell.CFrame=CFrame.new(0,0.6,0)
  local head=newPart(m,"Head",Color3.fromRGB(80,160,80),Vector3.new(0.8,0.7,0.8)) head.CFrame=CFrame.new(0,0.6,1.4)
  m.PrimaryPart=shell return m
end
local function makeDuck()
  local m=Instance.new("Model") m.Name="Duck"
  local body=newPart(m,"Body",Color3.fromRGB(255,240,180),Vector3.new(2,1.6,1.4)) body.CFrame=CFrame.new(0,0.8,0)
  local head=newPart(m,"Head",Color3.fromRGB(255,240,180),Vector3.new(1,1,1)) head.Shape=Enum.PartType.Ball head.CFrame=CFrame.new(0,2,0.6)
  local beak=newPart(m,"Beak",Color3.fromRGB(255,180,40),Vector3.new(0.6,0.3,0.6)) beak.CFrame=CFrame.new(0,1.95,1.2)
  m.PrimaryPart=body return m
end
local function makeButterfly()
  local m=Instance.new("Model") m.Name="Butterfly"
  local body=newPart(m,"Body",Color3.fromRGB(40,40,40),Vector3.new(0.2,0.2,1)) body.CFrame=CFrame.new(0,5,0)
  local color=Color3.fromHSV(math.random(),0.8,0.95)
  local wL=newPart(m,"WingL",color,Vector3.new(1.2,0.05,1)) wL.CFrame=CFrame.new(-0.6,5,0)
  local wR=newPart(m,"WingR",color,Vector3.new(1.2,0.05,1)) wR.CFrame=CFrame.new(0.6,5,0)
  m.PrimaryPart=body return m
end
local function makeGoldfish()
  local m=Instance.new("Model") m.Name="Goldfish"
  local body=newPart(m,"Body",Color3.fromRGB(255,140,40),Vector3.new(1.4,0.6,0.4)) body.CFrame=CFrame.new(0,0.4,0)
  local tail=newPart(m,"Tail",Color3.fromRGB(255,160,60),Vector3.new(0.6,0.6,0.1)) tail.CFrame=CFrame.new(-0.9,0.4,0)
  m.PrimaryPart=body return m
end
local function makeHuman(skinColor,hatColor)
  local m=Instance.new("Model") m.Name="FriendlyHuman"
  local torso=newPart(m,"Torso",Color3.fromRGB(60,80,160),Vector3.new(2,2,1)) torso.CFrame=CFrame.new(0,3,0)
  local head=newPart(m,"Head",skinColor,Vector3.new(1.4,1.4,1.4)) head.Shape=Enum.PartType.Ball head.CFrame=CFrame.new(0,4.7,0)
  local hat=newPart(m,"Hat",hatColor,Vector3.new(1.6,0.3,1.6)) hat.CFrame=CFrame.new(0,5.6,0)
  m.PrimaryPart=torso return m
end
local function makeChef()
  local m=Instance.new("Model") m.Name="ChefBoss"
  local torso=newPart(m,"Torso",Color3.fromRGB(255,255,255),Vector3.new(2.2,2.4,1.2)) torso.CFrame=CFrame.new(0,3,0)
  local head=newPart(m,"Head",Color3.fromRGB(255,200,170),Vector3.new(1.4,1.4,1.4)) head.Shape=Enum.PartType.Ball head.CFrame=CFrame.new(0,4.9,0)
  local hat=newPart(m,"ChefHat",Color3.fromRGB(255,255,255),Vector3.new(1.4,2,1.4)) hat.CFrame=CFrame.new(0,6.5,0)
  m.PrimaryPart=torso return m
end
local function makeRatKing()
  local m=Instance.new("Model") m.Name="SewerRatKing"
  local body=newPart(m,"Body",Color3.fromRGB(80,60,50),Vector3.new(4,3,5)) body.CFrame=CFrame.new(0,1.5,0)
  local head=newPart(m,"Head",Color3.fromRGB(100,80,70),Vector3.new(2.4,2,2.4)) head.CFrame=CFrame.new(0,2.5,3)
  local crown=newPart(m,"Crown",Color3.fromRGB(255,200,40),Vector3.new(2,1,2),Enum.Material.Metal) crown.CFrame=CFrame.new(0,3.6,3)
  m.PrimaryPart=body return m
end
local function makeDemon(scale)
  scale=scale or 1
  local m=Instance.new("Model") m.Name=scale>1.5 and "DemonLord" or "Demon"
  local torso=newPart(m,"Torso",Color3.fromRGB(80,20,30),Vector3.new(2*scale,3*scale,1.4*scale)) torso.CFrame=CFrame.new(0,1.5*scale,0)
  local head=newPart(m,"Head",Color3.fromRGB(120,30,40),Vector3.new(1.4*scale,1.4*scale,1.4*scale)) head.Shape=Enum.PartType.Ball head.CFrame=CFrame.new(0,3.5*scale,0)
  m.PrimaryPart=torso return m
end
local function makeSWAT()
  local m=Instance.new("Model") m.Name="AnimalControlSWAT"
  local torso=newPart(m,"Torso",Color3.fromRGB(40,50,40),Vector3.new(2.2,2.4,1.2)) torso.CFrame=CFrame.new(0,3,0)
  local head=newPart(m,"Head",Color3.fromRGB(220,180,150),Vector3.new(1.4,1.4,1.4)) head.Shape=Enum.PartType.Ball head.CFrame=CFrame.new(0,4.9,0)
  local helmet=newPart(m,"Helmet",Color3.fromRGB(20,20,20),Vector3.new(1.6,1,1.6),Enum.Material.Metal) helmet.CFrame=CFrame.new(0,5.6,0)
  m.PrimaryPart=torso return m
end

local function scatter(ctor,n,radius)
  for i=1,n do local angle=math.random()*math.pi*2 local r=math.random(20,radius) local m=ctor() if m then place(m,math.cos(angle)*r,0,math.sin(angle)*r) end end
end
scatter(makeTurtle,6,180) scatter(makeDuck,8,200) scatter(makeButterfly,12,150) scatter(makeGoldfish,8,160)
scatter(function() return makeHuman(Color3.fromRGB(255,210,170),Color3.fromRGB(40,40,80)) end,4,180)
scatter(function() return makeHuman(Color3.fromRGB(220,170,140),Color3.fromRGB(255,80,80)) end,4,180)
scatter(function() return makeHuman(Color3.fromRGB(180,140,100),Color3.fromRGB(40,180,80)) end,4,180)
scatter(makeChef,3,200) scatter(function() return makeDemon(1) end,5,250) scatter(makeSWAT,4,220)
local rk=makeRatKing() place(rk,0,0,180)
local dl=makeDemon(2) place(dl,0,0,-180)
print("[ExtraNPCs] Spawned 60+ new NPCs across 11 species")
]==]
local s=Instance.new("Script") s.Name="ExtraNPCs" s.Source=src s.Parent=SSS
print("[Done] 11 new NPC types deployed")
