-- HideCombatLog.lua
-- Feature: Completely removes the Combat Log tab from the chat dock

local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

local HideCombatLog = {
    name      = "HideCombatLog",
    label     = "Hide Combat Log Tab",
    tooltip   = "Completely removes the Combat Log tab from the chat window.",
    shortcut  = "hcl",
    isEnabled = false,
}

local eventFrame  = CreateFrame("Frame")
local clFrame     = nil   -- resolved once on first Enable
local hooksSetup  = false

--------------------------------------------------------------------------------
-- Private helpers
--------------------------------------------------------------------------------

local function FindCombatLogFrame()
    for i = 1, NUM_CHAT_WINDOWS do
        local messages = { GetChatWindowMessages(i) }
        for _, msg in ipairs(messages) do
            if msg == "COMBATLOG" then
                return _G["ChatFrame" .. i]
            end
        end
    end
    return ChatFrame2  -- fallback: default combat log position
end

-- Hook OnShow on both the frame and its tab so Blizzard can never re-show them
-- while the feature is enabled. HookScript is permanent, but the guard checks
-- isEnabled so it becomes a no-op when the feature is disabled.
local function SetupHooks(frame)
    if hooksSetup then return end
    hooksSetup = true

    frame:HookScript("OnShow", function(self)
        if HideCombatLog.isEnabled then
            self:Hide()
        end
    end)

    local tab = _G[frame:GetName() .. "Tab"]
    if tab then
        tab:HookScript("OnShow", function(self)
            if HideCombatLog.isEnabled then
                self:Hide()
            end
        end)
    end
end

local function ApplyHide()
    if not clFrame then return end
    -- Undock: removes the tab from the docked tab group and reflows remaining tabs
    FCF_UnDockFrame(clFrame)
    clFrame:Hide()
    local tab = _G[clFrame:GetName() .. "Tab"]
    if tab then tab:Hide() end
end

local function ApplyShow()
    if not clFrame then return end
    clFrame:Show()
    -- Re-dock back into the main chat frame's dock
    FCF_DockFrame(clFrame, ChatFrame1, false)
end

--------------------------------------------------------------------------------
-- Event handler
--------------------------------------------------------------------------------

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if HideCombatLog.isEnabled then
            ApplyHide()
        end
    end
end)

--------------------------------------------------------------------------------
-- Feature API
--------------------------------------------------------------------------------

function HideCombatLog:Initialize()
end

function HideCombatLog:Enable()
    self.isEnabled = true
    if not clFrame then
        clFrame = FindCombatLogFrame()
    end
    SetupHooks(clFrame)
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    ApplyHide()
end

function HideCombatLog:Disable()
    self.isEnabled = false
    eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    ApplyShow()
end

function HideCombatLog:GetDefaults()
    return { enabled = false }
end

QoL:RegisterFeature(HideCombatLog)
