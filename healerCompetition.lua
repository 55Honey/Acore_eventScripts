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

local Config = {}                       -- General config flags

-- Name of Eluna dB scheme
Config.customDbName = "ac_eluna"
-- Min GM rank to start an event
Config.GMRankForEventStart = 2
-- Min GM rank to add NPCs to the db
Config.GMRankForUpdateDB = 3
-- Set to 1 to print error messages to the console. Any other value including nil turns it off.
Config.printErrorsToConsole = 1
-- Npc to talk to when starting the competition
Config.npcEntry = 1114001
-- Text to display when talking to the npc
Config.npcText = 92111
-- Phase to send players to while they're doing the event. Phases 1+2 are left out by default.
Config.Phase = 4

------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------

--constants
local PLAYER_EVENT_ON_COMMAND = 42          -- (event, player, command) - player is nil if command used from console. Can return false
local GOSSIP_EVENT_ON_HELLO = 1             -- (event, player, object) - Object is the Creature/GameObject/Item. Can return false to do default action. For item gossip can return false to stop spell casting.
local GOSSIP_EVENT_ON_SELECT = 2            -- (event, player, object, sender, intid, code, menu_id)
local OPTION_ICON_CHAT = 0
local CLASS_WARRIOR = 1                     -- Warrior
local CLASS_PALADIN = 2                     -- Paladin
local CLASS_HUNTER = 3                      -- Hunter
local CLASS_ROGUE = 4                       -- Rogue
local CLASS_PRIEST = 5                      -- Priest
local CLASS_DEATH_KNIGHT = 6                -- Death Knight
local CLASS_SHAMAN = 7                      -- Shaman
local CLASS_MAGE = 8                        -- Mage
local CLASS_WARLOCK = 9                     -- Warlock
local CLASS_DRUID = 11                      -- Druid

-- local variables
local encounterStartTime
local activePlayerGuid
local activeLevel
local playerClass

--local arrays
local spawnedCreatureGuid = {}
local beatenLevel = {}

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

local function eS_getTimeSince(time)
    local dt = GetTimeDiff(time)
    return dt
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
    if activeLevel ~= nil then
        creature:SendUnitSay("A hero is still trying to rescue the victims of the past since "..eS_getEncounterDuration(), 0 )
        player:GossipMenuAddItem(OPTION_ICON_CHAT, "What's my score?", Config.npcEntry, 0)
        return
    end

    if player == nil then return end
    playerClass = player:GetClass()

    player:GossipMenuAddItem(OPTION_ICON_CHAT, "What's my score?", Config.npcEntry, 0)
    player:GossipMenuAddItem(OPTION_ICON_CHAT, "Who's the best healer?", Config.npcEntry, 1)
    if playerClass == 2 or playerClass == 5 or playerClass == 7 or playerClass == 11 then
        player:GossipMenuAddItem(OPTION_ICON_CHAT, "I want to retry the same challenge!", Config.npcEntry, 2)
        player:GossipMenuAddItem(OPTION_ICON_CHAT, "I want to try a new challenge!", Config.npcEntry, 3)
    end
    player:GossipSendMenu(Config.npcText, creature, 0)
end

local function storeEncounter()
    local gameTime = (tonumber(tostring(GetGameTime())))
    local playerLowGuid = GetGUIDLow(activePlayerGuid)
    CharDBExecute('INSERT IGNORE INTO `'..Config.customDbName..'`.`eventscript_healer_challenge` VALUES ('..gameTime..', '..playerClass..', '..playerLowGuid..', '..activeLevel..', '..eS_getTimeSince(encounterStartTime)..');');
    activeLevel = nil
end

local function eS_healerGossip(event, player, object, sender, intid, code, menu_id)
    if player == nil then return end
    local playerLowGuid = GetGUIDLow(activePlayerGuid)
    if intid == 0 then
        if playerClass == 2 or playerClass == 5 or playerClass == 7 or playerClass == 11 then
            if beatenLevel[playerLowGuid] == nil then
                player:SendBroadcastMessage("You haven't beaten a level in this competition yet.")
            else
                player:SendBroadcastMessage("Your highest beaten level is: "..beatenLevel[playerLowGuid])
            end
        else
            player:SendBroadcastMessage("You are not a healer unfortunately. I am sure there are other tasks for you in Azeroth.")
        end
        player:GossipComplete()

    elseif intid == 1 then
        --todo: print records in chat

    elseif intid == 2 then

        if beatenLevel[playerLowGuid] == nil then
            beatenLevel[playerLowGuid] = 0
        end

        activeLevel = beatenLevel[playerLowGuid]

        encounterStartTime = GetCurrTime()

        player:SetPhaseMask(Config.Phase)
        activePlayerGuid = player:GetGUID()

        --todo: add an event to spawn things to heal
        --todo: add an event to check if things die or are full
        --todo: make fully healed NPCs despawn and make the player loose if something dies
    elseif intid == 3 then

        if beatenLevel[playerLowGuid] == nil then
            beatenLevel[playerLowGuid] = 0
        end

        activeLevel = beatenLevel[playerLowGuid] + 1

        encounterStartTime = GetCurrTime()

        player:SetPhaseMask(Config.Phase)
        activePlayerGuid = player:GetGUID()

        --todo: add an event to spawn things to heal
        --todo: add an event to check if things die or are full
        --todo: make full things despawn and make the player loose if something dies
    end
    player:GossipComplete()
end

--on ReloadEluna / Startup
CharDBQuery('CREATE DATABASE IF NOT EXISTS `'..Config.customDbName..'`;');
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..Config.customDbName..'`.`eventscript_encounters` (`playerGuid` INT NOT NULL, `difficulty` INT DEFAULT 1, `time_stamp` INT NOT NULL, `duration` INT NOT NULL, PRIMARY KEY (`playerGuid`, `time_stamp`));');

--todo: read records from db on startup