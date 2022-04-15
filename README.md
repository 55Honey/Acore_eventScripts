## EventScripts
Lua script for Azerothcore with ElunaLUA to
- spawn (custom) NPCs and grant them scripted combat abilities (customWorldboss.lua)
- a fun event to teleport players who opt-in to Gurubashi (funTools.lua)


#### Find me on patreon: https://www.patreon.com/Honeys

## Requirements:
Compile your [Azerothcore](https://github.com/azerothcore/azerothcore-wotlk) with [Eluna Lua](https://github.com/azerothcore/mod-eluna)
The ElunaLua module itself usually doesn't require much setup/config. Just specify the subfolder where to put your lua_scripts in its .conf file.

If the directory was not changed in the ElunaLua config, add the .lua script to your `../lua_scripts/` directory as a subfolder of the worldserver.


# customWorldboss.lua
## Admin Usage:
Adjust the config flags and IDs in the .lua and .sql in case of conflicts and run the associated SQL to add the required NPCs. You can add more encounters by just adding more config flags.

It is possible to reward players for participating in events. There is a config flag each to award score for playing 5man and for raid encounters. The amouont of score is configurable too.
Another config flag allows to store any and all events in the db and visualize them, e.g. with a module for acore_cms.
-  the acore_cms module assumes that 1112001 is the boss of encounter 1 and adding +10 for each subsequent encounter (1112011 = boss for encounter 2 / 1112021 = boss for encounter 3, etc.)
-  While the boss entries always end with `1`, the summoning NPC ends with `2`, and the add NPCs end with `3`. 4-0 are reserved for future use.

## Website connection
To award score to a currency on an acore_cms powered website, the queries in [query-points.sql](https://github.com/55Honey/Acore_eventScripts/blob/main/scripts/query-points.sql) can be used.

## GM Usage:
Use .startevent $event $difficulty to start and spawn the NPC players can interact with. Use .stopevent to despawn it. Possibly offer teleports.
It is advised to not leave the event NPC unattended. In case a player bugs out, they can be returned to the game with `.modify phase 1`.

## Player Usage:
Be in a party or raid respectively. As the party/raid leader: Talk to the NPC. Go nuts!

**[Video of a 5man encounter](https://www.twitch.tv/videos/1052264022)**

**[Video of a raid encounter](https://www.twitch.tv/videos/1052269366)**

![image](https://user-images.githubusercontent.com/71938210/121605986-a8e7fb00-ca4d-11eb-9327-04535a674bc5.png)

![image](https://user-images.githubusercontent.com/71938210/121604233-6f61c080-ca4a-11eb-8c71-70774a9881ad.png)

# funTools.lua
## Admin Usage:
Adjust the config flags and IDs in the .lua. You can change spells, allowed maps and locations.

## GM Usage:
.fun gurubashi [$repeats]
will start an announcement about an incoming fun event happening every minute. Repeats defaults to 15.

The last Repetition will result in all players who are in open world and opt-in by typing '.fun on' to do the following:
- leave their parties/raids
- get resurrected and set to full health
- receive a strong hot
- have their position stored
- get teleported to Gurubashi Arena

## Player Usage:
`.fun on` to opt-in for the event.
`.fun no` to opt-out of the event (default).
`.fun return` they are teleported to their saved position and their saved position is deleted.
