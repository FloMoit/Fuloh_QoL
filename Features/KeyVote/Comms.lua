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

local function SendStart(sessionID, duration)
    Send(Constants.OPCODE_START .. ":" .. sessionID .. ":" .. (duration or Constants.VOTE_DURATION))
end

local function SendPing(pingID)
    Send(Constants.OPCODE_PING .. ":" .. pingID)
end

local function SendPong(pingID, mapID, level, name)
    Send(Constants.OPCODE_PONG .. ":" .. pingID .. ":" .. (mapID or 0) .. ":" .. (level or 0) .. ":" .. (name or ""))
end

local function SendKey(sessionID, mapID, level, name)
    -- Name is appended as last field (may be empty, may contain special chars)
    Send(Constants.OPCODE_KEY .. ":" .. sessionID .. ":" .. mapID .. ":" .. level .. ":" .. (name or ""))
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
        local duration = tonumber(parts[3]) or Constants.VOTE_DURATION
        return { opcode = opcode, sessionID = sessionID, duration = duration }

    elseif opcode == Constants.OPCODE_PING then
        -- parts[2] is pingID (reused from sessionID slot)
        return { opcode = opcode, pingID = sessionID }

    elseif opcode == Constants.OPCODE_PONG then
        -- KVPONG:pingID:mapID:level:name  (name is last field, may be empty)
        if #parts < 4 then return nil end
        local mapID = tonumber(parts[3])
        local level = tonumber(parts[4])
        if not mapID or not level then return nil end
        -- Grab everything after the 4th colon for name (same pattern as KVKEY)
        local pos = 0
        for i = 1, 4 do
            pos = payload:find(":", pos + 1, true)
            if not pos then break end
        end
        local name = pos and payload:sub(pos + 1) or nil
        if name == "" then name = nil end
        return { opcode = opcode, pingID = sessionID, mapID = mapID, level = level, name = name }

    elseif opcode == Constants.OPCODE_KEY then
        if #parts < 4 then return nil end
        local mapID = tonumber(parts[3])
        local level = tonumber(parts[4])
        if not mapID or not level then return nil end
        -- Name is everything after the 4th colon (last field, may contain colons)
        local pos = 0
        for i = 1, 4 do
            pos = payload:find(":", pos + 1, true)
            if not pos then break end
        end
        local name = pos and payload:sub(pos + 1) or nil
        if name == "" then name = nil end
        return { opcode = opcode, sessionID = sessionID, mapID = mapID, level = level, name = name }

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

QoL.Features.KeyVote_SendStart    = SendStart
QoL.Features.KeyVote_SendKey      = SendKey
QoL.Features.KeyVote_SendVote     = SendVote
QoL.Features.KeyVote_SendCancel   = SendCancel
QoL.Features.KeyVote_SendPing     = SendPing
QoL.Features.KeyVote_SendPong     = SendPong
QoL.Features.KeyVote_ParseMessage = ParseMessage
