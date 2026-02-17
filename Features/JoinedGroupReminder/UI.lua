-- UI.lua
-- JoinedGroupReminder reminder banner UI creation and display

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

-- Get Constants (loaded before this file)
local UI = QoL.Features.JoinedGroupReminder_Constants.UI
local FONTS = QoL.Features.JoinedGroupReminder_Constants.FONTS
local L = QoL.Features.JoinedGroupReminder_Constants.L

-- Main frame reference
local reminderFrame = nil

-- Database accessor
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.JoinedGroupReminder or {}
end

-- Forward declaration for ClearCachedState (will be provided by JoinedGroupReminder.lua)
local clearCachedState = nil

local function CreateReminderFrame()
    local frame = CreateFrame("Frame", "Fuloh_QoL_JGR_ReminderFrame", UIParent, "BackdropTemplate")
    frame:SetSize(UI.WIDTH, UI.HEIGHT)

    -- Position calculation (use saved position if available)
    local db = GetDB()
    if db.position then
        local pos = db.position
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, UI.Y_OFFSET)
    end
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()

    -- Backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(unpack(UI.BACKGROUND_COLOR))
    frame:SetBackdropBorderColor(unpack(UI.BORDER_COLOR))

    -- Subtle gradient overlay
    local gradient = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    gradient:SetTexture("Interface\\Buttons\\WHITE8x8")
    gradient:SetGradient("VERTICAL",
        CreateColor(0.15, 0.15, 0.2, 0.2),
        CreateColor(0.05, 0.05, 0.08, 0.1)
    )
    gradient:SetAllPoints(frame)

    -- Left accent bar
    local accentBar = frame:CreateTexture(nil, "ARTWORK")
    accentBar:SetTexture("Interface\\Buttons\\WHITE8x8")
    accentBar:SetSize(6, UI.HEIGHT - 2)
    accentBar:SetPoint("LEFT", frame, "LEFT", 1, 0)
    accentBar:SetVertexColor(0.9, 0.7, 0.2, 0.8)
    frame.accentBar = accentBar

    -- Teleport button (left side, after accent bar)
    local teleportBtn = CreateFrame("Button", nil, frame, "SecureActionButtonTemplate")
    teleportBtn:SetSize(UI.ICON_SIZE, UI.ICON_SIZE)
    teleportBtn:SetPoint("LEFT", frame, "LEFT", 18, 0)
    teleportBtn:RegisterForClicks("AnyUp", "AnyDown")
    teleportBtn:Hide()

    local teleportIcon = teleportBtn:CreateTexture(nil, "ARTWORK")
    teleportIcon:SetAllPoints()
    teleportIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    teleportBtn.icon = teleportIcon

    -- Simple highlight on hover
    teleportBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local highlight = teleportBtn:GetHighlightTexture()
    highlight:SetAlpha(0.3)

    local teleportCooldown = CreateFrame("Cooldown", nil, teleportBtn, "CooldownFrameTemplate")
    teleportCooldown:SetAllPoints()
    teleportBtn.cooldown = teleportCooldown

    teleportBtn:SetScript("OnEnter", function(self)
        if self.spellID then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetSpellByID(self.spellID)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["Click to teleport"], 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end
    end)

    teleportBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    frame.teleportBtn = teleportBtn

    -- Text container (adjusts based on teleport button visibility)
    local textContainer = CreateFrame("Frame", nil, frame)
    textContainer:SetPoint("LEFT", frame, "LEFT", 18, 0)
    textContainer:SetPoint("RIGHT", frame, "RIGHT", -42, 0)
    textContainer:SetPoint("TOP", frame, "TOP", 0, 0)
    textContainer:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
    frame.textContainer = textContainer

    -- Dungeon name (main text, centered)
    local dungeonText = textContainer:CreateFontString(nil, "OVERLAY", FONTS.DUNGEON)
    dungeonText:SetPoint("CENTER", textContainer, "CENTER", 0, 10)
    dungeonText:SetTextColor(unpack(UI.DUNGEON_TEXT_COLOR))
    dungeonText:SetJustifyH("CENTER")
    dungeonText:SetWidth(UI.WIDTH - 120)
    dungeonText:SetMaxLines(1)
    frame.dungeonText = dungeonText

    -- Group name subtitle
    local groupText = textContainer:CreateFontString(nil, "OVERLAY", FONTS.GROUP)
    groupText:SetPoint("TOP", dungeonText, "BOTTOM", 0, -4)
    groupText:SetTextColor(unpack(UI.GROUP_TEXT_COLOR))
    groupText:SetJustifyH("CENTER")
    groupText:SetWidth(UI.WIDTH - 120)
    groupText:SetMaxLines(1)
    frame.groupText = groupText

    -- Close button (right side)
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(UI.CLOSE_BUTTON_SIZE, UI.CLOSE_BUTTON_SIZE)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

    local closeBtnBg = closeBtn:CreateTexture(nil, "BACKGROUND")
    closeBtnBg:SetAllPoints()
    closeBtnBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    closeBtnBg:SetVertexColor(0.2, 0.2, 0.25, 0.6)
    closeBtn.bg = closeBtnBg

    local closeBtnText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeBtnText:SetPoint("CENTER", 0, 0)
    closeBtnText:SetText("×")
    closeBtnText:SetTextColor(0.7, 0.7, 0.7)
    closeBtnText:SetFont(closeBtnText:GetFont(), 24)
    closeBtn.text = closeBtnText

    closeBtn:SetScript("OnEnter", function(self)
        self.text:SetTextColor(1.0, 0.4, 0.4)
        self.bg:SetVertexColor(0.3, 0.15, 0.15, 0.8)
    end)

    closeBtn:SetScript("OnLeave", function(self)
        self.text:SetTextColor(0.7, 0.7, 0.7)
        self.bg:SetVertexColor(0.2, 0.2, 0.25, 0.6)
    end)

    closeBtn:SetScript("OnClick", function()
        QoL.Features.JoinedGroupReminder_HideReminder(true)
    end)

    frame.closeBtn = closeBtn

    -- Hover effect on main frame
    frame:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(UI.BORDER_HIGHLIGHT_COLOR))
    end)

    frame:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(UI.BORDER_COLOR))
    end)

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        local db = GetDB()
        db.position = {
            point = point,
            relativePoint = relativePoint,
            x = xOfs,
            y = yOfs
        }
    end)

    return frame
