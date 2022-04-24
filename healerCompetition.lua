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
-- Starting entry for the woudned NPCs. Default 1114000 will result in 1114001-1114012 being used
Config.woundedEntry = 1114000
-- Text to display when talking to the npc
Config.npcText = 92111
-- Phase to send players to while they're doing the event. Phases 1+2 are left out by default
Config.encounterPhases = {4,8,16,32,64,128,256,512,1024,2048,4096,8192,16384,32768,65536,131072 }
-- Map where the events happen(must match the spawn of the event NPC)
Config.mapId = 0
-- Modificator for health increase of injured NPCs per level
Config.healthMod = 100
-- Base health for injured NPCs
Config.baseHealth = 1000

------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------

-- constants
local PLAYER_EVENT_ON_LOGOUT = 4            -- (event, player)
local PLAYER_EVENT_ON_MAP_CHANGE = 28       -- (event, player)
local PLAYER_EVENT_ON_COMMAND = 42          -- (event, player, command) - player is nil if command used from console. Can return false
local GOSSIP_EVENT_ON_HELLO = 1             -- (event, player, object) - Object is the Creature/GameObject/Item. Can return false to do default action. For item gossip can return false to stop spell casting.
local GOSSIP_EVENT_ON_SELECT = 2            -- (event, player, object, sender, intid, code, menu_id)
local CREATURE_EVENT_ON_SPAWN = 5           -- (event, creature) - Can return true to stop normal action
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

local function eS_newAutotable(dim)
    local MT = {};
    for i=1, dim do
        MT[i] = {__index = function(t, k)
            if i < dim then
                t[k] = setmetatable({}, MT[i+1])
                return t[k];
            end
        end}
    end

    return setmetatable({}, MT[1]);
end

-- local variables
local x
local y
local z
local o
local lastRecordPrinted = 0

local beatenLevel = {}                          -- highest beaten level per characterGuid
local beatenLevelTime = {}                      -- duration for highest beaten level per characterGuid
local recordLevel = {}                          -- record per healerclass
local recordTime = {}                           -- record per healerclass
local recordName = {}                           -- name of the record holder per healerclass

-- events
local cancelSpawns = {}
local cancelEndEvent = {}
local spawnedCreatureGuid = eS_newAutotable(2)              -- spawned creature guid [encounter Id 1-16][Spawn 1-15]
local cancelSpawnedCreatureEvents = eS_newAutotable(2)      -- eventIds where the spawned creatures are getting damaged [encounter Id 1-16][eventId of Spawn 1-15]

local encounterStartTime = {}
local activePlayerGuid = {}
local activeLevel = {}
local activePlayerClass = {}
local nextWounded = {}
local difficulty = {}

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
levelSpawn[10] = { 10,11,8,11,12,10,8,11,9,10,11,8,10,11,12 }

local function eS_hasValue (tab, val)
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

local function eS_getEncounterDuration(phaseId)
    local dt = GetTimeDiff(encounterStartTime[phaseId])
    return string.format("%.2d:%.2d", (dt / 1000 / 60) % 60, (dt / 1000) % 60)
end

local function eS_formatTime(beatenLevelTime)
    return string.format("%.2d:%.2d", (beatenLevelTime / 1000 / 60) % 60, (beatenLevelTime / 1000) % 60)
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

local function eS_getFreePhaseId()
    local n
    for n = 1,16 do
        if activePlayerGuid[n] == nil then
            return n
        end
    end
    return 0
end

local function eS_getSpawnTimer(activeLevel)
    return 3000 + ( 300 * activeLevel )
end

local function eS_getDurationTimer(activeLevel)
    return 15 * eS_getSpawnTimer(activeLevel) + 15000
end

local function eS_getMaxHealth(level)
    --return health based on a formula to be found
    return level * Config.healthMod + Config.baseHealth
end

local function eS_getEventIndex(eventid,array)
    for ind,val in pairs(array) do
        if val == eventid then
            return ind
        end
    end
    return 0
end

local function eS_accounceNewLevel()
    -- todo
end

local function eS_announceNewTime()
    -- todo
end

local function eS_SaveToDB(playerLowGuid)
    -- todo
end

local function eS_SaveRecordsToDB()
    -- todo
