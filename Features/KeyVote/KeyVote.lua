-- KeyVote.lua
-- Feature: Group vote on which Mythic+ keystone to run
-- State machine, event wiring, feature registration

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

-- Create feature object
local KeyVote = {
    name = "KeyVote",
    label = "Key Vote",
    shortcut = "vote",
    isEnabled = false,
}

-- Constants and Comms references (populated in Initialize)
local C, L
local SendStart, SendKey, SendVote, SendCancel, ParseMessage
local ShowVotingPopup, UpdateVotingPopup, LockVotingPopup, UpdateWaitingCount
local HideVotingPopup, ShowResults, HideResults

-- Private state
local eventFrame = CreateFrame("Frame")

local STATE_IDLE    = "IDLE"
local STATE_VOTING  = "VOTING"
local STATE_RESULTS = "RESULTS"

local session = {
    id = "",
    state = STATE_IDLE,
    initiator = "",
    startTime = 0,
    participants = {},    -- { [playerName] = { mapID=N, level=N, name="..." } }
    votes = {},           -- { [playerName] = { "mapID-level", ... } }
    myVoteSubmitted = false,
    timerHandle = nil,
    resultsTimerHandle = nil,
}

-- Forward declarations for functions referenced before definition
local StartVote, DismissResults

-- Color codes
local COLOR_PREFIX  = "|cff00bfff"
local COLOR_RESET   = "|r"
local COLOR_SUCCESS = "|cff44ff44"
local COLOR_GOLD    = "|cffffff00"

local function Print(msg)
    print(COLOR_PREFIX .. "[Key Vote]" .. COLOR_RESET .. " " .. msg)
end

-- Database accessor
local function GetDB()
    return Fuloh_QoLDB and Fuloh_QoLDB.KeyVote or {}
end

-- ResolveDungeonInfo reference (populated in Initialize)
local ResolveDungeonInfo

--------------------------------------------------------------------------------
-- Keystone Detection (local player)
--------------------------------------------------------------------------------

-- Scan bags for keystone display name (fallback when C_ChallengeMode returns nil).
-- Locale-independent: detects keystones via |Hkeystone: hyperlink tag, then strips
-- the localized prefix (e.g. "Keystone: " / "Clé de voûte : ") and level suffix.
local function ScanKeystoneName()
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink and info.hyperlink:find("|Hkeystone:", 1, true) then
                local displayName = info.hyperlink:match("%[(.+)%]")
                if displayName then
                    -- Strip everything up to and including the first ": " (works for all locales)
                    local name = displayName:match("^.+:%s*(.+)$") or displayName
                    -- Strip level suffix like " [10]"
                    name = name:gsub("%s*%[%d+%]$", "")
                    return name
                end
            end
        end
    end
    return nil
end

local function GetOwnKeystone()
    local mapID = C_MythicPlus.GetOwnedKeystoneMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()

    if not mapID or mapID == 0 or not level or level == 0 then
        return 0, 0, nil
    end

    -- Get display name: try C_ChallengeMode first, then bag scan
    local name = C_ChallengeMode.GetMapUIInfo(mapID)
    if not name then
        name = ScanKeystoneName()
    end

    return mapID, level, name
end

--------------------------------------------------------------------------------
-- Session Helpers
--------------------------------------------------------------------------------

local function ResetSession()
    if session.timerHandle then
        session.timerHandle:Cancel()
        session.timerHandle = nil
    end
    if session.resultsTimerHandle then
        session.resultsTimerHandle:Cancel()
        session.resultsTimerHandle = nil
    end
    session.id = ""
    session.state = STATE_IDLE
    session.initiator = ""
    session.startTime = 0
    session.participants = {}
    session.votes = {}
    session.myVoteSubmitted = false
end

-- Get the local player's name (without realm if same server)
local function GetPlayerName()
    local name = UnitName("player")
    return name or "Unknown"
end

-- Count participants and voters
local function GetParticipantCount()
    local count = 0
    for _ in pairs(session.participants) do count = count + 1 end
    return count
