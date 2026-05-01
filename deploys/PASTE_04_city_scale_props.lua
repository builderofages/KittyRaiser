-- PASTE 4 — City scale 8x + 200 street props
-- Tile ToolboxCity into 3x3 grid, then scatter 200 mailboxes/cans/lights/benches/hydrants/cars/lamps/plants
local ws=workspace
local CityName="ToolboxCity"
local cityMaster=ws:FindFirstChild(CityName)
if not cityMaster then warn("ToolboxCity missing") return end

-- Compute current bounds
local function bounds(model)
  local cf,size=model:GetBoundingBox()
  return cf,size
end
local cfBase,sizeBase=bounds(cityMaster)
print(("[CityScale] Current city size = %.0f x %.0f studs"):format(sizeBase.X,sizeBase.Z))

-- If already tiled, skip
local tiled=ws:FindFirstChild("CityTiles")
if tiled then tiled:Destroy() end
local TILES=Instance.new("Folder") TILES.Name="CityTiles" TILES.Parent=ws

-- Build 3x3 grid (the original is the center tile)
local function shiftClone(parent,baseModel,xOff,zOff)
  local c=baseModel:Clone()
  c.Name=baseModel.Name.."_T"
  c.Parent=parent
  local cf,_=c:GetBoundingBox()
  c:PivotTo(cf*CFrame.new(xOff,0,zOff))
  return c
end

local sx,sz=sizeBase.X-20,sizeBase.Z-20 -- overlap a tiny bit so seams hide
local placed=0
for ix=-1,1 do
  for iz=-1,1 do
    if not (ix==0 and iz==0) then
      shiftClone(TILES,cityMaster,ix*sx,iz*sz)
      placed=placed+1
    end
  end
end
print(("[CityScale] Tiled %d additional cities"):format(placed))

-- Re-bound for prop scatter
local megaCF,megaSize=ws:GetBoundingBox()
print(("[CityScale] World bounds now %.0f x %.0f"):format(megaSize.X,megaSize.Z))

-- Street props folder
local Props=ws:FindFirstChild("StreetProps") if Props then Props:Destroy() end
Props=Instance.new("Folder") Props.Name="StreetProps" Props.Parent=ws

local function place(model,x,y,z,ry)
  model.Parent=Props
  model:PivotTo(CFrame.new(x,y,z)*CFrame.Angles(0,math.rad(ry or 0),0))
end

-- Lightweight prop builders
local function newPart(parent,name,color,size,material)
  local p=Instance.new("Part") p.Name=name p.Anchored=true p.Material=material or Enum.Material.SmoothPlastic
  p.Color=color or Color3.fromRGB(120,120,130) p.Size=size or Vector3.new(2,2,2) p.Parent=parent
  return p
end
local function makeMailbox()
  local m=Instance.new("Model") m.Name="Mailbox"
  local pole=newPart(m,"Pole",Color3.fromRGB(60,60,80),Vector3.new(0.4,3,0.4),Enum.Material.Metal)
  pole.CFrame=CFrame.new(0,1.5,0)
  local box=newPart(m,"Box",Color3.fromRGB(40,80,200),Vector3.new(2,1.5,1.2),Enum.Material.Metal)
  box.CFrame=CFrame.new(0,3.5,0)
  local lid=newPart(m,"Lid",Color3.fromRGB(60,100,220),Vector3.new(0.6,0.3,1.2),Enum.Material.Metal)
  lid.CFrame=CFrame.new(0.7,3.5,0)
  m.PrimaryPart=pole
  return m
end
local function makeTrashCan()
  local m=Instance.new("Model") m.Name="TrashCan"
  local can=newPart(m,"Can",Color3.fromRGB(50,50,50),Vector3.new(2,3,2),Enum.Material.Metal)
  can.Shape=Enum.PartType.Cylinder can.CFrame=CFrame.new(0,1.5,0)*CFrame.Angles(0,0,math.rad(90))
  local lid=newPart(m,"Lid",Color3.fromRGB(70,70,70),Vector3.new(2.2,0.3,2.2),Enum.Material.Metal)
  lid.Shape=Enum.PartType.Cylinder lid.CFrame=CFrame.new(0,3.1,0)*CFrame.Angles(0,0,math.rad(90))
  m.PrimaryPart=can
  return m
