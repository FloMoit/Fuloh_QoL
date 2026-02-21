-- Utils.lua
-- GGGuys pure functions and constants

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

local Utils = {}

Utils.DefaultGGs = {
    "GG :)",
    "Nice run!",
    "Well played!",
    "Good job everyone!",
    "GGs",
}

if GetLocale() == "frFR" then
    Utils.DefaultGGs = {
        "GG :)",
        "Bien joué tous !",
        "Propre !",
        "Merci pour la clé !",
    }
end

-- Export to Fuloh_QoL.Features namespace
QoL.Features.GGGuys_Utils = Utils
