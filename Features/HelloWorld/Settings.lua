-- Settings.lua
-- HelloWorld settings for greeting customization (Embedded in main hub)

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

local Settings = {}

-- Database accessor
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.HelloWorld or {}
end

-- Create the embedded UI elements
function Settings.CreateEmbeddedSettings(parent, yOffset)
    -- Indent slightly to show relation to the checkbox
    local xOffset = 40
    
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetText("Greeting Messages (one per line):")
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
    local scrollFrame = CreateFrame("ScrollFrame", "FulohQoL_HelloWorld_Scroll", bg, "UIPanelScrollFrameTemplate")
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
    local Utils = QoL.Features.HelloWorld_Utils
    local list = (db.greetings and #db.greetings > 0)
                 and db.greetings
                 or (Utils and Utils.DefaultGreetings or {})
    local text = table.concat(list, "\n")
    editBox:SetText(text)

    -- Function to save data
    local function SaveGreetings()
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
        db.greetings = cleaned
    end

    -- Save on focus lost
    editBox:SetScript("OnEditFocusLost", SaveGreetings)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Make bg clickable
    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    -- Return the new yOffset (height of the controls we added)
    return yOffset - 90
end

-- Legacy support (keep definitions but don't auto-initialize standalone panel)
function Settings.Initialize()
    -- No longer creates a standalone panel
end

function Settings.OpenSettings()
    -- Redirect to main hub if possible
    if _G.Settings and _G.Settings.OpenToCategory then
        _G.Settings.OpenToCategory("Fuloh's QoL")
    end
end

-- Export to Fuloh_QoL.Features namespace
QoL.Features.HelloWorld_Settings = Settings
QoL.Features.HelloWorld_OpenSettings = Settings.OpenSettings
