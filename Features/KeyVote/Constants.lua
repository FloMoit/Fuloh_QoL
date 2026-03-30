-- Constants.lua
-- KeyVote constants: protocol opcodes, UI config, localization

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

local locale = GetLocale()

local Constants = {
    -- Addon message prefix (shared across all features using comms)
    ADDON_PREFIX = "FulohQoL",

    -- Protocol opcodes
    OPCODE_START  = "KVSTART",
    OPCODE_KEY    = "KVKEY",
    OPCODE_VOTE   = "KVVOTE",
    OPCODE_CANCEL = "KVCANCEL",

    -- Timers (seconds)
    VOTE_DURATION    = 30,
    RESULTS_DURATION = 15,

    -- UI: Voting Popup
    VOTE_UI = {
        WIDTH  = 400,
        HEIGHT = 350,
        ROW_HEIGHT = 28,
        ICON_SIZE  = 22,

        BACKGROUND_COLOR = { 0.08, 0.08, 0.12, 0.95 },
        BORDER_COLOR     = { 0.9, 0.7, 0.2, 0.8 },

        TITLE_COLOR    = { 1.0, 0.82, 0.0 },
        SUBTITLE_COLOR = { 0.6, 0.6, 0.6 },
        OWNER_COLOR    = { 0.5, 0.5, 0.5 },
        NOKEY_COLOR    = { 0.4, 0.4, 0.4 },
        TIMER_COLOR    = { 0.9, 0.7, 0.2, 0.9 },

        FADE_DURATION = 0.2,
    },

    -- UI: Results Overlay
    RESULTS_UI = {
        WIDTH  = 450,
        HEIGHT = 220,

        ICON_SIZE_NORMAL = 40,
        ICON_SIZE_WINNER = 64,

        WINNER_COLOR   = { 1.0, 0.82, 0.0 },
        NORMAL_COLOR   = { 0.8, 0.8, 0.8 },
        VOTE_COUNT_COLOR = { 0.6, 0.6, 0.6 },

        FADE_DURATION = 0.3,
    },

    -- Localized strings
    L = {
        ["Key Vote"]         = (locale == "frFR") and "Vote de Clé" or "Key Vote",
        ["Started by"]       = (locale == "frFR") and "Lancé par" or "Started by",
        ["Vote"]             = (locale == "frFR") and "Voter" or "Vote",
        ["Waiting"]          = (locale == "frFR") and "En attente..." or "Waiting for others...",
        ["No key"]           = (locale == "frFR") and "Pas de clé" or "No key",
        ["Vote Results"]     = (locale == "frFR") and "Résultats du vote" or "Vote Results",
        ["Winner"]           = (locale == "frFR") and "GAGNANT" or "WINNER",
        ["vote"]             = (locale == "frFR") and "vote" or "vote",
        ["votes"]            = (locale == "frFR") and "votes" or "votes",
        ["Close"]            = (locale == "frFR") and "Fermer" or "Close",
        ["Click to teleport"] = (locale == "frFR") and "Cliquer pour se téléporter" or "Click to teleport",
        ["remaining"]        = (locale == "frFR") and "restantes" or "remaining",
        ["Already active"]   = (locale == "frFR") and "Un vote est déjà en cours." or "A vote is already in progress.",
        ["Not in group"]     = (locale == "frFR") and "Vous devez être dans un groupe." or "You must be in a group.",
        ["Vote cancelled"]   = (locale == "frFR") and "Vote annulé." or "Vote cancelled.",
        ["No active vote"]   = (locale == "frFR") and "Aucun vote en cours." or "No active vote.",
        ["wins"]             = (locale == "frFR") and "gagne !" or "wins!",
        ["Tie"]              = (locale == "frFR") and "Égalité" or "Tie",
    },
}

--------------------------------------------------------------------------------
-- Dungeon Info Resolution (with fallbacks)
--------------------------------------------------------------------------------

-- Resolve a challenge mode mapID to (name, texture).
-- Tries C_ChallengeMode.GetMapUIInfo first, then falls back to the
-- JoinedGroupReminder teleport spell icon for the texture.
-- If map info is not yet cached, requests it for future calls.
local function ResolveDungeonInfo(mapID)
    if not mapID or mapID == 0 then return nil, nil end

    -- Primary: C_ChallengeMode API
    local name, _, _, texture = C_ChallengeMode.GetMapUIInfo(mapID)

    -- If GetMapUIInfo returned nothing, request a cache refresh for next time
    if not name and C_MythicPlus and C_MythicPlus.RequestMapInfo then
        C_MythicPlus.RequestMapInfo()
    end

    -- Fallback for texture: use teleport spell icon from JoinedGroupReminder
    if not texture then
        local getSpell = QoL.Features.JoinedGroupReminder_GetDungeonTeleportSpellByMapID
        if getSpell then
            local spellID = getSpell(mapID)
            if spellID then
                local spellTexture = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
                if not spellTexture and GetSpellTexture then
                    spellTexture = GetSpellTexture(spellID)
                end
                texture = spellTexture
            end
        end
    end

    return name, texture
end

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

QoL.Features.KeyVote_Constants = Constants
QoL.Features.KeyVote_ResolveDungeonInfo = ResolveDungeonInfo
