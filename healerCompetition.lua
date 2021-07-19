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
-- GM GUIDE:     -  nothing to do, it's full auto mode
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
Config.npcEntry = 1114100
-- Starting entry for the woudned NPCs. Default 1114001 will result in 1114001-1114012 being used
Config.woundedEntry = 1114001
-- Text to display when talking to the npc
Config.npcText = 92111
-- Phase to send players to while they're doing the event. Phases 1+2 are left out by defaull
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
local CREATURE_EVENT_ON_SPAWN = 5           -- (event, creature) - Can return true to stop normal action

-- local variables
local encounterStartTime
local activePlayerGuid
local activeLevel
local playerClass
local lastRecordPrinted = 0

--local arrays
local spawnedCreatureGuid = {}              -- currently spawned creature
local beatenLevel = {}                      -- highest beaten level per characterGuid
local beatenLevelTime = {}                  -- duration for highest beaten level per characterGuid
local recordLevel = {}                      -- record per healerclass
local recordTime = {}                       -- record per healerclass
local recordName = {}                       -- name of the record holder per healerclass

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

local function eS_healNPCEvent(event, delay, pCall, creature)
    if creature:IsFullHealth() == true then
        --todo: if hp full remove NPC from creature guid table and despawn it. if table is empty and no spawns left, end event with victory.
    elseif creature:IsDead() == true then
        --todo: if dead: End event. player lost. Despawn all remaining NPCs. Stop events.
    end   
end

local function eS_startEvent()
    --todo: move the player to Config.Phase
    --todo: Store all spawned creature guids in a table
    --todo: schedule events which spawn things to heal based on the timer
end

local function es_stopEvent()
    local player = GetPlayerByGUID(activePlayerGuid)
    player:SetPhaseMask(1)
    --todo: more stuff to add probably
end

local function eS_onSpawn(event, creature)
    creature:RegisterEvent(eS_healNPCEvent, 100, 0)
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
        if eS_getTimeSince(lastRecordPrinted) > 10000 then

        else
            player:SendBroadcastMessage("You've just been told.")
        end

    elseif intid == 2 then

        if beatenLevel[playerLowGuid] == nil then
            beatenLevel[playerLowGuid] = 0
        end

        activeLevel = beatenLevel[playerLowGuid]

        encounterStartTime = GetCurrTime()

        player:SetPhaseMask(Config.Phase)
        activePlayerGuid = player:GetGUID()

        eS_startEvent()
    elseif intid == 3 then

        if beatenLevel[playerLowGuid] == nil then
            beatenLevel[playerLowGuid] = 0
        end

        activeLevel = beatenLevel[playerLowGuid] + 1

        encounterStartTime = GetCurrTime()

        player:SetPhaseMask(Config.Phase)
        activePlayerGuid = player:GetGUID()

        eS_startEvent()
    end
    player:GossipComplete()
end

--on ReloadEluna / Startup
CharDBQuery('CREATE DATABASE IF NOT EXISTS `'..Config.customDbName..'`;');
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..Config.customDbName..'`.`healer_levels` (`playerGuid` INT NOT NULL, `difficulty` INT DEFAULT 1, `time_stamp` INT NOT NULL, `duration` INT NOT NULL, PRIMARY KEY (`playerGuid`, `time_stamp`));');
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..Config.customDbName..'`.`healer_records` (`playerGuid` INT NOT NULL, `difficulty` INT DEFAULT 1, `duration` INT NOT NULL, `name` varchar(32), PRIMARY KEY (`playerGuid`));');

local Data_SQL = CharDBQuery('SELECT * FROM `'..Config.customDbName..'`.`healer_levels`;')
if Data_SQL ~= nil then
    local playerGuid
    repeat
        playerGuid = Data_SQL:GetUInt32(0)
        beatenLevel[playerGuid] = Data_SQL:GetUInt32(1)
        beatenLevelTime[playerGuid] = Data_SQL:GetUInt32(3)
    until not Data_SQL:NextRow()
end

local Data_SQL = CharDBQuery('SELECT * FROM `'..Config.customDbName..'`.`healer_records`;')
if Data_SQL ~= nil then
    local class
    repeat
        class = Data_SQL:GetUInt32(0)
        recordLevel[class] = Data_SQL:GetUInt32(1)
        recordTime[class] = Data_SQL:GetUInt32(2)
        recordName[class] = Data_SQL:GetString(3)
    until not Data_SQL:NextRow()
end
Data_SQL = nil

local cancelEventIdHello = RegisterCreatureGossipEvent(Config.npcEntry, GOSSIP_EVENT_ON_HELLO, eS_onHello)
local cancelEventIdStart = RegisterCreatureGossipEvent(Config.npcEntry, GOSSIP_EVENT_ON_SELECT, eS_healerGossip)

local n
for n = 1114001,1114001 + 11 do
    RegisterCreatureEvent(n, CREATURE_EVENT_ON_SPAWN, eS_onSpawn) -- OnSpawn
end

--todo: Find a non-spammy way to announce records
