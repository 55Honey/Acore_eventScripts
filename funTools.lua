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

local function newAutotable( dim )
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

local GAME_EVENT_START = 34                     -- (event, gameeventid)

------------------------------------------
-- Begin of config section
------------------------------------------

local Config = {}
local mapId = {}
local xCoord = {}
local yCoord = {}
local zCoord = {}
local orientation = {}
local initialMessage = {}
local followupMessage = {}
local pvpOn = {}
local minLevel = {}
local checkAmount = {}

Config.Spell1 = 71142       -- Rejuvenation with 6750 to 11250 ticks for 15s. Applied before teleport. May be nil.
Config.Spell2 = 61734       -- Noblegarden Bunny. Applied after teleport. May be nil.
Config.AllowedMaps = {0,1,530,571}
-- Allowed maps are: Eastern Kingdoms, Kalimdor, Outland (Including Belf and Spacegoat starting zones), Northrend

-- Config for the Gurubashi teleport event
mapId['gurubashi'] = 0
xCoord['gurubashi'] = -13207.77
yCoord['gurubashi'] = 274.35
zCoord['gurubashi'] = 38.23
orientation['gurubashi'] = 4.22
initialMessage['gurubashi'] = " minutes from now all players which reside in an open world map AND opt in will be teleported for FFA-PvP. If you wish to participate type '.fun on'. There will be further announcements every minute."
followupMessage['gurubashi'] = " all players in open world maps who sign up, will be teleported for FFA-PvP. If you wish to opt in, please type '.fun on'."
pvpOn['gurubashi'] = false -- Don't turn World PvP on
minLevel['gurubashi'] = nil -- it is ffa PvP, no need for a minimum level
checkAmount['gurubashi'] = false

-- Config for the Halaa teleport event
Config.startTime = newAutotable(2)
-- Config.startTime[weekday][hour]   Sunday = 1, Wednesday = 4, Saturday = 7, hour = 0-23
-- [7][20] means every saturday at 20.00 / 8pm
Config.startTime[1][2] = true
Config.startTime[2][2] = true
Config.startTime[3][2] = true
Config.startTime[4][2] = true
Config.startTime[5][2] = true
Config.startTime[6][2] = true
Config.startTime[7][2] = true
Config.startTime[1][20] = true
Config.startTime[2][20] = true
Config.startTime[3][20] = true
Config.startTime[4][20] = true
Config.startTime[5][20] = true
Config.startTime[6][20] = true
Config.startTime[7][20] = true
mapId['halaa_defender'] = 530
xCoord['halaa_defender'] = -1568
yCoord['halaa_defender'] = 7947
zCoord['halaa_defender'] = -13
orientation['halaa_defender'] = 1.29
mapId['halaa_attacker'] = 530
xCoord['halaa_attacker'] = -1908
yCoord['halaa_attacker'] = 8038
zCoord['halaa_attacker'] = -8
orientation['halaa_attacker'] = 6
initialMessage['halaa'] = " minutes from now all players which reside in an open world map AND opt in will be teleported to Halaa for mass-PvP. If you wish to participate type '.fun on'. There will be further announcements every minute."
followupMessage['halaa'] = " all players in open world maps who sign up, will be teleported to Halaa for mass-PvP. If you wish to opt in, please type '.fun on'."
pvpOn['halaa'] = true
minLevel['halaa'] = 58
checkAmount['halaa'] = true

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
local numExpectedAllies = 0
local numExpectedHorde = 0

local eventName
local attacker          -- team Id
local attackers = {}    -- array of attacking players low guids
local defenders = {}    -- array of defending players low guids

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

