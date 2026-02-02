-- Utils.lua
-- HelloWorld pure functions for greeting logic (testable without WoW environment)

-- Get namespace reference
local QoL = Fuloh_QoL
if not QoL then
    error("Fuloh_QoL namespace not found. Core.lua must load first.")
    return
end

-- Create utils table
local Utils = {}

Utils.DefaultGreetings = {
    "o/",
    "Hey!",
    "Hello there!",
    "Hello!",
}

--- Determines if and where the addon should send a greeting
-- @param oldState table - { inHome: boolean, inInst: boolean, numMembers: number }
-- @param newState table - { inHome: boolean, inInst: boolean, numMembers: number }
-- @param enabled boolean - whether the addon is enabled
-- @return string|nil - The chat channel to use, or nil if shouldn't greet
function Utils.GetGreetingChannel(oldState, newState, enabled)
    if not enabled then return nil end

    local isSolo = (newState.numMembers or 0) <= 1
    if isSolo then return nil end

    -- Trigger conditions:
    -- 1. We just joined a group category (Home or Instance)
    -- 2. We were a "group of 1" and someone else joined
    local groupJoined = newState.inHome and not oldState.inHome
    local instJoined = newState.inInst and not oldState.inInst
    local firstMemberJoined = (newState.numMembers or 0) > 1 and (oldState.numMembers or 0) <= 1

    -- Priority 1: Instance Chat (LFG, BGs, LFR)
    if instJoined or (newState.inInst and firstMemberJoined) then
        return "INSTANCE_CHAT"
    end

    -- Priority 2: Party Chat (Manual group)
    if groupJoined or firstMemberJoined then
        -- Don't double-greet if we are already in an instance
        if newState.inInst then return nil end
        -- Don't greet in manual raids unless it's a BG (handled by inInst check above)
        if IsInRaid() then return nil end

        return "PARTY"
    end

    return nil
end

-- Export to Fuloh_QoL.Features namespace
QoL.Features.HelloWorld_Utils = Utils
