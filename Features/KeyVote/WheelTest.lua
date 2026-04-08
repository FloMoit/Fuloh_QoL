-- WheelTest.lua
-- Spinning wheel popup for KeyVote feature.
-- Networked via KeyVote.lua; also usable standalone via /fuloh vote wheeltest.
--
-- Design: fixed gold arrow at 12 o'clock; the WHEEL rotates.
-- Animation: cubic ease-out on a fixed target angle — deterministic across clients.

local QoL = Fuloh_QoL
if not QoL then return end

------------------------------------------------------------------------
-- Tuning
------------------------------------------------------------------------
local WHEEL_RADIUS   = 130   -- px, half-diameter of the wheel
local ICON_RADIUS    = 80    -- px from center to icon midpoint
local LABEL_RADIUS   = 105   -- px from center to short-name label
local WEDGE_STEP     = 5     -- degrees per wedge (smooth circle)
local WEDGE_STEP_RAD = math.rad(WEDGE_STEP)
local WEDGE_OVERLAP  = 0.008 -- radians overlap to close sub-pixel gaps between wedges
local ICON_SIZE      = 40    -- px

------------------------------------------------------------------------
-- Color palette (assigned by segment index, wraps for >5 segments)
------------------------------------------------------------------------
local PALETTE = {
    {0.85, 0.28, 0.28},   -- red
    {0.25, 0.50, 0.85},   -- blue
    {0.85, 0.68, 0.15},   -- gold
    {0.55, 0.25, 0.75},   -- purple
    {0.22, 0.70, 0.35},   -- green
}

------------------------------------------------------------------------
-- Angle convention
--
--   wheelSpin = total CW rotation applied to the wheel (rad, increases over time).
--   Arrow is fixed at 12 o'clock (standard math π/2 = top, Y-up).
--
--   PIE WEDGE APPROACH (SetVertexOffset):
--     Each 5° wedge is a 1×1 texture deformed into a triangle by pinning its
--     two "lower" corners to the wheel center and placing the two "upper" corners
--     at the rim at the wedge's start and end angles.
--     Vertex indices: 1=UPPERLEFT, 2=UPPERRIGHT, 3=LOWERLEFT, 4=LOWERRIGHT
--
--   Wedge i initial start angle: π/2 + i * WEDGE_STEP_RAD  (CCW from 12 o'clock)
--   Current start angle after CW spin: startRad - wheelSpin
--
--   Winner = segment i where ((i-1)*SEG_ANGLE - wheelSpin) mod 2π closest to 0.
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Module state
------------------------------------------------------------------------
local wheelFrame     = nil
local wheelCenter    = nil
local wedges         = {}    -- {tex, startRad} per 5° wedge
local icons          = {}    -- Texture per segment
local iconInitAngles = {}
local iconLabels     = {}    -- FontString per segment
local resultText     = nil
local spinButton     = nil

-- Per-spin state
local wheelSpin      = 0
local spinTime       = 0
local targetSpin     = 0
local spinDuration   = 0
local isSpinning     = false

-- Callbacks supplied by ShowWheelPopup
local cbOnSpinRequested = nil   -- function(targetSpin, duration) or nil
local cbOnWheelDone     = nil   -- function(winnerIndex) or nil

-- Dynamic dungeon list (set at ShowWheelPopup time)
local currentDungeons   = nil
local currentNumSegs    = 0
local currentSegAngle   = 0

------------------------------------------------------------------------
-- GetSpellTexture wrapper
------------------------------------------------------------------------
local function GetDungeonIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellID)
    end
    return GetSpellTexture and GetSpellTexture(spellID)
end

------------------------------------------------------------------------
-- UpdateWheel: apply current wheelSpin to all rotating elements
------------------------------------------------------------------------
local function UpdateWheel()
    for _, w in ipairs(wedges) do
        local s  = w.startRad - wheelSpin
        local e  = s + WEDGE_STEP_RAD + WEDGE_OVERLAP
        local wx = math.cos(s) * WHEEL_RADIUS
        local wy = math.sin(s) * WHEEL_RADIUS
        local ex = math.cos(e) * WHEEL_RADIUS
        local ey = math.sin(e) * WHEEL_RADIUS
        w.tex:SetVertexOffset(1, wx + 0.5, wy - 0.5)
        w.tex:SetVertexOffset(2, ex - 0.5, ey - 0.5)
    end

    for i = 1, currentNumSegs do
        local angle = iconInitAngles[i] - wheelSpin
        local cx    = math.cos(angle)
        local cy    = math.sin(angle)

        icons[i]:ClearAllPoints()
        icons[i]:SetPoint("CENTER", wheelCenter, "CENTER",
            cx * ICON_RADIUS, cy * ICON_RADIUS)
        icons[i]:SetRotation(-wheelSpin)

        iconLabels[i]:ClearAllPoints()
        iconLabels[i]:SetPoint("CENTER", wheelCenter, "CENTER",
            cx * LABEL_RADIUS, cy * LABEL_RADIUS)
    end
