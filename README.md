## EventScripts
Lua script for Azerothcore with ElunaLUA to spawn (custom) NPCs and grant them scripted combat abilities

#### Find me on patreon: https://www.patreon.com/Honeys

## Requirements:
Compile your [Azerothcore](https://github.com/azerothcore/azerothcore-wotlk) with [Eluna Lua](https://www.azerothcore.org/catalogue-details.html?id=131435473).
Requires at least commit b824e9d18683ecfa498279de8ed1e49c1bfd887d of the Eluna Engine submodule hence commit 81548013dc0748c1aeb15179fed6b7fe861b64bc from [mod-eluna-lua](https://github.com/azerothcore/mod-eluna-lua-engine).
The ElunaLua module itself usually doesn't require much setup/config. Just specify the subfolder where to put your lua_scripts in its .conf file.

If the directory was not changed in the ElunaLua config, add the .lua script to your `../lua_scripts/` directory as a subfolder of the worldserver.
Adjust the top part of the .lua file with the config flags.

## Admin Usage:
Adjust the config flags and IDs in the .lua and .sql in case of conflicts and run the associated SQL to add the required NPCs.

## GM Usage:
Use .startevent $event $difficulty to start and spawn the NPC players can interact with. Use .stopevent to despawn it. Possibly offer teleports.

## Player Usage:
Be in a party or raid respectively. As the party/raid leader: Talk to the NPC. 