end

local function eS_lightDamage(eventId, delay, repeats, creature)
    -- todo
end

local function eS_heavyDamage(eventId, delay, repeats, creature)
    -- todo
end

local function eS_saveAndCheckRecords(phaseId,player)
    local class = activePlayerClass[phaseId]
    local playerGuid = activePlayerGuid[phaseId]
    local playerLowGuid = GetLowGUID(playerGuid)
    local duration = eS_getTimeSince(encounterStartTime[phaseId])

    if activeLevel[phaseId] > beatenLevel[playerLowGuid] then
        beatenLevel[playerLowGuid] = activeLevel[phaseId]
        eS_accounceNewLevel()
        eS_SaveToDB(playerLowGuid)
    elseif activeLevel[phaseId] == beatenLevel[playerLowGuid] and duration < beatenLevelTime[playerLowGuid] then
        beatenLevelTime[playerLowGuid] = duration
        eS_announceNewTime()
        eS_SaveToDB(playerLowGuid)
    end

    if beatenLevel[playerLowGuid] > recordLevel[class] then
        recordLevel[class] = beatenLevel[playerLowGuid]
        recordTime[class] = duration
        recordName[class] = player:GetName()
        eS_SaveRecordsToDB()
    elseif beatenLevel[playerLowGuid] == recordLevel[class] and duration < recordTime[class] then
        recordTime[class] = duration
        recordName[class] = player:GetName()
        eS_SaveRecordsToDB()
    end

end

local function eS_wipeEvent(phaseId,player)
    local map = GetMapById(Config.mapId)

    RemoveEventById(cancelSpawns[phaseId])
    RemoveEventById(cancelEndEvent[phaseId])

    local success = 1

    for n = 1, 15 do
        if cancelSpawnedCreatureEvents[phaseId][n] then
            RemoveEventById(cancelSpawnedCreatureEvents[phaseId][n])
        end
        cancelSpawnedCreatureEvents[phaseId][n] = nil
        print('-----------------------------------------------------')
        print('- Checking creature -')
        print('n: '..n)
        print('phaseId: '..phaseId)
        print('spawnedCreatureGuid[phaseId][n]:')
        print(spawnedCreatureGuid[phaseId][n])
        print('-----------------------------------------------------')

        if (spawnedCreatureGuid[phaseId][n]) then
            local creature = map:GetWorldObject(spawnedCreatureGuid[phaseId][n])
            if(creature) then
                print('271')
                if not creature:IsFullHealth() then
                    success = 0
                end

                spawnedCreatureGuid[phaseId][n] = nil
                creature:DespawnOrUnsummon(0)
            end
        end
    end

    if success == 1 then
        --store and save success
        eS_saveAndCheckRecords(phaseId,player)
    else
        --outro failure
    end

    activeLevel[phaseId] = nil
    encounterStartTime[phaseId] = nil
    activePlayerGuid[phaseId] = nil
    activePlayerClass[phaseId] = nil
    nextWounded[phaseId] = nil
    difficulty[phaseId] = nil
    cancelSpawns[phaseId] = nil
    cancelEndEvent[phaseId] = nil

    -- todo: check for missing stuff
end

local function eS_getPhaseIdByPlayer(player)
    --if the player doesn't log out in a relevant area, skip it.
    if player:GetMap():GetMapId() ~= Config.mapId then
        return 0
    end

    for n = 1,16 do
        if player:GetGUID() == activePlayerGuid[n] then
            return n
        end
    end
    return 0
end

local function eS_stopEvent(eventid, delay, repeats, player)
    local phaseId = eS_getEventIndex(eventid,cancelEndEvent)
    eS_wipeEvent(phaseId,player)
end

local function eS_checkNPCEvent(eventid, delay, repeats, worldobject)
    if worldobject:ToCreature():IsFullHealth() then
        worldobject:RemoveEvents()
    end
end

