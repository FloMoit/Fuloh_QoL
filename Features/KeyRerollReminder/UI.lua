-- UI.lua
-- KeyRerollReminder confirmation popup and big reminder overlay

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

--------------------------------------------------------------------------------
-- Localization
--------------------------------------------------------------------------------

local locale = GetLocale()

local L = {
    ["Popup Text"] = (locale == "frFR")
        and "Votre clé actuelle : %s\n\nVoulez-vous un rappel pour la reroll\nsi le donjon est terminé dans les temps ?"
        or "Your current key: %s\n\nDo you want to be reminded to reroll it\nif the dungeon is completed within the time limit?",
    ["Reminder Text"] = (locale == "frFR")
        and "REROLL TA CLÉ !"
        or "REROLL YOUR KEY DUDE!",
    ["Click to dismiss"] = (locale == "frFR")
        and "(Cliquez pour fermer)"
        or "(Click to dismiss)",
}

--------------------------------------------------------------------------------
-- Confirmation Popup (StaticPopup)
--------------------------------------------------------------------------------

-- Callbacks set by KeyRerollReminder.lua
local onAcceptCallback = nil
local onDeclineCallback = nil

StaticPopupDialogs["FULOH_KEY_REROLL_REMINDER"] = {
    text = L["Popup Text"],
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        if onAcceptCallback then onAcceptCallback() end
    end,
    OnCancel = function()
        if onDeclineCallback then onDeclineCallback() end
    end,
    timeout = 15,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function ShowConfirmPopup(keyDescription)
    StaticPopup_Show("FULOH_KEY_REROLL_REMINDER", keyDescription or "?")
end

local function HideConfirmPopup()
    StaticPopup_Hide("FULOH_KEY_REROLL_REMINDER")
end

--------------------------------------------------------------------------------
-- Big Reminder Overlay
--------------------------------------------------------------------------------

local reminderFrame = nil
local pulseAnimGroup = nil

local function CreateBigReminderFrame()
    local frame = CreateFrame("Frame", "Fuloh_QoL_KRR_ReminderFrame", UIParent, "BackdropTemplate")
    frame:SetSize(500, 120)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()

    -- Backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
    frame:SetBackdropBorderColor(0.2, 0.9, 0.3, 0.9)

    -- Gradient overlay
    local gradient = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    gradient:SetTexture("Interface\\Buttons\\WHITE8x8")
    gradient:SetGradient("VERTICAL",
        CreateColor(0.1, 0.2, 0.1, 0.3),
        CreateColor(0.05, 0.08, 0.05, 0.1)
    )
    gradient:SetAllPoints(frame)

    -- Glow texture (for pulse animation)
    local glow = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    glow:SetTexture("Interface\\Buttons\\WHITE8x8")
    glow:SetAllPoints(frame)
    glow:SetVertexColor(0.2, 0.9, 0.3, 0.0)
    frame.glow = glow

    -- Pulse animation on glow
    pulseAnimGroup = glow:CreateAnimationGroup()
    pulseAnimGroup:SetLooping("BOUNCE")

    local fadeIn = pulseAnimGroup:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(0.15)
    fadeIn:SetDuration(0.8)
    fadeIn:SetSmoothing("IN_OUT")

    -- Main text
    local mainText = frame:CreateFontString(nil, "OVERLAY")
    mainText:SetFont("Fonts\\FRIZQT__.TTF", 32, "OUTLINE")
    mainText:SetPoint("CENTER", frame, "CENTER", 0, 12)
    mainText:SetTextColor(1.0, 0.82, 0.0)
    mainText:SetText(L["Reminder Text"])
    mainText:SetJustifyH("CENTER")
    frame.mainText = mainText

    -- Subtitle
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtitle:SetPoint("TOP", mainText, "BOTTOM", 0, -6)
    subtitle:SetTextColor(0.7, 0.7, 0.7)
    subtitle:SetText(L["Click to dismiss"])
    subtitle:SetJustifyH("CENTER")
    frame.subtitle = subtitle

    -- Hover: brighten border
    frame:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.3, 1.0, 0.4, 1.0)
    end)

    frame:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.2, 0.9, 0.3, 0.9)
    end)

    -- Click to dismiss
    frame:SetScript("OnMouseDown", function()
        HideBigReminder()
    end)

    return frame
end

local function ShowBigReminder()
    if not reminderFrame then
        reminderFrame = CreateBigReminderFrame()
    end

    reminderFrame:SetAlpha(0)
    reminderFrame:Show()
    UIFrameFadeIn(reminderFrame, 0.3, 0, 1)

    -- Start pulse
    if pulseAnimGroup then
        pulseAnimGroup:Play()
    end
end

function HideBigReminder()
    if not reminderFrame or not reminderFrame:IsShown() then
        return
    end

    -- Stop pulse
    if pulseAnimGroup then
        pulseAnimGroup:Stop()
    end
    reminderFrame.glow:SetAlpha(0)

    UIFrameFadeOut(reminderFrame, 0.3, 1, 0)
    C_Timer.After(0.3, function()
        if reminderFrame then
            reminderFrame:Hide()
        end
    end)
end

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

QoL.Features.KeyRerollReminder_ShowConfirmPopup = ShowConfirmPopup
QoL.Features.KeyRerollReminder_HideConfirmPopup = HideConfirmPopup
QoL.Features.KeyRerollReminder_ShowBigReminder = ShowBigReminder
QoL.Features.KeyRerollReminder_HideBigReminder = HideBigReminder
QoL.Features.KeyRerollReminder_L = L

-- Allow KeyRerollReminder.lua to set popup callbacks
QoL.Features.KeyRerollReminder_SetPopupCallbacks = function(onAccept, onDecline)
    onAcceptCallback = onAccept
    onDeclineCallback = onDecline
end
