--
-- Created by IntelliJ IDEA.
-- User: Silvia
-- Date: 12/04/2021
-- Time: 19:27
-- To change this template use File | Settings | File Templates.
-- Originally created by Honey for Azerothcore
-- requires ElunaLua module


-- This module grants certain NPCs additional abilities and logs dungeon progress.
------------------------------------------------------------------------------------------------
-- ADMIN GUIDE:  -  compile the core with ElunaLua module
--               -  adjust config in this file
--               -  add this script to ../lua_scripts/
------------------------------------------------------------------------------------------------
-- GM GUIDE:     -  move near the entrance of SM Graveyard
--               -  invite all participating players to a raid
--               -  manually reset dungeon ids, rightclicking the player portrait
--               -  create a macro with: '.StartEventSMG'
--               -                       '
------------------------------------------------------------------------------------------------


local Config = {}

-- Name of Eluna dB scheme
Config.customDbName = "ac_eluna"
-- Min GM rank to start an event
Config.GMRankForEventStart = 3

------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------

-- NPCs:
-- Scarlet Sentry 4283
-- Scarlet Torturer 4306
-- Interrogator Vishas 3983
-- Unfettered Spirit 4308
-- Haunting Phantasm 6427
-- Illusionary Phantasm 6493
-- Anguished Dead 6426
-- Bloodmage Thalnos 4543

-- Spells:
-- 49760 Grenade
-- 27873 Hot
-- 15087 Evasion
-- 20223 Reflect 10 seconds
-- 26968 Deadly Poison
-- 3609  Poison Stun
-- 17742 Plague Cloud


local PLAYER_EVENT_ON_COMMAND = 42       -- (event, player, command) - player is nil if command used from console. Can return false

SMG_EventInProgress = 0
SMG_events = {}
SMG_eventListStart = {}
SMG_eventListEnd = {}
local ScarletSentry = {}
local ScarletTorturer = {}
local InterrogatorVishas = {}

    --this command triggers the event
function SMG_command(event, player, command)
    if player ~= nil then
        if player:GetGMRank() < Config.GMRankForEventStart then
            return
        end
    end
    local commandArray = SMG_splitString(command)
    if commandArray[1] == "EventStartSMG" then
        if SMG_EventInProgress ~= 0 then
            player:SendBroadcastMessage("Event already in progress. Aborting.")
            return false
        end
        SMG_EventInProgress = 1
        SMG_StartTime = GetCurrTime()

        SendWorldMessage("The run on the Scarlet Monastery - Graveyard has begun. Expect extraordinary resistance.")

        local logfile = io.open("SMGeventStart.log", "w+")
        logfile:write("Log file for Scarlet monastery graveyard event. Started at "..SMG_StartTime.." \n")

        group = player:GetGroup()
        if group ~= nil then
            print("111")
            groupPlayers = group:GetMembers()
            for _, v in pairs(groupPlayers) do
                print("222")
                if v ~= player then
                    local name = v:GetName()
                    logfile:write(name.."\n")
                    v:SummonPlayer(player)
                    v:UnbindAllInstances()
                    print(name)
                end
            end
            logfile:close()
            group:Disband()
        end
        SMG_registerEvents()

        return false
    elseif commandArray[1] == "EventAddPlayerSMG" then
    -- todo: also teleport this players raid and add all party members to the list/unbind their instances
    end


end

----------------------------------------------------------------------------------

function ScarletSentry.OnEnterCombat(event, creature, target)
    creature:RegisterEvent(ScarletSentry.Poison, math.random(3000, 5000), 0)
    if (math.random(1, 100) <= 50) then
        creature:CastSpell(creature, 15087)
        creature:RegisterEvent(ScarletSentry.Dodge, 10000, 0)
    else
        creature:CastSpell(creature, 20223)
        creature:RegisterEvent(ScarletSentry.Reflect, 10000, 0)
    end
end

function ScarletSentry.Reset(event, creature, killer)
    creature:RemoveEvents()
end

function ScarletSentry.Poison(event, delay, pCall, creature)
    if (math.random(1, 100) <= 75) then
        creature:CastSpell(creature:GetVictim(), 26968)
    end
