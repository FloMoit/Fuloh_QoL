-- Settings.lua
-- GGGuys settings for customization (Embedded in main hub)

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

local Settings = {}

-- Database accessor
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.GGGuys or {}
end

-- Create the embedded UI elements
function Settings.CreateEmbeddedSettings(parent, yOffset)
    -- Indent slightly to show relation to the checkbox
    local xOffset = 40
    
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    local labelText = "Congratulation Messages (one per line):"
    if GetLocale() == "frFR" then
        labelText = "Messages de félicitations (un par ligne) :"
    end
    label:SetText(labelText)
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset - 5)
    
    yOffset = yOffset - 25

    -- Background for the edit area
    local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bg:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    bg:SetBackdropColor(0, 0, 0, 0.4)
    bg:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.3)
    bg:SetSize(300, 80) -- Height for ~5 lines
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)

    -- ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "FulohQoL_GGGuys_Scroll", bg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)

    -- EditBox
    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(2000)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetWidth(270)
    scrollFrame:SetScrollChild(editBox)

    -- Load data
    local db = GetDB()
    local Utils = QoL.Features.GGGuys_Utils
    local list = (db.messages ~= nil)
                 and db.messages
                 or (Utils and Utils.DefaultGGs or {})
    local text = table.concat(list, "\n")
    editBox:SetText(text)

    -- Function to save data
    local function SaveMessages()
        local text = editBox:GetText()
        local lines = {strsplit("\n", text)}
        local cleaned = {}
        for _, line in ipairs(lines) do
            line = strtrim(line)
            if line ~= "" then
                table.insert(cleaned, line)
            end
        end
        local db = GetDB()
        db.messages = cleaned
    end

    -- Save on focus lost
    editBox:SetScript("OnEditFocusLost", SaveMessages)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Make bg clickable
    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    -- Return the new yOffset (height of the controls we added)
    return yOffset - 90
end

-- Export to Fuloh_QoL.Features namespace
QoL.Features.GGGuys_Settings = Settings
