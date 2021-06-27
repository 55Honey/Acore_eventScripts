--
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
--               -  adjust the IDs and config flags in case of conflicts and run the associated SQL to add the required NPCs
--               -  the acore_cms module assumes that 1112001 is the boss of encounter 1 and adding +10 for each subsequent encounter
--                  (1112011 = boss for encounter 2 / 1112021 = boss for encounter 3, etc.)
------------------------------------------------------------------------------------------------
-- GM GUIDE:     -  use .startevent $event $difficulty to start and spawn 
--               -  maybe offer teleports
--               -  use .stopevent to end the event and despawn the NPC
------------------------------------------------------------------------------------------------
local Config = {}                       --general config flags

local Config_npcEntry = {}              --db entry of the NPC creature to summon the boss
local Config_npcText = {}               --gossip in npc_text to be told by the summoning NPC
local Config_bossEntry = {}             --db entry of the boss creature
local Config_addEntry = {}              --db entry of the add creature

local Config_bossSpell1 = {}            --directly applied to the tank
local Config_bossSpell2 = {}            --randomly applied to a player in 35m range
local Config_bossSpell3 = {}            --on the 2nd nearest player within 30m
local Config_bossSpell4 = {}            --on a random player within 40m
local Config_bossSpell5 = {}            --directly applied to the tank with adds alive
local Config_bossSpell6 = {}            --directly applied to the tank when adds are dead
local Config_bossSpellSelf = {}         --cast on boss while adds are still alive
local Config_bossSpellEnrage = {}       --cast on boss once after Config_bossSpellEnrageTimer ms have passed

local Config_bossSpellTimer1 = {}       -- This timer applies to Config_bossSpell1 (in ms)
local Config_bossSpellTimer2 = {}       -- This timer applies to Config_bossSpell2 (in ms)
local Config_bossSpellTimer3 = {}       -- This timer applies to Config_bossSpellSelf in phase 1 and Config_bossSpell3+4 randomly later (in ms)
-- local Config_bossSpellTimer4 = {}    -- Not used. Timer3 covers BossSpells 3+4
local Config_bossSpellTimer5 = {}       -- This timer applies to Config_bossSpell5+6 (in ms)
local Config_bossSpellEnrageTimer = {}

local Config_addSpell1 = {}             -- min range 30m, 1-3rd farthest target within 30m
local Config_addSpell2 = {}             -- min range 45m, cast on tank
local Config_addSpell3 = {}             -- min range 0m
local Config_addSpell4 = {}             -- cast on the boss

local Config_addSpellEnrage = {}        -- This spell will be cast on the add in 5man mode only after 300 seconds
local Config_addSpellTimer1 = {}        -- This timer applies to Config_addSpell1 (in ms)
local Config_addSpellTimer2 = {}        -- This timer applies to Config_addSpell2 (in ms)
local Config_addSpellTimer3 = {}        -- This timer applies to Config_addSpell3 (in ms)
local Config_addSpellTimer4 = {}        -- This timer applies to Config_addSpell4 (in ms)

local Config_addsAmount = {}            -- how many adds will spawn
local Config_aura1Add1 = {}             -- an aura to add to the 1st add
local Config_aura2Add1 = {}             -- another aura to add to the 1st add
local Config_aura1Add2 = {}             -- an aura to add to the 2nd add
local Config_aura2Add2 = {}             -- another aura to add to the 2nd add
local Config_aura1Add3 = {}             -- an aura to add to the 3rd add
local Config_aura2Add3 = {}             -- another aura to add to the 3rd add

local Config_addSpell3Yell = {}         -- yell for the add when Spell 3 is cast
local Config_bossYellPhase2 = {}        -- yell for the boss when phase 2 starts

local Config_fireworks = {}

------------------------------------------
-- Begin of config section
------------------------------------------

-- Name of Eluna dB scheme
Config.customDbName = "ac_eluna"
-- Min GM rank to start an event
Config.GMRankForEventStart = 2
-- Min GM rank to add NPCs to the db
Config.GMRankForUpdateDB = 3
-- set to 1 to print error messages to the console. Any other value including nil turns it off.
Config.printErrorsToConsole = 1
-- time in ms before adds enrage in 5man mode
Config.addEnrageTimer = 300000
-- spell to cast at 33 and 66%hp in party mode
Config.addEnoughSpell = 19471
-- base score per encounter
Config.baseScore = 40
-- additional score per difficulty level
Config.additionalScore = 10
-- set to award score for beating raids. Any other value including nil turns it off.
Config.rewardRaid = 1
-- set to 1 to store succesful raid attempts in the db. Any other value including nil turns it off.
Config.storeRaid = 1
-- set to award score for beating party encounter. Any other value including nil turns it off.
Config.rewardParty = 0
-- set to 1 to store succesful party attempts in the db. Any other value including nil turns it off.
Config.storeParty = 1

------------------------------------------
-- Begin of encounter 1 config
------------------------------------------

-- Database NPC entries. Must match the associated .sql file
Config_bossEntry[1] = 1112001           --db entry of the boss creature
Config_npcEntry[1] = 1112002            --db entry of the NPC creature to summon the boss
Config_addEntry[1] = 1112003            --db entry of the add creature
Config_npcText[1] = 91111               --gossip in npc_text to be told by the summoning NPC

-- list of spells:
Config_addSpell1[1] = 12421             -- min range 30m, 1-3rd farthest target within 30m -- Mithril Frag Bomb 8y 149-201 damage + stun
Config_addSpell2[1] = 60488             -- min range 45m, cast on tank -- Shadow Bolt (30)
Config_addSpell3[1] = 24326             -- min range 0m -- HIGH knockback (ZulFarrak beast)
Config_addSpell4[1] = nil               -- this line is not neccesary. If a spell is missing it will just be skipped
Config_addSpellEnrage[1] = 69166        -- Soft Enrage

