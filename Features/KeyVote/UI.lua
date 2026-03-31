-- UI.lua
-- KeyVote voting popup and results overlay frames
-- Lazy frame creation, reused across sessions

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

local C = QoL.Features.KeyVote_Constants
local L = C.L
local VUI = C.VOTE_UI
local RUI = C.RESULTS_UI
local ResolveDungeonInfo = QoL.Features.KeyVote_ResolveDungeonInfo

--------------------------------------------------------------------------------
-- Callbacks (set by KeyVote.lua)
--------------------------------------------------------------------------------

local onVoteSubmit = nil     -- function(selectedKeys) called when user clicks Vote
local onVoteClose = nil      -- function() called when user closes the voting popup
local onResultsDismiss = nil -- function() called when user dismisses results

-- Database accessor
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.KeyVote or {}
end

local function SavePosition(key, frame)
    local db = GetDB()
    local point, _, relativePoint, x, y = frame:GetPoint()
    db[key] = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function ApplyPosition(key, frame, defaultX, defaultY)
    local db = GetDB()
    local pos = db[key]
    if pos then
        frame:SetPoint(pos.point, UIParent, pos.relativePoint, pos.x, pos.y)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", defaultX, defaultY)
    end
end

-- Forward declaration
local UpdateVoteButtonState

--------------------------------------------------------------------------------
-- Voting Popup
--------------------------------------------------------------------------------

local votingFrame = nil
local checkboxRows = {}      -- reusable row frames

