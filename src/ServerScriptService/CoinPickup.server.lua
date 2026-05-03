-- CoinPickup.server.lua
-- Coins spawned by RagdollOnPrank get a Touched handler that grants the
-- toucher a small chaos bonus + plays a pickup sound. Auto-attached via
-- DescendantAdded on Workspace, scoped to coin-shaped parts.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("RemoteEvents"))
local AssetIds = require(ReplicatedStorage.Modules.AssetIds)
local SharedUtil = require(ReplicatedStorage.Modules.SharedUtil)

local DataHandler = SharedUtil.waitForGlobal("KittyRaiserData", 30)
if not DataHandler then return end

local COIN_VALUE = 5

local function isCoin(part)
    return part:IsA("BasePart")
        and part.Color == Color3.fromRGB(255, 215, 0)
        and part.Material == Enum.Material.Neon
        and not part:GetAttribute("Collected")
        and part.Name == "Part"
        and part.Shape == Enum.PartType.Cylinder
end

local function attach(part)
    if not isCoin(part) then return end
    local conn
    conn = part.Touched:Connect(function(hit)
        local model = hit and hit.Parent
        if not model then return end
        local player = Players:GetPlayerFromCharacter(model)
        if not player then return end
        if part:GetAttribute("Collected") then return end
        part:SetAttribute("Collected", true)
        if conn then conn:Disconnect() end
        DataHandler.modify(player, function(d)
            d.chaosPoints = (d.chaosPoints or 0) + COIN_VALUE
        end)
        -- Spawn a small pickup sound at the part's location
        if AssetIds.coin_pickup then
            local s = Instance.new("Sound")
            s.SoundId = AssetIds.coin_pickup
            s.Volume = 0.5
            s.Parent = part
            s:Play()
        end
        part:Destroy()
    end)
end

Workspace.DescendantAdded:Connect(attach)
for _, p in ipairs(Workspace:GetDescendants()) do attach(p) end

print("[CoinPickup] online — coins worth " .. COIN_VALUE .. " chaos each")
