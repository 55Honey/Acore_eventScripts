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
------------------------------------------------------------------------------------------------
-- GM GUIDE:     -  use .startevent $event $difficulty to start and spawn 
--               -  maybe offer teleports
--               -  use .stopevent to end the event and despawn the NPC
------------------------------------------------------------------------------------------------
local Config = {}                   --general config flags

local Config_npcEntry = {}          --db entry of the NPC creature to summon the boss
local Config_npcText = {}           --gossip in npc_text to be told by the summoning NPC
local Config_bossEntry = {}         --db entry of the boss creature
local Config_addEntry = {}          --db entry of the add creature

local Config_bossSpell1 = {}            --directly applied to the tank
local Config_bossSpell2 = {}            --randomly applied to a player in 35m range
local Config_bossSpell3 = {}            --on the 2nd nearest player within 30m
local Config_bossSpell4 = {}            --on a random player within 40m
local Config_bossSpellSelf = {}         --cast on boss while adds are still alive
local Config_bossSpellEnrage = {}

local Config_bossSpellTimer1 = {}       -- This timer applies to Config_bossSpell1
local Config_bossSpellTimer2 = {}       -- This timer applies to Config_bossSpell2
local Config_bossSpellTimer3 = {}       -- This timer applies to Config_bossSpellSelf in phase 1 and Config_bossSpell3+4 randomly later
local Config_bossSpellEnrageTimer = {}

local Config_addSpell1 = {}
local Config_addSpell2 = {}
local Config_addSpell3 = {}

local Config_addSpellEnrage = {}
local Config_addSpellTimer1 = {}
local Config_addSpellTimer2 = {}
local Config_addSpellTimer3 = {}

local Config_addsAmount = {}                   -- how many adds will spawn
local Config_aura1Add1 = {}                    -- an aura to add to the 1st add
local Config_aura2Add1 = {}                    -- another aura to add toe the 1st add
local Config_aura1Add2 = {}                    -- an aura to add to the 2nd add
local Config_aura2Add2 = {}                    -- another aura to add toe the 2nd add
local Config_aura1Add3 = {}                    -- an aura to add to the 3rd add
local Config_aura2Add3 = {}                    -- another aura to add toe the 3rd add

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

-- Database NPC entries. Must match the associated .sql file
Config_bossEntry[1] = 1112001
Config_npcEntry[1] = 1112002
Config_addEntry[1] = 1112003
Config_npcText[1] = 91111

-- list of spells:
Config_addSpell1[1] = 60488         -- Mithril Frag Bomb 8y 149-201 damage + stun
Config_addSpell2[1] = 24326         -- Shadow Bolt (30)
Config_addSpell3[1] = 12421         -- HIGH knockback (ZulFarrak beast)

Config_bossSpell1[1] = 38846        -- Forceful Cleave (Target + nearest ally)
Config_bossSpell2[1] = 45108        -- CKs Fireball
Config_bossSpell3[1] = 53721        -- Death and decay (10% hp per second)
Config_bossSpell4[1] = 37279        -- Rain of Fire
Config_bossSpellSelf[1] = 69898     -- Hot
Config_bossSpellEnrage[1] = 69166   -- Soft Enrage

Config_addSpellTimer1[1] = 13000
Config_addSpellTimer2[1] = 11000
Config_addSpellTimer3[1] = 37000

Config_bossSpellTimer1[1] = 19000   -- This timer applies to Config_bossSpell1
Config_bossSpellTimer2[1] = 23000   -- This timer applies to Config_bossSpell2
Config_bossSpellTimer3[1] = 11000   -- This timer applies to Config_bossSpellSelf in phase 1 and Config_bossSpell3+4 randomly later
Config_bossSpellEnrageTimer[1] = 180000

Config_addsAmount[1] = 3

Config_aura1Add1[1] = 34184         -- Arcane
Config_aura2Add1[1] = 7941          -- Nature
Config_aura1Add2[1] = 7942          -- Fire
Config_aura2Add2[1] = 7940          -- Frost
Config_aura1Add3[1] = 34182         -- Holy
Config_aura2Add3[1] = 34309         -- Shadow

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
local lastBossSpellSelf
local lastAddSpell1
local lastAddSpell2
local lastAddSpell3