local function CreateVotingFrame()
    local frame = CreateFrame("Frame", "Fuloh_QoL_KV_VotingFrame", UIParent, "BackdropTemplate")
    frame:SetSize(VUI.WIDTH, VUI.HEIGHT)
    ApplyPosition("votingPosition", frame, 0, 50)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:EnableKeyboard(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition("votingPosition", self)
    end)
    frame:Hide()

    -- Backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(unpack(VUI.BACKGROUND_COLOR))
    frame:SetBackdropBorderColor(unpack(VUI.BORDER_COLOR))

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

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -14)
    title:SetTextColor(unpack(VUI.TITLE_COLOR))
    title:SetText(L["Key Vote"])
    frame.title = title

    -- Subtitle (started by)
    local subtitle = frame:CreateFontString(nil, "OVERLAY")
    subtitle:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetTextColor(unpack(VUI.SUBTITLE_COLOR))
    frame.subtitle = subtitle

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    closeBtn:SetNormalFontObject("GameFontNormal")

    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY")
    closeTxt:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    closeTxt:SetPoint("CENTER")
    closeTxt:SetText("x")
    closeTxt:SetTextColor(0.5, 0.5, 0.5)

    closeBtn:SetScript("OnEnter", function() closeTxt:SetTextColor(1.0, 0.3, 0.3) end)
    closeBtn:SetScript("OnLeave", function() closeTxt:SetTextColor(0.5, 0.5, 0.5) end)
    closeBtn:SetScript("OnClick", function()
        if onVoteClose then onVoteClose() end
    end)

    -- Content area for keystone rows
    local contentTop = -52
    local contentArea = CreateFrame("Frame", nil, frame)
    contentArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, contentTop)
    contentArea:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, contentTop)
    contentArea:SetHeight(VUI.ROW_HEIGHT * 6)
    frame.contentArea = contentArea

    -- Timer bar background
    local timerBg = frame:CreateTexture(nil, "ARTWORK")
    timerBg:SetTexture("Interface\\Buttons\\WHITE8x8")
    timerBg:SetHeight(4)
    timerBg:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 52)
    timerBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 52)
    timerBg:SetVertexColor(0.15, 0.15, 0.2, 0.5)

    -- Timer bar fill
    local timerBar = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    timerBar:SetTexture("Interface\\Buttons\\WHITE8x8")
    timerBar:SetHeight(4)
    timerBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 52)
    timerBar:SetVertexColor(unpack(VUI.TIMER_COLOR))
    frame.timerBar = timerBar

    -- Timer text
    local timerText = frame:CreateFontString(nil, "OVERLAY")
    timerText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    timerText:SetPoint("BOTTOM", timerBg, "TOP", 0, 4)
    timerText:SetTextColor(unpack(VUI.SUBTITLE_COLOR))
    frame.timerText = timerText

    -- Vote button
    local voteBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    voteBtn:SetSize(120, 32)
    voteBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 12)
    voteBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    voteBtn:SetBackdropColor(0.15, 0.35, 0.15, 0.9)
    voteBtn:SetBackdropBorderColor(0.3, 0.7, 0.3, 0.8)

    local voteBtnText = voteBtn:CreateFontString(nil, "OVERLAY")
    voteBtnText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    voteBtnText:SetPoint("CENTER")
    voteBtnText:SetText(L["Vote"])
    voteBtnText:SetTextColor(0.3, 1.0, 0.3)
    frame.voteBtnText = voteBtnText

    voteBtn:SetScript("OnEnter", function(self)
        if self:IsEnabled() then
            self:SetBackdropColor(0.2, 0.45, 0.2, 0.95)
            self:SetBackdropBorderColor(0.4, 0.9, 0.4, 1.0)
        end
    end)
    voteBtn:SetScript("OnLeave", function(self)
        if self:IsEnabled() then
            self:SetBackdropColor(0.15, 0.35, 0.15, 0.9)
            self:SetBackdropBorderColor(0.3, 0.7, 0.3, 0.8)
        end
    end)
    voteBtn:SetScript("OnClick", function()
        if not onVoteSubmit then return end
        local selected = {}
        for _, row in ipairs(checkboxRows) do
            if row:IsShown() and row.checkbox:GetChecked() then
                selected[#selected + 1] = row.keyID
            end
        end
        if #selected > 0 then
            onVoteSubmit(selected)
        end
    end)
    frame.voteBtn = voteBtn

    -- ESC to close
    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            if onVoteClose then onVoteClose() end
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    return frame
end

-- Get or create a checkbox row at the given index
local function GetCheckboxRow(parent, index)
    if checkboxRows[index] then
        return checkboxRows[index]
    end

    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(VUI.ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * VUI.ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(index - 1) * VUI.ROW_HEIGHT)

    -- Checkbox
    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("LEFT", row, "LEFT", 0, 0)
    cb:SetScript("OnClick", function()
        UpdateVoteButtonState()
    end)
    row.checkbox = cb

    -- Dungeon icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(VUI.ICON_SIZE, VUI.ICON_SIZE)
    icon:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    row.icon = icon

    -- Key name + level text
    local keyText = row:CreateFontString(nil, "OVERLAY")
    keyText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    keyText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    keyText:SetTextColor(0.9, 0.9, 0.9)
    row.keyText = keyText

    -- Owner names text (right-aligned)
    local ownerText = row:CreateFontString(nil, "OVERLAY")
    ownerText:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    ownerText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    ownerText:SetTextColor(unpack(VUI.OWNER_COLOR))
    row.ownerText = ownerText

    row.keyID = nil
    checkboxRows[index] = row
    return row
end

-- Enable/disable the vote button based on checkbox state
UpdateVoteButtonState = function()
    if not votingFrame then return end
    local anyChecked = false
    for _, row in ipairs(checkboxRows) do
        if row:IsShown() and row.checkbox:IsEnabled() and row.checkbox:GetChecked() then
            anyChecked = true
            break
        end
    end
    if anyChecked then
        votingFrame.voteBtn:Enable()
        votingFrame.voteBtnText:SetTextColor(0.3, 1.0, 0.3)
    else
        votingFrame.voteBtn:Disable()
        votingFrame.voteBtnText:SetTextColor(0.3, 0.3, 0.3)
    end
end

-- Show the voting popup.
-- sessionData = { initiator, participants, startTime }
-- keystones = sorted array of { keyID="mapID-level", mapID, level, name, owners={} }
local function ShowVotingPopup(sessionData, keystones)
    if not votingFrame then
        votingFrame = CreateVotingFrame()
    end

    votingFrame.subtitle:SetText(L["Started by"] .. " " .. (sessionData.initiator or "?"))

    -- Populate keystone rows
    for i = 1, math.max(#keystones, #checkboxRows) do
        local ks = keystones[i]
        local row = GetCheckboxRow(votingFrame.contentArea, i)

        if ks then
            row.keyID = ks.keyID
            row.checkbox:SetChecked(false)

            if ks.mapID == 0 then
                -- No key
                row.checkbox:Disable()
                row.checkbox:SetAlpha(0.3)
                row.icon:SetTexture(nil)
                row.keyText:SetText(L["No key"])
                row.keyText:SetTextColor(unpack(VUI.NOKEY_COLOR))
            else
                row.checkbox:Enable()
                row.checkbox:SetAlpha(1)
                -- Dungeon icon and name (with fallback to teleport spell icon)
                local resolvedName, resolvedTexture = ResolveDungeonInfo(ks.mapID)
                row.icon:SetTexture(resolvedTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.keyText:SetText((ks.name or resolvedName or "?") .. " +" .. ks.level)
                row.keyText:SetTextColor(0.9, 0.9, 0.9)
            end

            row.ownerText:SetText(table.concat(ks.owners, ", "))
            row:Show()
        else
            row:Hide()
        end
    end

    -- Resize frame height based on row count
    local rowCount = math.max(#keystones, 1)
    local contentHeight = rowCount * VUI.ROW_HEIGHT
    votingFrame.contentArea:SetHeight(contentHeight)
    votingFrame:SetHeight(contentHeight + 120)

    -- Reset timer bar
    local fullWidth = votingFrame:GetWidth() - 4
    votingFrame.timerBar:SetWidth(fullWidth)
    votingFrame.timerText:SetText(C.VOTE_DURATION .. "s " .. L["remaining"])

    -- Timer update
    local startTime = sessionData.startTime or GetTime()
    votingFrame:SetScript("OnUpdate", function(self, elapsed)
        local elapsed_total = GetTime() - startTime
        local remaining = C.VOTE_DURATION - elapsed_total
        if remaining <= 0 then
            self.timerBar:SetWidth(1)
            self.timerText:SetText("0s " .. L["remaining"])
            return
        end
        local fraction = remaining / C.VOTE_DURATION
        self.timerBar:SetWidth(math.max(1, fraction * fullWidth))
        self.timerText:SetText(math.ceil(remaining) .. "s " .. L["remaining"])
    end)

    -- Reset vote button
    votingFrame.voteBtn:Enable()
    votingFrame.voteBtn:SetWidth(120)
    votingFrame.voteBtnText:SetText(L["Vote"])
    votingFrame.voteBtnText:SetTextColor(0.3, 1.0, 0.3)
    votingFrame.voteBtn:SetBackdropColor(0.15, 0.35, 0.15, 0.9)
    votingFrame.voteBtn:SetBackdropBorderColor(0.3, 0.7, 0.3, 0.8)
    UpdateVoteButtonState()

    votingFrame:SetAlpha(0)
    votingFrame:Show()
    UIFrameFadeIn(votingFrame, VUI.FADE_DURATION, 0, 1)
end

-- Update the voting popup with new keystone/voter data
local function UpdateVotingPopup(sessionData, keystones)
    if not votingFrame or not votingFrame:IsShown() then return end

    for i = 1, math.max(#keystones, #checkboxRows) do
        local ks = keystones[i]
        local row = GetCheckboxRow(votingFrame.contentArea, i)

        if ks then
            row.keyID = ks.keyID

            if ks.mapID == 0 then
                row.checkbox:Disable()
                row.checkbox:SetAlpha(0.3)
                row.icon:SetTexture(nil)
                row.keyText:SetText(L["No key"])
                row.keyText:SetTextColor(unpack(VUI.NOKEY_COLOR))
            else
                if not row.checkbox.locked then
                    row.checkbox:Enable()
                    row.checkbox:SetAlpha(1)
                end
                local resolvedName, resolvedTexture = ResolveDungeonInfo(ks.mapID)
                row.icon:SetTexture(resolvedTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.keyText:SetText((ks.name or resolvedName or "?") .. " +" .. ks.level)
                row.keyText:SetTextColor(0.9, 0.9, 0.9)
            end

            row.ownerText:SetText(table.concat(ks.owners, ", "))
            row:Show()
        else
            row:Hide()
        end
    end

    -- Resize
    local rowCount = math.max(#keystones, 1)
    local contentHeight = rowCount * VUI.ROW_HEIGHT
    votingFrame.contentArea:SetHeight(contentHeight)
    votingFrame:SetHeight(contentHeight + 120)
end

-- Lock the voting popup after local vote submitted
local function LockVotingPopup(voteCount, totalCount)
    if not votingFrame or not votingFrame:IsShown() then return end

    for _, row in ipairs(checkboxRows) do
        if row:IsShown() then
            row.checkbox:Disable()
            row.checkbox.locked = true
        end
    end

    votingFrame.voteBtn:Disable()
    votingFrame.voteBtn:SetWidth(200)
    votingFrame.voteBtnText:SetText(L["Waiting"] .. " (" .. voteCount .. "/" .. totalCount .. ")")
    votingFrame.voteBtnText:SetTextColor(0.6, 0.6, 0.6)
    votingFrame.voteBtn:SetBackdropColor(0.12, 0.12, 0.15, 0.9)
    votingFrame.voteBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
end

-- Update the waiting count text
local function UpdateWaitingCount(voteCount, totalCount)
    if not votingFrame or not votingFrame:IsShown() then return end
    votingFrame.voteBtnText:SetText(L["Waiting"] .. " (" .. voteCount .. "/" .. totalCount .. ")")
end

local function HideVotingPopup()
    if not votingFrame or not votingFrame:IsShown() then return end
    votingFrame:SetScript("OnUpdate", nil)

    -- Unlock checkboxes for next use
    for _, row in ipairs(checkboxRows) do
        row.checkbox.locked = nil
    end

    UIFrameFadeOut(votingFrame, VUI.FADE_DURATION, 1, 0)
    C_Timer.After(VUI.FADE_DURATION, function()
        if votingFrame then votingFrame:Hide() end
    end)
end

--------------------------------------------------------------------------------
-- Results Overlay
--------------------------------------------------------------------------------

local resultsFrame = nil
local resultIcons = {}   -- reusable icon frames
local pulseAnimGroup = nil

local function CreateResultsFrame()
    local frame = CreateFrame("Frame", "Fuloh_QoL_KV_ResultsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(RUI.WIDTH, RUI.HEIGHT)
    ApplyPosition("resultsPosition", frame, 0, 50)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition("resultsPosition", self)
    end)
    frame:Hide()

    -- Backdrop
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(unpack(VUI.BACKGROUND_COLOR))
    frame:SetBackdropBorderColor(unpack(VUI.BORDER_COLOR))

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

    -- Title
    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetTextColor(unpack(VUI.TITLE_COLOR))
    title:SetText(L["Vote Results"])

    -- Icons container
    local iconContainer = CreateFrame("Frame", nil, frame)
    iconContainer:SetPoint("CENTER", frame, "CENTER", 0, -5)
    iconContainer:SetSize(RUI.WIDTH - 40, RUI.ICON_SIZE_WINNER + 50)
    frame.iconContainer = iconContainer

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    closeBtn:SetSize(80, 28)
    closeBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
    closeBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    closeBtn:SetBackdropColor(0.25, 0.08, 0.08, 0.9)
    closeBtn:SetBackdropBorderColor(0.6, 0.2, 0.2, 0.8)

    local closeBtnText = closeBtn:CreateFontString(nil, "OVERLAY")
    closeBtnText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    closeBtnText:SetPoint("CENTER")
    closeBtnText:SetText(L["Close"])
    closeBtnText:SetTextColor(1.0, 0.4, 0.4)

    closeBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.4, 0.1, 0.1, 0.95)
        self:SetBackdropBorderColor(0.9, 0.3, 0.3, 1.0)
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.25, 0.08, 0.08, 0.9)
        self:SetBackdropBorderColor(0.6, 0.2, 0.2, 0.8)
    end)
    closeBtn:SetScript("OnClick", function()
        if onResultsDismiss then onResultsDismiss() end
    end)

    return frame
end

-- Get or create a result icon column at the given index
local function GetResultIcon(parent, index)
    if resultIcons[index] then
        return resultIcons[index]
    end

    local col = CreateFrame("Frame", nil, parent)
    col:SetSize(80, RUI.ICON_SIZE_WINNER + 50)

    -- Icon frame (with border) — SecureActionButton so spells can be cast on click
    local iconFrame = CreateFrame("Button", nil, col, "SecureActionButtonTemplate,BackdropTemplate")
    iconFrame:RegisterForClicks("AnyUp", "AnyDown")
    iconFrame:SetPoint("TOP", col, "TOP", 0, 0)
    iconFrame:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    col.iconFrame = iconFrame

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(iconFrame)
    col.icon = icon

    -- Glow texture for winner pulse
    local glow = iconFrame:CreateTexture(nil, "BACKGROUND", nil, 2)
    glow:SetTexture("Interface\\Buttons\\WHITE8x8")
    glow:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", -4, 4)
    glow:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 4, -4)
    glow:SetVertexColor(0.9, 0.7, 0.2, 0)
    col.glow = glow

    -- Key label (abbreviation + level)
    local label = col:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    label:SetPoint("TOP", iconFrame, "BOTTOM", 0, -4)
    label:SetJustifyH("CENTER")
    col.label = label

    -- Vote count
    local countText = col:CreateFontString(nil, "OVERLAY")
    countText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    countText:SetPoint("TOP", label, "BOTTOM", 0, -2)
    countText:SetJustifyH("CENTER")
    countText:SetTextColor(unpack(RUI.VOTE_COUNT_COLOR))
    col.countText = countText

    -- Winner text
    local winnerText = col:CreateFontString(nil, "OVERLAY")
    winnerText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    winnerText:SetPoint("TOP", countText, "BOTTOM", 0, -2)
    winnerText:SetJustifyH("CENTER")
    winnerText:SetTextColor(unpack(RUI.WINNER_COLOR))
    col.winnerText = winnerText

    resultIcons[index] = col
    return col
end

-- Abbreviate a dungeon name (first letters of each word)
local function AbbreviateName(name)
    if not name then return "?" end
    local abbr = ""
    for word in name:gmatch("%S+") do
        local first = word:sub(1, 1)
        if first:match("%a") then
            abbr = abbr .. first:upper()
        end
    end
    if #abbr < 2 then return name:sub(1, 4) end
    return abbr
end

-- Show the results overlay.
-- results = sorted array of { keyID, mapID, level, name, voteCount, isWinner }
local function ShowResults(results)
    if not resultsFrame then
        resultsFrame = CreateResultsFrame()
    end

    -- Hide all existing icons
    for _, col in ipairs(resultIcons) do
        col:Hide()
    end

    -- Stop any existing pulse
    if pulseAnimGroup then
        pulseAnimGroup:Stop()
        pulseAnimGroup = nil
    end

    local count = #results
    if count == 0 then return end

    -- Calculate spacing
    local colWidth = 80
    local totalWidth = count * colWidth
    local startX = -(totalWidth / 2) + (colWidth / 2)

    for i, r in ipairs(results) do
        local col = GetResultIcon(resultsFrame.iconContainer, i)
        local isWinner = r.isWinner
        local iconSize = isWinner and RUI.ICON_SIZE_WINNER or RUI.ICON_SIZE_NORMAL

        col.iconFrame:SetSize(iconSize, iconSize)
        col.icon:SetAllPoints(col.iconFrame)

        -- Dungeon texture (with fallback to teleport spell icon)
        local resolvedName, resolvedTexture = ResolveDungeonInfo(r.mapID)
        col.icon:SetTexture(resolvedTexture or "Interface\\Icons\\INV_Misc_QuestionMark")

        -- Border color
        local normalBorderColor = isWinner and { 0.9, 0.7, 0.2, 1.0 } or { 0.3, 0.3, 0.4, 0.6 }
        col.iconFrame:SetBackdropBorderColor(unpack(normalBorderColor))

        -- Teleport on icon click
        local GetTeleportSpell = QoL.Features.JoinedGroupReminder_GetDungeonTeleportSpellByMapID
        local HasTeleport      = QoL.Features.JoinedGroupReminder_HasDungeonTeleport
        local spellID = GetTeleportSpell and GetTeleportSpell(r.mapID)
        local canTeleport = spellID and HasTeleport and HasTeleport(spellID)

        if canTeleport then
            col.iconFrame:EnableMouse(true)
            col.iconFrame:SetAttribute("type", "spell")
            col.iconFrame:SetAttribute("spell", spellID)
            col.iconFrame:SetScript("OnEnter", function(self)
                self:SetBackdropBorderColor(0.3, 0.8, 1.0, 1.0)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetSpellByID(spellID)
                GameTooltip:AddLine(L["Click to teleport"], 0.5, 0.5, 0.5)
                GameTooltip:Show()
            end)
            col.iconFrame:SetScript("OnLeave", function(self)
                self:SetBackdropBorderColor(unpack(normalBorderColor))
                GameTooltip:Hide()
            end)
        else
            col.iconFrame:EnableMouse(false)
            col.iconFrame:SetAttribute("type", nil)
            col.iconFrame:SetAttribute("spell", nil)
            col.iconFrame:SetScript("OnEnter", nil)
            col.iconFrame:SetScript("OnLeave", nil)
        end

        -- Label
        local abbr = AbbreviateName(r.name or resolvedName)
        col.label:SetText(abbr .. " +" .. r.level)
        col.label:SetTextColor(unpack(isWinner and RUI.WINNER_COLOR or RUI.NORMAL_COLOR))

        -- Vote count
        local voteWord = (r.voteCount == 1) and L["vote"] or L["votes"]
        col.countText:SetText(r.voteCount .. " " .. voteWord)

        -- Winner text
        if isWinner then
            col.winnerText:SetText(L["Winner"])
            col.winnerText:Show()
        else
            col.winnerText:SetText("")
            col.winnerText:Hide()
        end

        -- Glow for winner
        if isWinner then
            col.glow:SetVertexColor(0.9, 0.7, 0.2, 0)
            -- Create pulse animation
            if not pulseAnimGroup then
                pulseAnimGroup = col.glow:CreateAnimationGroup()
                pulseAnimGroup:SetLooping("BOUNCE")
                local fadeIn = pulseAnimGroup:CreateAnimation("Alpha")
                fadeIn:SetFromAlpha(0)
                fadeIn:SetToAlpha(0.2)
                fadeIn:SetDuration(0.8)
                fadeIn:SetSmoothing("IN_OUT")
            end
            pulseAnimGroup:Play()
        else
            col.glow:SetAlpha(0)
        end

        -- Position
        col:SetPoint("CENTER", resultsFrame.iconContainer, "CENTER", startX + (i - 1) * colWidth, 0)
        col:Show()
    end

    resultsFrame:SetAlpha(0)
    resultsFrame:Show()
    UIFrameFadeIn(resultsFrame, RUI.FADE_DURATION, 0, 1)
end

local function HideResults()
    if not resultsFrame or not resultsFrame:IsShown() then return end

    if pulseAnimGroup then
        pulseAnimGroup:Stop()
        pulseAnimGroup = nil
    end

    UIFrameFadeOut(resultsFrame, RUI.FADE_DURATION, 1, 0)
    C_Timer.After(RUI.FADE_DURATION, function()
        if resultsFrame then resultsFrame:Hide() end
    end)
end

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

QoL.Features.KeyVote_ShowVotingPopup  = ShowVotingPopup
QoL.Features.KeyVote_UpdateVotingPopup = UpdateVotingPopup
QoL.Features.KeyVote_LockVotingPopup  = LockVotingPopup
QoL.Features.KeyVote_UpdateWaitingCount = UpdateWaitingCount
QoL.Features.KeyVote_HideVotingPopup  = HideVotingPopup
QoL.Features.KeyVote_ShowResults      = ShowResults
QoL.Features.KeyVote_HideResults      = HideResults

QoL.Features.KeyVote_SetVoteSubmitCallback = function(cb) onVoteSubmit = cb end
QoL.Features.KeyVote_SetVoteCloseCallback  = function(cb) onVoteClose = cb end
QoL.Features.KeyVote_SetResultsDismissCallback = function(cb) onResultsDismiss = cb end
