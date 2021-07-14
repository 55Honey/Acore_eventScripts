DELETE FROM `creature_template` WHERE `entry` IN (1114001,1114002,1114003,1114004,1114005,1114006,1114007,1114008,1114009,1114010,1114011,1114012);
DELETE FROM `creature_template_addon` WHERE `entry` IN (1114001,1114002,1114003,1114004,1114005,1114006,1114007,1114008,1114009,1114010,1114011,1114012);
DELETE FROM `npc_text` WHERE `ID` IN (91201);
DELETE FROM `gossip_menu` WHERE `MenuID` IN (63001);


INSERT INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `modelid1`, `modelid2`, `modelid3`, `modelid4`, `name`, `subname`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `trainer_type`, `trainer_spell`, `trainer_class`, `trainer_race`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `InhabitType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `mechanic_immune_mask`, `spell_school_immune_mask`, `flags_extra`, `ScriptName`, `VerifiedBuild`) VALUES
#Injured
(1114001, 0, 0, 0, 0, 0, 21761, 2988, 4602, 0, 'Mildly Injured Soldier', '', 0, 63, 63, 0, 35, 1, 1, 1.14286, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 33536, 2048, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 1, 1.35, 1, 1, 0, 0, 0, 0, 0, 2, '', 0),
(1114002, 0, 0, 0, 0, 0, 6570, 2987, 21760, 0, 'Injured Soldier', '', 0, 63, 63, 0, 35, 1, 1, 1.14286, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 33536, 2048, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 1, 1.35, 1, 1, 0, 0, 0, 0, 0, 2, '', 0),
(1114003, 0, 0, 0, 0, 0, 2588, 2986, 21759, 0, 'Severely Injured Soldier', '', 0, 63, 63, 0, 35, 1, 1, 1.14286, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 33536, 2048, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 1, 1.35, 1, 1, 0, 0, 0, 0, 0, 2, '', 0),
(1114004, 0, 0, 0, 0, 0, 1027, 2985, 23186, 0, 'Critically Injured Soldier', '', 0, 63, 63, 0, 35, 1, 1, 1.14286, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 33536, 2048, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 1, 1.35, 1, 1, 0, 0, 0, 0, 0, 2, '', 0),
(1114005, 0, 0, 0, 0, 0, 14533, 16307, 23185, 0, 'Mildly Injured Soldier', 'Bleeding', 0, 63, 63, 0, 35, 1, 1, 1.14286, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 33536, 2048, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 1, 1.35, 1, 1, 0, 0, 0, 0, 0, 2, '', 0),
(1114006, 0, 0, 0, 0, 0, 14534, 16308, 23184, 0, 'Injured Soldier', 'Bleeding', 0, 63, 63, 0, 35, 1, 1, 1.14286, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 33536, 2048, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 1, 1.35, 1, 1, 0, 0, 0, 0, 0, 2, '', 0),
(1114007, 0, 0, 0, 0, 0, 14535, 23179, 23044, 0, 'Severely Injured Soldier', 'Bleeding', 0, 63, 63, 0, 35, 1, 1, 1.14286, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 33536, 2048, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 1, 1.35, 1, 1, 0, 0, 0, 0, 0, 2, '', 0),
(1114008, 0, 0, 0, 0, 0, 14536, 23078, 23186, 0, ''Critically Injured Soldier', 'Bleeding', 0, 63, 63, 0, 35, 1, 1, 1.14286, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 33536, 2048, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 1, 1.35, 1, 1, 0, 0, 0, 0, 0, 2, '', 0),
(1114009, 0, 0, 0, 0, 0, 16490, 18024, 26248, 0, 'Mildly Injured Soldier', 'Dying', 0, 63, 63, 0, 35, 1, 1, 1.14286, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 33536, 2048, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 1, 1.35, 1, 1, 0, 0, 0, 0, 0, 2, '', 0),
(1114010, 0, 0, 0, 0, 0, 16491, 18025, 26249, 0, 'Injured Soldier', 'Dying', 0, 63, 63, 0, 35, 1, 1, 1.14286, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 33536, 2048, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 1, 1.35, 1, 1, 0, 0, 0, 0, 0, 2, '', 0),
(1114011, 0, 0, 0, 0, 0, 16492, 18026, 26893, 0, 'Severely Injured Soldier', 'Dying', 0, 63, 63, 0, 35, 1, 1, 1.14286, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 33536, 2048, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 1, 1.35, 1, 1, 0, 0, 0, 0, 0, 2, '', 0),
(1114012, 0, 0, 0, 0, 0, 16493, 18027, 26894, 0, ''Critically Injured Soldier', 'Dying', 0, 63, 63, 0, 35, 1, 1, 1.14286, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 33536, 2048, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 1, 1.35, 1, 1, 0, 0, 0, 0, 0, 2, '', 0),
#Gossip NPC
(1114100, 0, 0, 0, 0, 0, 10508, 0, 0, 0, 'Lushen Asralius', 'Port Nurse', 63001, 63, 63, 0, 35, 1, 1, 1.14286, 1, 0, 0, 1, 2000, 2000, 1, 1, 1, 33536, 2048, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, '', 0, 3, 1, 1.35, 1, 1, 0, 0, 1, 0, 0, 2, '', 0);

INSERT INTO `creature_template_addon` (`entry`, `path_id`, `mount`, `bytes1`, `bytes2`, `emote`, `isLarge`, `auras`) VALUES
(1114001, 0, 0, 3, 0, 0, 0, ''),
(1114002, 0, 0, 3, 0, 0, 0, ''),
(1114003, 0, 0, 3, 0, 0, 0, ''),
(1114004, 0, 0, 3, 0, 0, 0, ''),
(1114005, 0, 0, 3, 0, 0, 0, ''),
(1114006, 0, 0, 3, 0, 0, 0, ''),
(1114007, 0, 0, 3, 0, 0, 0, ''),
(1114008, 0, 0, 3, 0, 0, 0, ''),
(1114009, 0, 0, 3, 0, 0, 0, ''),
(1114010, 0, 0, 3, 0, 0, 0, ''),
(1114011, 0, 0, 3, 0, 0, 0, ''),
(1114012, 0, 0, 3, 0, 0, 0, '');

INSERT INTO `npc_text` (`ID`, `text0_0`, `BroadcastTextID0`, `lang0`, `Probability0`, `em0_0`, `em0_1`, `em0_2`, `em0_3`, `em0_4`, `em0_5`, `BroadcastTextID1`, `lang1`, `Probability1`, `em1_0`, `em1_1`, `em1_2`, `em1_3`, `em1_4`, `em1_5`, `BroadcastTextID2`, `lang2`, `Probability2`, `em2_0`, `em2_1`, `em2_2`, `em2_3`, `em2_4`, `em2_5`, `BroadcastTextID3`, `lang3`, `Probability3`, `em3_0`, `em3_1`, `em3_2`, `em3_3`, `em3_4`, `em3_5`, `BroadcastTextID4`, `lang4`, `Probability4`, `em4_0`, `em4_1`, `em4_2`, `em4_3`, `em4_4`, `em4_5`, `BroadcastTextID5`, `lang5`, `Probability5`, `em5_0`, `em5_1`, `em5_2`, `em5_3`, `em5_4`, `em5_5`, `BroadcastTextID6`, `lang6`, `Probability6`, `em6_0`, `em6_1`, `em6_2`, `em6_3`, `em6_4`, `em6_5`, `BroadcastTextID7`, `lang7`, `Probability7`, `em7_0`, `em7_1`, `em7_2`, `em7_3`, `em7_4`, `em7_5`, `VerifiedBuild`) VALUES
(91201, 'Greetings, $n. Many soldiers got injured in a recent battle alongside the shore. The wounded are just about to arrive. Can you help and safe them?', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1);

INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES
(63001, 91201);

#todo: adjust models