end

------------------------------------------------------------------------
-- GetSegmentUnderArrow: returns 1-indexed winner
------------------------------------------------------------------------
local function GetSegmentUnderArrow()
    local best, bestDist = 1, math.huge
    for i = 1, currentNumSegs do
        local offset = ((i - 1) * currentSegAngle - wheelSpin) % (2 * math.pi)
        if offset > math.pi then offset = offset - 2 * math.pi end
        local dist = math.abs(offset)
        if dist < bestDist then bestDist = dist; best = i end
    end
    return best
end

------------------------------------------------------------------------
-- UpdateIconHighlights
------------------------------------------------------------------------
local function UpdateIconHighlights(activeIndex)
    for i, icon in ipairs(icons) do
        if i == activeIndex then
            icon:SetVertexColor(1, 1, 1, 1)
        else
            icon:SetVertexColor(0.4, 0.4, 0.4, 0.7)
        end
    end
end

------------------------------------------------------------------------
-- SnapToNearestSegment
------------------------------------------------------------------------
local function SnapToNearestSegment()
    local best   = GetSegmentUnderArrow()
    local target = (best - 1) * currentSegAngle
    local k      = math.floor((wheelSpin - target) / (2 * math.pi) + 0.5)
    wheelSpin    = target + k * 2 * math.pi

    UpdateWheel()
    UpdateIconHighlights(best)

    local d = currentDungeons and currentDungeons[best]
    resultText:SetText("Winner: |cffffd700" .. (d and d.name or "?") .. "|r")
    isSpinning = false
    spinButton:Enable()
    spinButton:SetAlpha(1)
    wheelFrame:SetScript("OnUpdate", nil)

    if cbOnWheelDone then cbOnWheelDone(best) end
end

------------------------------------------------------------------------
-- Animation: cubic ease-out on fixed targetSpin
------------------------------------------------------------------------
local function OnUpdate(self, elapsed)
    if not isSpinning then return end
    spinTime = spinTime + elapsed
    local t     = math.min(spinTime / spinDuration, 1.0)
    local eased = 1 - (1 - t) ^ 3
    wheelSpin   = targetSpin * eased
    UpdateWheel()
    UpdateIconHighlights(GetSegmentUnderArrow())
    if t >= 1.0 then
        SnapToNearestSegment()
    end
end

------------------------------------------------------------------------
-- GenerateSpinParams
------------------------------------------------------------------------
local function GenerateSpinParams()
    local winner   = math.random(1, currentNumSegs)
    local laps     = math.random(4, 7)
    local tSpin    = (winner - 1) * currentSegAngle + laps * 2 * math.pi
    local dur      = math.random(5, 8)
    return tSpin, dur
end

------------------------------------------------------------------------
-- StartSpin: begins animation with given params
------------------------------------------------------------------------
local function StartSpin(tSpin, dur)
    if isSpinning then return end
    resultText:SetText("")
    UpdateIconHighlights(0)
    targetSpin   = tSpin
    spinDuration = dur
    spinTime     = 0
    isSpinning   = true
    spinButton:Disable()
    spinButton:SetAlpha(0.5)
    wheelFrame:SetScript("OnUpdate", OnUpdate)
end

------------------------------------------------------------------------
-- OnSpinButtonClick (initiator only)
------------------------------------------------------------------------
local function OnSpinButtonClick()
    if isSpinning then return end
    local tSpin, dur = GenerateSpinParams()
    if cbOnSpinRequested then
        -- Real networked flow: callback broadcasts KVSPIN and calls StartWheelSpin locally
        cbOnSpinRequested(tSpin, dur)
    else
        -- Test / standalone mode: just animate locally
        StartSpin(tSpin, dur)
    end
end