--local arrays
local cancelEventIdHello = {}
local cancelEventIdStart = {}
local addNPC = {}
local bossNPC = {}
local playersInRaid = {}
local groupPlayers = {}
local playersForFireworks = {}
local spawnedCreatureGuid = {}

--todo: move add abilities to a single event

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
    
function eS_summonEventNPC(playerGuid)
    local player
    -- tempSummon an NPC with a dialouge option to start the encounter, store the guid for later unsummon
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
    cancelEventIdStart[eventInProgress] = RegisterCreatureGossipEvent(Config_npcEntry[eventInProgress], GOSSIP_EVENT_ON_SELECT, eS_spawnBoss)
end

function eS_onHello(event, player, creature)
    if bossfightInProgress ~= nil then return end

    if player == nil then return end
    player:GossipMenuAddItem(OPTION_ICON_CHAT, "We are ready to fight a servant!", Config_npcEntry[eventInProgress], 0)
    player:GossipMenuAddItem(OPTION_ICON_CHAT, "We brought the best there is and we're ready for anything.", Config_npcEntry[eventInProgress], 1)
    player:GossipSendMenu(Config_npcText[1], creature, 0)
end

function eS_spawnBoss(event, player, object, sender, intid, code, menu_id)
    local spawnedBoss
    local spawnedCreature = {}

    if player == nil then return end
    if player:IsInGroup() == false then
        player:SendBroadcastMessage("You need to be in a party.")
        player:GossipComplete()
        return
    end

    local group = player:GetGroup()

    if intid == 0 then
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
        --start 5man encounter
        bossfightInProgress = 1
        spawnedCreature[1]= player:SpawnCreature(Config_addEntry[eventInProgress], x, y, z, o)
        spawnedCreature[1]:SetPhaseMask(2)
        spawnedCreature[1]:SetScale(spawnedCreature[1]:GetScale() * eS_getSize(difficulty))
        encounterStartTime = GetCurrTime()

        groupPlayers = group:GetMembers()
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

    elseif intid == 1 then
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
        --start raid encounter
        bossfightInProgress = 2

        spawnedBoss = player:SpawnCreature(Config_bossEntry[eventInProgress], x, y, z+2, o)
        spawnedBoss:SetPhaseMask(2)
        spawnedBoss:SetScale(spawnedBoss:GetScale() * eS_getSize(difficulty))
        spawnedBossGuid = spawnedBoss:GetGUID()

        for c = 1, Config_addsAmount[eventInProgress] do
            local randomX = (math.sin(math.random(1,360)) * 20)
            local randomY = (math.sin(math.random(1,360)) * 20)
            spawnedCreature[c] = player:SpawnCreature(Config_addEntry[eventInProgress], x + randomX, y + randomY, z+2, o)
            spawnedCreature[c]:SetPhaseMask(2)
            spawnedCreature[c]:SetScale(spawnedCreature[c]:GetScale() * eS_getSize(difficulty))
            spawnedCreatureGuid[c] = spawnedCreature[1]:GetGUID()
        end
        encounterStartTime = GetCurrTime()

        groupPlayers = group:GetMembers()
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
        for c = 1, #spawnedCreature do
            if spawnedCreature[c] ~= nil then
                if Config_aura1Add1[c] ~= nil then
                    spawnedCreature[c]:AddAura(Config_aura1Add1[c], spawnedCreature[c])
                end
                if Config_aura2Add1[c] ~= nil then
                    spawnedCreature[c]:AddAura(Config_aura2Add1[c], spawnedCreature[c])
                end
            end

            if spawnedCreature[c] ~= nil then
                if Config_aura1Add2[c] ~= nil then
                    spawnedCreature[c]:AddAura(Config_aura1Add2[c], spawnedCreature[c])
                end
                if Config_aura2Add2[c] ~= nil then
                    spawnedCreature[c]:AddAura(Config_aura2Add2[c], spawnedCreature[c])
                end
            end

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
    player:GossipComplete()
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
    lastBossSpellSelf = encounterStartTime
end

