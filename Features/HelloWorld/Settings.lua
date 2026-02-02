-- Settings.lua
-- HelloWorld settings panel for greeting customization

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

local Settings = {}

local panel = nil
local initialized = false

-- Database accessor
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.HelloWorld or {}
end

-- Helper to create a heading
local function CreateHeading(text, parent)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetText(text)
    return header
end

-- Create the UI elements
function Settings.Initialize()
    if initialized then return end

    panel = CreateFrame("Frame", "Fuloh_QoL_HelloWorld_SettingsPanel", UIParent)
    panel.name = "HelloWorld Greetings"
    panel.parent = "Fuloh's QoL"  -- Make it a sub-panel

    local title = CreateHeading("HelloWorld Greetings", panel)
    title:SetPoint("TOPLEFT", 16, -16)

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetText("Configure your auto-greeting messages. Enter one message per line.")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetJustifyH("LEFT")

    -- Multi-line EditBox with ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    scrollFrame:SetPoint("BOTTOMRIGHT", -32, 40)

    -- Background for the edit area
    local bg = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    bg:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = true, tileSize = 16, edgeSize = 1,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    bg:SetBackdropColor(0, 0, 0, 0.8)
    bg:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.5)
    bg:SetPoint("TOPLEFT", scrollFrame, -5, 5)
    bg:SetPoint("BOTTOMRIGHT", scrollFrame, 25, -5)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(2000)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("GameFontHighlight")
    editBox:SetWidth(scrollFrame:GetWidth() > 0 and scrollFrame:GetWidth() or 500)
    scrollFrame:SetScrollChild(editBox)

    -- Make the entire background clickable to focus the editbox
    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    -- Update width when scroll frame is shown or resized
    scrollFrame:SetScript("OnSizeChanged", function(self, width)
        editBox:SetWidth(width)
    end)

    -- Load data into EditBox when shown
    panel:SetScript("OnShow", function()
        local db = GetDB()
        local Utils = QoL.Features.HelloWorld_Utils

        local list = (db.greetings and #db.greetings > 0)
                     and db.greetings
                     or (Utils and Utils.DefaultGreetings or {})

        local text = table.concat(list, "\n")
        editBox:SetText(text)
        editBox:SetCursorPosition(0)
    end)

    -- Save button
    local saveBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    saveBtn:SetText("Save Greetings")
    saveBtn:SetSize(120, 25)
    saveBtn:SetPoint("BOTTOMLEFT", 16, 10)
    saveBtn:SetScript("OnClick", function()
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
        print("|cff00ff00[HelloWorld]|r: Greetings updated.")
        editBox:ClearFocus()
    end)

    -- Focus handling
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Modern Settings Registration
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "HelloWorld Greetings")
        category.ID = "HelloWorld Greetings"
        Settings.RegisterAddOnCategory(category)
    else
        -- Fallback for older versions
        InterfaceOptions_AddCategory(panel)
    end

    initialized = true
end

-- Function to open the settings panel
function Settings.OpenSettings()
    if not initialized then
        Settings.Initialize()
    end

    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory("HelloWorld Greetings")
    else
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

-- Export to Fuloh_QoL.Features namespace
QoL.Features.HelloWorld_Settings = Settings
QoL.Features.HelloWorld_OpenSettings = Settings.OpenSettings
