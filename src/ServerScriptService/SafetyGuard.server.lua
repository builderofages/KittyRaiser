-- SafetyGuard.server.lua
-- If DataHandler / AntiCheat fail to come up within 30 seconds, we refuse new
-- joiners with a clear message instead of installing silent stubs that pretend
-- the game is working while progress is ephemeral.
-- Place in: ServerScriptService > SafetyGuard. Auto-runs.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local READY_TIMEOUT = 30
local boot = os.clock()

local function bootedOk()
    return _G.KittyRaiserData ~= nil and _G.KittyRaiserAntiCheat ~= nil
end

task.spawn(function()
    while os.clock() - boot < READY_TIMEOUT do
        if bootedOk() then
            print("[SafetyGuard] core systems online")
            return
        end
        task.wait(0.5)
    end

    warn("[SafetyGuard] CORE SYSTEMS DID NOT INITIALIZE within "
        .. READY_TIMEOUT .. "s. Kicking active players and refusing new joiners "
        .. "to prevent data corruption. Check DataHandler / AntiCheat init logs.")

    -- Kick anyone currently online so they don't lose progress.
    for _, p in ipairs(Players:GetPlayers()) do
        pcall(function()
            p:Kick("KittyRaiser is starting up. Please rejoin in a moment.")
        end)
    end
    -- Refuse new joiners until a manual server restart.
    Players.PlayerAdded:Connect(function(p)
        pcall(function()
            p:Kick("KittyRaiser is undergoing maintenance. Please try a different server.")
        end)
    end)
end)

print("[SafetyGuard] watching for DataHandler / AntiCheat globals "
    .. (RunService:IsStudio() and "(Studio mode)" or "(Production)"))
