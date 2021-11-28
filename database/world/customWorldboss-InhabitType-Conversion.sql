-- Delete if already exsisting for rerun ability

DELETE FROM `creature_template_movement` WHERE `CreatureId` IN (1112001,1112002,1112003,1112011,1112012,1112013,1112021,1112022,1112023,1112031,1112032,1112033,1112041,1112042,1112043);

-- insert new movement type adjustments since their old inhabit type was 3 for ground and water

INSERT INTO `creature_template_movement` (`CreatureId`, `Ground`, `Swim`, `Flight`, `Rooted`, `Chase`, `Random`, `InteractionPauseTimer`) VALUES 
(1112001, 1, 1, 0, 0, 0, 0, NULL), -- Event 1 Boss
(1112002, 1, 1, 0, 0, 0, 0, NULL), -- Custom Chromie 1
(1112003, 1, 1, 0, 0, 0, 0, NULL), -- Event 1 Add
(1112011, 1, 1, 0, 0, 0, 0, NULL), -- Event 2 Boss
(1112012, 1, 1, 0, 0, 0, 0, NULL), -- Custom Chromie 2
(1112013, 1, 1, 0, 0, 0, 0, NULL), -- Event 2 Add
(1112021, 1, 1, 0, 0, 0, 0, NULL), -- Event 3 Boss
(1112022, 1, 1, 0, 0, 0, 0, NULL), -- Custom Chromie 3
(1112023, 1, 1, 0, 0, 0, 0, NULL), -- Event 3 Add
(1112031, 1, 1, 0, 0, 0, 0, NULL), -- Event 4 Boss
(1112032, 1, 1, 0, 0, 0, 0, NULL), -- Custom Chromie 4
(1112033, 1, 1, 0, 0, 0, 0, NULL), -- Event 4 Add
(1112041, 1, 1, 0, 0, 0, 0, NULL), -- Event 4 Boss
(1112042, 1, 1, 0, 0, 0, 0, NULL), -- Custom Chromie 4
(1112043, 1, 1, 0, 0, 0, 0, NULL); -- Event 4 Add
