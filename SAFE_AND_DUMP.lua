-- SAFE_AND_DUMP — paste in Studio Command Bar, Cmd+Enter
-- Fixes spawn-instakill AND prints all uploaded asset IDs in AssetIds.lua format
(function()
  local W = game:GetService("Workspace")
  local Players = game:GetService("Players")

  -- ground first
  local g = W:FindFirstChild("KittyGround")
  if not g then
    g = Instance.new("Part", W)
    g.Name = "KittyGround"; g.Anchored = true; g.CanCollide = true
    g.Size = Vector3.new(4000, 4, 4000); g.Position = Vector3.new(0, -2, 0)
    g.Material = Enum.Material.Concrete; g.Color = Color3.fromRGB(48,48,54); g.TopSurface = Enum.SurfaceType.Smooth
  end

  -- safe spawn
  for _, sp in ipairs(W:GetDescendants()) do if sp:IsA("SpawnLocation") then sp:Destroy() end end
  local s = Instance.new("SpawnLocation", W)
  s.Name = "MainSpawn"; s.Anchored = true; s.CanCollide = true
  s.Size = Vector3.new(8,1,8); s.CFrame = CFrame.new(0, 5, 24)
  s.Material = Enum.Material.SmoothPlastic; s.Transparency = 1; s.TopSurface = Enum.SurfaceType.Smooth

  -- heal-on-spawn so SurvivalSystem can't insta-kill
  local function heal(c)
    if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid")
    if h then h.Health = h.MaxHealth; h.WalkSpeed = 16 end
  end
  Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function(c) task.wait(0.1); heal(c) end) end)
  for _, p in ipairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(function(c) task.wait(0.1); heal(c) end)
    if p.Character then heal(p.Character) end
  end

  -- now dump asset IDs from Asset Manager
  print("===KITTYRAISER_ASSET_DUMP_START===")
  local ams_ok, AMS = pcall(function() return game:GetService("AssetManagerService") end)
  if not ams_ok then print("no AMS service"); return end

  -- Method A: try GetAliases (deprecated but may still work)
  local ok_aliases, aliases = pcall(function() return AMS:GetAliases() end)
  if ok_aliases and type(aliases) == "table" then
    for _, alias in ipairs(aliases) do
      print("ALIAS:" .. tostring(alias))
    end
  end

  -- Method B: GetImage / GetAudio / GetMesh per known asset name
  local function tryByMethod(method, name)
    local ok, id = pcall(function() return AMS[method](AMS, name) end)
    if ok and id and id ~= 0 then return tostring(id) end
    return nil
  end

  local ICONS = {"coin","gem","robux","paw","scratch","pie","fish","slushie","tp","anvil","skull","wings","shop","bag","bars","gift","slot","star","trophy"}
  local TEXTURES = {"asphalt","brick","concrete","fur_orange","grass","neon_sign","skyscraper_windows"}
  local SOUNDS = {"anvil_clang","cat_scratch","coin_pickup","fish_slap","flight_whoosh","ko_sound","level_up","meow_1","meow_2","meow_3","pie_splat","purrgatory","slushie_freeze","spawn_chime","tp_unroll"}
  local MESHES = {"anvil","brownstone","cat_body","cat_ear","cat_head","cat_leg","cat_tail_segment","hydrant","mailbox","pie","skyscraper","taxi","trashcan"}

  for _, n in ipairs(ICONS) do
    local id = tryByMethod("GetImage", n) or tryByMethod("GetImageAssetIdByAlias", n)
    if id then print(("ICON: %s = rbxassetid://%s"):format(n, id)) end
  end
  for _, n in ipairs(TEXTURES) do
    local id = tryByMethod("GetImage", n) or tryByMethod("GetImageAssetIdByAlias", n)
    if id then print(("TEXTURE: %s = rbxassetid://%s"):format(n, id)) end
  end
  for _, n in ipairs(SOUNDS) do
    local id = tryByMethod("GetAudio", n) or tryByMethod("GetAudioAssetIdByAlias", n)
    if id then print(("SOUND: %s = rbxassetid://%s"):format(n, id)) end
  end
  for _, n in ipairs(MESHES) do
    local id = tryByMethod("GetMesh", n) or tryByMethod("GetMeshAssetIdByAlias", n)
    if id then print(("MESH: %s = rbxassetid://%s"):format(n, id)) end
  end

  print("===KITTYRAISER_ASSET_DUMP_END===")
  print("[SAFE_AND_DUMP] done")
end)()