local function eS_spawnInjured(eventid, delay, repeats, player)
    local phaseId = eS_getEventIndex(eventid,cancelSpawns)
    local spawnedCreature
    local randomX = (math.sin(math.random(1,360)) * 7)
    local randomY = (math.sin(math.random(1,360)) * 7)
    local npcId = levelSpawn[difficulty[phaseId]][nextWounded[phaseId]]
    local npcEntry = Config.woundedEntry + npcId

    spawnedCreature = player:SpawnCreature(npcEntry, x + randomX, y + randomY, z + 0.2, o)
    spawnedCreatureGuid[phaseId][nextWounded[phaseId]] = spawnedCreature:GetGUID()
    print('-----------------------------------------------------')
    print('- Spawning -')
    print('phaseId: '..phaseId)
    print('nextWounded[phaseId]: '..nextWounded[phaseId])
    print('spawnedCreatureGuid[phaseId][nextWounded[phaseId]]:')
    print(spawnedCreatureGuid[phaseId][nextWounded[phaseId]])
    print('-----------------------------------------------------')
    spawnedCreature:SetLevel(difficulty[phaseId])
    local maxHealth = eS_getMaxHealth(activeLevel[phaseId])
    spawnedCreature:SetMaxHealth(maxHealth)

    if npcId == 4 or npcId == 8 or npcId == 12 then
        spawnedCreature:SetHealth(math.floor(maxHealth / 5))
    elseif npcId == 3 or npcId == 7 or npcId == 11 then
        spawnedCreature:SetHealth(math.floor(maxHealth / 4))
    elseif npcId == 2 or npcId == 6 or npcId == 10 then
        spawnedCreature:SetHealth(math.floor(maxHealth / 3))
    elseif npcId == 1 or npcId == 5 or npcId == 9 then
        spawnedCreature:SetHealth(math.floor(maxHealth / 2))
    end

    if npcId > 8 then
        -- register event to damage heavily
        cancelSpawnedCreatureEvents[phaseId][nextWounded[phaseId]] = spawnedCreature:RegisterEvent(eS_heavyDamage, delay, 0)
    elseif npcId > 4 then
        -- register event to damage lightly
        cancelSpawnedCreatureEvents[phaseId][nextWounded[phaseId]] = spawnedCreature:RegisterEvent(eS_lightDamage, delay, 0)
    end

    spawnedCreature:RegisterEvent(eS_checkNPCEvent, 100, 0)
    spawnedCreature:SetPhaseMask(Config.encounterPhases[phaseId])
    nextWounded[phaseId] = nextWounded[phaseId] + 1
end

local function eS_startEvent(phaseId, player, playerClass)
    encounterStartTime[phaseId] = GetCurrTime()
    activePlayerGuid[phaseId] = player:GetGUID()
    activePlayerClass[phaseId] = playerClass
    player:SetPhaseMask(Config.encounterPhases[phaseId])

    difficulty[phaseId] = 1
    if activeLevel[phaseId] > 10 then
        local currentLevel = activeLevel[phaseId]
        repeat
            currentLevel = currentLevel - 10
            difficulty[phaseId] = difficulty[phaseId] + 1
        until currentLevel < 10
    end
    nextWounded[phaseId] = 1

    -- one level has 15 adds max, so call it 15 times
    cancelSpawns[phaseId] = player:RegisterEvent(eS_spawnInjured, eS_getSpawnTimer(activeLevel[phaseId]), 15)
    -- event is ended regardless after a certain time. Same needs to happen when player logs out.
    cancelEndEvent[phaseId] = player:RegisterEvent(eS_stopEvent, eS_getDurationTimer(activeLevel[phaseId]), 1)
end

local function eS_onHello(event, player, creature)
    if player == nil then return end
    local playerClass = player:GetClass()
    local playerLowGuid = player:GetGUIDLow()
    player:GossipMenuAddItem(OPTION_ICON_CHAT, "What's my score?", Config.npcEntry, 0)
    player:GossipMenuAddItem(OPTION_ICON_CHAT, "Who's the best healer?", Config.npcEntry, 1)
    if eS_getFreePhaseId() > 0 then
        if playerClass == 2 or playerClass == 5 or playerClass == 7 or playerClass == 11 then
            if beatenLevel[playerLowGuid] ~= nil then
                player:GossipMenuAddItem(OPTION_ICON_CHAT, "I want to retry the same challenge!", Config.npcEntry, 2)
            end
            player:GossipMenuAddItem(OPTION_ICON_CHAT, "I want to try a new challenge!", Config.npcEntry, 3)
        end
    else
        creature:SendUnitSay("Another hero is still trying to rescue the victims of the past since "..eS_getEncounterDuration(), 0 )
    end
    player:GossipSendMenu(Config.npcText, creature, 0)