end

function ScarletSentry.Dodge(event, delay, pCall, creature)
    creature:CastSpell(creature, 15087)
end

function ScarletSentry.Reflect(event, delay, pCall, creature)
    creature:CastSpell(creature, 20223)
end

----------------------------------------------------------------------------------

function ScarletTorturer.OnEnterCombat(event, creature, target)
    creature:RegisterEvent(ScarletTorturer.PoisonStun, math.random(10000, 14000), 0)
    creature:RegisterEvent(ScarletTorturer.Grenade, math.random(5000, 20000), 1)
end

function ScarletTorturer.Reset(event, creature, killer)
    creature:RemoveEvents()
end

function ScarletTorturer.PoisonStun(event, delay, pCall, creature)
    creature:CastSpell(creature:GetVictim(), 3609)
end

function ScarletTorturer.Grenade(event, delay, pCall, creature)
    creature:CastSpell(creature:GetAITarget(0), 49760)
end
----------------------------------------------------------------------------------

function InterrogatorVishas.OnEnterCombat(event, creature, target)
    creature:CastSpell(creature, 27873)
    creature:RegisterEvent(InterrogatorVishas.Hot, 12000, 0)
    creature:RegisterEvent(InterrogatorVishas.Grenade, 8000, 0)
    creature:RegisterEvent(InterrogatorVishas.PlagueCloud, 30000, 0)
end

function InterrogatorVishas.Reset(event, creature, killer)
    creature:RemoveEvents()
end

function InterrogatorVishas.Hot(event, delay, pCall, creature)
    creature:CastSpell(creature, 27873)
end

function InterrogatorVishas.Grenade(event, delay, pCall, creature)
    print("ScarletTorturer.Grenade")
    creature:CastSpell(creature:GetAITarget(0), 49760)
end

function InterrogatorVishas.PlagueCloud(event, delay, pCall, creature)
    print("ScarletTorturer.Grenade")
    creature:CastSpell(creature:GetAITarget(0), 17742)
end
----------------------------------------------------------------------------------

function SMG_registerEvents()
    SMG_eventListStart[1] = RegisterCreatureEvent(4283, 1, ScarletSentry.OnEnterCombat)
    SMG_eventListStart[2] = RegisterCreatureEvent(4306, 1, ScarletTorturer.OnEnterCombat)
    SMG_eventListStart[3] = RegisterCreatureEvent(3983, 1, InterrogatorVishas.OnEnterCombat)

    SMG_eventListEnd[1] = RegisterCreatureEvent(4283, 2, ScarletSentry.Reset) -- OnLeaveCombat
    SMG_eventListEnd[2] = RegisterCreatureEvent(4283, 4, ScarletSentry.Reset) -- OnDied
    SMG_eventListEnd[3] = RegisterCreatureEvent(4306, 2, ScarletTorturer.Reset) -- OnLeaveCombat
    SMG_eventListEnd[4] = RegisterCreatureEvent(4306, 4, ScarletTorturer.Reset) -- OnDied
    SMG_eventListEnd[5] = RegisterCreatureEvent(3983, 2, InterrogatorVishas.Reset) -- OnLeaveCombat
    SMG_eventListEnd[6] = RegisterCreatureEvent(3983, 4, InterrogatorVishas.Reset) -- OnDied
end

function SMG_removeStartEvents()
    local n
    local eventId
    for n, eventId in pairs(SMG_eventListStart) do
        RemoveEventById(SMG_eventListStart[n])
    end
    -- remove all events to remove creature events in 20 minutes.
    CreateLuaEvent(SMG_removeStopEvents, 1200000)
end

function SMG_removeStopEvents()
    local n
    local eventId
    for n, eventId in pairs(SMG_eventListEnd) do
        RemoveEventById(SMG_eventListEnd[n])
    end
end

function SMG_splitString(inputstr, seperator)
    if seperator == nil then
        seperator = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..seperator.."]+)") do
        table.insert(t, str)
    end
    return t
end

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, SMG_command)
