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
        WIDTH = 300,
        HEIGHT = 52,
        Y_OFFSET = -100,

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
        DUNGEON = "GameFontNormalLarge",
        GROUP = "GameFontNormal",
    },
}

-- Dungeon teleport spell IDs (Hero's Path teleports)
local DungeonTeleports = {
    -- The War Within
    ["City of Threads"] = 445416,
    ["Dawnbreaker"] = 445414,
    ["Stonevault"] = 445269,
    ["Rookery"] = 445443,
    ["Cinderbrew"] = 445440,
    ["Priory of the Sacred Flame"] = 445444,
    ["Ara-Kara"] = 445417,
    ["Darkflame Cleft"] = 445441,
    ["Operation: Floodgate"] = 1216786,
    ["Floodgate"] = 1216786,

    -- Dragonflight
    ["Ruby Life Pools"] = 393256,
    ["Nokhud Offensive"] = 393262,
    ["Brackenhide"] = 393267,
    ["Algeth'ar Academy"] = 393273,
    ["Neltharus"] = 393276,
    ["Azure Vault"] = 393279,
    ["Halls of Infusion"] = 393283,
    ["Uldaman"] = 393222,
    ["Dawn of the Infinite"] = 424197,

    -- Shadowlands
    ["Necrotic Wake"] = 354462,
    ["Plaguefall"] = 354463,
    ["Mists of Tirna Scithe"] = 354464,
    ["Tirna Scithe"] = 354464,
    ["Halls of Atonement"] = 354465,
    ["Spires of Ascension"] = 354466,
    ["Theater of Pain"] = 354467,
    ["De Other Side"] = 354468,
    ["Sanguine Depths"] = 354469,
    ["Tazavesh"] = 367416,

    -- Battle for Azeroth
    ["Freehold"] = 410071,
    ["Underrot"] = 410074,
    ["Mechagon"] = 373274,
    ["Waycrest Manor"] = 424167,
    ["Atal'Dazar"] = 424187,
    ["Siege of Boralus"] = 445418,
    ["MOTHERLODE"] = 467553,

    -- Legion
    ["Halls of Valor"] = 393764,
    ["Neltharion's Lair"] = 410078,
    ["Court of Stars"] = 393766,
    ["Karazhan"] = 373262,
    ["Black Rook Hold"] = 424153,
    ["Darkheart Thicket"] = 424163,

    -- Warlords of Draenor
    ["Everbloom"] = 159901,
    ["Shadowmoon Burial"] = 159899,
    ["Grimrail Depot"] = 159900,
    ["Iron Docks"] = 159896,
    ["Bloodmaul Slag"] = 159895,
    ["Auchindoun"] = 159897,
    ["Skyreach"] = 159898,
    ["Upper Blackrock"] = 159902,

    -- Mists of Pandaria
    ["Temple of the Jade Serpent"] = 131204,
    ["Jade Serpent"] = 131204,
    ["Stormstout Brewery"] = 131205,
    ["Shado-Pan Monastery"] = 131206,
    ["Mogu'shan Palace"] = 131222,
    ["Gate of the Setting Sun"] = 131225,
    ["Siege of Niuzao"] = 131228,
    ["Scarlet Monastery"] = 131229,
    ["Scarlet Halls"] = 131231,
    ["Scholomance"] = 131232,

    -- Cataclysm
    ["Vortex Pinnacle"] = 410080,
    ["Throne of the Tides"] = 424142,
    ["Grim Batol"] = 445424,
}

-- Find teleport spell for a dungeon name
local function GetDungeonTeleportSpell(dungeonName)
    if not dungeonName then return nil end

    -- Try exact match first
    if DungeonTeleports[dungeonName] then
        return DungeonTeleports[dungeonName]
    end

    -- Try partial match
    for pattern, spellID in pairs(DungeonTeleports) do
        if dungeonName:find(pattern, 1, true) then
            return spellID
        end
    end

    return nil
end

-- Check if player has a teleport spell
local function HasDungeonTeleport(spellID)
    if not spellID then return false end
    local isUsable = C_Spell.IsSpellUsable(spellID)
    return isUsable or false
end

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
            if activityInfo.fullName:find("Mythic") or activityInfo.fullName:find("Keystone") then
                return true
            end
        end

        if activityInfo.shortName then
            if activityInfo.shortName:find("Mythic") or activityInfo.shortName:find("Keystone") then
                return true
            end
        end
    end

    return false
end

-- Get dungeon name from activity ID
local function GetDungeonName(activityID)
    if not activityID then return "Unknown Dungeon" end

    local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
    if activityInfo and activityInfo.fullName then
        local name = activityInfo.fullName:gsub("^Mythic Keystone:%s*", "")
        return name
    end

    return "Unknown Dungeon"
end

-- Export to Fuloh_QoL.Features namespace
QoL.Features.JoinedGroupReminder_Constants = Constants
QoL.Features.JoinedGroupReminder_GetDungeonTeleportSpell = GetDungeonTeleportSpell
QoL.Features.JoinedGroupReminder_HasDungeonTeleport = HasDungeonTeleport
QoL.Features.JoinedGroupReminder_IsMythicPlusActivity = IsMythicPlusActivity
QoL.Features.JoinedGroupReminder_GetDungeonName = GetDungeonName