end

local function ShowReminder(dungeonName, groupName)
    if not reminderFrame then
        reminderFrame = CreateReminderFrame()
    end

    reminderFrame.dungeonText:SetText(dungeonName or L["Unknown Dungeon"])
    if groupName and groupName ~= "" then
        reminderFrame.groupText:SetText(groupName)
    else
        reminderFrame.groupText:SetText("")
    end

    -- Setup teleport button if spell is available
    local teleportBtn = reminderFrame.teleportBtn
    local textContainer = reminderFrame.textContainer
    local spellID = QoL.Features.JoinedGroupReminder_GetDungeonTeleportSpell(dungeonName)

    if spellID and QoL.Features.JoinedGroupReminder_HasDungeonTeleport(spellID) then
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        if spellInfo and spellInfo.iconID then
            teleportBtn.icon:SetTexture(spellInfo.iconID)
        end

        teleportBtn:SetAttribute("type", "spell")
        teleportBtn:SetAttribute("spell", spellID)
        teleportBtn.spellID = spellID

        local start, duration = C_Spell.GetSpellCooldown(spellID)
        if start and duration and duration > 0 then
            teleportBtn.cooldown:SetCooldown(start, duration)
        end

        teleportBtn:Show()
        textContainer:SetPoint("LEFT", reminderFrame, "LEFT", 72, 0)
    else
        teleportBtn:Hide()
        textContainer:SetPoint("LEFT", reminderFrame, "LEFT", 18, 0)
    end

    -- Reset alpha for fade-in
    reminderFrame:SetAlpha(0)
    reminderFrame:Show()

    -- Fade in animation
    UIFrameFadeIn(reminderFrame, UI.FADE_DURATION, 0, 1)
end

local function HideReminder(clearState)
    if not reminderFrame or not reminderFrame:IsShown() then
        return
    end

    -- Fade out animation
    UIFrameFadeOut(reminderFrame, UI.FADE_DURATION, 1, 0)

    -- Hide after fade completes
    C_Timer.After(UI.FADE_DURATION, function()
        if reminderFrame then
            reminderFrame:Hide()
        end
    end)

    -- Clear cached state only if requested
    if clearState and clearCachedState then
        clearCachedState()
    end
end

local function IsReminderShown()
    return reminderFrame and reminderFrame:IsShown()
end

-- Export to Fuloh_QoL.Features namespace
QoL.Features.JoinedGroupReminder_ShowReminder = ShowReminder
QoL.Features.JoinedGroupReminder_HideReminder = HideReminder
QoL.Features.JoinedGroupReminder_IsReminderShown = IsReminderShown

-- Allow JoinedGroupReminder.lua to provide ClearCachedState callback
QoL.Features.JoinedGroupReminder_SetClearCachedStateCallback = function(callback)
    clearCachedState = callback
end