local function ft_wipePos( player )
    if player then
        --deduct 1 player from the expected number of participants
        if player:GetTeam() == TEAM_ALLIANCE then
            numExpectedAllies = numExpectedAllies - 1
        elseif player:GetTeam() == TEAM_HORDE then
            numExpectedHorde = numExpectedHorde - 1
        end

        -- safety check
        if numExpectedAllies < 0 then numExpectedAllies = 0 end
        if numExpectedHorde < 0 then numExpectedHorde = 0 end

        --
        player:SendBroadcastMessage("Your teleport has expired.")
        storedMap[player:GetGUIDLow()] = nil
        storedX[player:GetGUIDLow()] = nil
        storedY[player:GetGUIDLow()] = nil
        storedZ[player:GetGUIDLow()] = nil
        optIn[player:GetGUIDLow()] = nil
    end
end

local function ft_wipePosEvent( _, _, _, player )
    ft_wipePos(player)
end

local function ft_wipePosLogout( _, player )
    ft_wipePos(player)
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

                -- if the event involves world PvP, there's gonna be attacker and defender. Else just summon everyone to the same place.
                if pvpOn[eventName] then
                    local target
                    if playerArray[n]:GetTeam() == attacker then
                        target= eventName..'_attacker'
                        table.insert(attackers, playerArray[n]:GetGUIDLow())
                    else
                        target= eventName..'_defender'
                        table.insert(defenders, playerArray[n]:GetGUIDLow())
                    end

                    playerArray[n]:SetPvP( true )
                    playerArray[n]:Teleport( mapId[target], randomised(xCoord[target]), randomised(yCoord[target]), zCoord[target], orientation[target] )

                else
                    playerArray[n]:Teleport( mapId[eventName], randomised(xCoord[eventName]), randomised(yCoord[eventName]), zCoord[eventName], orientation[eventName] )
                    playerArray[n]:RegisterEvent(ft_wipePosEvent, 300000)
                end

                playerArray[n]:PlayDirectSound(2847, playerArray[n])
                playerArray[n]:SendBroadcastMessage( message )
            else
                playerArray[n]:SendBroadcastMessage( 'You can not participate from raids/dungeons/BGs/arenas.' )
            end

        end

    end
end

