-- CodeConfig.lua
-- Promotional codes redeemable by players. ADD new codes here.
-- Each code can have an expiry timestamp (0 = never), max global uses (0 = unlimited),
-- and a reward payload that the server applies on redemption.

local CodeConfig = {}

CodeConfig.Codes = {
    LAUNCH      = {chaos = 5000,  hellTokens = 0,  expiry = 0, max = 0,
                   message = "Welcome to KittyRaiser! +5,000 Chaos"},
    PURRFECT    = {chaos = 10000, hellTokens = 5,  expiry = 0, max = 0,
                   message = "+10K Chaos and 5 Hell Tokens"},
    KITTY100K   = {chaos = 0,     hellTokens = 25, expiry = 0, max = 0,
                   message = "100K visit milestone — 25 Hell Tokens"},
    MEOWMEOW    = {chaos = 2500,  hellTokens = 0,  expiry = 0, max = 0,
                   message = "+2,500 Chaos"},
    ANVIL       = {chaos = 7500,  hellTokens = 1,  expiry = 0, max = 0,
                   message = "Anvil drop! +7,500 Chaos +1 Hell Token"},
}

function CodeConfig.normalize(code)
    if type(code) ~= "string" then return nil end
    return code:upper():gsub("%s+", "")
end

function CodeConfig.get(code)
    local k = CodeConfig.normalize(code)
    if not k then return nil end
    return CodeConfig.Codes[k], k
end

return CodeConfig
