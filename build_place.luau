-- build_place.luau
-- Walks src/ and emits build/KittyRaiser.rbxl — a real Roblox place file
-- containing every source script in its proper service/folder, ready to
-- double-click open in Studio. No more pasting loader chunks.
--
-- Usage: lune run build_place.luau

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local SRC = "src"
local OUT_DIR = "build"
local OUT_PATH = OUT_DIR .. "/KittyRaiser.rbxl"

if not fs.isDir(OUT_DIR) then fs.writeDir(OUT_DIR) end

-- Build the DataModel
local game = roblox.Instance.new("DataModel")

local function service(className)
    local s = game:FindFirstChildOfClass(className)
    if not s then
        s = roblox.Instance.new(className)
        s.Name = className
        s.Parent = game
    end
    return s
end

-- Top-level services we populate
local rs = service("ReplicatedStorage")
local sss = service("ServerScriptService")
local sg = service("StarterGui")
local sp = service("StarterPlayer")
local ws = service("Workspace")
local lighting = service("Lighting")

-- StarterPlayer needs StarterPlayerScripts/StarterCharacterScripts children
local function ensureChild(parent, className, name)
    local c = parent:FindFirstChild(name)
    if not c then
        c = roblox.Instance.new(className)
        c.Name = name
        c.Parent = parent
    end
    return c
end
local sps = ensureChild(sp, "StarterPlayerScripts", "StarterPlayerScripts")

-- Build Modules folder under ReplicatedStorage
local modulesFolder = ensureChild(rs, "Folder", "Modules")

-- Classify a file path → (Instance className, target parent, leaf name)
local function classify(relPath)
    local parts = {}
    for piece in relPath:gmatch("[^/]+") do table.insert(parts, piece) end
    local fileName = parts[#parts]

    local kind, name
    if fileName:sub(-#".server.lua") == ".server.lua" then
        kind = "Script"
        name = fileName:sub(1, -#".server.lua" - 1)
    elseif fileName:sub(-#".client.lua") == ".client.lua" then
        kind = "LocalScript"
        name = fileName:sub(1, -#".client.lua" - 1)
    else
        kind = "ModuleScript"
        name = fileName:sub(1, -#".lua" - 1)
    end

    -- Decide parent based on top-level dir
    local top = parts[1]
    local parent
    if top == "ReplicatedStorage" then
        parent = modulesFolder  -- all module scripts live under Modules
    elseif top == "ServerScriptService" then
        parent = sss
    elseif top == "StarterGui" then
        parent = sg
    elseif top == "StarterPlayer" then
        parent = sps  -- skip StarterPlayerScripts subdir, all client scripts go here
    else
        error("unknown top-level dir: " .. tostring(top))
    end
    return kind, parent, name
end

-- Walk src/
local function walk(dir, out)
    out = out or {}
    for _, name in ipairs(fs.readDir(dir)) do
        local path = dir .. "/" .. name
        if fs.isDir(path) then
            walk(path, out)
        elseif name:match("%.lua$") then
            table.insert(out, path)
        end
    end
    return out
end

local files = walk(SRC)
table.sort(files)

local installed = 0
for _, abs in ipairs(files) do
    local rel = abs:sub(#SRC + 2)  -- strip "src/"
    local kind, parent, name = classify(rel)
    local source = fs.readFile(abs)

    -- If a script with this Name already exists at this parent, replace it
    local existing = parent:FindFirstChild(name)
    if existing then existing:Destroy() end

    local s = roblox.Instance.new(kind)
    s.Name = name
    s.Source = source
    s.Parent = parent
    installed = installed + 1
end

-- Lighting defaults are set by StrayLighting.server.lua at runtime; we only
-- need the service to exist so scripts find it via game:GetService.
print(("[build_place] %d scripts placed in DataModel"):format(installed))

-- Serialize to bytes, write to file.
local bytes = roblox.serializePlace(game)
fs.writeFile(OUT_PATH, bytes)
print(("[build_place] wrote %s (%.1f KB)"):format(OUT_PATH, #bytes / 1024))
print("[build_place] open this file in Roblox Studio (File → Open from File…)")
