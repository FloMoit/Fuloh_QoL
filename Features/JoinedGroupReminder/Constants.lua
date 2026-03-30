-- Constants.lua
-- JoinedGroupReminder constants, dungeon teleport mappings, and utility functions

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

-- Create constants table
local Constants = {
    -- LFG Category IDs
    CATEGORY_ID_DUNGEON = 2,

    -- Group types that indicate M+
    GROUP_TYPE_MYTHIC_PLUS = 1,

    -- UI Configuration
    UI = {
        WIDTH = 450,
        HEIGHT = 78,
        Y_OFFSET = -100,

        ICON_SIZE = 48,
        CLOSE_BUTTON_SIZE = 30,

        -- Colors (RGBA)
        BACKGROUND_COLOR = { 0.08, 0.08, 0.12, 0.92 },
        BORDER_COLOR = { 0.3, 0.3, 0.4, 0.6 },
        BORDER_HIGHLIGHT_COLOR = { 0.5, 0.4, 0.9, 1.0 },

        DUNGEON_TEXT_COLOR = { 1.0, 0.82, 0.0 },  -- Gold
        GROUP_TEXT_COLOR = { 0.6, 0.6, 0.6 },      -- Dimmed gray

        CLOSE_BUTTON_COLOR = { 0.5, 0.5, 0.5 },
        CLOSE_BUTTON_HOVER = { 1.0, 0.3, 0.3 },

        -- Animation
        FADE_DURATION = 0.2,
    },

    -- Fonts
    FONTS = {
        DUNGEON = "GameFontNormalHuge",
        GROUP = "GameFontNormalLarge",
    },

    -- Localized strings
    L = {
        ["Click to teleport"] = (GetLocale() == "frFR") and "Cliquer pour se téléporter" or "Click to teleport",
        ["Unknown Dungeon"] = (GetLocale() == "frFR") and "Donjon inconnu" or "Unknown Dungeon",
        ["Close"] = (GetLocale() == "frFR") and "Fermer" or "Close",
        ["LFG Group"] = (GetLocale() == "frFR") and "Groupe recherche" or "LFG Group",
        ["Joined group"] = (GetLocale() == "frFR") and "Groupe rejoint" or "Joined group",
        ["Group updated"] = (GetLocale() == "frFR") and "Groupe mis à jour" or "Group updated",
    },
}

-- Faction-specific spell IDs
local faction = UnitFactionGroup("player")
local siegeID = (faction == "Horde") and 464256 or 445418
local motherID = (faction == "Horde") and 467555 or 467553

--------------------------------------------------------------------------------
-- Dungeon Teleport Spell IDs (map challenge mode ID -> spell ID)
-- Sourced from BigWigs/Tools/Keystones.lua and cross-referenced with existing data
--------------------------------------------------------------------------------

local TeleportsByMapID = {
    -- Midnight
    [2805] = 1254400,  -- Windrunner Spire
    [2811] = 1254572,  -- Magisters' Terrace
    [2874] = 1254559,  -- Maisara Caverns
    [2915] = 1254563,  -- Nexus-Point Xenas

    -- The War Within
    [2648] = 445443,   -- The Rookery
    [2649] = 445444,   -- Priory of the Sacred Flame
    [2651] = 445441,   -- Darkflame Cleft
    [2652] = 445269,   -- The Stonevault
    [2660] = 445417,   -- Ara-Kara, City of Echoes
    [2661] = 445440,   -- Cinderbrew Meadery
    [2662] = 445414,   -- The Dawnbreaker
    [2669] = 445416,   -- City of Threads
    [2773] = 1216786,  -- Operation: Floodgate
    [2830] = 1237215,  -- Eco-Dome Al'dani

    -- Dragonflight
    [2451] = 393222,   -- Uldaman: Legacy of Tyr
    [2515] = 393279,   -- The Azure Vault
    [2516] = 393262,   -- The Nokhud Offensive
    [2519] = 393276,   -- Neltharus
    [2520] = 393267,   -- Brackenhide Hollow
    [2521] = 393256,   -- Ruby Life Pools
    [2526] = 393273,   -- Algeth'ar Academy
    [2527] = 393283,   -- Halls of Infusion
    [2579] = 424197,   -- Dawn of the Infinite

    -- Shadowlands
    [2284] = 354469,   -- Sanguine Depths
    [2285] = 354466,   -- Spires of Ascension
    [2286] = 354462,   -- The Necrotic Wake
    [2287] = 354465,   -- Halls of Atonement
    [2289] = 354463,   -- Plaguefall
    [2290] = 354464,   -- Mists of Tirna Scithe
    [2291] = 354468,   -- De Other Side
    [2293] = 354467,   -- Theater of Pain
    [2441] = 367416,   -- Tazavesh, the Veiled Market

    -- Battle for Azeroth
    [1763] = 424187,   -- Atal'Dazar
    [1754] = 410071,   -- Freehold
    [1822] = siegeID,   -- Siege of Boralus (faction-specific)
    [1594] = motherID,  -- The MOTHERLODE!! (faction-specific)
    [1841] = 410074,   -- The Underrot
    [1862] = 424167,   -- Waycrest Manor
    [2097] = 373274,   -- Operation: Mechagon

    -- Legion
    [1571] = 393766,   -- Court of Stars
    [1651] = 373262,   -- Return to Karazhan
    [1501] = 424153,   -- Black Rook Hold
    [1466] = 424163,   -- Darkheart Thicket
    [1458] = 410078,   -- Neltharion's Lair
    [1477] = 393764,   -- Halls of Valor
    [1753] = 1254551,  -- Seat of the Triumvirate

    -- Warlords of Draenor
    [1209] = 159898,   -- Skyreach
    [1176] = 159899,   -- Shadowmoon Burial Grounds
    [1208] = 159900,   -- Grimrail Depot
    [1279] = 159901,   -- The Everbloom
    [1195] = 159896,   -- Iron Docks
    [1182] = 159897,   -- Auchindoun
    [1175] = 159895,   -- Bloodmaul Slag Mines
    [1358] = 159902,   -- Upper Blackrock Spire

    -- Mists of Pandaria
    [959]  = 131206,   -- Shado-Pan Monastery
    [960]  = 131204,   -- Temple of the Jade Serpent
    [961]  = 131205,   -- Stormstout Brewery
    [962]  = 131225,   -- Gate of the Setting Sun
    [994]  = 131222,   -- Mogu'shan Palace
    [1001] = 131231,   -- Scarlet Halls
    [1007] = 131232,   -- Scholomance
    [1011] = 131228,   -- Siege of Niuzao Temple
    [1004] = 131229,   -- Scarlet Monastery

    -- Cataclysm
    [643]  = 424142,   -- Throne of the Tides
    [657]  = 410080,   -- The Vortex Pinnacle
    [670]  = 445424,   -- Grim Batol

    -- Wrath of the Lich King
    [658]  = 1254555,  -- Pit of Saron
}

