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
-- Phase to send players to while they're doing the event. Phases 1+2 are left out by default
Config.Phase = 4

------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------

-- constants
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
local x
local y
local z
local o
local lastRecordPrinted = 0
local currentLevel
local nextWounded
local difficulty

-- local arrays
local spawnedCreatureGuid = {}              -- currently spawned creature
local beatenLevel = {}                      -- highest beaten level per characterGuid
local beatenLevelTime = {}                  -- duration for highest beaten level per characterGuid
local recordLevel = {}                      -- record per healerclass
local recordTime = {}                       -- record per healerclass
local recordName = {}                       -- name of the record holder per healerclass

-- level data
local levelSpawn = {}
levelSpawn[1] = { 1,2,1,3,1,2,4,2,5,2,3,1,6,1,2 }
levelSpawn[2] = { 2,2,1,3,2,2,4,3,5,2,3,2,6,1,2 }
levelSpawn[3] = { 2,2,3,3,2,2,4,3,5,2,3,2,6,3,2 }
levelSpawn[4] = { 3,9,3,3,2,7,4,3,5,2,3,2,6,3,6 }
levelSpawn[5] = { 6,9,3,3,8,7,4,3,5,10,3,7,6,3,6 }
levelSpawn[6] = { 6,9,8,4,8,7,4,4,5,10,3,7,6,11,6 }
levelSpawn[7] = { 7,11,8,4,8,7,8,4,9,10,7,7,6,11,10 }
levelSpawn[8] = { 7,11,8,8,12,7,8,8,9,10,11,7,10,11,10 }
levelSpawn[9] = { 7,11,8,8,12,7,8,8,9,10,11,7,10,11,10 }
levelSpawn[0] = { 10,11,8,11,12,10,8,11,9,10,11,8,10,11,12 }

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

local function eS_checkVictory()
    if nextWounded > 15 then
       for n = 1,15,1 do
           if spawnedCreatureGuid[n] ~= nil then
               return false
           end
       end
       return true
    else
        return false
    end
end

local function eS_storeEncounter()
    local gameTime = (tonumber(tostring(GetGameTime())))
    local playerLowGuid = GetGUIDLow(activePlayerGuid)
    CharDBExecute('INSERT IGNORE INTO `'..Config.customDbName..'`.`eventscript_healer_challenge` VALUES ('..gameTime..', '..playerClass..', '..playerLowGuid..', '..activeLevel..', '..eS_getTimeSince(encounterStartTime)..');');
    activeLevel = nil
end

local function es_stopEvent()
    local player = GetPlayerByGUID(activePlayerGuid)
    player:SetPhaseMask(1)
    --todo: more stuff to add probably
end

local function eS_healNPCEvent(event, delay, pCall, creature)
    local creatureIndex
    if creature:IsFullHealth() == true then
        --todo: if hp full remove NPC from creature guid table and despawn it. if table is empty and no spawns left, end event with victory.
        creatureIndex = eS_returnIndex(spawnedCreatureGuid,creature:GetGUID())
        creature:DespawnOrUnsummon(0)
        spawnedCreatureGuid[creatureIndex] = nil
        if eS_checkVictory() == true then
            eS_storeEncounter()
            es_stopEvent()
        end
    elseif creature:IsDead() == true then
        --todo: if dead: End event. player lost. Despawn all remaining NPCs. Stop events.
        es_stopEvent()
    end   
end

local function eS_spawnInjured()
    local spawnedCreature
    local player = GetPlayerByGUID(activePlayerGuid)

    local randomX = (math.sin(math.random(1,360)) * 7)
    local randomY = (math.sin(math.random(1,360)) * 7)
    spawnedCreature = player:SpawnCreature(Config.woundedEntry + levelSpawn[currentLevel][nextWounded], x + randomX, y + randomY, z+2, o)  --todo: fix this line
    spawnedCreature:SetPhaseMask(Config.Phase)

    spawnedCreatureGuid[nextWounded] = spawnedCreature:GetGUID()
    nextWounded = nextWounded + 1
end

local function eS_startEvent()
    difficulty = 0
    if currentLevel > 9 then
        repeat
            currentLevel = currentLevel - 10
            difficulty = difficulty + 1
        until currentLevel < 10
    end
    nextWounded = 1
    --todo: schedule events which spawn things to heal based on the timer
end

local function eS_onSpawn(event, creature)
    creature:RegisterEvent(eS_healNPCEvent, 100, 0)
end

local function eS_onHello(event, player, creature)
    if activeLevel ~= nil then
        creature:SendUnitSay("Another hero is still trying to rescue the victims of the past since "..eS_getEncounterDuration(), 0 )
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
            object:ToCreature():SendUnitSay("The dev forgot to print the records here.") --.todo. print records in /s
            lastRecordPrinted = GetCurrTime()
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

        x = player:GetX()
        y = player:GetY()
        z = player:GetZ()
        o = player:GetO()

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
for n = Config.woundedEntry,Config.woundedEntry + 11 do
    RegisterCreatureEvent(n, CREATURE_EVENT_ON_SPAWN, eS_onSpawn) -- OnSpawn
end

--todo: Find a non-spammy way to announce records