Config_bossSpell1[1] = 38846            --directly applied to the tank-- Forceful Cleave (Target + nearest ally)
Config_bossSpell2[1] = 45108            --randomly applied to a player in 35m range-- CKs Fireball
Config_bossSpell3[1] = 53721            --on the 2nd nearest player within 30m-- Death and decay (10% hp per second)
Config_bossSpell4[1] = 37279            --on a random player within 40m-- Rain of Fire
Config_bossSpell5[1] = nil              --this line is not neccesary. If a spell is missing it will just be skipped
Config_bossSpell6[1] = nil              --this line is not neccesary. If a spell is missing it will just be skipped
Config_bossSpellSelf[1] = 69898         --cast on boss while adds are still alive-- Hot
Config_bossSpellEnrage[1] = 69166       --cast on boss once after Config_bossSpellEnrageTimer ms have passed-- Soft Enrage

Config_addSpellTimer1[1] = 13000        -- This timer applies to Config_addSpell1
Config_addSpellTimer2[1] = 11000        -- This timer applies to Config_addSpell2
Config_addSpellTimer3[1] = 37000        -- This timer applies to Config_addSpell3
Config_addSpellTimer4[1] = nil          -- This timer applies to Config_addSpell4

Config_bossSpellTimer1[1] = 19000       -- This timer applies to Config_bossSpell1
Config_bossSpellTimer2[1] = 23000       -- This timer applies to Config_bossSpell2
Config_bossSpellTimer3[1] = 11000       -- This timer applies to Config_bossSpellSelf in phase 1 and Config_bossSpell3+4 randomly later
Config_bossSpellTimer5[1] = nil         -- This timer applies to Config_bossSpell5+6
Config_bossSpellEnrageTimer[1] = 180000

Config_addsAmount[1] = 3                -- how many adds will spawn

Config_aura1Add1[1] = 34184             -- an aura to add to the 1st add-- Arcane
Config_aura2Add1[1] = 7941              -- another aura to add to the 1st add-- Nature
Config_aura1Add2[1] = 7942              -- an aura to add to the 2nd add-- Fire
Config_aura2Add2[1] = 7940              -- another aura to add to the 2nd add-- Frost
Config_aura1Add3[1] = 34182             -- an aura to add to the 3rd add-- Holy
Config_aura2Add3[1] = 34309             -- another aura to add to the 3rd add-- Shadow

Config_addSpell3Yell[1] = "Me smash."   -- yell for the add when Spell 3 is cast
Config_bossYellPhase2[1] = "You might have handled these creatures. But now I WILL handle YOU!"

------------------------------------------
-- Begin of encounter 2 config
------------------------------------------

-- Database NPC entries. Must match the associated .sql file
Config_bossEntry[2] = 1112011           --db entry of the boss creature
Config_npcEntry[2] = 1112002            --db entry of the NPC creature to summon the boss
Config_addEntry[2] = 1112013            --db entry of the add creature
Config_npcText[2] = 91111               --gossip in npc_text to be told by the summoning NPC

-- list of spells:
Config_addSpell1[2] = 10150             -- min range 30m, 1-3rd farthest target within 30m
Config_addSpell2[2] = 37704             -- min range 45m, cast on tank
Config_addSpell3[2] = 68958             -- min range 0m -- Blast Nova
Config_addSpell4[2] = 69389             -- cast on the boss
Config_addSpellEnrage[2] = nil          -- Soft Enrage

Config_bossSpell1[2] = 33661            --directly applied to the tank-- Crush Armor: 10% reduction, stacks
Config_bossSpell2[2] = 51503            --randomly applied to a player in 35m range-- Domination
Config_bossSpell3[2] = 35198            --on the 2nd nearest player within 30m-- AE fear
Config_bossSpell4[2] = 35198            --on a random player within 40m-- AE Fear
Config_bossSpell5[2] = nil              --this line is not neccesary. If a spell is missing it will just be skipped
Config_bossSpell6[2] = 31436            --directly applied to the tank when adds are dead
Config_bossSpellSelf[2] = nil           --cast on boss while adds are still alive
Config_bossSpellEnrage[2] = 54356       --cast on boss once after Config_bossSpellEnrageTimer ms have passed-- Soft Enrage

Config_addSpellTimer1[2] = 13000        -- This timer applies to Config_addSpell1
Config_addSpellTimer2[2] = 11000        -- This timer applies to Config_addSpell2
Config_addSpellTimer3[2] = 37000        -- This timer applies to Config_addSpell3
Config_addSpellTimer4[2] = 23000        -- This timer applies to Config_addSpell4

Config_bossSpellTimer1[2] = 10000       -- This timer applies to Config_bossSpell1
Config_bossSpellTimer2[2] = 23000       -- This timer applies to Config_bossSpell2
Config_bossSpellTimer3[2] = 29000       -- This timer applies to Config_bossSpellSelf in phase 1 and Config_bossSpell3+4 randomly later
Config_bossSpellTimer5[2] = 19000       -- This timer applies to Config_bossSpell5+6
Config_bossSpellEnrageTimer[2] = 180000

Config_addsAmount[2] = 2                -- how many adds will spawn

Config_aura1Add1[2] = nil               -- an aura to add to the 1st add-- Arcane
Config_aura2Add1[2] = nil               -- another aura to add to the 1st add-- Nature
Config_aura1Add2[2] = nil               -- an aura to add to the 2nd add-- Fire
Config_aura2Add2[2] = nil               -- another aura to add to the 2nd add-- Frost
Config_aura1Add3[2] = nil               -- an aura to add to all ads from the 3rd on-- Holy
Config_aura2Add3[2] = nil               -- another aura to add to all add from the 3rd on-- Shadow

