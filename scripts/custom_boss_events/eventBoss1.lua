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

------------------------------------------------------------------------------------------
-- The data below is mandatory for the main script to work with the encounter.          --
-- Adjust as needed. The encounterId must be unique for each encounter.                 --
------------------------------------------------------------------------------------------

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

------------------------------------------------------------------------------------------
-- There are no changes required to this part. It is mandatory for the script to work.  --
-- Custom scripting goes to the designated section at the bottom.                       --
------------------------------------------------------------------------------------------

local addDownCounter = {}

function bossNPC.onEnterCombat( event, creature, target )
    creature:CallAssistance()
    creature:CallForHelp( 200 )
    local difficulty = creature:GetData('ebs_difficulty')
    bossNPC.CustomEnterCombat( creature, target, difficulty )
end

function bossNPC.reset( event, creature )
    creature:RemoveEvents()
    local difficulty = creature:GetData('ebs_difficulty')
    bossNPC.CustomReset( creature, difficulty )
    ebs.bossReset( event, creature )
end

function addNPC.onEnterCombat( event, add, target )
    add:CallAssistance()
    local difficulty = add:GetData('ebs_difficulty')
    addNPC.CustomEnterCombat( add, target, difficulty )
end

function addNPC.reset( event, add )
    add:RemoveEvents()
    local slotId
    local difficulty = add:GetData('ebs_difficulty')
    local bossLowGUID = add:GetData('ebs_boss_lowguid')
    local guid = GetUnitGUID( bossLowGUID, ebs.encounter[ encounterId ].bossEntry )
    local boss = add:GetMap():GetWorldObject( guid )
    if add:IsDead() then

        local hasValue
        hasValue, slotId = ebs.returnKey ( ebs.spawnedBossGuid, bossLowGUID )
        if ebs.fightType[ slotId ] ~= RAID_IN_PROGRESS then
            ebs.addReset( event, add )
            return
        end

        if not addDownCounter[ slotId ] then
            addDownCounter[ slotId ] = 0
        end

        addDownCounter[ slotId ] = addDownCounter[ slotId ] + 1
        if addDownCounter[ slotId ] == ebs.encounter[ encounterId ].addAmount then

            if boss then
                -------------------------------------------------------------------------------
                -- last add died, boss is still alive
                -------------------------------------------------------------------------------
                addNPC.CustomLastAddDead( add, boss, difficulty, slotId )

            end
        end
    end

    addNPC.CustomReset( add, boss, difficulty, slotId )
    ebs.addReset( event, add )
end

--**********************************************************************************
--****                          CUSTOM SCRIPTING BELOW                          ****
--**********************************************************************************

function bossNPC.CustomEnterCombat( creature, target, difficulty )
    -------------------------------------------------------------------------------
    -- This function runs when the raid boss enters combat. It's main use is to register events.
    -------------------------------------------------------------------------------
    creature:RegisterEvent( bossNPC.Fire, ebs.GetTimer( 10000, difficulty ), 0 )
end

function bossNPC.CustomReset( creature, difficulty )
    -------------------------------------------------------------------------------
    -- This function runs for the boss when it resets. This includes everything which ends their combat.
    -- You can add custom scripting here, e.g. checking:
    -- if creature:IsDead() then
    -------------------------------------------------------------------------------
end

function addNPC.CustomEnterCombat( add, target, difficulty )
    -------------------------------------------------------------------------------
    -- This function runs when an add enters combat. It's main use is to register events.
    -------------------------------------------------------------------------------
    add:RegisterEvent( addNPC.HealBoss, { 10000, 15000 }, 0 )
    add:RegisterEvent( addNPC.Splash, { ebs.GetTimer( 10000, difficulty ), 15000 }, 0 )
    if difficulty >= 3 or add:GetData('ebs_mode') == PARTY_IN_PROGRESS then
        add:RegisterEvent( bossNPC.PullIn, { ebs.GetTimer( 10000, difficulty ), 15000 }, 0 )
    end
end