end
local function makeTrafficLight()
  local m=Instance.new("Model") m.Name="TrafficLight"
  local pole=newPart(m,"Pole",Color3.fromRGB(40,40,40),Vector3.new(0.5,12,0.5),Enum.Material.Metal)
  pole.CFrame=CFrame.new(0,6,0)
  local box=newPart(m,"Lights",Color3.fromRGB(20,20,20),Vector3.new(1.2,3,1.2),Enum.Material.Metal)
  box.CFrame=CFrame.new(0,11,0)
  local r=newPart(m,"Red",Color3.fromRGB(255,40,40),Vector3.new(0.7,0.7,0.7),Enum.Material.Neon) r.Shape=Enum.PartType.Ball r.CFrame=CFrame.new(0,12,0.7)
  local y=newPart(m,"Yellow",Color3.fromRGB(255,200,40),Vector3.new(0.7,0.7,0.7),Enum.Material.Neon) y.Shape=Enum.PartType.Ball y.CFrame=CFrame.new(0,11,0.7)
  local g=newPart(m,"Green",Color3.fromRGB(40,255,80),Vector3.new(0.7,0.7,0.7),Enum.Material.Neon) g.Shape=Enum.PartType.Ball g.CFrame=CFrame.new(0,10,0.7)
  m.PrimaryPart=pole
  return m
end
local function makeBench()
  local m=Instance.new("Model") m.Name="Bench"
  local seat=newPart(m,"Seat",Color3.fromRGB(120,80,40),Vector3.new(5,0.4,1.6),Enum.Material.WoodPlanks)
  seat.CFrame=CFrame.new(0,1.4,0)
  local back=newPart(m,"Back",Color3.fromRGB(120,80,40),Vector3.new(5,2,0.4),Enum.Material.WoodPlanks)
  back.CFrame=CFrame.new(0,2.4,-0.6)
  local lL=newPart(m,"LegL",Color3.fromRGB(60,60,60),Vector3.new(0.4,1.4,0.4),Enum.Material.Metal) lL.CFrame=CFrame.new(-2,0.7,0)
  local lR=newPart(m,"LegR",Color3.fromRGB(60,60,60),Vector3.new(0.4,1.4,0.4),Enum.Material.Metal) lR.CFrame=CFrame.new( 2,0.7,0)
  m.PrimaryPart=seat
  return m
end
local function makeHydrant()
  local m=Instance.new("Model") m.Name="FireHydrant"
  local body=newPart(m,"Body",Color3.fromRGB(220,40,40),Vector3.new(1.4,2.4,1.4),Enum.Material.Metal)
  body.Shape=Enum.PartType.Cylinder body.CFrame=CFrame.new(0,1.2,0)*CFrame.Angles(0,0,math.rad(90))
  local cap=newPart(m,"Cap",Color3.fromRGB(255,80,80),Vector3.new(1.6,0.5,1.6),Enum.Material.Metal)
  cap.Shape=Enum.PartType.Cylinder cap.CFrame=CFrame.new(0,2.7,0)*CFrame.Angles(0,0,math.rad(90))
  m.PrimaryPart=body
  return m
