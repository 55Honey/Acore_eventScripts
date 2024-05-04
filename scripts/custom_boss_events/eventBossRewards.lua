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
-- Date: 22/03/2024
-- Time: 20:07
-- Originally created by Honey for Azerothcore
-- requires mod-eluna

if not ebs then
    require('eventBosses')
end

------------------------------------------
-- Begin of config section
------------------------------------------

ebs.Config.cityAreas = { 3703, 3899,                                 -- Shattrath
                         4395, 4560, 4567, 4601, 4613, 4616, 4620    -- Dalaran
}
ebs.Config.cityAuras = { [1] = 22586,  -- 5% speed
                         [2] = 22586,  -- 5% speed
                         [3] = 22587,  -- 8% speed
                         [4] = 22587,  -- 8% speed
                         [5] = 22588,  -- 10% speed
                         [6] = 22588,  -- 10% speed
                         [7] = 22589,  -- 13% speed
                         [8] = 22589,  -- 13% speed
                         [9] = 22589,  -- 13% speed
                         [10] = 22590  -- 15% speed
}

ebs.Config.raidAura = 2147
ebs.Config.raidAuraBaseDuration = 8
ebs.Config.raidAuraAdditionalDuration = 2
ebs.Config.boostedFactions = { 270, -- Zandalar Tribe
                               509, -- League of Arathor
                               510, -- The Defilers
                               609, -- Cenarion Circle
                               729, -- Frostwolf Clan
                               730, -- Stormpike Guard
                               749, -- Hydraxian Waterlords
                               889, -- Warsong Outriders
                               890, -- Silverwing Sentinels
                               910  -- Brood of Nozdormu
}

------------------------------------------
-- NO ADJUSTMENTS REQUIRED BELOW THIS LINE
------------------------------------------

function ebs.BuffInRaid(player)
    print("69: actually buffing")
    if not ebs.clearedDifficulty[player:GetAccountId()] then
        ebs.clearedDifficulty[player:GetAccountId()] = {}
    end
    local difficulty = ebs.clearedDifficulty[player:GetAccountId()][PARTY_IN_PROGRESS]
    if not difficulty then
        return
    end
    if difficulty > ebs.Config.maxRewardLevel then
        difficulty = ebs.Config.maxRewardLevel
    end

    local duration = ebs.Config.raidAuraBaseDuration + (ebs.Config.raidAuraAdditionalDuration * difficulty)
    player:AddAura(ebs.Config.raidAura, player)
    player:RegisterEvent(function(_, _, _, player)
        player:RemoveAura(ebs.Config.raidAura)
    end, duration * 1000, 1)
end

function ebs.RemovePlayerAuras(_, player)
    player:RemoveAura(ebs.Config.raidAura)
    for _,v in ipairs(ebs.Config.cityAreas) do
        player:RemoveAura(v)
    end
end

function ebs.BuffInCity(event, player, oldArea, newArea)
    -- if the player is now in a main city area, buff it
    if ebs.has_value (ebs.Config.cityAreas, newArea) then
        -- if the player has not completed anything, stop checking early
        if ebs.clearedDifficulty[player:GetAccountId()] == nil then
            return
        end

        local difficulty = ebs.clearedDifficulty[player:GetAccountId()][RAID_IN_PROGRESS]
        if not difficulty then
            return
        end
        if difficulty > ebs.Config.maxRewardLevel then
            difficulty = ebs.Config.maxRewardLevel
        end
        player:AddAura(ebs.Config.cityAuras[difficulty], player)

        -- if the player was in a main city area before, remove the auras
    else
        ebs.RemovePlayerAuras(_, player)
    end
end

function ebs.BoostReputation(_, player, factionId, standing, incremental) -- Can return new standing -> if standing == -1, it will prevent default action (rep gain)
    print('standing: '..standing)
    print('incrememntal: '..incremental)
    if ebs.has_value(ebs.Config.boostedFactions, factionId) then
        if not ebs.clearedDifficulty[player:GetAccountId()] then
            return
        end
        if ebs.clearedDifficulty[player:GetAccountId()][RAID_IN_PROGRESS] >= ebs.Config.maxRewardLevel then
            print('standing: + incremental: '..standing + (incremental * REPUTATION_FACTOR))
            return standing + (incremental * REPUTATION_FACTOR)
        end
    end
end

function ebs.RemoveRaidAuras()
    for m = 1,2 do
        local players = GetPlayersInWorld( n )
        for _, player in pairs(players) do
            player:RemoveAura(ebs.Config.raidAura)
        end
    end
end

function ebs.RemovePartyAuras()
    for n = 1,2 do
        local players = GetPlayersInWorld( n )
        for _, player in pairs(players) do
            for _,v in ipairs(ebs.Config.cityAuras) do
                player:RemoveAura(v)
            end
        end
    end
end

local PLAYER_EVENT_ON_LOGOUT = 4
local PLAYER_EVENT_ON_REPUTATION_CHANGE = 15
local PLAYER_EVENT_ON_UPDATE_AREA = 47

RegisterPlayerEvent( PLAYER_EVENT_ON_LOGOUT, ebs.RemovePlayerAuras )

if ebs.Config.reputationFactor ~= 1 then
    RegisterPlayerEvent( PLAYER_EVENT_ON_REPUTATION_CHANGE, ebs.BoostReputation )
end

if ebs.Config.rewardRaid == 1 then
    RegisterPlayerEvent( PLAYER_EVENT_ON_UPDATE_AREA, ebs.BuffInCity )
    RegisterPlayerEvent( PLAYER_EVENT_ON_LOGIN, ebs.BuffInCity )
end