function bossNPC.reset(event, creature)
    local player
    creature:RemoveEvents()
    bossfightInProgress = nil
    addsDownCounter = nil
    if creature:IsDead() == true then
        creature:SendUnitYell("Master, save me!", 0 )
        creature:PlayDirectSound(8865)
        local playerListString
        for _, v in pairs(playersInRaid) do
            player = GetPlayerByGUID(v)
            if player ~= nil then
                player:SetPhaseMask(1)
                if playerListString == nil then
                    playerListString = player:GetName()
                else
                    playerListString = playerListString..", "..player:GetName()
                end
            end
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
                player:SetPhaseMask(1)
            end
        end
        playersInRaid = {}
    end
    creature:DespawnOrUnsummon(0)
end

function bossNPC.Event(event, delay, pCall, creature)
    if creature:IsCasting() == true then return end

    if Config_bossSpellEnrageTimer[eventInProgress] ~= nil and Config_bossSpellEnrage[eventInProgress] ~= nil then
        if eS_getDifficultyTimer(Config_bossSpellEnrageTimer[eventInProgress]) < eS_getTimeSince(encounterStartTime)then
            if phase == 2 and eS_getTimeSince(encounterStartTime) > Config_bossSpellEnrageTimer[eventInProgress] then
                phase = 3
                if Config_bossSpellEnrage[eventInProgress] ~= nil then
                    creature:SendUnitYell("FEEL MY WRATH!", 0 )
                    creature:CastSpell(creature, Config_bossSpellEnrage[eventInProgress])
                    return
                end
            end
        end
    end

    if Config_bossSpellTimer3[eventInProgress] ~= nil then
        if eS_getDifficultyTimer(Config_bossSpellTimer3[eventInProgress]) < eS_getTimeSince(lastBossSpell3) then
            if addsDownCounter < 3 then
                if Config_bossSpellSelf[eventInProgress] ~= nil then
                    creature:CastSpell(creature, Config_bossSpellSelf[eventInProgress])
                    lastBossSpell3 = GetCurrTime()
                    return
                end
            elseif phase == 1 then
                creature:SendUnitYell("You might have handled these creatures. But now I WILL handle YOU!", 0 )
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
end

function addNPC.onEnterCombat(event, creature, target)
    local player

    timer1 = Config_addSpellTimer1[eventInProgress] / (1 + ((difficulty - 1) / 5))
    timer2 = Config_addSpellTimer2[eventInProgress] / (1 + ((difficulty - 1) / 5))
    timer3 = Config_addSpellTimer3[eventInProgress] / (1 + ((difficulty - 1) / 5))

    creature:RegisterEvent(addNPC.Bomb, timer1, 0)
    creature:RegisterEvent(addNPC.Bolt, timer2, 0)
    creature:RegisterEvent(addNPC.Knockback, timer3, 0)
    creature:CallAssistance()
    for _, v in pairs(playersInRaid) do
        player = GetPlayerByGUID(v)
        creature:AddThreat(player, 1)
    end
    addphase = 1

    lastAddSpell1 = encounterStartTime
    lastAddSpell2 = encounterStartTime
    lastAddSpell3 = encounterStartTime
end

function addNPC.Bomb(event, delay, pCall, creature)
    if creature:IsCasting() == true then return end
    local random = math.random(0, 2)
    local players = creature:GetPlayersInRange(30)
    if #players > 1 then
        creature:CastSpell(creature:GetAITarget(SELECT_TARGET_FARTHEST, true, random, 30), 12421)
    else
        creature:CastSpell(creature:GetVictim(),12421)
    end
end

function addNPC.Bolt(event, delay, pCall, creature)
    if creature:IsCasting() == true then return end
    if addphase == 1 and creature:GetHealthPct() < 68 then
        addphase = 2
        creature:SendUnitYell("ENOUGH", 0 )
        creature:PlayDirectSound(412)
        local players = creature:GetPlayersInRange(30)
        if #players > 1 then
            creature:CastSpell(creature:GetAITarget(SELECT_TARGET_FARTHEST, true, 0, 30), 19471)
        else
            creature:CastSpell(creature:GetAITarget(SELECT_TARGET_FARTHEST, true, 0, 30), 60488)
        end
    elseif addphase == 2 and creature:GetHealthPct() < 35 then
        addphase = 3
        creature:SendUnitYell("ENOUGH", 0 )
        creature:PlayDirectSound(412)
        local players = creature:GetPlayersInRange(30)
        if #players > 1 then
            creature:CastSpell(creature:GetAITarget(SELECT_TARGET_FARTHEST, true, 0, 30), 19471)
        else
            creature:CastSpell(creature:GetAITarget(SELECT_TARGET_FARTHEST, true, 0, 30), 60488)
        end
    else
        if (math.random(1, 100) <= 25) then
            creature:PlayDirectSound(6436)
            creature:CastSpell(creature:GetVictim(), 60488)
        end
    end
