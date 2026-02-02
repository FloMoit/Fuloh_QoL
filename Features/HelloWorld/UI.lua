-- UI.lua
-- HelloWorld minimap button creation and interaction

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

-- Create UI table
local UI = {}

local minimapButton = nil

-- Database accessor
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.HelloWorld or {}
end

-- Update the button's visual state based on enabled status
local function UpdateButtonVisual()
    if not minimapButton then return end

    local icon = minimapButton.icon
    if not icon then return end

    local db = GetDB()
    if db.enabled then
        icon:SetDesaturated(false)
        minimapButton:SetAlpha(1.0)
    else
        icon:SetDesaturated(true)
        minimapButton:SetAlpha(0.7)
    end
end

-- Update button position based on angle
local function UpdateButtonPosition()
    if not minimapButton then return end

    local db = GetDB()
    local angle = math.rad(db.minimapPos or 45)
    local radius = 80

    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius

    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Handle button click - toggle enabled state
local function OnClick(self, button)
    if button == "LeftButton" then
        -- Toggle feature via Fuloh_QoL
        QoL:ToggleFeature("HelloWorld")
        UpdateButtonVisual()

    elseif button == "RightButton" then
        if QoL.Features.HelloWorld_OpenSettings then
            QoL.Features.HelloWorld_OpenSettings()
        else
            print("|cff00ff00HelloWorld|r: /fuloh hello settings to open settings.")
        end
    end
end

-- Handle button dragging
local function OnDragStart(self)
    self:SetScript("OnUpdate", function(self)
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()

        px, py = px / scale, py / scale

        local angle = math.atan2(py - my, px - mx)
        local degrees = math.deg(angle)

        local db = GetDB()
        db.minimapPos = degrees
        UpdateButtonPosition()
    end)
    GameTooltip:Hide()
end

local function OnDragStop(self)
    self:SetScript("OnUpdate", nil)
end

-- Show tooltip on hover
local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("HelloWorld", 1, 1, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffFFFFFFLeft-Click:|r Toggle auto-greeting", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cffFFFFFFRight-Click:|r Open settings", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cffFFFFFFDrag:|r Move button", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(" ")

    local db = GetDB()
    local status = db.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"
    GameTooltip:AddLine("Status: " .. status, 1, 1, 1)

    GameTooltip:Show()
end

local function OnLeave(self)
    GameTooltip:Hide()
end

-- Create the minimap button
function UI.CreateMinimapButton()
    if minimapButton then return end

    minimapButton = CreateFrame("Button", "Fuloh_QoL_HelloWorld_MinimapButton", Minimap)
    minimapButton:SetSize(31, 31)
    minimapButton:SetFrameStrata("MEDIUM")
    minimapButton:SetFrameLevel(10)

    -- Background Texture
    local background = minimapButton:CreateTexture(nil, "BACKGROUND")
    background:SetSize(21, 21)
    background:SetPoint("CENTER", 0, 0)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    -- Icon
    local icon = minimapButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 0)
    icon:SetTexture("Interface\\AddOns\\Fuloh_QoL\\Features\\HelloWorld\\icon.png")

    -- Circular mask
    local mask = minimapButton:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetSize(20, 20)
    mask:SetPoint("CENTER", 0, 0)
    icon:AddMaskTexture(mask)

    minimapButton.icon = icon

    -- Border / Tracking Circle
    local border = minimapButton:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT", -1, 1)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- Highlight Texture
    minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    -- Interactivity
    minimapButton:SetMovable(true)
    minimapButton:EnableMouse(true)
    minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapButton:RegisterForDrag("LeftButton")

    -- Event handlers
    minimapButton:SetScript("OnClick", OnClick)
    minimapButton:SetScript("OnDragStart", OnDragStart)
    minimapButton:SetScript("OnDragStop", OnDragStop)
    minimapButton:SetScript("OnEnter", OnEnter)
    minimapButton:SetScript("OnLeave", OnLeave)

    -- Position and state
    UpdateButtonPosition()
    UpdateButtonVisual()
end

-- Public updates
function UI.UpdateVisual()
    UpdateButtonVisual()
end

function UI.Show()
    if minimapButton then
        minimapButton:Show()
    end
end

function UI.Hide()
    if minimapButton then
        minimapButton:Hide()
    end
end

-- Export to Fuloh_QoL.Features namespace
QoL.Features.HelloWorld_UI = UI
QoL.Features.HelloWorld_UI_UpdateVisual = UI.UpdateVisual