end

local function GetVoteCount()
    local count = 0
    for _ in pairs(session.votes) do count = count + 1 end
    return count
end

-- Build sorted keystone list from participants for UI display.
-- Groups by mapID-level, aggregates owner names.
local function BuildKeystoneList()
    local keyMap = {}  -- { ["mapID-level"] = { mapID, level, name, owners={} } }
    local order = {}   -- insertion order

    for playerName, data in pairs(session.participants) do
        local keyID = data.mapID .. "-" .. data.level
        if not keyMap[keyID] then
            keyMap[keyID] = {
                keyID = keyID,
                mapID = data.mapID,
                level = data.level,
                name = data.name,
                owners = {},
            }
            order[#order + 1] = keyID
        end
        local owners = keyMap[keyID].owners
        owners[#owners + 1] = playerName
    end

    -- Sort: real keys first (by level desc), then no-key entries
    local result = {}
    for _, keyID in ipairs(order) do
        result[#result + 1] = keyMap[keyID]
    end
    table.sort(result, function(a, b)
        if a.mapID == 0 and b.mapID ~= 0 then return false end
        if a.mapID ~= 0 and b.mapID == 0 then return true end
        if a.level ~= b.level then return a.level > b.level end
        return (a.name or "") < (b.name or "")
    end)

    return result
end

-- Tally votes and produce results.
-- Returns sorted array of { keyID, mapID, level, name, voteCount, isWinner }
local function TallyVotes()
    local tally = {}  -- { ["mapID-level"] = count }

    for _, selectedKeys in pairs(session.votes) do
        for _, keyID in ipairs(selectedKeys) do
            tally[keyID] = (tally[keyID] or 0) + 1
        end
    end

    -- Find max votes
    local maxVotes = 0
    for _, count in pairs(tally) do
        if count > maxVotes then maxVotes = count end
    end

    -- Build results from participant keystones (only real keys)
    local results = {}
    local seen = {}
    for _, data in pairs(session.participants) do
        if data.mapID ~= 0 then
            local keyID = data.mapID .. "-" .. data.level
            if not seen[keyID] then
                seen[keyID] = true
                local count = tally[keyID] or 0
                results[#results + 1] = {
                    keyID = keyID,
                    mapID = data.mapID,
                    level = data.level,
                    name = data.name,
                    voteCount = count,
                    isWinner = (count > 0 and count == maxVotes),
                }
            end
        end
    end

    -- Sort by vote count desc
    table.sort(results, function(a, b)
        if a.voteCount ~= b.voteCount then return a.voteCount > b.voteCount end
        return a.level > b.level
    end)

    return results
end

--------------------------------------------------------------------------------
-- State Transitions
--------------------------------------------------------------------------------

local function TransitionToResults()
    session.state = STATE_RESULTS

    if session.timerHandle then
        session.timerHandle:Cancel()
        session.timerHandle = nil
    end

    HideVotingPopup()

    local results = TallyVotes()
    ShowResults(results)

    -- Print local summary
    if #results > 0 and results[1].voteCount > 0 then
        local winner = results[1]
        local name = winner.name or C_ChallengeMode.GetMapUIInfo(winner.mapID) or "?"
        local totalVoters = GetVoteCount()
        Print(COLOR_GOLD .. name .. " +" .. winner.level .. COLOR_RESET .. " " .. L["wins"] .. " (" .. winner.voteCount .. "/" .. totalVoters .. " " .. L["votes"] .. ")")
    else
        Print(L["No active vote"])
    end

    -- Results stay visible until the user clicks to dismiss (no auto-hide)
end

DismissResults = function()
    HideResults()
    ResetSession()
end

local function CheckAllVoted()
    if session.state ~= STATE_VOTING then return end

    local participantCount = GetParticipantCount()
    local voteCount = GetVoteCount()

    if voteCount >= participantCount and participantCount > 0 then
        TransitionToResults()
    end
end

--------------------------------------------------------------------------------
-- Protocol Handlers
--------------------------------------------------------------------------------

local function HandleStart(senderName, msg)
    if session.state ~= STATE_IDLE then return end

    session.id = msg.sessionID
    session.state = STATE_VOTING
    session.initiator = senderName
    session.startTime = GetTime()
    session.participants = {}
    session.votes = {}
    session.myVoteSubmitted = false

    -- Send own key (including name so other clients can use it)
    local mapID, level, name = GetOwnKeystone()
    SendKey(session.id, mapID, level, name)

    -- Add self as participant immediately
    session.participants[GetPlayerName()] = { mapID = mapID, level = level, name = name }

    -- Show voting popup
    local keystones = BuildKeystoneList()
    ShowVotingPopup(session, keystones)

    -- Start vote timer
    session.timerHandle = C_Timer.NewTimer(C.VOTE_DURATION, function()
        if session.state == STATE_VOTING then
            TransitionToResults()
        end
    end)
end

local function HandleKey(senderName, msg)
    if session.state ~= STATE_VOTING then return end
    if msg.sessionID ~= session.id then return end

    -- Resolve display name: prefer sender's name (from protocol), then local resolution,
    -- then keep any existing name we already have for this participant.
    local displayName = msg.name
    if not displayName and msg.mapID ~= 0 then
        displayName = ResolveDungeonInfo(msg.mapID)
    end
    local existing = session.participants[senderName]
    if not displayName and existing then
        displayName = existing.name
    end

    session.participants[senderName] = {
        mapID = msg.mapID,
        level = msg.level,
        name = displayName,
    }

    -- Update UI
    local keystones = BuildKeystoneList()
    UpdateVotingPopup(session, keystones)
end

local function HandleVote(senderName, msg)
    if session.state ~= STATE_VOTING then return end
    if msg.sessionID ~= session.id then return end

    -- Record vote (use event sender, not payload)
    session.votes[senderName] = msg.selectedKeys

    -- Update waiting count in UI
    local voteCount = GetVoteCount()
    local totalCount = GetParticipantCount()
    UpdateWaitingCount(voteCount, totalCount)

    CheckAllVoted()
end

local function HandleCancel(senderName, msg)
    if session.state == STATE_IDLE then return end
    if msg.sessionID ~= session.id then return end

    HideVotingPopup()
    HideResults()
    ResetSession()
    Print(L["Vote cancelled"])
end

--------------------------------------------------------------------------------
-- Event Handlers
--------------------------------------------------------------------------------

local function OnChatMsgAddon(prefix, payload, _, senderName)
    if prefix ~= C.ADDON_PREFIX then return end
    if not KeyVote.isEnabled then return end

    -- Strip realm name if present (e.g., "Player-Realm" -> "Player")
    local shortName = senderName:match("^([^-]+)") or senderName

    local msg = ParseMessage(payload)
    if not msg then return end

    if msg.opcode == C.OPCODE_START then
        HandleStart(shortName, msg)
    elseif msg.opcode == C.OPCODE_KEY then
        HandleKey(shortName, msg)
    elseif msg.opcode == C.OPCODE_VOTE then
        HandleVote(shortName, msg)
    elseif msg.opcode == C.OPCODE_CANCEL then
        HandleCancel(shortName, msg)
    end
end

local function OnGroupRosterUpdate()
    if session.state == STATE_IDLE then return end

    -- If we left the group entirely, cancel
    if not IsInGroup() then
        HideVotingPopup()
        HideResults()
        ResetSession()
        return
    end

    -- Remove participants who left the group
    local groupMembers = {}
    local numMembers = GetNumGroupMembers()
    for i = 1, numMembers do
        local name = GetRaidRosterInfo(i)
        if name then
            local shortName = name:match("^([^-]+)") or name
            groupMembers[shortName] = true
        end
    end

    local removed = false
    for playerName in pairs(session.participants) do
        if not groupMembers[playerName] then
            session.participants[playerName] = nil
            session.votes[playerName] = nil
            removed = true
        end
    end

    if removed and session.state == STATE_VOTING then
        local keystones = BuildKeystoneList()
        UpdateVotingPopup(session, keystones)
        CheckAllVoted()
    end
end

local function OnChatMsgParty(msg, senderName)
    if not KeyVote.isEnabled then return end

    local db = GetDB()
    if not db.enableChatTrigger then return end

    -- Only react to own messages
    local playerName = GetPlayerName()
    local shortSender = senderName:match("^([^-]+)") or senderName
    if shortSender ~= playerName then return end

    local lower = msg:lower()
    if lower == "!vote" or lower == "!keyvote" then
        StartVote()
    end
end

local function OnEvent(self, event, ...)
    if event == "CHAT_MSG_ADDON" then
        OnChatMsgAddon(...)
    elseif event == "GROUP_ROSTER_UPDATE" then
        OnGroupRosterUpdate()
    elseif event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
        OnChatMsgParty(...)
    end
end

--------------------------------------------------------------------------------
-- Vote Actions
--------------------------------------------------------------------------------

StartVote = function()
    if session.state ~= STATE_IDLE then
        Print(L["Already active"])
        return
    end

    if not IsInGroup() then
        Print(L["Not in group"])
        return
    end

    local playerName = GetPlayerName()
    local sessionID = playerName .. "-" .. math.floor(GetTime())

    -- Broadcast KVSTART
    SendStart(sessionID)

    -- Handle our own start (since CHAT_MSG_ADDON delivers our own messages too,
    -- this will be handled by HandleStart — but we call it directly to ensure
    -- immediate UI response regardless of addon message delivery timing)
    -- The HandleStart checks state == IDLE, so the duplicate from CHAT_MSG_ADDON
    -- will be safely ignored since we've already transitioned to VOTING.
    HandleStart(playerName, { opcode = C.OPCODE_START, sessionID = sessionID })
end

local function CancelVote()
    if session.state == STATE_IDLE then
        Print(L["No active vote"])
        return
    end

    if session.initiator ~= GetPlayerName() then
        Print("Only the initiator can cancel the vote.")
        return
    end

    SendCancel(session.id)
    HideVotingPopup()
    HideResults()
    ResetSession()
    Print(L["Vote cancelled"])
end

local function OnLocalVoteSubmit(selectedKeys)
    if session.state ~= STATE_VOTING then return end
    if session.myVoteSubmitted then return end

    session.myVoteSubmitted = true

    -- Broadcast our vote
    SendVote(session.id, selectedKeys)

    -- Record locally
    session.votes[GetPlayerName()] = selectedKeys

    -- Lock UI
    local voteCount = GetVoteCount()
    local totalCount = GetParticipantCount()
    LockVotingPopup(voteCount, totalCount)

    CheckAllVoted()
end

local function OnLocalVoteClose()
    if session.state ~= STATE_VOTING then return end

    -- If initiator, cancel for everyone
    if session.initiator == GetPlayerName() then
        CancelVote()
    else
        -- Non-initiator: just hide locally (counts as abstain)
        HideVotingPopup()
    end
end

--------------------------------------------------------------------------------
-- Test Commands (debug UI preview)
--------------------------------------------------------------------------------

local function TestVotingUI()
    local fakeSession = {
        initiator = GetPlayerName(),
        startTime = GetTime(),
    }
    local fakeKeystones = {
        { keyID = "2660-10", mapID = 2660, level = 10, name = "Ara-Kara, City of Echoes", owners = { "PlayerA", "PlayerC" } },
        { keyID = "2652-12", mapID = 2652, level = 12, name = "The Stonevault", owners = { "PlayerB" } },
        { keyID = "2661-8",  mapID = 2661, level = 8,  name = "Cinderbrew Meadery", owners = { "PlayerD" } },
        { keyID = "0-0",     mapID = 0,    level = 0,  name = nil, owners = { "PlayerE" } },
    }
    ShowVotingPopup(fakeSession, fakeKeystones)
    Print("Test voting UI shown. Close with X or ESC.")
end

local function TestResultsUI()
    local fakeResults = {
        { keyID = "2652-12", mapID = 2652, level = 12, name = "The Stonevault", voteCount = 3, isWinner = true },
        { keyID = "2660-10", mapID = 2660, level = 10, name = "Ara-Kara, City of Echoes", voteCount = 2, isWinner = false },
        { keyID = "2661-8",  mapID = 2661, level = 8,  name = "Cinderbrew Meadery", voteCount = 1, isWinner = false },
    }
    ShowResults(fakeResults)
    Print("Test results UI shown. Click to dismiss.")
end

--------------------------------------------------------------------------------
-- Feature API Implementation
--------------------------------------------------------------------------------

function KeyVote:Initialize()
    -- Get references to constants and helpers
    C = QoL.Features.KeyVote_Constants
    L = C.L
    ResolveDungeonInfo = QoL.Features.KeyVote_ResolveDungeonInfo

    -- Get references to comms functions
    SendStart   = QoL.Features.KeyVote_SendStart
    SendKey     = QoL.Features.KeyVote_SendKey
    SendVote    = QoL.Features.KeyVote_SendVote
    SendCancel  = QoL.Features.KeyVote_SendCancel
    ParseMessage = QoL.Features.KeyVote_ParseMessage

    -- Get references to UI functions
    ShowVotingPopup  = QoL.Features.KeyVote_ShowVotingPopup
    UpdateVotingPopup = QoL.Features.KeyVote_UpdateVotingPopup
    LockVotingPopup  = QoL.Features.KeyVote_LockVotingPopup
    UpdateWaitingCount = QoL.Features.KeyVote_UpdateWaitingCount
    HideVotingPopup  = QoL.Features.KeyVote_HideVotingPopup
    ShowResults      = QoL.Features.KeyVote_ShowResults
    HideResults      = QoL.Features.KeyVote_HideResults

    -- Register UI callbacks
    QoL.Features.KeyVote_SetVoteSubmitCallback(OnLocalVoteSubmit)
    QoL.Features.KeyVote_SetVoteCloseCallback(OnLocalVoteClose)
    QoL.Features.KeyVote_SetResultsDismissCallback(DismissResults)

    -- Register addon message prefix (must be eager — messages before registration are dropped)
    C_ChatInfo.RegisterAddonMessagePrefix(C.ADDON_PREFIX)

    -- Pre-warm the M+ map data cache so C_ChallengeMode.GetMapUIInfo() returns data
    if C_MythicPlus and C_MythicPlus.RequestMapInfo then
        C_MythicPlus.RequestMapInfo()
    end
end

function KeyVote:Enable()
    self.isEnabled = true

    eventFrame:SetScript("OnEvent", OnEvent)
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("CHAT_MSG_PARTY")
    eventFrame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
end

function KeyVote:Disable()
    self.isEnabled = false

    eventFrame:UnregisterAllEvents()
    eventFrame:SetScript("OnEvent", nil)

    -- Clean up any active session
    HideVotingPopup()
    HideResults()
    ResetSession()
end

function KeyVote:GetDefaults()
    return {
        enabled = false,
        enableChatTrigger = true,
    }
end

function KeyVote:HandleCommand(args)
    local cmd = args:lower():match("^(%S+)") or args:lower()

    if cmd == "" or cmd == "start" then
        StartVote()
    elseif cmd == "cancel" then
        CancelVote()
    elseif cmd == "toggle" then
        QoL:ToggleFeature("KeyVote")
    elseif cmd == "test" then
        TestVotingUI()
    elseif cmd == "testresult" then
        TestResultsUI()
    elseif cmd == "help" then
        Print("Commands:")
        print("  /fuloh vote          - Start a key vote")
        print("  /fuloh vote cancel   - Cancel the current vote")
        print("  /fuloh vote toggle   - Toggle feature on/off")
        print("  /fuloh vote test     - Preview the voting UI")
        print("  /fuloh vote testresult - Preview the results UI")
    else
        -- Default: try to start a vote
        StartVote()
    end
end

-- Register this feature
QoL:RegisterFeature(KeyVote)