end

function addNPC.Knockback(event, delay, pCall, creature)
    creature:SendUnitYell("Me smash.", 0 )
    creature:CastSpell(creature, 24326)
    eS_checkInCombat()
end

function addNPC.reset(event, creature)
    local player
    creature:RemoveEvents()
    if bossfightInProgress == 1 then
        if creature:IsDead() == true then
            local playerListString
            CreateLuaEvent(eS_castFireworks, 1000, 20)
            creature:PlayDirectSound(8803)
            for _, v in pairs(playersInRaid) do
                player = GetPlayerByGUID(v)
                if player ~= nil then
                    player:SetPhaseMask(1)
                    if playerListString == nil then
                        playerListString = player:GetName()
                    else
                        playerListString = playerListString..", "..player:GetName()
                    end
                end
            end
            SendWorldMessage("The party encounter "..creature:GetName().." was completed on difficulty "..difficulty.." in "..eS_getEncounterDuration().." by: "..playerListString..". Congratulations!")
            playersForFireworks = playersInRaid
            playersInRaid = {}
        else
            creature:SendUnitYell("Hahahaha!", 0 )
            for _, v in pairs(playersInRaid) do
                player = GetPlayerByGUID(v)
                if player ~= nil then
                    player:SetPhaseMask(1)
                end
            end
            playersInRaid = {}
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
    bossfightInProgress = nil
    creature:DespawnOrUnsummon(0)
end

function eS_castFireworks(eventId, delay, repeats)
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

function eS_resetPlayers(event, player)
    if eS_has_value(playersInRaid, player:GetGUID()) and player:GetPhaseMask() ~= 1 then
        if player ~= nil then
            player:SetPhaseMask(1)
            player:SendBroadcastMessage("You left the event.")
        end
    end
end

function eS_getSize(difficulty)
    local value
    if difficulty == 1 then
        value = 1
    else
        value = 1 + (difficulty - 1) / 4
    end
    return value
end

function eS_splitString(inputstr, seperator)
    if seperator == nil then
        seperator = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..seperator.."]+)") do
        table.insert(t, str)
    end
    return t
end

function eS_checkInCombat()
    --check if all players are in combat
    local player
    for n, v in pairs(playersInRaid) do
        player = GetPlayerByGUID(v)
        if player ~= nil then
            if player:IsInCombat() == false and player:GetPhaseMask() == 2 then
                player:SetPhaseMask(1)
                player:SendBroadcastMessage("You were returned to the real time because you did not participate.")
            end
        end
    end
end

function eS_getEncounterDuration()
    local dt = GetTimeDiff(encounterStartTime)
    return string.format("%.2d:%.2d", (dt / 1000 / 60) % 60, (dt / 1000) % 60)
end

function eS_getTimeSince(time)
    local dt = GetTimeDiff(time)
    return dt
end

function eS_has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

function eS_getDifficultyTimer(rawTimer)
    local timer = rawTimer / (1 + ((difficulty - 1) / 5))
    return timer
end

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, eS_command)
RegisterPlayerEvent(PLAYER_EVENT_ON_REPOP, eS_resetPlayers)

--init combat events
RegisterCreatureEvent(1112003, 1, addNPC.onEnterCombat)
RegisterCreatureEvent(1112003, 2, addNPC.reset) -- OnLeaveCombat
RegisterCreatureEvent(1112003, 4, addNPC.reset) -- OnDied

RegisterCreatureEvent(1112001, 1, bossNPC.onEnterCombat)
RegisterCreatureEvent(1112001, 2, bossNPC.reset) -- OnLeaveCombat
RegisterCreatureEvent(1112001, 4, bossNPC.reset) -- OnDied