-- Auto-built name -> spellID table (populated by BuildNameLookup)
local TeleportsByName = {}

-- Build localized name lookup from map IDs using the game API
local function BuildNameLookup()
    TeleportsByName = {}
    for mapID, spellID in pairs(TeleportsByMapID) do
        local name = C_ChallengeMode.GetMapUIInfo(mapID)
        if name then
            TeleportsByName[name] = spellID
        end
    end
end

--------------------------------------------------------------------------------
-- Teleport Lookup Functions
--------------------------------------------------------------------------------

-- Find teleport spell by dungeon map ID (preferred)
local function GetDungeonTeleportSpellByMapID(mapID)
    return mapID and TeleportsByMapID[mapID] or nil
end

-- Find teleport spell by dungeon name (auto-built from game API)
local function GetDungeonTeleportSpell(dungeonName)
    if not dungeonName then return nil end

    -- Exact match (localized names built from game API)
    if TeleportsByName[dungeonName] then
        return TeleportsByName[dungeonName]
    end

    -- Partial match (handles prefixed names like "Mythic Keystone: ...")
    for name, spellID in pairs(TeleportsByName) do
        if dungeonName:find(name, 1, true) then
            return spellID
        end
    end

    return nil
end

-- Check if player knows a teleport spell (shows button even on cooldown)
local function HasDungeonTeleport(spellID)
    if not spellID then return false end
    if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellID) then
        return true
    end
    if C_Spell.IsSpellKnownOrOverridesKnown and C_Spell.IsSpellKnownOrOverridesKnown(spellID) then
        return true
    end
    -- Fallback to usable check
    local isUsable = C_Spell.IsSpellUsable(spellID)
    return isUsable or false
end

--------------------------------------------------------------------------------
-- LFG Helper Functions
--------------------------------------------------------------------------------

-- Helper function to check if an activity is M+
local function IsMythicPlusActivity(activityID)
    if not activityID then return false end

    local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
    if not activityInfo then return false end

    if activityInfo.categoryID == Constants.CATEGORY_ID_DUNGEON then
        if activityInfo.isMythicPlusActivity then
            return true
        end

        if activityInfo.isMythicActivity then
            return true
        end

        if activityInfo.useMythicPlusRules then
            return true
        end

        -- Fallback: check name
        if activityInfo.fullName then
            if activityInfo.fullName:find("Mythic") or activityInfo.fullName:find("Keystone") or
               activityInfo.fullName:find("Mythique") or activityInfo.fullName:find("Clé") then
                return true
            end
        end

        if activityInfo.shortName then
            if activityInfo.shortName:find("Mythic") or activityInfo.shortName:find("Keystone") or
               activityInfo.shortName:find("Mythique") or activityInfo.shortName:find("Clé") then
                return true
            end
        end
    end

    return false
end

-- Get dungeon name from activity ID
local function GetDungeonName(activityID)
    if not activityID then return Constants.L["Unknown Dungeon"] end

    local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
    if activityInfo and activityInfo.fullName then
        local name = activityInfo.fullName
        -- Strip English prefix
        name = name:gsub("^Mythic Keystone:%s*", "")
        -- Strip French prefix
        name = name:gsub("^Clé mythique :%s*", "")
        return name
    end

    return Constants.L["Unknown Dungeon"]
end

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

QoL.Features.JoinedGroupReminder_Constants = Constants
QoL.Features.JoinedGroupReminder_GetDungeonTeleportSpell = GetDungeonTeleportSpell
QoL.Features.JoinedGroupReminder_GetDungeonTeleportSpellByMapID = GetDungeonTeleportSpellByMapID
QoL.Features.JoinedGroupReminder_HasDungeonTeleport = HasDungeonTeleport
QoL.Features.JoinedGroupReminder_IsMythicPlusActivity = IsMythicPlusActivity
QoL.Features.JoinedGroupReminder_GetDungeonName = GetDungeonName
QoL.Features.JoinedGroupReminder_BuildNameLookup = BuildNameLookup
