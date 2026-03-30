-- UI.lua
-- MageFoodReminder: lazy reminder frame

local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

local Constants = QoL.Features.MageFoodReminder_Constants
local L         = Constants.L

--------------------------------------------------------------------------------
-- Frame state
--------------------------------------------------------------------------------

local frame = nil

--------------------------------------------------------------------------------
-- Frame construction
--------------------------------------------------------------------------------

local function CreateReminderFrame()
    local f = CreateFrame("Frame", "Fuloh_QoL_MFR_Frame", UIParent, "BackdropTemplate")
    f:SetSize(Constants.FRAME_WIDTH, Constants.FRAME_HEIGHT)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, -150)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:Hide()

    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })

    -- Left accent bar
    local accent = f:CreateTexture(nil, "ARTWORK")
    accent:SetTexture("Interface\\Buttons\\WHITE8x8")
    accent:SetWidth(Constants.ACCENT_WIDTH)
    accent:SetPoint("TOPLEFT",    f, "TOPLEFT",    2, -2)
    accent:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2,  2)
    f.accent = accent

    -- Icon
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(Constants.ICON_SIZE, Constants.ICON_SIZE)
    icon:SetPoint("LEFT", f, "LEFT", Constants.ACCENT_WIDTH + 10, 0)
    icon:SetTexture(Constants.MAGE_FOOD_ICON_ID)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
    title:SetTextColor(1, 1, 1)
    title:SetText(L.title)

    -- Body
    local body = f:CreateFontString(nil, "OVERLAY")
    body:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    f.body = body

    -- Dismiss hint
    local hint = f:CreateFontString(nil, "OVERLAY")
    hint:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
    hint:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -3)
    hint:SetTextColor(0.45, 0.45, 0.5)
    hint:SetText(L.dismiss)

    return f
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

local function ShowUI(count, onDismiss)
    if not frame then
        frame = CreateReminderFrame()
    end

    local isAlert = (count == 0)

    -- Background
    local bg = isAlert and Constants.ALERT_BG or Constants.NORMAL_BG
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    frame:SetBackdropBorderColor(bg[1] * 0.5, bg[2] * 0.5, bg[3] * 0.5, 0.6)

    -- Accent bar
    local ac = isAlert and Constants.ALERT_ACCENT or Constants.NORMAL_ACCENT
    frame.accent:SetVertexColor(ac[1], ac[2], ac[3], ac[4])

    -- Body text
    local bc = isAlert and Constants.ALERT_BODY_COLOR or Constants.NORMAL_BODY_COLOR
    frame.body:SetTextColor(bc[1], bc[2], bc[3])
    if isAlert then
        frame.body:SetText(L.alert_body)
    else
        frame.body:SetText(L.normal_body:format(count))
    end

    -- Click handler
    frame:SetScript("OnMouseDown", onDismiss or function() end)

    frame:Show()
end

local function HideUI()
    if frame and frame:IsShown() then
        frame:Hide()
    end
end

QoL.Features.MageFoodReminder_ShowUI = ShowUI
QoL.Features.MageFoodReminder_HideUI = HideUI
