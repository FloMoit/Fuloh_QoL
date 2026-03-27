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
    ["Popup Title"] = (locale == "frFR")
        and "Rappel de Reroll"
        or "Key Reroll Reminder",
    ["Popup Question"] = (locale == "frFR")
        and "Voulez-vous un rappel pour reroll cette clé\nsi le donjon est terminé dans les temps ?"
        or "Do you want to be reminded to reroll this key\nif the dungeon is completed within the time limit?",
    ["Reminder Text"] = (locale == "frFR")
        and "REROLL TA CLÉ !"
        or "REROLL YOUR KEY DUDE!",
    ["Click to dismiss"] = (locale == "frFR")
        and "(Cliquez pour fermer)"
        or "(Click to dismiss)",
}

--------------------------------------------------------------------------------
-- Confirmation Popup (Custom Frame)
--------------------------------------------------------------------------------

local onAcceptCallback = nil
local onDeclineCallback = nil
local confirmFrame = nil
local CONFIRM_TIMEOUT = 15

local function HideConfirmPopup()
    if not confirmFrame or not confirmFrame:IsShown() then return end
    confirmFrame:SetScript("OnUpdate", nil)
    UIFrameFadeOut(confirmFrame, 0.2, 1, 0)
    C_Timer.After(0.2, function()
        if confirmFrame then confirmFrame:Hide() end
    end)
end

local function CreateConfirmFrame()
    local frame = CreateFrame("Frame", "Fuloh_QoL_KRR_ConfirmFrame", UIParent, "BackdropTemplate")
    frame:SetSize(420, 175)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:EnableKeyboard(true)
    frame:Hide()

    -- Backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
    frame:SetBackdropBorderColor(0.9, 0.7, 0.2, 0.8)

    -- Gradient overlay
    local gradient = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    gradient:SetTexture("Interface\\Buttons\\WHITE8x8")
    gradient:SetGradient("VERTICAL",
        CreateColor(0.15, 0.12, 0.05, 0.3),
        CreateColor(0.05, 0.05, 0.08, 0.1)
    )
    gradient:SetAllPoints(frame)

    -- Top accent bar
    local accentBar = frame:CreateTexture(nil, "ARTWORK")
    accentBar:SetTexture("Interface\\Buttons\\WHITE8x8")
    accentBar:SetHeight(3)
    accentBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    accentBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    accentBar:SetVertexColor(0.9, 0.7, 0.2, 0.9)

    -- Title (small, subtle)
    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetTextColor(0.6, 0.6, 0.6)
    title:SetText(L["Popup Title"])

    -- Key name (prominent, gold)
    local keyText = frame:CreateFontString(nil, "OVERLAY")
    keyText:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
    keyText:SetPoint("TOP", title, "BOTTOM", 0, -10)
    keyText:SetTextColor(1.0, 0.82, 0.0)
    keyText:SetJustifyH("CENTER")
    frame.keyText = keyText

    -- Question text
    local question = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    question:SetPoint("TOP", keyText, "BOTTOM", 0, -8)
    question:SetTextColor(0.8, 0.8, 0.8)
    question:SetText(L["Popup Question"])
    question:SetJustifyH("CENTER")

    -- Button dimensions
    local btnWidth, btnHeight = 100, 28

    -- Yes button (green)
    local yesBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    yesBtn:SetSize(btnWidth, btnHeight)
    yesBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -10, 20)
    yesBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    yesBtn:SetBackdropColor(0.15, 0.35, 0.15, 0.9)
    yesBtn:SetBackdropBorderColor(0.3, 0.7, 0.3, 0.8)

    local yesText = yesBtn:CreateFontString(nil, "OVERLAY")
    yesText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    yesText:SetPoint("CENTER")
    yesText:SetText(YES)
    yesText:SetTextColor(0.3, 1.0, 0.3)

    yesBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.2, 0.45, 0.2, 0.95)
        self:SetBackdropBorderColor(0.4, 0.9, 0.4, 1.0)
    end)
    yesBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.15, 0.35, 0.15, 0.9)
        self:SetBackdropBorderColor(0.3, 0.7, 0.3, 0.8)
    end)
    yesBtn:SetScript("OnClick", function()
        if onAcceptCallback then onAcceptCallback() end
        HideConfirmPopup()
    end)

    -- No button (red)
    local noBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    noBtn:SetSize(btnWidth, btnHeight)
    noBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 10, 20)
    noBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    noBtn:SetBackdropColor(0.3, 0.12, 0.12, 0.9)
    noBtn:SetBackdropBorderColor(0.6, 0.2, 0.2, 0.8)

    local noText = noBtn:CreateFontString(nil, "OVERLAY")
    noText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    noText:SetPoint("CENTER")
    noText:SetText(NO)
    noText:SetTextColor(1.0, 0.4, 0.4)

    noBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.4, 0.15, 0.15, 0.95)
        self:SetBackdropBorderColor(0.8, 0.3, 0.3, 1.0)
    end)
    noBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.3, 0.12, 0.12, 0.9)
        self:SetBackdropBorderColor(0.6, 0.2, 0.2, 0.8)
    end)
    noBtn:SetScript("OnClick", function()
        if onDeclineCallback then onDeclineCallback() end
        HideConfirmPopup()
    end)

    -- Timeout bar background
    local timeoutBarBg = frame:CreateTexture(nil, "ARTWORK")
    timeoutBarBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    timeoutBarBg:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
    timeoutBarBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    timeoutBarBg:SetHeight(3)
    timeoutBarBg:SetVertexColor(0.15, 0.15, 0.2, 0.5)

    -- Timeout bar (shrinks over time)
    local timeoutBar = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    timeoutBar:SetTexture("Interface\\Buttons\\WHITE8x8")
    timeoutBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
    timeoutBar:SetHeight(3)
    timeoutBar:SetVertexColor(0.9, 0.7, 0.2, 0.9)
    frame.timeoutBar = timeoutBar

    -- ESC to decline
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            if onDeclineCallback then onDeclineCallback() end
            HideConfirmPopup()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    return frame
