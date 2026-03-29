-- Constants.lua
-- FilledGroupAlert constants, sound options, and localization

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

local Constants = {}

-- LFG category ID for dungeons (not raids)
Constants.CATEGORY_ID_DUNGEON = 2

-- Full dungeon group size
Constants.DUNGEON_GROUP_SIZE = 5

--------------------------------------------------------------------------------
-- Sound Options
--------------------------------------------------------------------------------

-- Curated list of recognizable WoW SoundKit IDs.
-- PlaySound() silently no-ops on invalid IDs, so no crash risk.
Constants.SOUND_OPTIONS = {
    { id = 12867,  name = "Alarm Clock Warning", nameFR = "Alarme" },
    { id = 8960,   name = "Ready Check",        nameFR = "Appel de disponibilite" },
    { id = 8959,   name = "Raid Warning",        nameFR = "Avertissement de raid" },
    { id = 3332,   name = "Auction House Open",  nameFR = "Hotel des ventes" },
    { id = 170566, name = "Mythic+ Start",       nameFR = "Debut Mythique+" },
}

Constants.DEFAULT_SOUND_ID = Constants.SOUND_OPTIONS[1].id

--------------------------------------------------------------------------------
-- Localization
--------------------------------------------------------------------------------

local locale = GetLocale()

Constants.L = {
    ["Sound Label"] = (locale == "frFR") and "Son d'alerte :" or "Alert Sound:",
    ["Preview"]     = (locale == "frFR") and "Apercu" or "Preview",
}

-- Return the localized name for a sound option entry
function Constants.GetLocalizedSoundName(soundEntry)
    if locale == "frFR" and soundEntry.nameFR then
        return soundEntry.nameFR
    end
    return soundEntry.name
end

-- Find a sound entry by SoundKit ID
function Constants.GetSoundEntryByID(soundID)
    for _, entry in ipairs(Constants.SOUND_OPTIONS) do
        if entry.id == soundID then
            return entry
        end
    end
    return Constants.SOUND_OPTIONS[1]
end

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

QoL.Features.FilledGroupAlert_Constants = Constants
