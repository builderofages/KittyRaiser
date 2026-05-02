-- DiagnosticDump.server.lua
-- Auto-runs on play. Dumps full system status to Output every 5 seconds for first 30 sec.
-- So you can see what's actually working vs broken in-game.
-- Place in: ServerScriptService > DiagnosticDump (Script). Auto-runs.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local START = os.clock()

local function dump()
  print("\n=== KITTYRAISER DIAGNOSTIC @ t=" .. string.format("%.1f", os.clock() - START) .. "s ===")
  print("\nWORKSPACE CHILDREN:")
  for _, c in ipairs(Workspace:GetChildren()) do
    local count = #c:GetChildren()
    print(("  [%s] %s (%d children)"):format(c.ClassName, c.Name, count))
  end

  print("\nPLAYERS:")
  for _, p in ipairs(Players:GetPlayers()) do
    local char = p.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char.PrimaryPart
    print(("  %s | char=%s | hum=%s | pos=%s | health=%s/%s"):format(
      p.Name,
      tostring(char ~= nil),
      tostring(hum ~= nil),
      hrp and tostring(hrp.Position) or "nil",
      hum and tostring(hum.Health) or "?",
      hum and tostring(hum.MaxHealth) or "?"
    ))
  end
  print("  CharacterAutoLoads = " .. tostring(Players.CharacterAutoLoads))

  print("\nKEY FOLDERS:")
  for _, name in ipairs({"CyberpunkCity", "KittyCity", "AmbientCrowd", "PrankNPCs", "PrankParticlePool", "Plaza"}) do
    local f = Workspace:FindFirstChild(name)
    print(("  %s = %s (%d items)"):format(name, tostring(f ~= nil), f and #f:GetChildren() or 0))
  end

  print("\nKITTYGROUND:")
  local g = Workspace:FindFirstChild("KittyGround")
  if g then
    print("  exists, size=" .. tostring(g.Size) .. " pos=" .. tostring(g.Position))
  else
    print("  MISSING — players will fall into void")
  end

  print("\nSPAWN:")
  local sp = Workspace:FindFirstChild("MainSpawn") or Workspace:FindFirstChildOfClass("SpawnLocation")
  if sp then
    print(("  %s at %s"):format(sp.Name, tostring(sp.CFrame.Position)))
  else
    print("  MISSING — players spawn at default 0,0,0")
  end

  print("\nREPLICATEDSTORAGE.MODULES:")
  local m = ReplicatedStorage:FindFirstChild("Modules")
  if m then
    for _, c in ipairs(m:GetChildren()) do
      print("  - " .. c.Name)
    end
  end

  print("\nSERVERSTORAGE.CATTEMPLATES:")
  local ct = ServerStorage:FindFirstChild("CatTemplates")
  if ct then
    for _, c in ipairs(ct:GetChildren()) do
      print("  - " .. c.Name .. " (children: " .. #c:GetChildren() .. ")")
    end
    if #ct:GetChildren() == 0 then
      print("  EMPTY — Toolbox cat rig didn't load via InsertService")
    end
  else
    print("  MISSING")
  end

  print("\nLIGHTING:")
  print("  Tech=" .. tostring(Lighting.Technology) .. " Brightness=" .. Lighting.Brightness .. " ClockTime=" .. Lighting.ClockTime)
  for _, fx in ipairs(Lighting:GetChildren()) do
    print("  fx: " .. fx.ClassName .. " " .. fx.Name)
  end

  print("\nGLOBALS:")
  print("  _G.KittyRaiserData = " .. tostring(_G.KittyRaiserData ~= nil))
  print("  _G.KittyRaiserAntiCheat = " .. tostring(_G.KittyRaiserAntiCheat ~= nil))
  print("  _G.KittyRaiserSummon = " .. tostring(_G.KittyRaiserSummon ~= nil))
  print("  _G.KittyRaiserMeshes = " .. tostring(_G.KittyRaiserMeshes ~= nil) .. (_G.KittyRaiserMeshes and " (" .. (function() local n=0; for _ in pairs(_G.KittyRaiserMeshes) do n=n+1 end; return n end)() .. " meshes)" or ""))

  print("=== END DIAGNOSTIC ===\n")
end

-- Dump immediately and every 5 seconds for first 30 sec
task.spawn(function()
  task.wait(2)  -- give other systems time to init
  for i = 1, 6 do
    dump()
    task.wait(5)
  end
end)