------------------------------------------------------------------------
-- RebuildSegments: destroy and recreate wedges/icons/labels for a new
-- dungeon list. Called from ShowWheelPopup when the list changes.
------------------------------------------------------------------------
local function RebuildSegments(dungeons)
    local numSegs  = #dungeons
    local segAngle = (2 * math.pi) / numSegs
    local SEG_DEG  = 360 / numSegs

    currentDungeons = dungeons
    currentNumSegs  = numSegs
    currentSegAngle = segAngle

    -- Hide / clear old elements
    for _, w in ipairs(wedges) do w.tex:Hide() end
    for _, ic in ipairs(icons) do ic:Hide() end
    for _, lb in ipairs(iconLabels) do lb:Hide() end
    wedges         = {}
    icons          = {}
    iconInitAngles = {}
    iconLabels     = {}

    -- Circular mask (recreated each time for correct draw-layer ordering)
    local mask = wheelFrame:CreateMaskTexture()
    mask:SetTexture(
        "Interface\\CharacterFrame\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"
    )
    mask:SetSize(WHEEL_RADIUS * 2, WHEEL_RADIUS * 2)
    mask:SetPoint("CENTER", wheelCenter, "CENTER", 0, 0)

    -- Pie wedges
    local wedgeCount = math.floor(360 / WEDGE_STEP)
    for i = 0, wedgeCount - 1 do
        local deg   = i * WEDGE_STEP
        local seg_i = (math.floor((deg + SEG_DEG / 2) / SEG_DEG) % numSegs) + 1
        local c     = PALETTE[(seg_i - 1) % #PALETTE + 1]

        local startRad = math.pi / 2 + math.rad(deg)
        local endRad   = startRad + WEDGE_STEP_RAD + WEDGE_OVERLAP

        local wx = math.cos(startRad) * WHEEL_RADIUS
        local wy = math.sin(startRad) * WHEEL_RADIUS
        local ex = math.cos(endRad) * WHEEL_RADIUS
        local ey = math.sin(endRad) * WHEEL_RADIUS

        local wedge = wheelFrame:CreateTexture(nil, "ARTWORK", nil, -1)
        wedge:SetColorTexture(c[1], c[2], c[3], 1)
        wedge:SetSize(1, 1)
        wedge:SetPoint("CENTER", wheelCenter, "CENTER", 0, 0)
        wedge:AddMaskTexture(mask)

        wedge:SetVertexOffset(3,  0.5,  0.5)
        wedge:SetVertexOffset(4, -0.5,  0.5)
        wedge:SetVertexOffset(1, wx + 0.5, wy - 0.5)
        wedge:SetVertexOffset(2, ex - 0.5, ey - 0.5)

        wedges[#wedges + 1] = { tex = wedge, startRad = startRad }
    end

    -- Icons and labels
    for i = 1, numSegs do
        local angle   = math.pi / 2 + (i - 1) * segAngle
        iconInitAngles[i] = angle

        local d       = dungeons[i]
        local texture = (d.spellID and GetDungeonIcon(d.spellID))
                     or "Interface\\Icons\\INV_Misc_QuestionMark"

        local icon = wheelFrame:CreateTexture(nil, "OVERLAY", nil, 3)
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetTexture(texture)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetPoint("CENTER", wheelCenter, "CENTER",
            math.cos(angle) * ICON_RADIUS,
            math.sin(angle) * ICON_RADIUS)
        icons[i] = icon

        local lbl = wheelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetText(d.name or "?")
        lbl:SetPoint("CENTER", wheelCenter, "CENTER",
            math.cos(angle) * LABEL_RADIUS,
            math.sin(angle) * LABEL_RADIUS)
        iconLabels[i] = lbl
    end
end

------------------------------------------------------------------------
-- BuildWheelFrame: created once, houses all persistent chrome
------------------------------------------------------------------------
local function BuildWheelFrame()
    local f = CreateFrame("Frame", "FulohWheelPopupFrame", UIParent, "BackdropTemplate")
    f:SetSize(320, 480)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0.08, 0.08, 0.12, 0.97)
    f:SetBackdropBorderColor(0.9, 0.7, 0.2, 1)
    tinsert(UISpecialFrames, "FulohWheelPopupFrame")

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("|cffffff00Wheel Spin|r")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 2)

    -- Wheel center anchor
    wheelCenter = CreateFrame("Frame", nil, f)
    wheelCenter:SetSize(1, 1)
    wheelCenter:SetPoint("CENTER", f, "CENTER", 0, 30)

    -- Dark background circle (persistent; sits behind wedges)
    local bgMask = f:CreateMaskTexture()
    bgMask:SetTexture(
        "Interface\\CharacterFrame\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"
    )
    bgMask:SetSize(WHEEL_RADIUS * 2, WHEEL_RADIUS * 2)
    bgMask:SetPoint("CENTER", wheelCenter, "CENTER", 0, 0)

    local bg = f:CreateTexture(nil, "ARTWORK", nil, -2)
    bg:SetColorTexture(0.04, 0.04, 0.08, 1)
    bg:SetSize(WHEEL_RADIUS * 2, WHEEL_RADIUS * 2)
    bg:SetPoint("CENTER", wheelCenter, "CENTER", 0, 0)
    bg:AddMaskTexture(bgMask)

    -- Center dot (over wedge convergence point)
    local dotMask = f:CreateMaskTexture()
    dotMask:SetTexture(
        "Interface\\CharacterFrame\\TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE"
    )
    dotMask:SetSize(20, 20)
    dotMask:SetPoint("CENTER", wheelCenter, "CENTER", 0, 0)

    local centerDot = f:CreateTexture(nil, "OVERLAY", nil, 2)
    centerDot:SetColorTexture(0.06, 0.06, 0.10, 1)
    centerDot:SetSize(20, 20)
    centerDot:SetPoint("CENTER", wheelCenter, "CENTER", 0, 0)
    centerDot:AddMaskTexture(dotMask)

    -- Fixed gold arrow at 12 o'clock
    local arrow = f:CreateTexture(nil, "OVERLAY", nil, 6)
    arrow:SetTexture("Interface\\AddOns\\Fuloh_QoL\\Features\\KeyVote\\Gold-Arrow-Down.png")
    arrow:SetSize(28, 24)
    arrow:SetPoint("BOTTOM", wheelCenter, "CENTER", 0, WHEEL_RADIUS - 4)

    -- Divider
    local divider = f:CreateTexture(nil, "OVERLAY")
    divider:SetColorTexture(0.9, 0.7, 0.2, 0.35)
    divider:SetSize(280, 1)
    divider:SetPoint("TOP", wheelCenter, "BOTTOM", 0, -14)

    -- Result text
    resultText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    resultText:SetPoint("BOTTOM", f, "BOTTOM", 0, 58)
    resultText:SetText("")

    -- Spin button
    spinButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    spinButton:SetSize(120, 30)
    spinButton:SetPoint("BOTTOM", f, "BOTTOM", 0, 18)
    spinButton:SetText("Spin!")
    spinButton:SetScript("OnClick", OnSpinButtonClick)

    wheelFrame = f
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

