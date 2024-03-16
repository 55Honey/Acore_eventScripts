--Copyright (C) 2022-2024  https://github.com/55Honey
--
--This program is free software: you can redistribute it and/or modify
--it under the terms of the GNU Affero General Public License as published by
--the Free Software Foundation, either version 3 of the License, or
--(at your option) any later version.
--
--This program is distributed in the hope that it will be useful,
--but WITHOUT ANY WARRANTY; without even the implied warranty of
--MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--GNU Affero General Public License for more details.
--
--You should have received a copy of the GNU Affero General Public License
--along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--
--
--
-- Created by IntelliJ IDEA.
-- User: Silvia
-- Date: 05/02/2024
-- Time: 12:31
-- Originally created by Honey for Azerothcore
-- requires mod-eluna


-- This module spawns (custom) NPCs and grants them scripted combat abilities
------------------------------------------------------------------------------------------------
-- ADMIN GUIDE:  -  compile the core with mod-eluna
--               -  adjust config in this file
--               -  add this script to ../lua_scripts/
--               -  possibly add additional boss scripts
--               -  adjust the IDs and config flags in case of conflicts and run the associated SQL to add the required NPCs
--               -  the acore_cms module assumes that 1112001 is the boss of encounter 1 and adding +10 for each subsequent encounter
--                  (1112011 = boss for encounter 2 / 1112021 = boss for encounter 3, etc.)
------------------------------------------------------------------------------------------------
-- GM GUIDE:     -  use .startevent $event to start and spawn
--               -  maybe offer teleports
--               -  use .stopevent to end the event and despawn the NPC
------------------------------------------------------------------------------------------------
ebs = {}

------------------------------------------
-- Begin of config section
------------------------------------------

ebs.Config = {
    ["creature_template"] = {}, --db entry of the boss creature
    ["customDbName"] = "ac_eluna",
    ["eventPhase"] = { 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024 },
    ["fireworks"] = { 66400, 66402, 46847, 46829, 46830, 62074, 62075, 62077, 55420 },
    ["GMRankForEventStart"] = 2,
    ["GMRankForUpdateDB"] = 3,
    ["addEnrageTimer"] = 300000,
    ["baseScore"] = 40,
    ["additionalScore"] = 10,
    ["rewardRaid"] = 1,
    ["storeRaid"] = 1,
    ["rewardParty"] = 1,
    ["storeParty"] = 1
}

------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------

if tostring(ebs.Config.customDbName) == "" or (ebs.Config.customDbName) == nil then
    PrintError("eventBosses.lua: Missing flag ebs.Config.customDbName. Defaulting to ac_eluna.")
    ebs.Config.customDbName = "ac_eluna"
end

CharDBQuery('CREATE DATABASE IF NOT EXISTS `'..ebs.Config.customDbName..'`;');
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..ebs.Config.customDbName..'`.`eventscript_encounters` (`time_stamp` INT NOT NULL, `playerGuid` INT NOT NULL, `encounter` INT DEFAULT 0, `difficulty` TINYINT DEFAULT 0, `group_type` TINYINT DEFAULT 0, `duration` INT NOT NULL, PRIMARY KEY (`time_stamp`, `playerGuid`));');
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..ebs.Config.customDbName..'`.`eventscript_score` (`account_id` INT NOT NULL, `score_earned_current` INT DEFAULT 0, `score_earned_total` INT DEFAULT 0, PRIMARY KEY (`account_id`));')
CharDBQuery('CREATE TABLE IF NOT EXISTS `'..ebs.Config.customDbName..'`.`eventscript_difficulty` (`account_id` INT NOT NULL, `encounter_id` INT NOT NULL, `encounter_type` INT NOT NULL, `difficulty` INT NOT NULL, PRIMARY KEY (`account_id`, `encounter_id`, `encounter_type`));')