Config_addSpell3Yell[2] = "Thissss."    -- yell for the add when Spell 3 is cast
Config_bossYellPhase2[2] = "Now. You. Die."

------------------------------------------
-- End of encounter 2
------------------------------------------

-- these are the fireworks to be cast randomly for 20s when an encounter was beaten
Config_fireworks[1] = 66400
Config_fireworks[2] = 66402
Config_fireworks[3] = 46847
Config_fireworks[4] = 46829
Config_fireworks[5] = 46830
Config_fireworks[6] = 62074
Config_fireworks[7] = 62075
Config_fireworks[8] = 62077
Config_fireworks[9] = 55420

------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------

--constants
local PLAYER_EVENT_ON_LOGOUT = 4            -- (event, player)
local PLAYER_EVENT_ON_REPOP = 35            -- (event, player)
local PLAYER_EVENT_ON_COMMAND = 42          -- (event, player, command) - player is nil if command used from console. Can return false
local TEMPSUMMON_MANUAL_DESPAWN = 8         -- despawns when UnSummon() is called
local GOSSIP_EVENT_ON_HELLO = 1             -- (event, player, object) - Object is the Creature/GameObject/Item. Can return false to do default action. For item gossip can return false to stop spell casting.
local GOSSIP_EVENT_ON_SELECT = 2            -- (event, player, object, sender, intid, code, menu_id)
local OPTION_ICON_CHAT = 0
local OPTION_ICON_BATTLE = 9

local SELECT_TARGET_RANDOM = 0              -- Just selects a random target
local SELECT_TARGET_TOPAGGRO = 1            -- Selects targets from top aggro to bottom
local SELECT_TARGET_BOTTOMAGGRO = 2         -- Selects targets from bottom aggro to top
local SELECT_TARGET_NEAREST = 3
local SELECT_TARGET_FARTHEST = 4

local PARTY_IN_PROGRESS = 1
local RAID_IN_PROGRESS = 2

--local variables
local cancelGossipEvent
local eventInProgress
local bossfightInProgress
local difficulty                            -- difficulty is set when using .startevent and it is meant for a range of 1-10
local addsDownCounter
local phase
local addphase
local x
local y
local z
local o
local spawnedBossGuid
local spawnedNPCGuid
local encounterStartTime
local mapEventStart

local lastBossSpell1
local lastBossSpell2
local lastBossSpell3
local lastBossSpell5
local lastBossSpellSelf
local lastAddSpell1 = {}
local lastAddSpell2 = {}
local lastAddSpell3 = {}
local lastAddSpell4 = {}

--local arrays
local cancelEventIdHello = {}
local cancelEventIdStart = {}
local addNPC = {}
local bossNPC = {}
local playersInRaid = {}
local groupPlayers = {}
local playersForFireworks = {}
local spawnedCreatureGuid = {}
local scoreEarned = {}
local scoreTotal = {}

if Config.addEnoughSpell == nil then print("customWorldboss.lua: Missing flag Config.addEnoughSpell.") end
if Config.customDbName == nil then print("customWorldboss.lua: Missing flag Config.customDbName.") end
if Config.GMRankForEventStart == nil then print("customWorldboss.lua: Missing flag Config.GMRankForEventStart.") end
if Config.GMRankForUpdateDB == nil then print("customWorldboss.lua: Missing flag Config.GMRankForUpdateDB.") end
if Config.printErrorsToConsole == nil then print("customWorldboss.lua: Missing flag Config.printErrorsToConsole.") end
if Config.addEnrageTimer == nil then print("customWorldboss.lua: Missing flag Config.addEnrageTimer.") end

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

local function newAutotable(dim)
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