end
local function makeLamp()
  local m=Instance.new("Model") m.Name="Lamp"
  local pole=newPart(m,"Pole",Color3.fromRGB(30,30,40),Vector3.new(0.4,16,0.4),Enum.Material.Metal)
  pole.CFrame=CFrame.new(0,8,0)
  local arm=newPart(m,"Arm",Color3.fromRGB(30,30,40),Vector3.new(2,0.3,0.3),Enum.Material.Metal)
  arm.CFrame=CFrame.new(1,15.8,0)
  local bulb=newPart(m,"Bulb",Color3.fromRGB(255,230,140),Vector3.new(1.2,1.2,1.2),Enum.Material.Neon)
  bulb.Shape=Enum.PartType.Ball bulb.CFrame=CFrame.new(2,15.5,0)
  local pl=Instance.new("PointLight") pl.Color=Color3.fromRGB(255,220,140) pl.Brightness=2 pl.Range=20 pl.Parent=bulb
  m.PrimaryPart=pole
  return m
end
local function makePlant()
  local m=Instance.new("Model") m.Name="Plant"
  local pot=newPart(m,"Pot",Color3.fromRGB(140,70,40),Vector3.new(1.6,1.4,1.6),Enum.Material.Slate) pot.CFrame=CFrame.new(0,0.7,0)
  local foliage=newPart(m,"Leaves",Color3.fromRGB(60,180,80),Vector3.new(2.4,2.4,2.4),Enum.Material.Grass) foliage.Shape=Enum.PartType.Ball foliage.CFrame=CFrame.new(0,2.6,0)
  m.PrimaryPart=pot
  return m
end
local function makeCar()
  local m=Instance.new("Model") m.Name="Car"
  local color=Color3.fromHSV(math.random(),0.7,0.9)
  local body=newPart(m,"Body",color,Vector3.new(8,2,3.4),Enum.Material.SmoothPlastic) body.CFrame=CFrame.new(0,2,0)
  local cab=newPart(m,"Cab",color,Vector3.new(4,1.5,3.2),Enum.Material.Glass) cab.CFrame=CFrame.new(0,3.7,0)
  local tireFL=newPart(m,"TireFL",Color3.fromRGB(20,20,20),Vector3.new(1.6,1.6,0.8),Enum.Material.Rubber) tireFL.Shape=Enum.PartType.Cylinder tireFL.CFrame=CFrame.new( 2.4,0.8, 1.7)
  local tireFR=newPart(m,"TireFR",Color3.fromRGB(20,20,20),Vector3.new(1.6,1.6,0.8),Enum.Material.Rubber) tireFR.Shape=Enum.PartType.Cylinder tireFR.CFrame=CFrame.new( 2.4,0.8,-1.7)
  local tireBL=newPart(m,"TireBL",Color3.fromRGB(20,20,20),Vector3.new(1.6,1.6,0.8),Enum.Material.Rubber) tireBL.Shape=Enum.PartType.Cylinder tireBL.CFrame=CFrame.new(-2.4,0.8, 1.7)
  local tireBR=newPart(m,"TireBR",Color3.fromRGB(20,20,20),Vector3.new(1.6,1.6,0.8),Enum.Material.Rubber) tireBR.Shape=Enum.PartType.Cylinder tireBR.CFrame=CFrame.new(-2.4,0.8,-1.7)
  m.PrimaryPart=body
  return m
end

-- Distribution config: how many of each
local mix={
  {ctor=makeMailbox,count=30,minY=0},
  {ctor=makeTrashCan,count=40,minY=0},
  {ctor=makeTrafficLight,count=24,minY=0},
  {ctor=makeBench,count=30,minY=0},
  {ctor=makeHydrant,count=24,minY=0},
  {ctor=makeLamp,count=30,minY=0},
  {ctor=makePlant,count=40,minY=0},
  {ctor=makeCar,count=20,minY=0},
}

local total=0
for _,m in ipairs(mix) do
  for i=1,m.count do
    local x=megaCF.X + (math.random()-0.5)*megaSize.X*0.9
    local z=megaCF.Z + (math.random()-0.5)*megaSize.Z*0.9
    local rot=math.random(0,3)*90
    local model=m.ctor()
    place(model,x, 0, z, rot)
    total=total+1
  end
end

print(("[CityScale] Spawned %d street props"):format(total))
print("[Done] City scaled and props placed")
