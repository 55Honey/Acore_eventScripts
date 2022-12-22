--Copyright (C) 2022  https://github.com/55Honey
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
-- Date: 15/02/2022
-- Time: 20:07
-- To change this template use File | Settings | File Templates.
-- Originally created by Honey for Azerothcore
-- requires ElunaLua module


--[[ This script serves for providing fun and fool events
    Typing

    .fun gurubashi [$repeats]
    will start an announcement about an incoming fun event happening every minute. Repeats defaults to 15.

    The last Repetition will result in all players who are in open world and opt-in by typing '.fun on' to do the following:
    - leave their parties/raids
    - get resurrected and set to full health
    - receive a strong hot
    - have their position stored
    - get teleported to Gurubashi Arena

    If the player types `.fun return` they are teleported to their saved position and their saved position is deleted.
--]]

------------------------------------------------------------------------------------------------
-- ADMIN GUIDE:  -  compile the core with ElunaLua module
--               -  adjust config in this file
--               -  add this script to ../lua_scripts/
------------------------------------------------------------------------------------------------

------------------------------------------
-- Begin of config section
------------------------------------------

local Config = {}

Config.Spell1 = 71142       -- Rejuvenation with 6750 to 11250 ticks for 15s. Applied before teleport. May be nil.
Config.Spell2 = 61734       -- Noblegarden Bunny. Applied after teleport. May be nil.
Config.AllowedMaps = {0,1,530,571}
-- Allowed maps are: Eastern Kingdoms, Kalimdor, Outland (Including Belf and Spacegoat starting zones), Northrend


local mapId = {}
local xCoord = {}
local yCoord = {}
local zCoord = {}
local orientation = {}
local initialMessage = {}
local followupMessage = {}

-- Config for the Gurubashi teleport event
mapId['gurabashi'] = 0
xCoord['gurabashi'] = -13207.77
yCoord['gurabashi'] = 274.35
zCoord['gurabashi'] = 38.23
orientation['gurabashi'] = 4.22
initialMessage['gurabashi'] = " minutes from now all players which reside in an open world map AND opt in will be teleported for an event. If you wish to participate type '.fun on'. There will be further announcements every minute."
followupMessage['gurabashi'] = " all players in open world maps who sign up, will be teleported for an event. If you wish to opt in, please type '.fun on'."

-- Config for the Halaa teleport event
mapId['halaa'] = 530
xCoord['halaa'] = -1568.77
yCoord['halaa'] = 7947.6
zCoord['halaa'] = -13.23
orientation['halaa'] = 1.29
initialMessage['halaa'] = " minutes from now all players which reside in an open world map AND opt in will be teleported to Halaa for mass-PvP. If you wish to participate type '.fun on'. There will be further announcements every minute."
followupMessage['halaa'] = " all players in open world maps who sign up, will be teleported to Halaa for mass-PvP. If you wish to opt in, please type '.fun on'."

------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------

local PLAYER_EVENT_ON_LOGOUT = 4            -- (event, player)
local PLAYER_EVENT_ON_COMMAND = 42          -- (event, player, command, chatHandler) - player is nil if command used from console. Can return false
local TEAM_ALLIANCE = 0
local TEAM_HORDE = 1
local TEAM_NEUTRAL = 2

local message = "Party time! Greetings from Chromie and her helpers!"

local storedMap = {}
local storedX = {}
local storedY = {}
local storedZ = {}
local optIn = {}

local eventName

local function randomised(init)
    return math.random (-20, 20) + init
end

