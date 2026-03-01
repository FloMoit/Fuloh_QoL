-- RotationMarker.lua
-- Rotate world markers at cursor position

local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

-- Create feature object
local RotationMarker = {
    name = "RotationMarker",
    label = "Rotation Marker (@Cursor)",
    shortcut = "rmarker",
    isEnabled = false,
}

if GetLocale() == "frFR" then
    RotationMarker.label = "Marqueur de Rotation (@Curseur)"
end

-- Initialize the protected interface buttons
function RotationMarker:Initialize()
    -- Set up global bindings names for localization in the Key Bindings menu
    _G.BINDING_HEADER_FULOH_QOL_HEADER = "Fuloh's QoL"
    _G["BINDING_NAME_CLICK FulohQoL_RotationMarker_CycleBtn:LeftButton"] = "Cycle World Marker (@Cursor)"
    _G["BINDING_NAME_CLICK FulohQoL_RotationMarker_ClearBtn:LeftButton"] = "Clear All World Markers"
    
    if GetLocale() == "frFR" then
        _G["BINDING_NAME_CLICK FulohQoL_RotationMarker_CycleBtn:LeftButton"] = "Faire défiler les marqueurs de monde (@Curseur)"
        _G["BINDING_NAME_CLICK FulohQoL_RotationMarker_ClearBtn:LeftButton"] = "Effacer tous les marqueurs de monde"
    end

    -- 1. Create the Clear Button
    local clearBtn = CreateFrame("Button", "FulohQoL_RotationMarker_ClearBtn", UIParent, "SecureActionButtonTemplate")
    clearBtn:RegisterForClicks("AnyDown")
    clearBtn:SetAttribute("type", "macro")
    clearBtn:SetAttribute("macrotext", "/cwm all")

    -- 2. Create the Cycle Manager Button
    -- Inherits SecureHandlerClickTemplate for the secure _onclick snippet
    local cycleBtn = CreateFrame("Button", "FulohQoL_RotationMarker_CycleBtn", UIParent, "SecureHandlerClickTemplate")
    cycleBtn:RegisterForClicks("AnyDown")
    
    -- Create the 8 sub-buttons for each marker (1 to 8)
    for i = 1, 8 do
        local btn = CreateFrame("Button", "FulohQoL_RotationMarker_Btn"..i, UIParent, "SecureActionButtonTemplate")
        btn:RegisterForClicks("AnyDown")
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

function RotationMarker:Enable()
    self.isEnabled = true
end

function RotationMarker:Disable()
    self.isEnabled = false
end

function RotationMarker:GetDefaults()
    return { enabled = true }
end

function RotationMarker:HandleCommand(args)
    local cmd = args:lower():match("^(%S+)") or args:lower()

    if cmd == "toggle" then
        QoL:ToggleFeature("RotationMarker")
    elseif cmd == "help" then
        print("|cff00ff00[RotationMarker]|r Commands:")
        print("  /fuloh rmarker toggle - Toggle feature on/off")
        print("  /fuloh rmarker help - Show this help message")
    else
        print("|cff00ff00[RotationMarker]|r: Unknown command. Type /fuloh rmarker help for commands.")
    end
end

-- Inject into the Settings Panel
function RotationMarker:OnSettingsUI(parent, yOffset)
    local xOffset = 40
    
    local function CreateKeybindButton(labelTxt, commandName, currentY)
        local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        label:SetText(labelTxt)
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, currentY)
        
        local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetSize(200, 22)
        button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
        
        local currentBinding = GetBindingKey(commandName)
        button:SetText(currentBinding and GetBindingText(currentBinding) or "Not Bound")
        
        button:SetScript("OnClick", function(self)
            if InCombatLockdown() then
                print("|cffff4444[Fuloh QoL] Cannot change keybindings during combat.|r")
                return
            end
            
            self:EnableKeyboard(true)
            self:SetText("Press key to bind...")
        end)
        
        button:SetScript("OnKeyDown", function(self, key)
            if key == "UNKNOWN" then return end
            
            if key == "ESCAPE" then
                self:EnableKeyboard(false)
                local b = GetBindingKey(commandName)
                self:SetText(b and GetBindingText(b) or "Not Bound")
                return
            end
            
            -- Ignore modifier keys on their own
            if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" or key == "META" then
                return
            end

            local prefix = ""
            if IsAltKeyDown() then prefix = prefix .. "ALT-" end
            if IsControlKeyDown() then prefix = prefix .. "CTRL-" end
            if IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
            
            local finalKey = prefix .. key

            if InCombatLockdown() then
                self:EnableKeyboard(false)
                local b = GetBindingKey(commandName)
                self:SetText(b and GetBindingText(b) or "Not Bound")
                print("|cffff4444[Fuloh QoL] Cannot change keybindings during combat.|r")
                return
            end

            -- Clear old binding assignment from this specific command
            local oldKeys = {GetBindingKey(commandName)}
            for _, oldKey in ipairs(oldKeys) do
                SetBinding(oldKey)
            end
            
            -- Unbind anything that previously used to be attached to this specific finalKey to prevent collision
            local oldCommandAssignedToFinalKey = GetBindingAction(finalKey)
            if oldCommandAssignedToFinalKey and oldCommandAssignedToFinalKey ~= "" then
                SetBinding(finalKey)
            end
            
            -- Bind new key
            SetBinding(finalKey, commandName)
            SaveBindings(GetCurrentBindingSet())
            
            self:EnableKeyboard(false)
            self:SetText(GetBindingText(finalKey))
        end)
        
        -- Also unfocus if we click away or lose focus
        button:SetScript("OnHide", function(self)
            self:EnableKeyboard(false)
            local current = GetBindingKey(commandName)
            self:SetText(current and GetBindingText(current) or "Not Bound")
        end)
        
        return currentY - 50
    end
    
    yOffset = CreateKeybindButton(
        GetLocale() == "frFR" and "Raccourci - Faire défiler" or "Cycle Marker Keybind",
        "CLICK FulohQoL_RotationMarker_CycleBtn:LeftButton",
        yOffset - 10
    )
    
    yOffset = CreateKeybindButton(
        GetLocale() == "frFR" and "Raccourci - Effacer" or "Clear Markers Keybind",
        "CLICK FulohQoL_RotationMarker_ClearBtn:LeftButton",
        yOffset
    )
    
    return yOffset - 10
end

-- Export module and register feature
QoL.Features.RotationMarker = RotationMarker
QoL:RegisterFeature(RotationMarker)
