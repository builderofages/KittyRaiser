-- roblox_mock.lua
-- A faked-just-enough Roblox API runtime for static execution of the codebase.
-- Loaded BEFORE any source modules; populates globals to match what Roblox provides.

-- Patch Lua 5.4 to behave more like Luau where the codebase relies on it.
table.find = table.find or function(t, value)
    for i, v in ipairs(t) do
        if v == value then return i end
    end
    return nil
end

table.clone = table.clone or function(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

string.split = string.split or function(s, sep)
    local result = {}
    local pattern = "([^" .. sep .. "]+)"
    for piece in s:gmatch(pattern) do table.insert(result, piece) end
    return result
end

-- typeof returns "Color3", "CFrame", "Vector3", "Instance", or the Lua type
function typeof(v)
    if type(v) == "table" and v.__type then return v.__type end
    return type(v)
end

-- Luau extensions to math
math.clamp = math.clamp or function(n, lo, hi)
    if n < lo then return lo elseif n > hi then return hi else return n end
end
math.round = math.round or function(n) return math.floor(n + 0.5) end
math.sign = math.sign or function(n) return (n > 0 and 1) or (n < 0 and -1) or 0 end

-- ============================================================================
-- Vector3 / CFrame / Color3 / Region3 / Enum stubs
-- ============================================================================

local Vector3 = {}
Vector3.__index = Vector3
Vector3.__type = "Vector3"
function Vector3.new(x, y, z)
    return setmetatable({X = x or 0, Y = y or 0, Z = z or 0, Magnitude = math.sqrt((x or 0)^2 + (y or 0)^2 + (z or 0)^2), Unit = nil, __type = "Vector3"}, Vector3)
end
Vector3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3.__mul = function(a, b)
    if type(b) == "number" then return Vector3.new(a.X*b, a.Y*b, a.Z*b) end
    return Vector3.new(a.X*b.X, a.Y*b.Y, a.Z*b.Z)
end
_G.Vector3 = Vector3

local CFrame = {}
CFrame.__index = CFrame
CFrame.__type = "CFrame"
function CFrame.new(x, y, z)
    if type(x) == "table" then  -- Vector3 form
        local v = x
        return setmetatable({Position = v, X = v.X, Y = v.Y, Z = v.Z, __type = "CFrame"}, CFrame)
    end
    local p = Vector3.new(x or 0, y or 0, z or 0)
    return setmetatable({Position = p, X = p.X, Y = p.Y, Z = p.Z, __type = "CFrame"}, CFrame)
end
function CFrame.Angles(rx, ry, rz) return CFrame.new(0, 0, 0) end
CFrame.__mul = function(a, b)
    if typeof(b) == "CFrame" then
        return CFrame.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
    end
    return CFrame.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
CFrame.__add = function(a, b) return CFrame.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
_G.CFrame = CFrame

local Color3 = {}
Color3.__index = Color3
Color3.__type = "Color3"
function Color3.new(r, g, b) return setmetatable({R = r or 0, G = g or 0, B = b or 0, __type = "Color3"}, Color3) end
function Color3.fromRGB(r, g, b) return Color3.new((r or 0)/255, (g or 0)/255, (b or 0)/255) end
_G.Color3 = Color3

local UDim = {}
UDim.__index = UDim
function UDim.new(scale, offset) return setmetatable({Scale = scale or 0, Offset = offset or 0}, UDim) end
_G.UDim = UDim

local UDim2 = {}
UDim2.__index = UDim2
UDim2.__type = "UDim2"
function UDim2.new(sx, ox, sy, oy)
    return setmetatable({
        X = UDim.new(sx, ox), Y = UDim.new(sy, oy),
        __type = "UDim2",
    }, UDim2)
end
function UDim2.fromScale(sx, sy) return UDim2.new(sx, 0, sy, 0) end
function UDim2.fromOffset(ox, oy) return UDim2.new(0, ox, 0, oy) end
_G.UDim2 = UDim2

local Vector2 = {}
function Vector2.new(x, y) return {X = x or 0, Y = y or 0} end
_G.Vector2 = Vector2

local NumberRange = {}
function NumberRange.new(a, b) return {Min = a, Max = b or a} end
_G.NumberRange = NumberRange

local NumberSequence = {}
function NumberSequence.new(...) return {keypoints = {...}} end
_G.NumberSequence = NumberSequence

local ColorSequence = {}
function ColorSequence.new(...) return {keypoints = {...}} end
_G.ColorSequence = ColorSequence

local ColorSequenceKeypoint = {}
function ColorSequenceKeypoint.new(t, c) return {Time = t, Value = c} end
_G.ColorSequenceKeypoint = ColorSequenceKeypoint

local TweenInfo = {}
function TweenInfo.new(...) return {args = {...}} end
_G.TweenInfo = TweenInfo

local Random = {}
Random.__index = Random
function Random.new(seed) return setmetatable({_seed = seed or 0}, Random) end
function Random:NextInteger(a, b) return math.random(a, b) end
function Random:NextNumber(a, b) return math.random() * ((b or 1) - (a or 0)) + (a or 0) end
_G.Random = Random

-- Enum: return any enum value as itself; equality is by identity
local Enum = setmetatable({}, {
    __index = function(t, name)
        local sub = setmetatable({}, {
            __index = function(_, key)
                return {EnumType = name, Name = key, Value = key}
            end
        })
        rawset(t, name, sub)
        return sub
    end,
})
_G.Enum = Enum

-- ============================================================================
-- Instance tree
-- ============================================================================

local Instance = {}
Instance.__type = "Instance"

local function makeInstance(className, name)
    local self = {
        ClassName = className,
        Name = name or className,
        Parent = nil,
        _children = {},
        _attributes = {},
        _connections = {},
        __type = "Instance",
        -- Sensible Part defaults so geometry math works under simulation.
        Position = Vector3.new(0, 0, 0),
        CFrame = CFrame.new(0, 0, 0),
        Size = Vector3.new(1, 1, 1),
        Color = Color3.new(0.5, 0.5, 0.5),
        Material = Enum.Material.Plastic,
        Transparency = 0,
        CanCollide = true,
        Anchored = false,
        Massless = false,
        AssemblyLinearVelocity = Vector3.new(0, 0, 0),
        AssemblyAngularVelocity = Vector3.new(0, 0, 0),
        Velocity = Vector3.new(0, 0, 0),
        TopSurface = Enum.SurfaceType.Smooth,
        BottomSurface = Enum.SurfaceType.Smooth,
        BrickColor = "Medium stone grey",
        Shape = "Block",
    }

    function self:GetChildren()
        local out = {}
        for _, c in ipairs(self._children) do table.insert(out, c) end
        return out
    end

    function self:GetDescendants()
        local out = {}
        local function walk(node)
            for _, c in ipairs(node._children or {}) do
                table.insert(out, c)
                walk(c)
            end
        end
        walk(self)
        return out
    end

    function self:FindFirstChild(name)
        for _, c in ipairs(self._children) do
            if c.Name == name then return c end
        end
        return nil
    end

    function self:FindFirstChildOfClass(className)
        for _, c in ipairs(self._children) do
            if c.ClassName == className then return c end
        end
        return nil
    end

    function self:WaitForChild(name, timeout)
        return self:FindFirstChild(name)  -- mock returns immediately
    end

    function self:IsA(className)
        return self.ClassName == className
            or (className == "BasePart" and (self.ClassName == "Part" or self.ClassName == "MeshPart"))
            or (className == "Instance" and true)
            or (className == "Model" and self.ClassName == "Model")
    end

    function self:IsDescendantOf(other)
        local p = self.Parent
        while p do
            if p == other then return true end
            p = p.Parent
        end
        return false
    end

    function self:Destroy()
        if self.Parent and self.Parent._children then
            for i, c in ipairs(self.Parent._children) do
                if c == self then table.remove(self.Parent._children, i); break end
            end
        end
        self.Parent = nil
    end

    function self:Clone()
        local c = makeInstance(self.ClassName, self.Name)
        for k, v in pairs(self._attributes) do c._attributes[k] = v end
        return c
    end

    function self:GetAttribute(k) return self._attributes[k] end
    function self:SetAttribute(k, v) self._attributes[k] = v end
    function self:GetAttributeChangedSignal(k)
        return {
            Connect = function(_, fn) return {Disconnect = function() end} end,
        }
    end

    function self:PivotTo(cf) end
    function self:GetPivot() return CFrame.new(0, 0, 0) end
    function self:ClearAllChildren()
        for i = #self._children, 1, -1 do
            self._children[i]:Destroy()
        end
    end

    -- mock signal events
    local function makeEvent()
        return {
            _handlers = {},
            Connect = function(s, fn)
                table.insert(s._handlers, fn)
                return {Disconnect = function() end}
            end,
            Once = function(s, fn) table.insert(s._handlers, fn); return {Disconnect = function() end} end,
            Fire = function(s, ...) for _, h in ipairs(s._handlers) do pcall(h, ...) end end,
        }
    end

    self.ChildAdded = makeEvent()
    self.DescendantAdded = makeEvent()
    self.AncestryChanged = makeEvent()
    self.Changed = makeEvent()
    self.Touched = makeEvent()
    -- Remote-specific
    self.OnServerEvent = makeEvent()
    self.OnClientEvent = makeEvent()
    -- For RemoteFunction
    function self.FireClient(_, ...) end
    function self.FireAllClients(_, ...) end
    function self.FireServer(_, ...) end
    function self.InvokeServer(_, ...) end
    function self.InvokeClient(_, ...) end

    -- Metatable: __newindex registers children when Parent is set;
    -- __index resolves child names like Roblox does (parent.ChildName), but
    -- ONLY as a fallback after rawget — otherwise members assigned via
    -- rawset (e.g., OnServerInvoke handler functions) would be invisible.
    local mt = {
        __index = function(t, k)
            local rv = rawget(t, k)
            if rv ~= nil then return rv end
            -- Fall back to child lookup
            local children = rawget(t, "_children")
            if children then
                for _, c in ipairs(children) do
                    if c.Name == k then return c end
                end
            end
            return nil
        end,
        __newindex = function(t, k, v)
            rawset(t, k, v)
            if k == "Parent" and v ~= nil then
                if v._children then table.insert(v._children, t) end
                if v.ChildAdded then v.ChildAdded:Fire(t) end
                local cur = v
                while cur do
                    if cur.DescendantAdded then cur.DescendantAdded:Fire(t) end
                    cur = cur.Parent
                end
            end
        end,
    }
    return setmetatable(self, mt)
end

Instance.new = function(className, parent)
    local i = makeInstance(className, className)
    if parent then i.Parent = parent end
    return i
end
_G.Instance = Instance

-- ============================================================================
-- game / services
-- ============================================================================

local services = {}
local game = {
    JobId = "",
    PlaceId = 0,
    _services = services,
}

function game:GetService(name)
    if not services[name] then
        services[name] = makeInstance(name, name)
    end
    return services[name]
end

function game:BindToClose(fn) end

-- Pre-create services that scripts pull at top level
for _, svc in ipairs({
    "Players", "Workspace", "ReplicatedStorage", "ServerScriptService", "ServerStorage",
    "StarterGui", "StarterPlayer", "Lighting", "RunService", "TweenService", "Debris",
    "MarketplaceService", "DataStoreService", "InsertService", "HttpService",
    "AnalyticsService", "GuiService", "SoundService", "UserInputService",
}) do
    services[svc] = makeInstance(svc, svc)
end

-- Players sub-API
services.Players.GetPlayers = function() return services.Players._children end
services.Players.GetPlayerByUserId = function(_, id) return nil end
services.Players.GetPlayerFromCharacter = function(_, char) return nil end
services.Players.PlayerAdded = makeInstance("PlayerAddedEvent", "PlayerAdded")
services.Players.PlayerAdded.Connect = function(_, fn) return {Disconnect = function() end} end
services.Players.PlayerRemoving = makeInstance("PlayerRemovingEvent", "PlayerRemoving")
services.Players.PlayerRemoving.Connect = function(_, fn) return {Disconnect = function() end} end
services.Players.CharacterAutoLoads = true

-- Workspace
services.Workspace.CurrentCamera = makeInstance("Camera", "Camera")
services.Workspace.CurrentCamera.CFrame = CFrame.new(0, 5, 0)
services.Workspace.CurrentCamera.FieldOfView = 70
services.Workspace.Gravity = 196.2

-- DataStoreService
services.DataStoreService.GetDataStore = function(_, name)
    local store = makeInstance("DataStore", "DataStore_" .. name)
    local data = {}
    store.GetAsync = function(_, key) return data[key] end
    store.SetAsync = function(_, key, value) data[key] = value end
    store.UpdateAsync = function(_, key, fn)
        local newValue = fn(data[key])
        if newValue ~= nil then data[key] = newValue end
        return data[key]
    end
    return store
end

-- MarketplaceService
services.MarketplaceService.UserOwnsGamePassAsync = function(_, userId, id) return false end
services.MarketplaceService.PromptProductPurchase = function(_, p, id) end
services.MarketplaceService.PromptGamePassPurchase = function(_, p, id) end
services.MarketplaceService.PromptGamePassPurchaseFinished = makeInstance("Event", "PromptGamePassPurchaseFinished")
services.MarketplaceService.PromptGamePassPurchaseFinished.Connect = function(_, fn) return {Disconnect = function()end} end

-- InsertService
services.InsertService.LoadAsset = function(_, id)
    return makeInstance("Model", "MockAsset_" .. tostring(id))
end

-- HttpService
services.HttpService.GenerateGUID = function(_, withBraces) return "MOCKGUID-" .. tostring(math.random(1, 1e6)) end
services.HttpService.JSONEncode = function(_, t) return tostring(t) end

-- RunService
services.RunService.IsStudio = function(_) return true end
services.RunService.IsServer = function(_) return true end
services.RunService.IsClient = function(_) return false end
services.RunService.Heartbeat = makeInstance("Event", "Heartbeat")
services.RunService.Heartbeat.Connect = function(_, fn) return {Disconnect = function() end} end
services.RunService.RenderStepped = makeInstance("Event", "RenderStepped")
services.RunService.RenderStepped.Connect = function(_, fn) return {Disconnect = function() end} end
services.RunService.Stepped = makeInstance("Event", "Stepped")
services.RunService.Stepped.Connect = function(_, fn) return {Disconnect = function() end} end

-- TweenService
services.TweenService.Create = function(_, target, info, props)
    return {
        Play = function() end,
        Cancel = function() end,
        Pause = function() end,
        Completed = {Connect = function(_, fn) return {Disconnect = function() end} end,
                     Once = function(_, fn) return {Disconnect = function() end} end},
    }
end

-- Debris
services.Debris.AddItem = function(_, obj, t) end

-- AnalyticsService
services.AnalyticsService.LogProgressionEvent = function() end
services.AnalyticsService.LogEconomyEvent = function() end

-- GuiService
services.GuiService.GetGuiInset = function() return Vector2.new(0, 36), Vector2.new(0, 36) end

-- ReplicatedStorage tree (script will materialize Modules + RemoteEventsFolder)
local rs = services.ReplicatedStorage

-- task: deliberately do NOT execute spawned coroutines. Most server scripts
-- launch `task.spawn(function() while true do task.wait(N) ... end end)`
-- main loops; running them in a no-yield env spins forever. We only need
-- the *init* path of each script to run.
_G.task = {
    spawn = function(fn, ...) end,
    delay = function(t, fn, ...) end,
    wait = function(t) return t or 0 end,
    defer = function(fn, ...) end,
}
_G.wait = function(t) return t or 0 end
_G.warn = print
_G.workspace = services.Workspace
_G.script = makeInstance("Script", "Script")  -- some scripts reference `script`

_G.game = game
return game
