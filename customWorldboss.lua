--
-- Created by IntelliJ IDEA.
-- User: Silvia
-- Date: 17/05/2021
-- Time: 19:50
-- To change this template use File | Settings | File Templates.
-- Originally created by Honey for Azerothcore
-- requires ElunaLua module


-- This module spawns (custom) NPCs and grants them scripted combat abilities
------------------------------------------------------------------------------------------------
-- ADMIN GUIDE:  -  compile the core with ElunaLua module
--               -  adjust config in this file
--               -  add this script to ../lua_scripts/
--               -  run .initcustomworldboss to add the required NPCs
------------------------------------------------------------------------------------------------
-- GM GUIDE:     -  use .startevent $event $difficulty to start and spawn 
--               -  maybe offer teleports               '
------------------------------------------------------------------------------------------------
local Config = {}
local Config_npcEntry = {}
local Config_addAmount = {}

-- Name of Eluna dB scheme
local Config.customDbName = "ac_eluna"
-- Min GM rank to start an event
local Config.GMRankForEventStart = 2
-- Min GM rank to add NPCs to the db
local Config.GMRankForUpdateDB = 3
-- set to 1 to print error messages to the console. Any other value including nil turns it off.
local Config.printErrorsToConsole = 1 

-- NPC to spawn for event [n]
Config_npcEntry[1] = 1112001
Config_addAmount[1] = 3

------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------

local PLAYER_EVENT_ON_COMMAND = 42       -- (event, player, command) - player is nil if command used from console. Can return false
local TEMPSUMMON_DEAD_DESPAWN = 7        -- despawns when the creature disappears
local TEMPSUMMON_MANUAL_DESPAWN = 8      -- despawns when UnSummon() is called
local GOSSIP_EVENT_ON_SELECT = 2         -- (event, player, object, sender, intid, code, menu_id)

local eventNPC
local difficulty
local eventInProgress
local cancelGossipEvent
-- todo: make a function to add the custom NPC to creature_template

local function eS_command(event, player, command)
    local commandArray = {}

    --prevent players from using this  
    if player ~= nil then  
        if player:GetGMRank() < Config.minGMRankForBind then
            return
        end  
    end
  
    -- split the command variable into several strings which can be compared individually
    commandArray = eS_splitString(command)

    if commandArray[2] ~= nil then
        commandArray[2] = commandArray[2]:gsub("[';\\, ]", "")
        if commandArray[3] ~= nil then
            commandArray[3] = commandArray[3]:gsub("[';\\, ]", "")
        end
    end
  
    if commandArray[2] == nil then commandArray[2] = 1 end
    if commandArray[3] == nil then commandArray[3] = 1 end
  
    if commandArray[1] == "startevent" then
        eventNPC = tonumber(commandArray[2])
        difficulty = tonumber(commandArray[3])
        summonEventNPC()
        return false
    end
    
    --prevent non-Admins from using the rest
    if player ~= nil then  
        if player:GetGMRank() < Config.GMRankForUpdateDB then
            return
        end  
    end
    
    if commandArray[] == "initcustomworldboss" then
        initCustomWorldBoss()
    end
end
    
local function summonEventNPC()
    -- tempSummon an NPC with a dialouge option to start the encounter
    print("summonEventNPC")
    -- add an event to spawn the Boss in a phase when the only gossip is clicked
    cancelGossipEvent = RegisterCreatureGossipEvent(Config_npcEntry[n], GOSSIP_EVENT_ON_SELECT, spawnBoss)   
end

local function initCustomWorldBoss()
    -- query to add the costom NPCs to the db
    print("initCustomWorldBoss")
end

local function spawnBoss(event, player, object, sender, intid, code, menu_id)
    print("spawnBoss")
    --spawn the boss in another phase
    --move the whole raid to the boss-phase
end

local function getSize(difficulty)
    local value
    if diffculty == 1 then
        value = 1
    else
        value = (difficulty - 1) / 4
    end
    return value
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

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, eS_command)

--todo: Try creating a gossip
