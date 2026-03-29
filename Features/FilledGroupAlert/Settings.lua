-- Settings.lua
-- FilledGroupAlert settings for sound selection (Embedded in main hub)

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

local Settings = {}

-- Import constants
local Constants = QoL.Features.FilledGroupAlert_Constants
local SOUND_OPTIONS = Constants.SOUND_OPTIONS
local L = Constants.L

-- Database accessor
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.FilledGroupAlert or {}
end

-- Create the embedded UI elements
function Settings.CreateEmbeddedSettings(parent, yOffset)
    local xOffset = 40

    -- Label
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetText(L["Sound Label"])
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset - 5)

    yOffset = yOffset - 25

    -- Sound dropdown
    local dropdown = CreateFrame("Frame", "FulohQoL_FilledGroupAlert_SoundDropdown", parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset - 16, yOffset)
    UIDropDownMenu_SetWidth(dropdown, 200)

    -- Initialize dropdown items
    UIDropDownMenu_Initialize(dropdown, function(self, level, menuList)
        local db = GetDB()
        local currentID = db.selectedSound or Constants.DEFAULT_SOUND_ID

        for _, sound in ipairs(SOUND_OPTIONS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = Constants.GetLocalizedSoundName(sound)
            info.value = sound.id
            info.func = function()
                local db = GetDB()
                db.selectedSound = sound.id
                UIDropDownMenu_SetSelectedValue(dropdown, sound.id)
                UIDropDownMenu_SetText(dropdown, Constants.GetLocalizedSoundName(sound))
            end
            info.checked = (currentID == sound.id)
            UIDropDownMenu_AddButton(info)
        end
    end)

    -- Set initial selection text
    local db = GetDB()
    local selectedID = db.selectedSound or Constants.DEFAULT_SOUND_ID
    local selectedEntry = Constants.GetSoundEntryByID(selectedID)
    UIDropDownMenu_SetSelectedValue(dropdown, selectedID)
    UIDropDownMenu_SetText(dropdown, Constants.GetLocalizedSoundName(selectedEntry))

    -- Preview button (right of dropdown)
    local previewBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    previewBtn:SetSize(80, 22)
    previewBtn:SetPoint("LEFT", dropdown, "RIGHT", 0, 2)
    previewBtn:SetText(L["Preview"])
    previewBtn:SetScript("OnClick", function()
        local db = GetDB()
        local soundID = db.selectedSound or Constants.DEFAULT_SOUND_ID
        PlaySound(soundID, "Master")
    end)

    return yOffset - 50
end

-- Export to Fuloh_QoL.Features namespace
QoL.Features.FilledGroupAlert_Settings = Settings