end

local function eS_healerGossip(event, player, object, sender, intid, code, menu_id)
    if player == nil then return end
    local playerLowGuid = player:GetGUIDLow()
    local playerClass = player:GetClass()

    if intid == 0 then
        if playerClass == 2 or playerClass == 5 or playerClass == 7 or playerClass == 11 then
            local missionString = "mission"
            if beatenLevel[playerLowGuid] == nil then
                player:SendBroadcastMessage("You haven't beaten a level in this competition yet.")
            else
                if beatenLevel[playerLowGuid] ~= 1 then
                    missionString = "missions"
                end
                player:SendBroadcastMessage(player:GetName()..", you've saved the victims of the past in "..beatenLevel[playerLowGuid].." "..missionString.." so far. It took you "..eS_formatTime(beatenLevelTime[playerLowGuid]).." to finish the last mission.")
            end
        else
            player:SendBroadcastMessage("You are not a healer unfortunately. I am sure there are other tasks for you in Azeroth.")
        end
        player:GossipComplete()

    elseif intid == 1 then
        if eS_getTimeSince(lastRecordPrinted) > 10000 then
            object:ToCreature():SendUnitSay("The dev forgot to print the records here.",0) --:todo print records in /s
            lastRecordPrinted = GetCurrTime()
        else
            player:SendBroadcastMessage("You've just been told.")
        end

    elseif intid >= 2 then
        local freePhaseId = eS_getFreePhaseId()
        if freePhaseId == 0 then
            object:ToCreature():SendUnitSay("Too many heroes are already trying to rescue the victims of the past. Hold on a second!", 0 )
            player:GossipComplete()
        end

        if beatenLevel[playerLowGuid] == nil then
            beatenLevel[playerLowGuid] = 0
        end

        if intid == 3 then
            activeLevel[freePhaseId] = beatenLevel[playerLowGuid] + 1
        else
            activeLevel[freePhaseId] = beatenLevel[playerLowGuid]
        end

        x = object:ToCreature():GetX()
        y = object:ToCreature():GetY()
        z = object:ToCreature():GetZ()
        o = object:ToCreature():GetO()

        eS_startEvent(freePhaseId,player,playerClass)

        player:GossipComplete()
    end
end

local function eS_checkPlayerPresence(event, player)
    local phaseId = eS_getPhaseIdByPlayer(player)
    if phaseId ~= nil and phaseId ~= 0 then
        eS_wipeEvent(phaseId,player)
    end
end

--on ReloadEluna / Startup
CharDBQuery('CREATE DATABASE IF NOT EXISTS `'..Config.customDbName..'`;');
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..Config.customDbName..'`.`healer_levels` (`playerGuid` INT NOT NULL, `difficulty` INT DEFAULT 1, `time_stamp` INT NOT NULL, `duration` INT NOT NULL, PRIMARY KEY (`playerGuid`, `time_stamp`));');
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..Config.customDbName..'`.`healer_records` (`playerGuid` INT NOT NULL, `difficulty` INT DEFAULT 1, `duration` INT NOT NULL, `name` varchar(32), PRIMARY KEY (`playerGuid`));');

local Data_SQL = CharDBQuery('SELECT * FROM `'..Config.customDbName..'`.`healer_levels`;')
if Data_SQL ~= nil then
    local playerGuidLow
    repeat
        playerGuidLow = Data_SQL:GetUInt32(0)
        beatenLevel[playerGuidLow] = Data_SQL:GetUInt32(1)
        beatenLevelTime[playerGuidLow] = Data_SQL:GetUInt32(3)
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

RegisterPlayerEvent(PLAYER_EVENT_ON_LOGOUT, eS_checkPlayerPresence)
RegisterPlayerEvent(PLAYER_EVENT_ON_MAP_CHANGE, eS_checkPlayerPresence)


--todo: Find a non-spammy way to announce records (probably /say from Lushen in BB)
--todo: Grant a reward. e.g. Mana potions