--constants
local PLAYER_EVENT_ON_LOGOUT = 4            -- (event, player)
local PLAYER_EVENT_ON_REPOP = 35            -- (event, player)
local PLAYER_EVENT_ON_COMMAND = 42          -- (event, player, command, chatHandler) - player is nil if command used from console. Can return false
local TEMPSUMMON_MANUAL_DESPAWN = 8         -- despawns when UnSummon() is called
local GOSSIP_EVENT_ON_HELLO = 1             -- (event, player, object) - Object is the Creature/GameObject/Item. Can return false to do default action. For item gossip can return false to stop spell casting.
local GOSSIP_EVENT_ON_SELECT = 2            -- (event, player, object, sender, intid, code, menu_id)
local OPTION_ICON_CHAT = 0
local OPTION_ICON_BATTLE = 9
local ELUNA_EVENT_ON_LUA_STATE_CLOSE = 16
local ELUNA_EVENT_ON_LUA_STATE_OPEN = 33

MECHANIC_CHARM = 1
MECHANIC_DISORIENTED= 2
MECHANIC_DISARM = 3
MECHANIC_DISTRACT = 4
MECHANIC_FEAR = 5
MECHANIC_GRIP = 6
MECHANIC_ROOT = 7
MECHANIC_SLOW_ATTACK = 8
MECHANIC_SILENCE = 9
MECHANIC_SLEEP = 10
MECHANIC_SNARE = 11
MECHANIC_STUN = 12
MECHANIC_FREEZE = 13
MECHANIC_KNOCKOUT = 14
MECHANIC_BLEED = 15
MECHANIC_BANDAGE = 16
MECHANIC_POLYMORPH = 17
MECHANIC_BANISH = 18
MECHANIC_SHIELD = 19
MECHANIC_SHACKLE = 20
MECHANIC_MOUNT = 21
MECHANIC_INFECTED = 22
MECHANIC_TURN = 23
MECHANIC_HORROR = 24
MECHANIC_INVULNERABILITY = 25
MECHANIC_INTERRUPT = 26
MECHANIC_DAZE = 27
MECHANIC_DISCOVERY = 28
MECHANIC_IMMUNE_SHIELD = 29
MECHANIC_SAPPED = 30
MECHANIC_ENRAGED = 31


SELECT_TARGET_RANDOM = 0              -- Just selects a random target
SELECT_TARGET_TOPAGGRO = 1            -- Selects targets from top aggro to bottom
SELECT_TARGET_BOTTOMAGGRO = 2         -- Selects targets from bottom aggro to top
SELECT_TARGET_NEAREST = 3
SELECT_TARGET_FARTHEST = 4

TYPE_CREATURE = 1
TYPE_GAMEOBJECT = 2

local PARTY_IN_PROGRESS = 1
local RAID_IN_PROGRESS = 2
local eventInProgress

ebs.playersInGroup = {
    [1] = {},
    [2] = {},
    [3] = {},
    [4] = {},
    [5] = {},
    [6] = {},
    [7] = {},
    [8] = {},
    [9] = {},
    [10] = {}
}
local scoreEarned = {}
local scoreTotal = {}
ebs.spawnedGossipNpcGuid = 0
ebs.spawnedBossGuid = {}
ebs.phaseIdDifficulty = {}      -- stores the difficulty of the encounter. 0 means the slot is free
ebs.fightType = {}              -- party or raid
ebs.encounter = {}
ebs.clearedDifficulty = {}
ebs.encounterStartTime = {}

function ebs.has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

