--
--
-- Created by IntelliJ IDEA.
-- User: Silvia
-- Date: 08/07/2021
-- Time: 13:26
-- To change this template use File | Settings | File Templates.
-- Originally created by Honey for Azerothcore
-- requires ElunaLua module


-- This module spawns (custom) NPCs and grants them scripted combat abilities
------------------------------------------------------------------------------------------------
-- ADMIN GUIDE:  -  compile the core with ElunaLua module
--               -  adjust config in this file
--               -  add this script to ../lua_scripts/
--               -  adjust the IDs and config flags in case of conflicts and run the associated SQL to add the required NPCs
------------------------------------------------------------------------------------------------
-- GM GUIDE:     -  add instructions here
------------------------------------------------------------------------------------------------

----------------------------------------
-- Begin of config section
------------------------------------------

local Config = {}                       --general config flags

-- Name of Eluna dB scheme
Config.customDbName = "ac_eluna"
-- Min GM rank to start an event
Config.GMRankForEventStart = 2
-- Min GM rank to add NPCs to the db
Config.GMRankForUpdateDB = 3
-- set to 1 to print error messages to the console. Any other value including nil turns it off.
Config.printErrorsToConsole = 1
-- npc to talk to when starting the competition
Config.npcEntry = 1114001
-- Text to display when talking to the npc
Config.npcText = 92111

--constants
local PLAYER_EVENT_ON_COMMAND = 42          -- (event, player, command) - player is nil if command used from console. Can return false
local GOSSIP_EVENT_ON_HELLO = 1             -- (event, player, object) - Object is the Creature/GameObject/Item. Can return false to do default action. For item gossip can return false to stop spell casting.
local GOSSIP_EVENT_ON_SELECT = 2            -- (event, player, object, sender, intid, code, menu_id)
local OPTION_ICON_CHAT = 0

local encounterStartTime
local triageInProgress
local variables

--local arrays
local spawnedCreatureGuid = {}

local function eS_has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

local function eS_returnIndex (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return index
        end
    end
    return false
end

local function eS_getEncounterDuration()
    local dt = GetTimeDiff(encounterStartTime)
    return string.format("%.2d:%.2d", (dt / 1000 / 60) % 60, (dt / 1000) % 60)
end

local function eS_splitString(inputstr, seperator)
    if seperator == nil then
        seperator = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..seperator.."]+)") do
        table.insert(t, str)
    end
    return t
end

local function eS_onHello(event, player, creature)
    if triageInProgress ~= nil then
        creature:SendUnitSay("A hero is still trying to rescue the victims of the past since "..eS_getEncounterDuration(), 0 )
        player:GossipMenuAddItem(OPTION_ICON_CHAT, "What's my score?", Config_npcEntry[eventInProgress], 0)
        return
    end

    if player == nil then return end
    player:GossipMenuAddItem(OPTION_ICON_CHAT, "What's my score?", Config.npcEntry, 0)
    player:GossipMenuAddItem(OPTION_ICON_CHAT, "I want to try a new challenge!", Config.npcEntry, 1)
    player:GossipSendMenu(Config.npcText, creature, 0)
end