local function eS_castFireworks(eventId, delay, repeats)
    local player
    for n, v in pairs(playersForFireworks) do
        player = GetPlayerByGUID(v)
        if player ~= nil then
            player:CastSpell(player, Config_fireworks[math.random(1, #Config_fireworks)])
        end
    end
    if repeats == 1 then
        playersForFireworks = {}
    end
end

local function eS_resetPlayers(event, player)
    if eS_has_value(playersInRaid, player:GetGUID()) and player:GetPhaseMask() ~= 1 then
        if player ~= nil then
            if player:GetCorpse() ~= nil then
                player:GetCorpse():SetPhaseMask(1)
            end
            player:SetPhaseMask(1)
            player:SendBroadcastMessage("You left the event.")
        end
    end
end

local function eS_getSize(difficulty)
    local value
    if difficulty == 1 then
        value = 1
    else
        value = 1 + (difficulty - 1) / 4
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

local function eS_checkInCombat()
    --check if all players are in combat
    local player
    for n, v in pairs(playersInRaid) do
        player = GetPlayerByGUID(v)
        if player ~= nil then
            if player:IsInCombat() == false and player:GetPhaseMask() == 2 then
                if player:GetCorpse() ~= nil then
                    player:GetCorpse():SetPhaseMask(1)
                end
                player:SetPhaseMask(1)
                player:SendBroadcastMessage("You were returned to the real time because you did not participate.")
            end
        end
    end
end

local function eS_getEncounterDuration()
    local dt = GetTimeDiff(encounterStartTime)
    return string.format("%.2d:%.2d", (dt / 1000 / 60) % 60, (dt / 1000) % 60)
end

local function eS_getTimeSince(time)
    local dt = GetTimeDiff(time)
    return dt
end

local function eS_getDifficultyTimer(rawTimer)
    local timer = rawTimer / (1 + ((difficulty - 1) / 5))
    return timer
end

local function eS_onHello(event, player, creature)
    if bossfightInProgress ~= nil then
        creature:SendUnitSay("Some heroes are still fighting the enemies of time since "..eS_getEncounterDuration(), 0 )
        player:GossipMenuAddItem(OPTION_ICON_CHAT, "What's my score?", Config_npcEntry[eventInProgress], 0)
        return
    end

    if player == nil then return end
    player:GossipMenuAddItem(OPTION_ICON_CHAT, "What's my score?", Config_npcEntry[eventInProgress], 0)
    player:GossipMenuAddItem(OPTION_ICON_CHAT, "We are ready to fight a servant!", Config_npcEntry[eventInProgress], 1)
    player:GossipMenuAddItem(OPTION_ICON_CHAT, "We brought the best there is and we're ready for anything.", Config_npcEntry[eventInProgress], 2)
    player:GossipSendMenu(Config_npcText[1], creature, 0)
end

local function awardScore()
    local score = Config.baseScore + (Config.additionalScore * difficulty)
    for n, playerGuid in pairs(playersInRaid) do
        local accountId = GetPlayerByGUID(playerGuid):GetAccountId()
        if scoreEarned[accountId] == nil then scoreEarned[accountId] = 0 end
        if scoreTotal[accountId] == nil then scoreTotal[accountId] = 0 end
        scoreEarned[accountId] = scoreEarned[accountId] + score
        scoreTotal[accountId] = scoreTotal[accountId] + score
        CharDBExecute('REPLACE INTO `'..Config.customDbName..'`.`eventscript_score` VALUES ('..accountId..', '..scoreEarned[accountId]..', '..scoreTotal[accountId]..');');
        local gameTime = (tonumber(tostring(GetGameTime())))
        local playerLowGuid = GetGUIDLow(playerGuid)
        CharDBExecute('INSERT IGNORE INTO `'..Config.customDbName..'`.`eventscript_encounters` VALUES ('..gameTime..', '..playerLowGuid..', '..eventInProgress..', '..difficulty..', '..bossfightInProgress..', '..eS_getTimeSince(encounterStartTime)..');');
    end
    bossfightInProgress = nil
end

local function storeEncounter()
    for n, playerGuid in pairs(playersInRaid) do
        local accountId = GetPlayerByGUID(playerGuid):GetAccountId()
        local gameTime = (tonumber(tostring(GetGameTime())))
        local playerLowGuid = GetGUIDLow(playerGuid)
        CharDBExecute('INSERT IGNORE INTO `'..Config.customDbName..'`.`eventscript_encounters` VALUES ('..gameTime..', '..playerLowGuid..', '..eventInProgress..', '..difficulty..', '..bossfightInProgress..', '..eS_getTimeSince(encounterStartTime)..');');
    end
    bossfightInProgress = nil
end

local function eS_chromieGossip(event, player, object, sender, intid, code, menu_id)
    local spawnedBoss
    local spawnedCreature = {}

    if player == nil then return end

    local group = player:GetGroup()

    if intid == 0 then
        local accountId = player:GetAccountId()
        if scoreEarned[accountId] == nil then scoreEarned[accountId] = 0 end
        if scoreTotal[accountId] == nil then scoreTotal[accountId] = 0 end
        player:SendBroadcastMessage("Your current event score is: "..scoreEarned[accountId].." and your all-time event score is: "..scoreTotal[accountId])
        player:GossipComplete()
    elseif intid == 1 then

        if player:IsInGroup() == false then
            player:SendBroadcastMessage("You need to be in a party.")
            player:GossipComplete()
            return
        end

        if group:IsRaidGroup() == true then
            player:SendBroadcastMessage("You can not accept that task while in a raid group.")
            player:GossipComplete()
            return
        end
        if not group:IsLeader(player:GetGUID()) then
            player:SendBroadcastMessage("You are not the leader of your group.")
            player:GossipComplete()
            return
        end
        groupPlayers = group:GetMembers()
        for n, v in pairs(groupPlayers) do
            if eS_has_value(playersForFireworks, v:GetGUID()) then
                object:SendUnitSay("Please, just a little break. I need to breathe, "..player:GetName()..". How about watching the fireworks?", 0 )
                player:GossipComplete()
                return
            end
        end
        --start 5man encounter
        bossfightInProgress = PARTY_IN_PROGRESS
        spawnedCreature[1]= player:SpawnCreature(Config_addEntry[eventInProgress], x, y, z, o)
        spawnedCreature[1]:SetPhaseMask(2)
        spawnedCreature[1]:SetScale(spawnedCreature[1]:GetScale() * eS_getSize(difficulty))
        encounterStartTime = GetCurrTime()

        for n, v in pairs(groupPlayers) do
            if v:GetDistance(player) ~= nil then
                if v:GetDistance(player) < 80 then
                    v:SetPhaseMask(2)
                    playersInRaid[n] = v:GetGUID()
                    spawnedCreature[1]:SetInCombatWith(v)
                    v:SetInCombatWith(spawnedCreature[1])
                    spawnedCreature[1]:AddThreat(v, 1)
                end
            else
                v:SendBroadcastMessage("You were too far away to join the fight.")
            end
        end

    elseif intid == 2 then

        if player:IsInGroup() == false then
            player:SendBroadcastMessage("You need to be in a party.")
            player:GossipComplete()
            return
        end

        if group:IsRaidGroup() == false then
            player:SendBroadcastMessage("You can not accept that task without being in a raid group.")
            player:GossipComplete()
            return
        end
        if not group:IsLeader(player:GetGUID()) then
            player:SendBroadcastMessage("You are not the leader of your group.")
            player:GossipComplete()
            return
        end
        groupPlayers = group:GetMembers()
        for n, v in pairs(groupPlayers) do
            if eS_has_value(playersForFireworks, v:GetGUID()) then
                object:SendUnitSay("Please, just a little break. I need to breathe, "..player:GetName()..". How about watching the fireworks?", 0 )
                player:GossipComplete()
                return
            end
        end
        --start raid encounter
        bossfightInProgress = RAID_IN_PROGRESS

        spawnedBoss = player:SpawnCreature(Config_bossEntry[eventInProgress], x, y, z+2, o)
        spawnedBoss:SetPhaseMask(2)
        spawnedBoss:SetScale(spawnedBoss:GetScale() * eS_getSize(difficulty))
        spawnedBossGuid = spawnedBoss:GetGUID()

        if Config_addsAmount[eventInProgress] == nil then Config_addsAmount[eventInProgress] = 1 end

        for c = 1, Config_addsAmount[eventInProgress] do
            local randomX = (math.sin(math.random(1,360)) * 15)
            local randomY = (math.sin(math.random(1,360)) * 15)
            spawnedCreature[c] = player:SpawnCreature(Config_addEntry[eventInProgress], x + randomX, y + randomY, z+2, o)
            spawnedCreature[c]:SetPhaseMask(2)
            spawnedCreature[c]:SetScale(spawnedCreature[c]:GetScale() * eS_getSize(difficulty))
            spawnedCreatureGuid[c] = spawnedCreature[c]:GetGUID()
        end
        encounterStartTime = GetCurrTime()

        for n, v in pairs(groupPlayers) do
            if v:GetDistance(player) ~= nil then
                if v:GetDistance(player) < 80 then
                    v:SetPhaseMask(2)
                    playersInRaid[n] = v:GetGUID()
                    spawnedBoss:SetInCombatWith(v)
                    v:SetInCombatWith(spawnedBoss)
                    spawnedBoss:AddThreat(v, 1)
                    for c = 1, Config_addsAmount[eventInProgress] do
                        spawnedCreature[c]:SetInCombatWith(v)
                        v:SetInCombatWith(spawnedCreature[c])
                        spawnedCreature[c]:AddThreat(v, 1)
                    end
                end
            else
                v:SendBroadcastMessage("You were too far away to join the fight.")
            end
        end

        --apply auras to adds
        if spawnedCreature[1] ~= nil then
            if Config_aura1Add1[1] ~= nil then
                spawnedCreature[1]:AddAura(Config_aura1Add1[1], spawnedCreature[1])
            end
            if Config_aura2Add1[1] ~= nil then
                spawnedCreature[1]:AddAura(Config_aura2Add1[1], spawnedCreature[1])
            end
        end

        if spawnedCreature[2] ~= nil then
            if Config_aura1Add2[2] ~= nil then
                spawnedCreature[2]:AddAura(Config_aura1Add2[2], spawnedCreature[2])
            end
            if Config_aura2Add2[2] ~= nil then
                spawnedCreature[2]:AddAura(Config_aura2Add2[2], spawnedCreature[2])
            end
        end
        if #spawnedCreature > 2 then
            for c = 3, #spawnedCreature do
                if spawnedCreature[c] ~= nil then
                    if Config_aura1Add3[c] ~= nil then
                        spawnedCreature[c]:AddAura(Config_aura1Add3[c], spawnedCreature[c])
                    end
                    if Config_aura2Add3[c] ~= nil then
                        spawnedCreature[c]:AddAura(Config_aura2Add3[c], spawnedCreature[c])
                    end
                end
            end
        end
    end
    player:GossipComplete()
end

local function eS_summonEventNPC(playerGuid)
    local player
    -- tempSummon an NPC with a dialogue option to start the encounter, store the guid for later unsummon
    player = GetPlayerByGUID(playerGuid)
    if player == nil then return end
    x = player:GetX()
    y = player:GetY()
    z = player:GetZ()
    o = player:GetO()
    local spawnedNPC = player:SpawnCreature(Config_npcEntry[eventInProgress], x, y, z, o)
    spawnedNPCGuid = spawnedNPC:GetGUID()

    -- add an event to spawn the Boss in a phase when gossip is clicked
    cancelEventIdHello[eventInProgress] = RegisterCreatureGossipEvent(Config_npcEntry[eventInProgress], GOSSIP_EVENT_ON_HELLO, eS_onHello)
    cancelEventIdStart[eventInProgress] = RegisterCreatureGossipEvent(Config_npcEntry[eventInProgress], GOSSIP_EVENT_ON_SELECT, eS_chromieGossip)
end

local function eS_command(event, player, command)
    local commandArray = {}
    local eventNPC

    --prevent players from using this  
    if player ~= nil then
        if player:GetGMRank() < Config.GMRankForEventStart then
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

        if Config_npcEntry[eventNPC] == nil or Config_bossEntry == nil or Config_addEntry == nil or Config_npcText == nil then
            player:SendBroadcastMessage("Event "..eventNPC.." is not properly configured. Aborting")
            return false
        end

        mapEventStart = player:GetMap():GetMapId()

        if difficulty <= 0 then difficulty = 1 end
        if difficulty > 10 then difficulty = 10 end

        if eventInProgress == nil then
            eventInProgress = eventNPC
            eS_summonEventNPC(player:GetGUID())
            player:SendBroadcastMessage("Starting event "..eventInProgress.." with difficulty "..difficulty..".")
            return false
        else
            player:SendBroadcastMessage("Event "..eventInProgress.." is already active.")
            return false
        end
    elseif commandArray[1] == "stopevent" then
        if player == nil then
            print("Must be used from inside the game.")
            return false
        end
        if eventInProgress == nil then
            player:SendBroadcastMessage("There is no event in progress.")
            return false
        end
        local map = player:GetMap()
        local mapId = map:GetMapId()
        if mapId ~= mapEventStart then
            player:SendBroadcastMessage("You must be in the same map to stop an event.")
            return false
        end
        player:SendBroadcastMessage("Stopping event "..eventInProgress..".")
        ClearCreatureGossipEvents(Config_npcEntry[eventInProgress])
        local spawnedNPC = map:GetWorldObject(spawnedNPCGuid):ToCreature()
        spawnedNPC:DespawnOrUnsummon(0)
        eventInProgress = nil
        return false
    end
    
    --prevent non-Admins from using the rest
    if player ~= nil then  
        if player:GetGMRank() < Config.GMRankForUpdateDB then
            return
        end  
    end
    --nothing here yet
end

-- list of spells:
-- 60488 Shadow Bolt (30)
-- 24326 HIGH knockback (ZulFarrak beast)
-- 12421 Mithril Frag Bomb 8y 149-201 damage + stun

function bossNPC.onEnterCombat(event, creature, target)
    creature:RegisterEvent(bossNPC.Event, 100, 0)
    creature:CallAssistance()
    creature:SendUnitYell("You will NOT interrupt this mission!", 0 )
    phase = 1
    addsDownCounter = 0
    creature:CallForHelp(200)
    creature:PlayDirectSound(8645)

    lastBossSpell1 = encounterStartTime
    lastBossSpell2 = encounterStartTime
    lastBossSpell3 = encounterStartTime
    lastBossSpell5 = encounterStartTime
    lastBossSpellSelf = encounterStartTime
end

function bossNPC.reset(event, creature)
    local player
    eS_checkInCombat()
    creature:RemoveEvents()
    if creature:IsDead() == true then
        creature:SendUnitYell("Master, save me!", 0 )
        creature:PlayDirectSound(8865)
        local playerListString
        for _, v in pairs(playersInRaid) do
            player = GetPlayerByGUID(v)
            if player ~= nil then
                if player:GetCorpse() ~= nil then
                    player:GetCorpse():SetPhaseMask(1)
                end
                player:SetPhaseMask(1)
                if playerListString == nil then
                    playerListString = player:GetName()
                else
                    playerListString = playerListString..", "..player:GetName()
                end
            end
        end
        if Config.rewardRaid == 1 then
            awardScore()
        elseif Config.storeRaid == 1 then
            storeEncounter()
        else
            bossfightInProgress = nil
        end
        SendWorldMessage("The raid encounter "..creature:GetName().." was completed on difficulty "..difficulty.." in "..eS_getEncounterDuration().." by: "..playerListString..". Congratulations!")
        CreateLuaEvent(eS_castFireworks, 1000, 20)
        playersForFireworks = playersInRaid
        playersInRaid = {}
    else
        creature:SendUnitYell("You never had a chance.", 0 )
        for _, v in pairs(playersInRaid) do
            player = GetPlayerByGUID(v)
            if player ~= nil then
                if player:GetCorpse() ~= nil then
                    player:GetCorpse():SetPhaseMask(1)
                end
                player:SetPhaseMask(1)
            end
        end
        playersInRaid = {}
        bossfightInProgress = nil
    end
    creature:DespawnOrUnsummon(0)
    addsDownCounter = nil
end

function bossNPC.Event(event, delay, pCall, creature)
    if creature:IsCasting() == true then return end

    if Config_bossSpellEnrageTimer[eventInProgress] ~= nil and Config_bossSpellEnrage[eventInProgress] ~= nil then
        if eS_getDifficultyTimer(Config_bossSpellEnrageTimer[eventInProgress]) < eS_getTimeSince(encounterStartTime) then
            if phase == 2 and eS_getTimeSince(encounterStartTime) > Config_bossSpellEnrageTimer[eventInProgress] then
                phase = 3
                creature:SendUnitYell("FEEL MY WRATH!", 0 )
                creature:CastSpell(creature, Config_bossSpellEnrage[eventInProgress])
                return
            end
        end
    end

    if Config_bossSpellTimer3[eventInProgress] ~= nil then
        if eS_getDifficultyTimer(Config_bossSpellTimer3[eventInProgress]) < eS_getTimeSince(lastBossSpell3) then
            if addsDownCounter < Config_addsAmount[eventInProgress] then
                if Config_bossSpellSelf[eventInProgress] ~= nil then
                    creature:CastSpell(creature, Config_bossSpellSelf[eventInProgress])
                    lastBossSpell3 = GetCurrTime()
                    return
                end
            elseif phase == 1 then
                if Config_bossYellPhase2[eventInProgress] ~= nil then
                    creature:SendUnitYell(Config_bossYellPhase2[eventInProgress], 0 )
                end
                phase = 2
            end
        end
    end

    if Config_bossSpellTimer1[eventInProgress] ~= nil then
        if eS_getDifficultyTimer(Config_bossSpellTimer1[eventInProgress]) < eS_getTimeSince(lastBossSpell1) then
            if Config_bossSpell1[eventInProgress] ~= nil then
                creature:CastSpell(creature:GetVictim(), Config_bossSpell1[eventInProgress])
                lastBossSpell1 = GetCurrTime()
                return
            end
        end
    end

    if Config_bossSpellTimer2[eventInProgress] ~= nil then
        if eS_getDifficultyTimer(Config_bossSpellTimer2[eventInProgress]) < eS_getTimeSince(lastBossSpell2) then
            if Config_bossSpell2[eventInProgress] ~= nil then
                if (math.random(1, 100) <= 50) then
                    local players = creature:GetPlayersInRange(35)
                    local targetPlayer = players[math.random(1, #players)]
                    creature:SendUnitYell("You die now, "..targetPlayer:GetName().."!", 0 )
                    creature:CastSpell(targetPlayer, Config_bossSpell2[eventInProgress])
                    lastBossSpell2 = GetCurrTime()
                    return
                end
            end
        end
    end

    if Config_bossSpellTimer3[eventInProgress] ~= nil then
        if eS_getDifficultyTimer(Config_bossSpellTimer3[eventInProgress]) < eS_getTimeSince(lastBossSpell3) then
            if phase > 1 then
                local players = creature:GetPlayersInRange(30)
                if #players > 1 then
                    if (math.random(1, 100) <= 50) then
                        if Config_bossSpell3[eventInProgress] ~= nil then
                            creature:CastSpell(creature:GetAITarget(SELECT_TARGET_NEAREST, true, 1, 30), Config_bossSpell3[eventInProgress])
                            lastBossSpell3 = GetCurrTime()
                            return
                        end
                    elseif phase > 1 then
                        if Config_bossSpell4[eventInProgress] ~= nil then
                            local players = creature:GetPlayersInRange(40)
                            local targetPlayer = players[math.random(1, #players)]
                            creature:CastSpell(targetPlayer, Config_bossSpell4[eventInProgress])
                            lastBossSpell3 = GetCurrTime()
                            return
                        end
                    end
                else
                    if Config_bossSpell3[eventInProgress] ~= nil then
                        creature:CastSpell(creature:GetVictim(),Config_bossSpell3[eventInProgress])
                        lastBossSpell3 = GetCurrTime()
                        return
                    end
                end
            end
        end
    end

    if Config_bossSpellTimer5[eventInProgress] ~= nil then
        if eS_getDifficultyTimer(Config_bossSpellTimer5[eventInProgress]) < eS_getTimeSince(lastBossSpell5) then
            if phase == 1 then
                if Config_bossSpell5[eventInProgress] ~= nil then
                    creature:CastSpell(creature:GetVictim(), Config_bossSpell5[eventInProgress])
                    lastBossSpell5 = GetCurrTime()
                    return
                end
            else
                if Config_bossSpell6[eventInProgress] ~= nil then
                    creature:CastSpell(creature:GetVictim(), Config_bossSpell6[eventInProgress])
                    lastBossSpell5 = GetCurrTime()
                    return
                end
            end
        end
    end
end

function addNPC.onEnterCombat(event, creature, target)
    local player

    creature:RegisterEvent(addNPC.Event, 100, 0)

    creature:CallAssistance()
    creature:CallForHelp(200)
    for _, v in pairs(playersInRaid) do
        player = GetPlayerByGUID(v)
        creature:AddThreat(player, 1)
    end
    addphase = 1

    if bossfightInProgress == PARTY_IN_PROGRESS then
        lastAddSpell1[1] = encounterStartTime
        lastAddSpell2[1] = encounterStartTime
        lastAddSpell3[1] = encounterStartTime
        lastAddSpell4[1] = encounterStartTime
    else
        for n, _ in pairs(spawnedCreatureGuid) do
            lastAddSpell1[n] = encounterStartTime
            lastAddSpell2[n] = encounterStartTime
            lastAddSpell3[n] = encounterStartTime
            lastAddSpell4[n] = encounterStartTime
        end
    end
end

function addNPC.Event(event, delay, pCall, creature)
    if creature:IsCasting() == true then return end

    if bossfightInProgress == PARTY_IN_PROGRESS and Config_addSpell1[eventInProgress] ~= nil then  -- only for the party version
        if addphase == 1 and creature:GetHealthPct() < 67 then
            addphase = 2
            creature:SendUnitYell("ENOUGH", 0 )
            creature:PlayDirectSound(412)
            local players = creature:GetPlayersInRange(30)
            if #players > 1 then
                creature:CastSpell(creature:GetAITarget(SELECT_TARGET_FARTHEST, true, 0, 30), Config.addEnoughSpell)
                return
            else
                creature:CastSpell(creature:GetAITarget(SELECT_TARGET_FARTHEST, true, 0, 30), Config_addSpell1[eventInProgress])
                return
            end
        elseif addphase == 2 and creature:GetHealthPct() < 34 then
            addphase = 3
            creature:SendUnitYell("ENOUGH", 0 )
            creature:PlayDirectSound(412)
            local players = creature:GetPlayersInRange(30)
            if #players > 1 then
                creature:CastSpell(creature:GetAITarget(SELECT_TARGET_FARTHEST, true, 0, 30), Config.addEnoughSpell)
                return
            else
                creature:CastSpell(creature:GetAITarget(SELECT_TARGET_FARTHEST, true, 0, 30), Config_addSpell1[eventInProgress])
                return
            end
        end
    end

    local n = eS_returnIndex(spawnedCreatureGuid, creature:GetGUID())   -- tell multiple adds apart in raid mode
    if n == false then n = 1 end                                        -- no need to set this in party mode


    if Config_addSpellEnrage[eventInProgress] ~= nil then
        if eS_getDifficultyTimer(Config.addEnrageTimer) < eS_getTimeSince(encounterStartTime)then
            if phase == 2 and eS_getTimeSince(encounterStartTime) > Config_addSpellEnrage[eventInProgress] then
                phase = 3
                creature:SendUnitYell("FEEL MY WRATH!", 0 )
                creature:CastSpell(creature, Config_addSpellEnrage[eventInProgress])
                return
            end
        end
    end

    local randomTimer = math.random(0,500)

    if Config_addSpellTimer1[eventInProgress] ~= nil and Config_addSpell1[eventInProgress] ~= nil then
        if eS_getDifficultyTimer(Config_addSpellTimer1[eventInProgress]) < randomTimer + eS_getTimeSince(lastAddSpell1[n]) then
            local random = math.random(0, 2)
            local players = creature:GetPlayersInRange(30)
            if #players > 1 then
                creature:CastSpell(creature:GetAITarget(SELECT_TARGET_FARTHEST, true, random, 30), Config_addSpell1[eventInProgress])
                lastAddSpell1[n] = GetCurrTime()
                return
            else
                creature:CastSpell(creature:GetVictim(),Config_addSpell1[eventInProgress])
                lastAddSpell1[n] = GetCurrTime()
                return
            end
        end
    end

    if Config_addSpellTimer2[eventInProgress] ~= nil and Config_addSpell2[eventInProgress] ~= nil then
        if eS_getDifficultyTimer(Config_addSpellTimer2[eventInProgress]) < randomTimer + (eS_getTimeSince(lastAddSpell2[n])) then
            creature:PlayDirectSound(6436)
            creature:CastSpell(creature:GetVictim(), Config_addSpell2[eventInProgress])
            lastAddSpell2[n] = GetCurrTime()
            return
        end
    end

    if Config_addSpellTimer3[eventInProgress] ~= nil and Config_addSpell3[eventInProgress] ~= nil then
        if eS_getDifficultyTimer(Config_addSpellTimer3[eventInProgress]) < randomTimer + eS_getTimeSince(lastAddSpell3[n]) then
            if Config_addSpell3Yell[eventInProgress] ~= nil then
                creature:SendUnitYell(Config_addSpell3Yell[eventInProgress], 0 )
            end
            creature:CastSpell(creature, Config_addSpell3[eventInProgress])
            lastAddSpell3[n] = GetCurrTime()
            return
        end
    end

    if bossfightInProgress == RAID_IN_PROGRESS then
        if Config_addSpellTimer4[eventInProgress] ~= nil and Config_addSpell4[eventInProgress] ~= nil then
            if eS_getDifficultyTimer(Config_addSpellTimer4[eventInProgress]) < randomTimer + eS_getTimeSince(lastAddSpell4[n]) then
                local map = creature:GetMap()
                if map ~= nil then
                    if  map:GetWorldObject(spawnedBossGuid) ~= nil then
                        local bossNPC = map:GetWorldObject(spawnedBossGuid):ToCreature()
                        creature:CastSpell(bossNPC, Config_addSpell4[eventInProgress])
                        lastAddSpell4[n] = GetCurrTime()
                        return
                    end
                end
            end
        end
    end
end

function addNPC.reset(event, creature)
    local player
    eS_checkInCombat()
    creature:RemoveEvents()
    if bossfightInProgress == PARTY_IN_PROGRESS then
        if creature:IsDead() == true then
            local playerListString
            CreateLuaEvent(eS_castFireworks, 1000, 20)
            creature:PlayDirectSound(8803)
            for _, v in pairs(playersInRaid) do
                player = GetPlayerByGUID(v)
                if player ~= nil then
                    if player:GetCorpse() ~= nil then
                        player:GetCorpse():SetPhaseMask(1)
                    end
                    player:SetPhaseMask(1)
                    if playerListString == nil then
                        playerListString = player:GetName()
                    else
                        playerListString = playerListString..", "..player:GetName()
                    end
                end
            end
            if Config.rewardParty == 1 then
                awardScore()
            elseif Config.storeParty == 1 then
                storeEncounter()
            else
                bossfightInProgress = nil
            end
            SendWorldMessage("The party encounter "..creature:GetName().." was completed on difficulty "..difficulty.." in "..eS_getEncounterDuration().." by: "..playerListString..". Congratulations!")
            playersForFireworks = playersInRaid
            playersInRaid = {}
        else
            creature:SendUnitYell("Hahahaha!", 0 )
            for _, v in pairs(playersInRaid) do
                player = GetPlayerByGUID(v)
                if player ~= nil then
                    if player:GetCorpse() ~= nil then
                        player:GetCorpse():SetPhaseMask(1)
                    end
                    player:SetPhaseMask(1)
                end
            end
            playersInRaid = {}
            bossfightInProgress = nil
        end
    else
        if creature:IsDead() == true then
            if addsDownCounter == nil then
                addsDownCounter = 1
            else
                addsDownCounter = addsDownCounter + 1
            end
        end
    end
    creature:DespawnOrUnsummon(0)
end

local function initBossEvents()
    for n = Config_bossEntry[1], Config_bossEntry[1] + 990, 10 do
        if eS_has_value(Config_bossEntry,n) then
            RegisterCreatureEvent(n, 1, bossNPC.onEnterCombat)
            RegisterCreatureEvent(n, 2, bossNPC.reset) -- OnLeaveCombat
            RegisterCreatureEvent(n, 4, bossNPC.reset) -- OnDied
        else
            return
        end
    end
end
local function initAddEvents()
    for n = Config_addEntry[1], Config_addEntry[1] + 990, 10 do
        if eS_has_value(Config_addEntry,n) then
            RegisterCreatureEvent(n, 1, addNPC.onEnterCombat)
            RegisterCreatureEvent(n, 2, addNPC.reset) -- OnLeaveCombat
            RegisterCreatureEvent(n, 4, addNPC.reset) -- OnDied
        else
            return
        end
    end
end

--on ReloadEluna / Startup
RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, eS_command)
RegisterPlayerEvent(PLAYER_EVENT_ON_REPOP, eS_resetPlayers)

initBossEvents()
initAddEvents()

CharDBQuery('CREATE DATABASE IF NOT EXISTS `'..Config.customDbName..'`;');
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..Config.customDbName..'`.`eventscript_encounters` (`time_stamp` INT NOT NULL, `playerGuid` INT NOT NULL, `encounter` INT DEFAULT 0, `difficulty` TINYINT DEFAULT 0, `group_type` TINYINT DEFAULT 0, `duration` INT NOT NULL, PRIMARY KEY (`time_stamp`, `playerGuid`));');
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..Config.customDbName..'`.`eventscript_score` (`account_id` INT NOT NULL, `score_earned_current` INT DEFAULT 0, `score_earned_total` INT DEFAULT 0, PRIMARY KEY (`account_id`));')

local Data_SQL = CharDBQuery('SELECT * FROM `'..Config.customDbName..'`.`eventscript_score`;')
if Data_SQL ~= nil then
    local account
    repeat
        account = Data_SQL:GetUInt32(0)
        scoreEarned[account] = Data_SQL:GetUInt32(1)
        scoreTotal[account] = Data_SQL:GetUInt32(1)
    until not Data_SQL:NextRow()
end