function addNPC.CustomLastAddDead( add, boss, difficulty, slotId )
    -------------------------------------------------------------------------------
    -- This function runs when the last add has died but the boss is still alive.
    -------------------------------------------------------------------------------
    boss:SendUnitYell( "You will pay for your actions!", 0 )
    boss:RegisterEvent( bossNPC.PullIn, { ebs.GetTimer( 4000, difficulty ), 6000 }, 0 )
    boss:RegisterEvent( bossNPC.Pool, { ebs.GetTimer( 10000, difficulty ), 12000}, 0 )
end

function addNPC.CustomReset( add, boss, difficulty, slotId )
    -------------------------------------------------------------------------------
    -- This function runs for every add that resets. This includes everything which ends their combat.
    -- You can add custom scripting here, e.g. checking:
    -- if add:IsDead() then
    -------------------------------------------------------------------------------
end

-------------------------------------------------------------------------------
-- End of pre-defined hooks
-------------------------------------------------------------------------------
local RAIN_OF_FIRE = 31340
local ABOMINATION_HOOK = 59395
local AIR_BURST = 32014
local DEATH_AND_DECAY = 53721
local HEAL = 30878

function bossNPC.Fire( _, _, _, creature )
    local target = creature:GetAITarget( SELECT_TARGET_RANDOM, true, nil, -10 )
    if target then
        creature:CastSpell( target, RAIN_OF_FIRE, false )
    end
end

function bossNPC.PullIn( _, _, _, creature )
    local target = creature:GetAITarget( SELECT_TARGET_FARTHEST, true, nil, -10 )
    creature:CastSpell( target, ABOMINATION_HOOK, true )
end

function bossNPC.Pool( _, _, _, creature )
    if math.random(1,2) == 1 then
        creature:CastSpell( creature, AIR_BURST, false )
    else
        creature:CastSpell( creature:GetVictim(), DEATH_AND_DECAY, false )
    end
end

function addNPC.RemoveInterrupt( _, _, _, add )
    add:SetImmuneTo( MECHANIC_INTERRUPT, false )
end

function addNPC.HealBoss( _, _, _, add )
    local bossLowGUID = add:GetData('ebs_boss_lowguid')
    local guid = GetUnitGUID( bossLowGUID, ebs.encounter[ encounterId ].bossEntry )
    local boss = add:GetMap():GetWorldObject( guid )
    if boss then
        if boss:GetHealthPct() < 90 then
            if math.random(1,2) == 1 then
                boss:SendUnitYell( "HAHAHA! You can't hurt me!", 0 )
            else
                add:SendUnitYell( "Don't you dare harm the master!", 0 )
            end
            --add:SetImmuneTo( MECHANIC_INTERRUPT, true )
            add:UnitMoveStop()
            add:CastCustomSpell( boss, HEAL, false, 1000000 )
            add:RegisterEvent( addNPC.ResumeChase, 2600, 1)
            --add:RegisterEvent( addNPC.RemoveInterrupt, 3000, 1 )
        end
    end
end

function addNPC.Splash( _, _, _, add )
    add:CastCustomSpell( add:GetVictim(), AIR_BURST, false, nil, 150 )
end

function addNPC.ResumeChase( _, _, _, add )
    add:UnitMoveChase()
end

--**********************************************************************************
--****                         END OF CUSTOM SCRIPTING                          ****
--**********************************************************************************

RegisterCreatureEvent( ebs.encounter[ encounterId ].bossEntry, 1, bossNPC.onEnterCombat )
RegisterCreatureEvent( ebs.encounter[ encounterId ].bossEntry, 2, bossNPC.reset ) -- OnLeaveCombat
RegisterCreatureEvent( ebs.encounter[ encounterId ].bossEntry, 4, bossNPC.reset ) -- OnDied

RegisterCreatureEvent( ebs.encounter[ encounterId ].addEntry, 1, addNPC.onEnterCombat )
RegisterCreatureEvent( ebs.encounter[ encounterId ].addEntry, 2, addNPC.reset ) -- OnLeaveCombat
RegisterCreatureEvent( ebs.encounter[ encounterId ].addEntry, 4, addNPC.reset ) -- OnDied