local function ft_hasValue(tab,val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

local function ft_wipePos(event, player)
    storedMap[player:GetGUIDLow()] = nil
    storedX[player:GetGUIDLow()] = nil
    storedY[player:GetGUIDLow()] = nil
    storedZ[player:GetGUIDLow()] = nil
    optIn[player:GetGUIDLow()] = nil
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

local function ft_storePos(player)
    storedMap[player:GetGUIDLow()] = player:GetMapId()
    storedX[player:GetGUIDLow()] = player:GetX()
    storedY[player:GetGUIDLow()] = player:GetY()
    storedZ[player:GetGUIDLow()] = player:GetZ()
end

local function ft_teleportReminder(eventId, delay, repeats)
    SendWorldMessage("Participants of the event can become revived AND return back to the position before the event by typing '.fun return'.")
    if repeats == 1 then
        eventName = nil
    end
end

local function ft_teleport(playerArray)

    for n = 1, #playerArray do

        if optIn[playerArray[n]:GetGUIDLow()] ~= nil then
            if ft_hasValue(Config.AllowedMaps,playerArray[n]:GetMapId()) then

                if not playerArray[n]:IsAlive() then
                    playerArray[n]:ResurrectPlayer(100)
                end
                ft_storePos(playerArray[n])
                playerArray[n]:SetHealth(playerArray[n]:GetMaxHealth())
                if Config.Spell1 ~= nil then
                    playerArray[n]:AddAura(Config.Spell1, playerArray[n])
                end

                if playerArray[n]:IsInGroup() then
                    playerArray[n]:RemoveFromGroup()
                end

                if Config.Spell2 ~= nil then
                    playerArray[n]:CastSpell(playerArray[n], Config.Spell2, true)
                end

                playerArray[n]:Teleport(mapId[eventName], randomised(xCoord)[eventName], randomised(yCoord)[eventName], zCoord[eventName], orientation[eventName])
                playerArray[n]:RegisterEvent(ft_wipePos, 300000)

                playerArray[n]:PlayDirectSound(2847, playerArray[n])
                playerArray[n]:SendBroadcastMessage( message )

            end
        end

    end
end

local function ft_funEventAnnouncer(eventid, delay, repeats)

    if repeats > 1 then
        local minutes = repeats - 1
        local text2
        if minutes == 1 then
            text2 = ' minute'
        else
            text2 = ' minutes'
        end
        SendWorldMessage('In '..minutes..text2..followupMessage)
    else
        local allyPlayers = GetPlayersInWorld(TEAM_ALLIANCE)
        local hordePlayers = GetPlayersInWorld(TEAM_HORDE)

        local duration = GetCurrTime()
        math.randomseed (duration)

        if allyPlayers ~= nil then
            ft_teleport(allyPlayers)
        end

        if hordePlayers ~= nil then
            ft_teleport(hordePlayers)
        end

        duration = GetCurrTime() - duration
        print( 'Executing Event Teleport. Duration: '..duration..'ms. Participants: '..#allyPlayers+#hordePlayers )

        CreateLuaEvent(ft_teleportReminder,30000,6)
        optIn = {}
    end
end

local function ft_command(event, player, command, chatHandler)

    local commandArray = splitString(command)
    if commandArray[1] ~= 'fun' then
        return
    end

    if commandArray[2] == nil then
        chatHandler:SendSysMessage("If you wish to opt in, please type '.fun on'. You can change your decision and opt out by typing '.fun no' or '.fun off'.")
    end

    if commandArray[2] == 'no' or commandArray[2] == 'off' then
        if player == nil then
            chatHandler:SendSysMessage("Can not use 'no' from the console. Requires player object.")
            return false
        end
        optIn[player:GetGUIDLow()] = nil
        chatHandler:SendSysMessage("You've chosen to not participate in the event this time.")
        return false
    end

    if commandArray[2] == 'on' then
        if player == nil then
            chatHandler:SendSysMessage("Can not use 'on' from the console. Requires player object.")
            return false
        end
        optIn[player:GetGUIDLow()] = 1
        chatHandler:SendSysMessage("You've signed up for the event! Use '.fun no' to opt out.")
        return false
    end

    if commandArray[2] == 'return' then
        if player == nil then
            chatHandler:SendSysMessage("Can not use 'return' from the console. Requires player object.")
            return false
        end
        if storedMap[player:GetGUIDLow()] ~= nil then
            if not player:IsAlive() then
                player:ResurrectPlayer(100)
            end
            player:CastSpell(player, 1706, true)
            player:Teleport(storedMap[player:GetGUIDLow()],storedX[player:GetGUIDLow()],storedY[player:GetGUIDLow()],storedZ[player:GetGUIDLow()],0)
            ft_wipePos(_,player)
            return false
        else
            chatHandler:SendSysMessage("There is no position saved for your character.")
            return false
        end
    end

    --GM rank 2 required to continue
    if not chatHandler:IsAvailable(2) then
        return
    end

    if commandArray[2] == 'gurubashi' or commandArray[2] == 'halaa' then
        eventName = commandArray[2]
        local repeats = 15

        if commandArray[3] ~= nil then
            repeats = tonumber(commandArray[3])
        end


        CreateLuaEvent(ft_funEventAnnouncer, 60000, repeats )

        local text2
        if repeats == 1 then
            text2 = ' minute'
        else
            text2 = ' minutes'
        end

        SendWorldMessage('In '..repeats..text2..initialMessage)
        return false
    end

    return
end

RegisterPlayerEvent(PLAYER_EVENT_ON_COMMAND, ft_command)
RegisterPlayerEvent(PLAYER_EVENT_ON_LOGOUT, ft_wipePos)