end

local function ShowConfirmPopup(keyDescription)
    if not confirmFrame then
        confirmFrame = CreateConfirmFrame()
    end

    confirmFrame.keyText:SetText(keyDescription or "?")

    -- Reset and start timeout bar animation
    local timeoutElapsed = 0
    local fullWidth = confirmFrame:GetWidth() - 4
    confirmFrame.timeoutBar:SetWidth(fullWidth)

    confirmFrame:SetScript("OnUpdate", function(self, elapsed)
        timeoutElapsed = timeoutElapsed + elapsed
        local remaining = 1 - (timeoutElapsed / CONFIRM_TIMEOUT)
        if remaining <= 0 then
            if onDeclineCallback then onDeclineCallback() end
            HideConfirmPopup()
            return
        end
        self.timeoutBar:SetWidth(math.max(1, remaining * fullWidth))
    end)

    confirmFrame:SetAlpha(0)
    confirmFrame:Show()
    UIFrameFadeIn(confirmFrame, 0.2, 0, 1)
end

--------------------------------------------------------------------------------
-- Big Reminder Overlay
--------------------------------------------------------------------------------

local reminderFrame = nil
local pulseAnimGroup = nil

local function CreateBigReminderFrame()
    local frame = CreateFrame("Frame", "Fuloh_QoL_KRR_ReminderFrame", UIParent, "BackdropTemplate")
    frame:SetSize(500, 150)
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
    mainText:SetPoint("CENTER", frame, "CENTER", 0, 22)
    mainText:SetTextColor(1.0, 0.82, 0.0)
    mainText:SetText(L["Reminder Text"])
    mainText:SetJustifyH("CENTER")
    frame.mainText = mainText

    -- Key description (shown below main text)
    local keyText = frame:CreateFontString(nil, "OVERLAY")
    keyText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    keyText:SetPoint("TOP", mainText, "BOTTOM", 0, -4)
    keyText:SetTextColor(0.9, 0.75, 0.3)
    keyText:SetJustifyH("CENTER")
    frame.keyText = keyText

    -- Subtitle
    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtitle:SetPoint("TOP", keyText, "BOTTOM", 0, -8)
    subtitle:SetTextColor(0.5, 0.5, 0.5)
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

local function ShowBigReminder(keyDescription)
    if not reminderFrame then
        reminderFrame = CreateBigReminderFrame()
    end

    reminderFrame.keyText:SetText(keyDescription or "")

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