local function ft_startEvent()
    local Players = {}
    local duration = GetCurrTime()
    math.randomseed (duration)

    for ind,val in pairs(optIn) do
        if val == 1 then
            table.insert(Players, GetPlayerByGUID(ind))
        end
    end

    -- For Halaa event only
    if eventName == 'halaa' then
        if numExpectedHorde > numExpectedAllies then
            attacker = TEAM_HORDE
            SetOwnerHalaa(0)
        else
            attacker = TEAM_ALLIANCE
            SetOwnerHalaa(1)
        end
        SendWorldMessage('The battle for Halaa has begun!')
    end

    if Players and #Players > 0 then
        ft_teleport(Players)
    end

    -- invite players to raids if it's world PvP
    local raidMembers = 0
    local leader = ''
    if pvpOn[eventName] then
        if attackers and #attackers > 0 then
            for ind, val in pairs(attackers) do

                if leader == '' then
                    leader = val
                    raidMembers = raidMembers + 1

                elseif raidMembers == 1 then
                    GetPlayerByGUID( leader ):GroupCreate( GetPlayerByGUID(val) )
                    if GetPlayerByGUID(leader) and GetPlayerByGUID(leader):GetGroup() then
                        if not GetPlayerByGUID(leader):GetGroup():IsRaidGroup() then
                            GetPlayerByGUID(leader):GetGroup():ConvertToRaid()
                        end
                    end
                    raidMembers = raidMembers + 1

                else
                    if GetPlayerByGUID(leader) and GetPlayerByGUID(leader):GetGroup() then
                        GetPlayerByGUID(leader):GetGroup():AddMember(GetPlayerByGUID(val))
                        raidMembers = raidMembers + 1
                    end
                end

                if raidMember == 40 then
                    leader = ''
                    raidMembers = 0
                end
            end
        end

        leader = ''
        raidMembers = 0

        if defenders and #defenders > 0 then
            for ind, val in pairs(defenders) do

                if leader == '' then
                    leader = val
                    raidMembers = raidMembers + 1

                elseif raidMembers == 1 then
                    GetPlayerByGUID( leader ):GroupCreate( GetPlayerByGUID(val) )
                    if GetPlayerByGUID(leader) and GetPlayerByGUID(leader):GetGroup() then
                        if not GetPlayerByGUID(leader):GetGroup():IsRaidGroup() then
                            GetPlayerByGUID(leader):GetGroup():ConvertToRaid()
                        end
                    end
                    raidMembers = raidMembers + 1

                else
                    if GetPlayerByGUID(leader) and GetPlayerByGUID(leader):GetGroup() then
                        GetPlayerByGUID(leader):GetGroup():AddMember(GetPlayerByGUID(val))
                        raidMembers = raidMembers + 1
                    end
                end

                if raidMember == 40 then
                    leader = ''
                    raidMembers = 0
                end
            end
        end
    end

    duration = GetCurrTime() - duration
    print( 'Executing Event Teleport. Duration: '..duration..'ms. Participants: '..#Players )

    CreateLuaEvent(ft_teleportReminder,30000,6)
    optIn = {}
    numExpectedAllies = 0
    numExpectedHorde = 0
    attackers = {}
    defenders = {}
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
        SendWorldMessage('In '..minutes..text2..followupMessage[eventName])
    else
        -- start the event
        ft_startEvent()
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
        chatHandler:SendSysMessage("You've chosen to NOT participate in the event this time.")
        return false
    end

    if commandArray[2] == 'on' then
        -- if player is nil, it's the console
        if player == nil then
            chatHandler:SendSysMessage("Can not use 'on' from the console. Requires player object.")
            return false
        end

        -- don't allow players too low to participate
        if minLevel[eventName] ~= nil then
            if player:GetLevel() < minLevel[eventName] then
                chatHandler:SendSysMessage("You are not high enough level to participate in this event. Minimum level is "..minLevel[eventName]..".")
                return false
            end
        end

        -- check if there are too many players from one faction
        if checkAmount[eventName] == true then
            if player:GetTeam() == TEAM_ALLIANCE then
                if numExpectedAllies > 10 and numExpectedAllies > numExpectedHorde * 1.5 then
                    chatHandler:SendSysMessage("There are too many players from the Alliance already. Care to join as Horde?")
                    return false
                end
            elseif player:GetTeam() == TEAM_HORDE then
                if numExpectedHorde > 10 and numExpectedHorde > numExpectedAllies * 1.5 then
                    chatHandler:SendSysMessage("There are too many players from the Horde already. Care to join as Alliance?")
                    return false
                end
            end
        end

        optIn[player:GetGUIDLow()] = 1
        chatHandler:SendSysMessage("You've signed up for the event! Use '.fun no' to opt out.")
        if player:GetTeam() == TEAM_ALLIANCE then
            numExpectedAllies = numExpectedAllies + 1
        else
            numExpectedHorde = numExpectedHorde + 1
        end
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
            ft_wipePos( player )
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

        if commandArray[3] ~= nil and tonumber(commandArray[3]) then
            repeats = tonumber(commandArray[3])
        end


        CreateLuaEvent(ft_funEventAnnouncer, 60000, repeats )

        local text2
        if repeats == 1 then
            text2 = ' minute'
        else
            text2 = ' minutes'
        end

        SendWorldMessage('In '..repeats..text2..initialMessage[eventName])
        return false
    end

    return
end

local function ft_OnGameEventStart( _, gameeventid )
    if gameeventid == 73 then   --hourly bells

        local nowTable = os.date('*t')
        local nowWDay = nowTable.wday
        local nowHour = nowTable.hour

        if Config.startTime[nowWDay][nowHour] == true then
            RunCommand('.fun halaa 15')
        end
    end
end

RegisterPlayerEvent( PLAYER_EVENT_ON_COMMAND, ft_command )
RegisterPlayerEvent( PLAYER_EVENT_ON_LOGOUT, ft_wipePosLogout )
RegisterServerEvent( GAME_EVENT_START, ft_OnGameEventStart, 0 )
