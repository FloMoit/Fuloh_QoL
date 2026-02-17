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
    },
}

-- Faction-specific IDs
local faction = UnitFactionGroup("player")
local siegeID = (faction == "Horde") and 464256 or 445418
local motherID = (faction == "Horde") and 467555 or 467553

-- Dungeon teleport spell IDs (Hero's Path teleports)
-- Index built from MDungeonTeleports/data/DungeonPortals.lua and locales/enUS.lua
local DungeonTeleports = {
    -- The War Within
    ["Ara-Kara, City of Echoes"] = 445417,
    ["The Dawnbreaker"] = 445414,
    ["Path of the Eco-Dome"] = 1237215,
    ["Eco-Dome"] = 1237215,
    ["Halls of Atonement"] = 354465,
    ["Operation: Floodgate"] = 1216786,
    ["Priory of the Sacred Flame"] = 445444,
    ["Tazavesh, the Veiled Market"] = 367416,
    ["Cinderbrew Meadery"] = 445440,
    ["City of Threads"] = 445416,
    ["Darkflame Cleft"] = 445441,
    ["The Rookery"] = 445443,
    ["The Stonevault"] = 445269,

    -- Midnight (Season 1)
    ["Algethar Academy"] = 393273,
    ["Magisters' Terrace"] = 1254572,
    ["Maisara Caverns"] = 1254559,
    ["Nexus-Point Xenas"] = 1254563,
    ["Pit of Saron"] = 1254555,
    ["Seat of the Triumvirate"] = 1254551,
    ["Skyreach"] = 1254557,
    ["Windrunner Spire"] = 1254400,

    -- Dragonflight
    ["The Azure Vault"] = 393279,
    ["Brackenhide Hollow"] = 393267,
    ["Dawn of the Infinite"] = 424197,
    ["Halls of Infusion"] = 393283,
    ["Neltharus"] = 393276,
    ["The Nokud Offensive"] = 393262,
    ["Ruby Life Pools"] = 393256,
    ["Uldaman: Legacy of Tyr"] = 393222,

    -- Shadowlands
    ["De Other Side"] = 354468,
    ["Mists of Tirna Scithe"] = 354464,
    ["The Necrotic Wake"] = 354462,
    ["Plaguefall"] = 354463,
    ["Sanguine Depths"] = 354469,
    ["Spires of Ascension"] = 354466,
    ["Theatre of Pain"] = 354467,

    -- Battle for Azeroth
    ["Atal'Dazar"] = 424187,
    ["Freehold"] = 410071,
    ["Operation: Mechagon"] = 373274,
    ["The MOTHERLODE!!"] = motherID,
    ["Siege of Boralus"] = siegeID,
    ["The Underrot"] = 410074,
    ["Waycrest Manor"] = 424167,

    -- Legion
    ["Blackrook Hold"] = 424153,
    ["Court of Stars"] = 393766,
    ["Darkheart Thicket"] = 424163,
    ["Halls of Valor"] = 393764,
    ["Karazhan"] = 373262,
    ["Neltharion's Lair"] = 410078,

    -- Warlords of Draenor
    ["Auchindoun"] = 159897,
    ["Bloodmaul Slag Mines"] = 159895,
    ["The Everbloom"] = 159901,
    ["Grimrail Depot"] = 159900,
    ["Iron Docks"] = 159896,
    ["Shadowmoon Valley"] = 159899,
    ["Upper Blackrock Spire"] = 159902,

    -- Mists of Pandaria
    ["Gate of the Setting Sun"] = 131225,
    ["Mogu'shan Palace"] = 131222,
    ["Scholomance"] = 131232,
    ["Scarlet Halls"] = 131231,
    ["Scarlet Monastery"] = 131229,
    ["Niuzao Temple"] = 131228,
    ["Shado-pan Monastery"] = 131206,
    ["Stormstout Brewery"] = 131205,
    ["Temple of the Jade Serpent"] = 131204,

    -- Cataclysm
    ["Grim Batol"] = 445424,
    ["Throne of the Tides"] = 424142,
    ["The Vortex Pinnacle"] = 410080,
    
    -- Additional Aliases/Short Names
    ["Ara-Kara"] = 445417,
    ["Dawnbreaker"] = 445414,
    ["Stonevault"] = 445269,
    ["Rookery"] = 445443,
    ["Cinderbrew"] = 445440,
    ["Priory"] = 445444,
    ["Floodgate"] = 1216786,
    ["Mists"] = 354464,
    ["Necrotic"] = 354462,
    ["Spires"] = 354466,
    ["Theatre"] = 354467,
    ["Mechagon"] = 373274,
    ["Tazavesh"] = 367416,
    ["Vortex Pinnacle"] = 410080,
    ["Throne of Tides"] = 424142,
    ["Everbloom"] = 159901,
    ["Grimrail"] = 159900,
    ["Iron Docks"] = 159896,
    ["Shadowmoon"] = 159899,
    ["Upper Blackrock"] = 159902,

    -- French Localization (The War Within & Legacy)
    ["Ara-Kara, la cité des Échos"] = 445417,
    ["Cité des Fils"] = 445416,
    ["La Cavepierre"] = 445269,
    ["Le Brise-Aube"] = 445414,
    ["Prieuré de la Flamme sacrée"] = 445444,
    ["Hydromellerie de Brassecendre"] = 445440,
    ["Faille de Flamme-Noire"] = 445441,
    ["La Colonie"] = 445443,
    ["Écodôme"] = 1237215,
    ["Salles de l'Expiation"] = 354465,
    ["Opération : Écluses"] = 1216786,
    ["Opération Vannes ouvertes"] = 1216786, -- Alternative name check
    ["Tazavesh, le marché dissimulé"] = 367416,
    
    -- Midnight (S1) French (Speculative/Confirmed)
    ["Académie d'Algeth'ar"] = 393273,
    ["Terrasse des Magistères"] = 1254572,
    ["Fosse de Saron"] = 1254555,
    ["Siège du Triumvirat"] = 1254551,
    ["Orée-du-Ciel"] = 1254557,
    ["Flèche Coursevent"] = 1254400,

    -- Dragonflight French
    ["Le caveau d'Azur"] = 393279,
    ["Creux des Fougerobes"] = 393267,
    ["Aube de l'Infini"] = 424197,
    ["Salles de l'Imprégnation"] = 393283,
    ["L'offensive Nokhud"] = 393262,
    ["Bassins de l'Essence rubis"] = 393256,
    ["Uldaman : l'héritage de Tyr"] = 393222,

    -- Shadowlands French
    ["L'Autre Côté"] = 354468,
    ["Brumes de Tirna Scithe"] = 354464,
    ["Sillage nécrotique"] = 354462,
    ["Malepeste"] = 354463,
    ["Profondeurs Sanguines"] = 354469,
    ["Flèches de l'Ascension"] = 354466,
    ["Théâtre de la Souffrance"] = 354467,

    -- BfA French
    ["Port-Liberté"] = 410071,
    ["Opération Mécagone"] = 373274,
    ["Le Filon"] = motherID,
    ["Siège de Boralus"] = siegeID,
    ["Les Tréfonds Putrides"] = 410074,
    ["Manoir Malvoie"] = 424167,

    -- Legion French
    ["Bastion du Freux"] = 424153,
    ["Cour des Étoiles"] = 393766,
    ["Fourré Sombrecœur"] = 424163,
    ["Salles des Valeureux"] = 393764,
    ["Retour à Karazhan"] = 373262,
    ["Repaire de Neltharion"] = 410078,

    -- WoD French
    ["Mines de la Masse-Sanglante"] = 159895,
    ["La Flore éternelle"] = 159901,
    ["Dépôt de Tristerail"] = 159900,
    ["Quais de Fer"] = 159896,
    ["Terres sacrées d'Ombrelune"] = 159899,
    ["Sommet du Pic Rochenoire"] = 159902,

    -- MoP French
    ["Porte du Soleil couchant"] = 131225,
    ["Palais Mogu'shan"] = 131222,
    ["Salles Écarlates"] = 131231,
    ["Monastère Écarlate"] = 131229,
    ["Siège du temple de Niuzao"] = 131228,
    ["Monastère des Pandashan"] = 131206,
    ["Brasserie Brune d'Orage"] = 131205,
    ["Temple du Serpent de jade"] = 131204,

    -- Cataclysm French
    ["Trône des marées"] = 424142,
    ["La cime du Vortex"] = 410080,
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

-- Export to Fuloh_QoL.Features namespace
QoL.Features.JoinedGroupReminder_Constants = Constants
QoL.Features.JoinedGroupReminder_GetDungeonTeleportSpell = GetDungeonTeleportSpell
QoL.Features.JoinedGroupReminder_HasDungeonTeleport = HasDungeonTeleport
QoL.Features.JoinedGroupReminder_IsMythicPlusActivity = IsMythicPlusActivity
QoL.Features.JoinedGroupReminder_GetDungeonName = GetDungeonName
