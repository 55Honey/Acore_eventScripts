--
--
-- Created by IntelliJ IDEA.
-- User: Silvia
-- Date: 15/02/2022
-- Time: 20:07
-- To change this template use File | Settings | File Templates.
-- Originally created by Honey for Azerothcore
-- requires ElunaLua module


-- This script serves for fun and fool events

------------------------------------------------------------------------------------------------
-- ADMIN GUIDE:  -  compile the core with ElunaLua module
--               -  adjust config in this file
--               -  add this script to ../lua_scripts/
------------------------------------------------------------------------------------------------

------------------------------------------
-- Begin of config section
------------------------------------------

local Config = {}

Config.spell1 = 71142       -- Rejuvenation with 6750 to 11250 ticks for 15s

--target of the gurubashi teleport spell
local mapId = 0
local xCoord = -13207.77
local yCoord = 274.35
local zCoord = 38.23
local orientation = 4.22

------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------

local PLAYER_EVENT_ON_COMMAND = 42          -- (event, player, command, chatHandler) - player is nil if command used from console. Can return false
local TEAM_ALLIANCE = 0
local TEAM_HORDE = 1
local TEAM_NEUTRAL = 2

local message = 'April foooooooools! Greetings from Chromie and her helpers!'

local function randomised(init)
    return math.random (-20, 20) + init
end

local function splitString(inputstr, seperator)
    if seperator == nil then
        seperator = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..seperator.."]+)") do
        table.insert(t, str)
    end
    return t
end

local function aF_command(event, player, command, chatHandler)
    --GM rank 2 required to continue
    if not chatHandler:IsAvailable(2) then
        return
    end

    local commandArray = splitString(command)

    if commandArray[1] ~= 'af' then
        return
    end

    local allyPlayers = GetPlayersInWorld(TEAM_ALLIANCE)
    local hordePlayers = GetPlayersInWorld(TEAM_HORDE)

    if commandArray[2] == 'gurubashi' then

        local duration = GetCurrTime()

        for n = 1, #allyPlayers do

            if not allyPlayers[n]:IsAlive() then
                allyPlayers[n]:ResurrectPlayer(100)
            end

            allyPlayers[n]:SetHealth(allyPlayers[n]:GetMaxHealth())
            allyPlayers[n]:AddAura(Config.spell1, allyPlayers[n])

            if allyPlayers[n]:IsInGroup() then
                allyPlayers[n]:RemoveFromGroup()
            end

            math.randomseed (n)

            allyPlayers[n]:Teleport(mapId, randomised(xCoord), randomised(yCoord), zCoord, orientation)

            allyPlayers[n]:PlayDirectSound(2847, allyPlayers[n])
            allyPlayers[n]:SendBroadcastMessage( message )

        end

        for n = 1, #hordePlayers do
            if not hordePlayers[n]:IsAlive() then
                hordePlayers[n]:ResurrectPlayer(100)
            end

            hordePlayers[n]:SetHealth(hordePlayers[n]:GetMaxHealth())
            hordePlayers[n]:AddAura(Config.spell1, hordePlayers[n])

            if hordePlayers[n]:IsInGroup() then
                hordePlayers[n]:RemoveFromGroup()
            end

            math.randomseed (n)

            hordePlayers[n]:Teleport(mapId, randomised(xCoord), randomised(yCoord), zCoord, orientation)

            hordePlayers[n]:PlayDirectSound(2847, hordePlayers[n])
            hordePlayers[n]:SendBroadcastMessage( message )

        end
    end

    duration = GetCurrTime() - duration
    chatHandler:SendSysMessage('Executing Gurubashi Teleport. Duration: '..duration..'ms')
end

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, aF_command)
