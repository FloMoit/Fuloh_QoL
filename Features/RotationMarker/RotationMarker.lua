-- RotationMarker.lua
-- Rotate world markers at cursor position

local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

local RotationMarker = {}

-- Create the buttons and setup bindings
function RotationMarker.Initialize()
    -- Set up global bindings names for localization in the Key Bindings menu
    _G.BINDING_HEADER_FULOH_QOL_HEADER = "Fuloh's QoL"
    _G.BINDING_NAME_FULOH_QOL_ROTATION_MARKER_CYCLE = "Cycle World Marker (@Cursor)"
    _G.BINDING_NAME_FULOH_QOL_ROTATION_MARKER_CLEAR = "Clear All World Markers"
    
    if GetLocale() == "frFR" then
        _G.BINDING_NAME_FULOH_QOL_ROTATION_MARKER_CYCLE = "Faire défiler les marqueurs de monde (@Curseur)"
        _G.BINDING_NAME_FULOH_QOL_ROTATION_MARKER_CLEAR = "Effacer tous les marqueurs de monde"
    end

    -- 1. Create the Clear Button
    local clearBtn = CreateFrame("Button", "FulohQoL_RotationMarker_ClearBtn", UIParent, "SecureActionButtonTemplate")
    clearBtn:SetAttribute("type", "macro")
    clearBtn:SetAttribute("macrotext", "/cwm all")

    -- 2. Create the Cycle Manager Button
    -- Inherits SecureHandlerClickTemplate for the secure _onclick snippet 
    -- and SecureActionButtonTemplate so the game knows it's a secure button
    local cycleBtn = CreateFrame("Button", "FulohQoL_RotationMarker_CycleBtn", UIParent, "SecureHandlerClickTemplate, SecureActionButtonTemplate")
    
    -- Create the 8 sub-buttons for each marker (1 to 8)
    for i = 1, 8 do
        local btn = CreateFrame("Button", "FulohQoL_RotationMarker_Btn"..i, UIParent, "SecureActionButtonTemplate")
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", "/wm [@cursor] " .. i)
        
        -- Securely link the child button to the manager button
        SecureHandlerSetFrameRef(cycleBtn, "Btn"..i, btn)
    end
    
    -- Initialize the state variable inside the restricted environment
    cycleBtn:Execute("currentMarker = 1")
    
    -- When the cycleBtn is clicked (via keybind), run this secure snippet to click the next marker button
    cycleBtn:SetAttribute("_onclick", [[
        local targetBtn = self:GetFrameRef("Btn" .. currentMarker)
        currentMarker = currentMarker + 1
        if currentMarker > 8 then
            currentMarker = 1
        end
        return targetBtn
    ]])
end

-- Export module
QoL.Features.RotationMarker = RotationMarker

-- Auto-initialize when file loads
RotationMarker.Initialize()