function ebs.returnKey (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return index
        end
    end
    return 0
end

function ebs.returnIndex (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return index
        end
    end
    return false
end

function ebs.splitString(inputstr, seperator)
    if seperator == nil then
        seperator = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..seperator.."]+)") do
        table.insert(t, str)
    end
    return t
end

function ebs.castFireworks(_, _, _, player)
    if player and player:GetPhaseMask() == 1 then
        player:CastSpell(player, ebs.Config.fireworks[math.random(1, #ebs.Config.fireworks)])
    end
end

function ebs.isParticipating(player)
    if not player then
        return false
    end
    for _,v in pairs(ebs.playersInGroup) do
        if ebs.has_value(v, player:GetGUID()) and player:GetPhaseMask() ~= 1 then
            return true
        end
    end
    return false
end

function ebs.resetPlayers(_, player)
    if ebs.isParticipating(player) then
        player:SetPhaseMask(1)
        player:SendBroadcastMessage("You left the event.")
        if player:GetCorpse() then
            player:GetCorpse():SetPhaseMask(1)
        end
    end
end

function ebs.getSize(difficulty)
    local value = 1
    if difficulty >= 1 then
        value = 1 + (difficulty - 1) / 4
    end
    return value
end

function ebs.checkInCombat(slotId)
    --check if all players are in combat
    local player
    for _, v in pairs(ebs.playersInGroup[slotId]) do
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

function ebs.getEncounterDuration(slotId)
    local dt = GetTimeDiff(ebs.encounterStartTime[slotId])
    return string.format("%.2d:%.2d", (dt / 1000 / 60) % 60, (dt / 1000) % 60)
end

function ebs.GetTimer(timer, difficulty)
    if difficulty == 1 then
        return timer
    else
        timer = timer / (1 + ((difficulty - 1) / 9))
        return timer
    end
end

function ebs.getFreeSlot()
    for k, v in ipairs(ebs.phaseIdDifficulty) do
        if v == nil then
            return k
        end
    end
    return 1
end

function ebs.getLastSuccessfulDifficulty(accountId, fightType)
    if ebs.clearedDifficulty[accountId] then
        local difficulty = ebs.clearedDifficulty[accountId][fightType]
        if difficulty then
            return difficulty
        end
    end
    return 0
end

function ebs.awardScore(slotId)
    for _, playerGuid in pairs(ebs.playersInGroup[slotId]) do
        local player GetPlayerByGUID(playerGuid)
        if player then
            local totalscore
            local basescore
            local accountId = GetPlayerByGUID(playerGuid):GetAccountId()

            if scoreEarned[accountId] == nil then scoreEarned[accountId] = 0 end
            if scoreTotal[accountId] == nil then scoreTotal[accountId] = 0 end
            local oldScore = scoreEarned[accountId]

            if ebs.fightType[slotId] == PARTY_IN_PROGRESS and ebs.Config.rewardParty == 1 then
                basescore = ebs.Config.baseScore + ebs.Config.additionalScore * ebs.GetLastSuccessfulDifficulty(accountId, PARTY_IN_PROGRESS)
            end

            if ebs.fightType[slotId] == RAID_IN_PROGRESS and ebs.Config.rewardRaid == 1 then
                totalscore = ebs.Config.baseScore + ebs.Config.additionalScore * ebs.GetLastSuccessfulDifficulty(accountId, RAID_IN_PROGRESS)
            end

            local gain = score - oldScore
            scoreEarned[accountId] = score
            scoreTotal[accountId] = scoreTotal[accountId] + gain
            CharDBExecute('REPLACE INTO `'..ebs.Config.customDbName..'`.`eventscript_score` VALUES ('..accountId..', '..scoreEarned[accountId]..', '..scoreTotal[accountId]..');');
            local gameTime = (tonumber(tostring(GetGameTime())))
            local playerLowGuid = GetGUIDLow(playerGuid)
            CharDBExecute('INSERT IGNORE INTO `'..ebs.Config.customDbName..'`.`eventscript_encounters` VALUES ('..gameTime..', '..playerLowGuid..', '..eventInProgress..', '..ebs.phaseIdDifficulty[slotId]..', '..ebs.fightType[slotId]..', '..GetTimeDiff(ebs.encounterStartTime[slotId])..');');
        end
    end
end

function ebs.storeEncounter(slotId)
    for _, playerGuid in pairs(ebs.playersInGroup[slotId]) do
        if  GetPlayerByGUID(playerGuid) then
            local accountId = GetPlayerByGUID(playerGuid):GetAccountId()
            local gameTime = (tonumber(tostring(GetGameTime())))
            local playerLowGuid = GetGUIDLow(playerGuid)
            CharDBExecute('INSERT IGNORE INTO `'..ebs.Config.customDbName..'`.`eventscript_encounters` VALUES ('..gameTime..', '..playerLowGuid..', '..eventInProgress..', '..ebs.phaseIdDifficulty[slotId]..', '..ebs.fightType[slotId]..', '..GetTimeDiff(ebs.encounterStartTime[slotId])..');');
        end
    end
end

function ebs.onHello(_, player, creature)
    if not player then
        return
    end
    if ebs.getFreeSlot() == nil then
        --todo: change broadcast message to whisper
        player:SendBroadcastMessage("Too many heroes are already fighting the enemies of time. Please hold on until i can support more timewalking magic.")
    else
        player:GossipMenuAddItem(OPTION_ICON_CHAT, "We are ready to fight a servant! (Difficulty " .. 1 + ebs.getLastSuccessfulDifficulty(player:GetAccountId(), PARTY_IN_PROGRESS) .. ")", ebs.encounter[eventInProgress].npc[2], 1)
        player:GossipMenuAddItem(OPTION_ICON_CHAT, "We brought the best there is and we're ready for anything (Difficulty " .. 1 + ebs.getLastSuccessfulDifficulty(player:GetAccountId(), RAID_IN_PROGRESS) .. ")", ebs.encounter[eventInProgress].npc[2], 2)
    end
    player:GossipMenuAddItem(OPTION_ICON_CHAT, "What's my score?", ebs.encounter[eventInProgress].npc[2], 0)
    player:GossipSendMenu(ebs.encounter[eventInProgress].npcText, creature, 0)
end

function ebs.chromieGossip(_, player, object, sender, intid, code, menu_id)
    local spawnedBoss
    local spawnedCreature = {}

    if player == nil then return end

    local group = player:GetGroup()
    local slotId = ebs.getFreeSlot()
    if intid == 0 then
        local accountId = player:GetAccountId()
        if scoreEarned[accountId] == nil then scoreEarned[accountId] = 0 end
        if scoreTotal[accountId] == nil then scoreTotal[accountId] = 0 end
        --todo: change broadcast message to whisper
        player:SendBroadcastMessage("Your current event score is: "..scoreEarned[accountId].." and your all-time event score is: "..scoreTotal[accountId])
        player:GossipComplete()
        return
    end

    if intid == 1 or intid == 2 then
        if slotId == nil then
            --todo: change broadcast message to whisper
            player:SendBroadcastMessage("Too many heroes are already fighting the enemies of time. Please hold on until i can support more timewalking magic.")
            player:GossipComplete()
            return
        end

        if player:IsInGroup() == false then
            --todo: change broadcast message to whisper
            player:SendBroadcastMessage("You need to be in a group to start this.")
            player:GossipComplete()
            return
        end

        if not group:IsLeader(player:GetGUID()) then
            --todo: change broadcast message to whisper
            player:SendBroadcastMessage("You are not the leader of your group.")
            player:GossipComplete()
            return
        end
    end

    local spawnType, entry, mapId, x, y, z, o, despawnTime = table.unpack(ebs.encounter[eventInProgress].npc)
    if intid == 1 then
        if group:IsRaidGroup() == true then
            --todo: change broadcast message to whisper
            player:SendBroadcastMessage("You can not accept that task while in a raid group.")
            player:GossipComplete()
            return
        end
        groupPlayers = group:GetMembers()

        --start 5man encounter
        ebs.fightType[slotId] = PARTY_IN_PROGRESS
        ebs.phaseIdDifficulty[slotId] = 1 + ebs.getLastSuccessfulDifficulty(player:GetAccountId(), ebs.fightType[slotId])
        spawnedCreature[1]= object:SpawnCreature(ebs.encounter[eventInProgress].addEntry, x, y, z+2, o, spawnType, despawnTime)
        spawnedCreature[1]:SetPhaseMask(ebs.Config.eventPhase[slotId])
        spawnedCreature[1]:SetScale(spawnedCreature[1]:GetScale() * ebs.getSize(slotId))
        ebs.spawnedBossGuid[slotId] = spawnedCreature[1]:GetGUID()
        spawnedCreature[1]:SetData('ebs_mode', ebs.fightType[slotId])
        spawnedCreature[1]:SetData('ebs_difficulty', ebs.phaseIdDifficulty[slotId])

        local maxHealth = ebs.encounter[eventInProgress].addHealthModifierParty * spawnedCreature[1]:GetMaxHealth()
        local health = ebs.encounter[eventInProgress].addHealthModifierParty * spawnedCreature[1]:GetHealth()
        spawnedCreature[1]:SetMaxHealth(maxHealth)
        spawnedCreature[1]:SetHealth(health)

        ebs.encounterStartTime[slotId] = GetCurrTime()

        for n, v in pairs(groupPlayers) do
            if v:GetDistance(object) < 80 then
                v:SetPhaseMask(ebs.Config.eventPhase[slotId])
                ebs.playersInGroup[slotId][n] = v:GetGUID()
                spawnedCreature[1]:SetInCombatWith(v)
                v:SetInCombatWith(spawnedCreature[1])
                spawnedCreature[1]:AddThreat(v, 1)
            else
                v:SendBroadcastMessage("You were too far away to join the fight.")
            end
        end
    end

    if intid == 2 then
        if group:IsRaidGroup() == false then
            --todo: change broadcast message to whisper
            player:SendBroadcastMessage("You can not accept that task without being in a raid group.")
            player:GossipComplete()
            return
        end
        groupPlayers = group:GetMembers()

        --start raid encounter
        ebs.fightType[slotId] = RAID_IN_PROGRESS
        ebs.phaseIdDifficulty[slotId] = 1 + ebs.getLastSuccessfulDifficulty(player:GetAccountId(), ebs.fightType[slotId])

        spawnedBoss = object:SpawnCreature(ebs.encounter[eventInProgress].bossEntry, x, y, z+2, o, spawnType, despawnTime)
        spawnedBoss:SetPhaseMask(ebs.Config.eventPhase[slotId])
        spawnedBoss:SetScale(spawnedBoss:GetScale() * ebs.getSize(ebs.phaseIdDifficulty[slotId]))
        ebs.spawnedBossGuid[slotId] = spawnedBoss:GetGUID()
        spawnedBoss:SetData('ebs_difficulty', ebs.phaseIdDifficulty[slotId])

        if ebs.encounter[slotId].addAmount > 0 then
            for c = 1, ebs.encounter[slotId].addAmount do
                local randomX = (math.sin(math.random(1,360)) * 15)
                local randomY = (math.sin(math.random(1,360)) * 15)
                spawnedCreature[c] = spawnedBoss:SpawnCreature(ebs.encounter[slotId].addEntry, x + randomX, y + randomY, z+2, o)
                spawnedCreature[c]:SetPhaseMask(ebs.Config.eventPhase[slotId])
                spawnedCreature[c]:SetScale(spawnedCreature[c]:GetScale() * ebs.getSize(ebs.phaseIdDifficulty[slotId]))
                spawnedCreature[c]:SetData('ebs_difficulty', ebs.phaseIdDifficulty[slotId])
            end
        end

        ebs.encounterStartTime[slotId] = GetCurrTime()

        for n, v in pairs(groupPlayers) do
            if v:GetDistance(object) < 80 then
                v:SetPhaseMask(ebs.Config.eventPhase[slotId])
                ebs.playersInGroup[slotId][n] = v:GetGUID()
                spawnedBoss:SetInCombatWith(v)
                v:SetInCombatWith(spawnedBoss)
                spawnedBoss:AddThreat(v, 1)
                if ebs.encounter[eventInProgress].addAmount > 0 then
                    for c = 1, ebs.encounter[eventInProgress].addAmount do
                        spawnedCreature[c]:SetInCombatWith(v)
                        v:SetInCombatWith(spawnedCreature[c])
                        spawnedCreature[c]:AddThreat(v, 1)
                    end
                end
            else
                v:SendBroadcastMessage("You were too far away to join the fight.")
            end
        end
    end
    player:GossipComplete()
end

function ebs.summonEventNPC()
    -- tempSummon an NPC with a dialogue option to start the encounter, store the guid for later unsummon
    local spawnType, entry, mapId, x, y, z, o, despawnTime = table.unpack(ebs.encounter[eventInProgress].npc)
    local spawnedNPC = PerformIngameSpawn(spawnType, entry, mapId, 0, x, y, z, o, false, despawnTime)
    ebs.spawnedGossipNpcGuid = spawnedNPC:GetGUID()
    RegisterCreatureGossipEvent(ebs.encounter[eventInProgress].npc[2], GOSSIP_EVENT_ON_HELLO, ebs.onHello)
    RegisterCreatureGossipEvent(ebs.encounter[eventInProgress].npc[2], GOSSIP_EVENT_ON_SELECT, ebs.chromieGossip)
end

function ebs.command(event, player, command, chatHandler)
    local commandArray = {}
    local eventId

    --prevent players from using this
    if not chatHandler:IsAvailable(ebs.Config.GMRankForEventStart) then
        return
    end

    -- split the command variable into several strings which can be compared individually
    commandArray = ebs.splitString(command)

    for k, v in pairs(commandArray) do
        commandArray[k] = string.lower(commandArray[k]:gsub("[';\\, ]", ""))
    end

    if commandArray[1] == "startevent" then
        eventId = tonumber(commandArray[2])
        if not eventId then
            chatHandler:SendSysMessage("Missing event id. Expected syntax: 'startevent $eventId'")
            return false
        end
        if ebs.encounter[eventId] then
            local spawnType, entry, mapId, x, y, z, o, despawnTime = table.unpack(ebs.encounter[eventId].npc)
        else
            chatHandler:SendSysMessage("Event "..eventId.." is not properly configured. Aborting")
            return false
        end

        if eventInProgress == nil then
            eventInProgress = eventId
            ebs.summonEventNPC()
            chatHandler:SendSysMessage("Starting event "..eventInProgress..".")
            return false
        else
            chatHandler:SendSysMessage("Event "..eventInProgress.." is already active.")
            return false
        end
    elseif commandArray[1] == "stopevent" then
        if eventInProgress == nil then
            chatHandler:SendSysMessage("There is no event in progress.")
            return false
        end
        chatHandler:SendSysMessage("Stopping event "..eventInProgress..".")
        local spawnType, entry, mapId, x, y, z, o, despawnTime = table.unpack(ebs.encounter[eventInProgress].npc)
        ClearCreatureGossipEvents(entry)
        local map = GetMapById(mapId)
        local spawnedNPC = map:GetWorldObject(ebs.spawnedGossipNpcGuid):ToCreature()
        if spawnedNPC then
            spawnedNPC:DespawnOrUnsummon(0)
        end
        eventInProgress = nil
        return false
    end

    --prevent non-Admins from using the rest
    if not chatHandler:IsAvailable(ebs.Config.GMRankForUpdateDB) then
        return
    end

    --nothing here yet
    return
end

function ebs.returnPlayers(slotId)
    local player
    local playerListString
    for _, v in pairs(ebs.playersInGroup[slotId]) do
        player = GetPlayerByGUID(v)
        if player then
            player:SetPhaseMask(1)
            if playerListString == nil then
                playerListString = player:GetName()
            else
                playerListString = playerListString..", "..player:GetName()
            end
            if player:GetCorpse() then
                player:GetCorpse():SetPhaseMask(1)
            end
        end
    end
    return playerListString
end

function ebs.finishPlayers(slotId)
    for _, v in pairs(ebs.playersInGroup[slotId]) do
        local player
        local accountId
        player = GetPlayerByGUID(v)
        accountId = player:GetAccountId()
        local difficulty = ebs.phaseIdDifficulty[slotId]
        if not ebs.clearedDifficulty[accountId] then
            ebs.clearedDifficulty[accountId] = {}
        end
        if not ebs.clearedDifficulty[accountId][ebs.fightType[slotId]]
                or ebs.clearedDifficulty[accountId][ebs.fightType[slotId]] < difficulty then
            ebs.clearedDifficulty[accountId][ebs.fightType[slotId]] = difficulty
            ebs.SaveProgress(accountId, ebs.fightType[slotId], difficulty)
        end
        if player then
            player:RegisterEvent(ebs.castFireworks, 1000, 20)
        end
    end
end

function ebs.bossReset(event, creature)
    local slotId = 0
    if ebs.has_value(ebs.spawnedBossGuid, creature:GetGUID()) then
        slotId = ebs.returnKey(ebs.spawnedBossGuid, creature:GetGUID())
    end

    if slotId == 0 then
        PrintError("eventBosses.lua: A Boss encounter ended without a valid slotId.")
        return
    end

    ebs.spawnedBossGuid[slotId] = nil

    local playerListString = ebs.returnPlayers(slotId)
    if creature:IsDead() == true then
        ebs.finishPlayers(slotId)
        ebs.awardScore(slotId)
        SendWorldMessage("The raid encounter "..creature:GetName().." was completed on difficulty " .. ebs.phaseIdDifficulty[slotId] ..
                " in " .. ebs.getEncounterDuration(slotId).." by: "..playerListString..". Congratulations!")
    end

    ebs.playersInGroup[slotId] = {}
    ebs.fightType[slotId] = nil
    creature:DespawnOrUnsummon(0)
end

function ebs.addReset(event, creature)
    local slotId = 0
    if ebs.has_value(ebs.spawnedBossGuid, creature:GetGUID()) then
        slotId = ebs.returnKey(ebs.spawnedBossGuid, creature:GetGUID())
    end

    if slotId == 0 then
        PrintError("eventBosses.lua: A Boss encounter ended without a valid slotId.")
        return
    end
    if ebs.fightType[slotId] ~= PARTY_IN_PROGRESS then
        return
    end

    ebs.spawnedBossGuid[slotId] = nil

    local playerListString = ebs.returnPlayers(slotId)
    if creature:IsDead() == true then
        ebs.finishPlayers(slotId)
        ebs.awardScore(slotId)
        SendWorldMessage("The party encounter "..creature:GetName().." was completed on difficulty " .. ebs.phaseIdDifficulty[slotId] ..
                " in " ..ebs.getEncounterDuration(slotId).." by: "..playerListString..". Congratulations!")
    end

    ebs.playersInGroup[slotId] = {}
    ebs.fightType[slotId] = nil
    creature:DespawnOrUnsummon(0)
end

function ebs.SaveProgress(accountId, encounterType, difficulty)
    CharDBExecute('REPLACE INTO `'..ebs.Config.customDbName..'`.`eventscript_difficulty` VALUES ('..accountId..', '..eventInProgress..', '..encounterType..', '..difficulty..');')
end

function ebs.closeLua(_)
    if eventInProgress then
        local npcObject
        local mapId
        mapId = ebs.encounter[eventInProgress].npc[3]
        if not mapId then
            PrintError("eventBosses.lua: No mapId found for the event ".. eventInProgress ..".")
            return
        end
        local map = GetMapById(mapId)
        npcObject = map:GetWorldObject(ebs.spawnedGossipNpcGuid):ToCreature()
        if not npcObject then
            PrintError("eventBosses.lua: No valid npcObject found for the event ".. eventInProgress ..".")
            return
        end
        npcObject:DespawnOrUnsummon(0)
    end
end

--on ReloadEluna / Startup
local query = CharDBQuery('SELECT * FROM `'..ebs.Config.customDbName..'`.`eventscript_score`;')
if query ~= nil then
    local account
    repeat
        account = query:GetUInt32(0)
        scoreEarned[account] = query:GetUInt32(1)
        scoreTotal[account] = query:GetUInt32(2)
    until not query:NextRow()
end

math.randomseed(os.time())

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, ebs.command)
RegisterPlayerEvent(PLAYER_EVENT_ON_REPOP, ebs.resetPlayers)
RegisterPlayerEvent(PLAYER_EVENT_ON_LOGOUT, ebs.resetPlayers)

RegisterServerEvent(ELUNA_EVENT_ON_LUA_STATE_CLOSE, ebs.closeLua, 0)
