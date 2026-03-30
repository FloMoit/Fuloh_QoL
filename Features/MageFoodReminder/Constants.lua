-- Constants.lua
-- MageFoodReminder: hardcoded values and localization

local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

local locale = GetLocale()

local Constants = {}

-- Item
Constants.MAGE_FOOD_ITEM_ID = 113509
Constants.MAGE_FOOD_ICON_ID = 134029
Constants.LOW_THRESHOLD     = 20

-- Difficulty IDs (set-keyed for O(1) lookup)
Constants.MYTHIC_DIFFICULTY_IDS = {
    [8]  = true,   -- Mythic Keystone (M+)
    [23] = true,   -- Regular Mythic
}

-- Frame sizing
Constants.FRAME_WIDTH    = 260
Constants.FRAME_HEIGHT   = 80
Constants.ICON_SIZE      = 36
Constants.ACCENT_WIDTH   = 4

-- Background colors
Constants.NORMAL_BG = { 0.08, 0.08, 0.12, 0.95 }
Constants.ALERT_BG  = { 0.35, 0.05, 0.05, 0.95 }

-- Accent bar colors
Constants.NORMAL_ACCENT = { 0.9, 0.7, 0.2, 1.0 }
Constants.ALERT_ACCENT  = { 0.9, 0.2, 0.2, 1.0 }

-- Body text colors
Constants.NORMAL_BODY_COLOR = { 0.9, 0.7, 0.2 }   -- gold
Constants.ALERT_BODY_COLOR  = { 1.0, 0.4, 0.4 }   -- red

-- Localized strings
Constants.L = {
    title = (locale == "frFR")
        and "Nourriture de mage"
        or  "Mage Food",
    normal_body = (locale == "frFR")
        and "%d restante(s)"
        or  "%d remaining",
    alert_body = (locale == "frFR")
        and "Vous n'avez pas de nourriture de mage !"
        or  "You have no Mage Food!",
    dismiss = (locale == "frFR")
        and "(Cliquez pour fermer)"
        or  "(Click to dismiss)",
}

QoL.Features.MageFoodReminder_Constants = Constants