-- ShowWheelPopup(dungeons, isInitiator, onSpinRequested, onWheelDone)
--   dungeons        = {{name, spellID, mapID}, ...}
--   isInitiator     = bool  (enables the Spin button)
--   onSpinRequested = function(targetSpin, duration) or nil (nil = test mode)
--   onWheelDone     = function(winnerIndex) or nil
local function ShowWheelPopup(dungeons, isInitiator, onSpinRequested, onWheelDone)
    if not wheelFrame then BuildWheelFrame() end

    cbOnSpinRequested = onSpinRequested
    cbOnWheelDone     = onWheelDone

    RebuildSegments(dungeons)

    -- Reset spin state
    wheelSpin    = 0
    spinTime     = 0
    targetSpin   = 0
    spinDuration = 0
    isSpinning   = false

    UpdateWheel()
    UpdateIconHighlights(GetSegmentUnderArrow())
    resultText:SetText("")
    wheelFrame:SetScript("OnUpdate", nil)

    if isInitiator then
        spinButton:Enable()
        spinButton:SetAlpha(1)
    else
        spinButton:Disable()
        spinButton:SetAlpha(0.4)
    end

    wheelFrame:Show()
end

-- StartWheelSpin(targetSpin, spinDuration)
--   Called on non-initiators when KVSPIN is received, and also by
--   the initiator's onSpinRequested callback immediately after broadcast.
local function StartWheelSpin(tSpin, dur)
    StartSpin(tSpin, dur)
end

-- HideWheelPopup: hides and fully resets
local function HideWheelPopup()
    if not wheelFrame then return end
    wheelFrame:SetScript("OnUpdate", nil)
    isSpinning        = false
    cbOnSpinRequested = nil
    cbOnWheelDone     = nil
    wheelFrame:Hide()
end

------------------------------------------------------------------------
-- Exports
------------------------------------------------------------------------
QoL.Features.KeyVote_ShowWheelPopup  = ShowWheelPopup
QoL.Features.KeyVote_StartWheelSpin  = StartWheelSpin
QoL.Features.KeyVote_HideWheelPopup  = HideWheelPopup

-- Kept for /fuloh vote wheeltest (local-only, no broadcast)
QoL.Features.KeyVote_TestWheelUI = function()
    local twwDungeons = {
        { name = "Ara-Kara",   spellID = 445417, mapID = 2660 },
        { name = "Stonevault", spellID = 445269, mapID = 2652 },
        { name = "Cinderbrew", spellID = 445440, mapID = 2661 },
        { name = "Darkflame",  spellID = 445441, mapID = 2519 },
        { name = "Priory",     spellID = 445444, mapID = 2662 },
    }
    ShowWheelPopup(twwDungeons, true, nil, nil)
end
