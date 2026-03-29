-- Comms.lua
-- KeyVote addon message serialization, sending, and parsing
-- Pure send/parse utilities — no state management

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

local Constants = QoL.Features.KeyVote_Constants

--------------------------------------------------------------------------------
-- Sending
--------------------------------------------------------------------------------

local function Send(payload)
    C_ChatInfo.SendAddonMessage(Constants.ADDON_PREFIX, payload, "PARTY")
end

local function SendStart(sessionID)
    Send(Constants.OPCODE_START .. ":" .. sessionID)
end

local function SendKey(sessionID, mapID, level)
    Send(Constants.OPCODE_KEY .. ":" .. sessionID .. ":" .. mapID .. ":" .. level)
end

local function SendVote(sessionID, selectedKeys)
    -- selectedKeys = { "mapID-level", "mapID-level", ... }
    local keyList = table.concat(selectedKeys, ",")
    Send(Constants.OPCODE_VOTE .. ":" .. sessionID .. ":" .. keyList)
end

local function SendCancel(sessionID)
    Send(Constants.OPCODE_CANCEL .. ":" .. sessionID)
end

--------------------------------------------------------------------------------
-- Parsing
--------------------------------------------------------------------------------

-- Split a string by delimiter
local function Split(str, delim)
    local result = {}
    for part in str:gmatch("[^" .. delim .. "]+") do
        result[#result + 1] = part
    end
    return result
end

-- Parse an incoming addon message payload.
-- Returns a table: { opcode, sessionID, ... } or nil on invalid message.
local function ParseMessage(payload)
    if not payload or payload == "" then return nil end

    local parts = Split(payload, ":")
    if #parts < 2 then return nil end

    local opcode = parts[1]
    local sessionID = parts[2]

    if opcode == Constants.OPCODE_START then
        return { opcode = opcode, sessionID = sessionID }

    elseif opcode == Constants.OPCODE_KEY then
        if #parts < 4 then return nil end
        local mapID = tonumber(parts[3])
        local level = tonumber(parts[4])
        if not mapID or not level then return nil end
        return { opcode = opcode, sessionID = sessionID, mapID = mapID, level = level }

    elseif opcode == Constants.OPCODE_VOTE then
        -- parts[3] is the comma-separated key list (may be empty for abstain)
        local keyList = parts[3] or ""
        local selectedKeys = {}
        if keyList ~= "" then
            for entry in keyList:gmatch("[^,]+") do
                selectedKeys[#selectedKeys + 1] = entry
            end
        end
        return { opcode = opcode, sessionID = sessionID, selectedKeys = selectedKeys }

    elseif opcode == Constants.OPCODE_CANCEL then
        return { opcode = opcode, sessionID = sessionID }
    end

    return nil
end

--------------------------------------------------------------------------------
-- Exports
--------------------------------------------------------------------------------

QoL.Features.KeyVote_SendStart   = SendStart
QoL.Features.KeyVote_SendKey     = SendKey
QoL.Features.KeyVote_SendVote    = SendVote
QoL.Features.KeyVote_SendCancel  = SendCancel
QoL.Features.KeyVote_ParseMessage = ParseMessage
