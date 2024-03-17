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

if not ebs then
    require('eventBosses')
end

local bossNPC = {}
local addNPC = {}

--------------------------------------------------------------------------------------
-- The data below is mandatory for the main script to work with the encounter.      --
-- The encounterId must be unique for each encounter.                               --
--------------------------------------------------------------------------------------

local encounterId = 1

ebs.encounter[encounterId] = {
    --                type          entry  map   x        y       z       o  despawnTime
    ["npc"] = { TYPE_CREATURE, 1112002, 1, 5507.3, -3685.5, 1594.3, 1.97, 0 },          -- gossip NPC for players to interact with
    ["npcText"] = 91111,                                                                -- gossip NPC text ID
    ["bossEntry"] = 1112001,                                                            -- boss entry (auto summoned)
    ["addEntry"] = 1112003,                                                             -- add entry (auto summoned, if addAmount > 0)
    ["addHealthModifierParty"] = 0.2,                                                   -- modifier for add health in 5man mode
    ["addAmount"] = 3                                                                   -- amount of adds to spawn right at the start of the encounter
}

--------------------------------------------------------------------------------------

local addDownCounter = {}

function bossNPC.Fire( eventid, delay, repeats, creature )
    local target = creature:GetAITarget( SELECT_TARGET_RANDOM, true, nil, -20 )
    if target then
        creature:CastSpell( target, 31340, false )
    end
end

function bossNPC.PullIn( eventid, delay, repeats, creature )
    local target = creature:GetAITarget( SELECT_TARGET_FARTHEST, true, nil, -20 )
    creature:CastSpell( target, 59395, true )
end

function bossNPC.Pool( eventid, delay, repeats, creature )
    if math.random(1,2) == 1 then
        creature:CastSpell( creature, 32014, false )
    else
        creature:CastSpell( creature:GetVictim(), 53721, false )
    end
end

function bossNPC.onEnterCombat( event, creature, target )
    creature:CallAssistance()
    creature:CallForHelp( 200 )
    local difficulty = creature:GetData('ebs_difficulty')
    -- add custom scripting below
    creature:RegisterEvent( bossNPC.Fire, ebs.GetTimer( 10000, difficulty ), 0 )
end

function bossNPC.reset( event, creature )
    creature:RemoveEvents()
    -- add custom scripting below

    -- add custom scripting above
    ebs.bossReset(event, creature)
end

function addNPC.RemoveInterrupt( eventid, delay, repeats, add )
    add:SetImmuneTo( MECHANIC_INTERRUPT, false )
end

function addNPC.HealBoss( eventid, delay, repeats, add )
    local boss = add:GetOwner()
    if boss then
        if boss:GetHealthPct() < 90 then
            if math.random(1,2) == 1 then
                boss:SendUnitYell( "HAHAHA! You can't hurt me!", 0 )
            else
                add:SendUnitYell( "Don't you dare harm the master!", 0 )
            end
            --add:SetImmuneTo( MECHANIC_INTERRUPT, true )
            add:CastCustomSpell( boss, 30878, false, nil, 1000000 )
            --add:RegisterEvent( addNPC.RemoveInterrupt, 3000, 1 )
        end
    end
end

function addNPC.Splash( eventid, delay, repeats, add )
    add:CastCustomSpell( add:GetVictim(), 32014, false, nil, 150 )
end

function addNPC.onEnterCombat( event, creature, target )
    creature:CallAssistance()
    creature:CallForHelp( 200 )
    local difficulty = creature:GetData('ebs_difficulty')
    -- add custom scripting below

    creature:RegisterEvent( addNPC.HealBoss, { 10000, 15000 }, 0 )
    creature:RegisterEvent( addNPC.Splash, { ebs.GetTimer( 10000, difficulty ), 15000 }, 0 )
    if difficulty >= 3 or creature:GetData('ebs_mode') == PARTY_IN_PROGRESS then
        creature:RegisterEvent( bossNPC.PullIn, { ebs.GetTimer( 10000, difficulty ), 15000 }, 0 )
    end
end

function addNPC.reset( event, creature )
    creature:RemoveEvents()
    local difficulty = creature:GetData('ebs_difficulty')
    local slotId
    if creature:IsDead() then
        local bossLowGUID = creature:GetData('ebs_boss_lowguid')

        local hasValue
        hasValue, slotId = ebs.returnKey ( ebs.spawnedBossGuid, bossLowGUID )
        if ebs.fightType[ slotId ] ~= RAID_IN_PROGRESS then
            ebs.addReset( event, creature )
            return
        end

        if not addDownCounter[ slotId ] then
            addDownCounter[ slotId ] = 0
        end

        addDownCounter[ slotId ] = addDownCounter[ slotId ] + 1
        if addDownCounter[ slotId ] == ebs.encounter[ encounterId ].addAmount then
            local guid = GetUnitGUID( bossLowGUID, ebs.encounter[ encounterId ].bossEntry )
            local boss = creature:GetMap():GetWorldObject( guid )
            if boss then
                -- add custom scripting below

                boss:SendUnitYell( "You will pay for your actions!", 0 )
                boss:RegisterEvent( bossNPC.PullIn, { ebs.GetTimer( 4000, difficulty ), 6000 }, 0 )
                boss:RegisterEvent( bossNPC.Pool, { ebs.GetTimer( 10000, difficulty ), 12000}, 0 )

                -- add custom scripting above
            end
        end
    end


    ebs.addReset( event, creature )
end

RegisterCreatureEvent( ebs.encounter[ encounterId ].bossEntry, 1, bossNPC.onEnterCombat )
RegisterCreatureEvent( ebs.encounter[ encounterId ].bossEntry, 2, bossNPC.reset ) -- OnLeaveCombat
RegisterCreatureEvent( ebs.encounter[ encounterId ].bossEntry, 4, bossNPC.reset ) -- OnDied

RegisterCreatureEvent( ebs.encounter[ encounterId ].addEntry, 1, addNPC.onEnterCombat )
RegisterCreatureEvent( ebs.encounter[ encounterId ].addEntry, 2, addNPC.reset ) -- OnLeaveCombat
RegisterCreatureEvent( ebs.encounter[ encounterId ].addEntry, 4, addNPC.reset ) -- OnDied
